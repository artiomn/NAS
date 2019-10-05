# Реализация программной платформы защищённого NAS

![](https://static-media.fxx.com/img/FX_Networks_-_FXX/950/643/Simpsons_10_18_P2.jpg)

В [предыдущей статье](https://habr.com/post/359344/) было описано проектирование программной платформы NAS.
Настало время её реализовать.

<cut/>

## Проверка

Обязательно, перед тем, как начинать проверьте работоспособность пула:
```
zpool status -v
```

Пул и все диски в нём должны быть ONLINE.

Далее я предполагаю, что на предыдущем этапе всё было сделано по [инструкции](https://habr.com/post/351932/), и работает, либо вы сами хорошо понимаете, что делаете.


## Удобства

Прежде всего, стоит позаботиться об удобном управлении, если вы этого не сделали с самого начала.
Потребуются:

- SSH-сервер: `apt-get install openssh-server`. Если вы не знаете, как настроить SSH, ~~делать NAS на Linux пока рано~~ можете почитать особенности его использования в [данной статье](https://habr.com/company/lodoss/blog/358800/), затем воспользоваться [одним из мануалов](https://wiki.debian.org/SSH).
- [tmux](https://wiki.archlinux.org/index.php/Tmux_(%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9)) или [screen](https://ru.wikipedia.org/wiki/GNU_Screen): `apt-get install tmux`. Чтобы сохранять сессию при входах по SSH и использовать несколько окон.

После установки SSH надо добавить пользователя, чтобы не заходить через SSH под root (вход по умолчанию отключен и не надо его включать):

```bash
zfs create rpool/home/user
adduser user
cp -a /etc/skel/.[!.]* /home/user
chown -R user:user /home/user
```

Для удалённого администрирования это достаточный минимум.

Тем не менее, пока нужно держать подключенными клавиатуру и монитор, т.к. ещё потребуется перезагружаться при обновлении ядра и для того, чтобы убедиться в том, что всё работает сразу после загрузки.

Альтернативный вариант использовать Virtual KVM, который предоставляет [IME](https://ru.wikipedia.org/wiki/Intel_Management_Engine). Там есть консоль, правда в моём случае она реализована в виде Java апплета, что не очень удобно.


## Настройка

### Подготовка кэша

Насколько вы помните, в описанной мной конфигурации есть отдельный SSD под L2ARC, который пока не используется, но взят "на вырост".

Необязательно, но желательно заполнить этот SSD случайными данными (в случае Samsung EVO всё-равно заполнится нулями после выполнения blkdiscard, но не на всех SSD так):

```bash
dd if=/dev/urandom of=/dev/disk/by-id/ata-Samsung_SSD_850_EVO bs=4M && blkdiscard /dev/disk/by-id/ata-Samsung_SSD_850_EVO
```


### Отключение сжатия логов

На ZFS и так используется сжатие, потому сжатие логов через gzip будет явно лишним.
Выключаю:

```bash
for file in /etc/logrotate.d/* ; do
  if grep -Eq "(^|[^#y])compress" "$file" ; then
    sed -i -r "s/(^|[^#y])(compress)/\1#\2/" "$file"
  fi
done
```


### Обновление системы

Тут всё просто:

```bash
apt-get dist-upgrade --yes
reboot
```


### Создание снэпшота для нового состояния

После перезагрузки, чтобы зафиксировать новое рабочее состояние, надо переписать первый снэпшот:

```bash
zfs destroy rpool/ROOT/debian@install
zfs snapshot rpool/ROOT/debian@install
```


Организация файловых систем
---------------------------

### Подготовка разделов для SLOG

Первое, что нужно сделать с целью достижения нормальной производительности ZFS - это вынести SLOG на SSD.
Напомню, что SLOG в используемой конфигурации дублируется на двух SSD: для него будут созданы устройства на LUKS-XTS поверх 4-го раздела каждой SSD:

```bash
dd if=/dev/urandom of=/etc/keys/slog.key bs=1 count=4096

cryptsetup --verbose --cipher "aes-xts-plain64:sha512" --key-size 512 --key-file /etc/keys/slog.key luksFormat /dev/disk/by-id/ata-Samsung_SSD_850_PRO-part4

cryptsetup --verbose --cipher "aes-xts-plain64:sha512" --key-size 512 --key-file /etc/keys/slog.key luksFormat /dev/disk/by-id/ata-Micron_1100-part4

echo "slog0_crypt1 /dev/disk/by-id/ata-Samsung_SSD_850_PRO-part4 /etc/keys/slog.key luks,discard" >> /etc/crypttab

echo "slog0_crypt2 /dev/disk/by-id/ata-Micron_1100-part4 /etc/keys/slog.key luks,discard" >> /etc/crypttab
```


### Подготовка разделов для L2ARC и подкачки

Сначала надо создать разделы под swap и l2arc:

```bash
sgdisk -n1:0:48G -t1:8200 -c1:part_swap -n2::196G -t2:8200 -c2:part_l2arc /dev/disk/by-id/ata-Samsung_SSD_850_EVO
```

Раздел подкачки и L2ARC будут зашифрованы на случайном ключе, т.к. после перезагрузки они не требуются и их всегда возможно создать заново.
Поэтому в crypttab прописывается строка для шифрования/расшифрования разделов в plain режиме:

```bash
echo swap_crypt /dev/disk/by-id/ata-Samsung_SSD_850_EVO-part1 /dev/urandom swap,cipher=aes-xts-plain64:sha512,size=512 >> /etc/crypttab

echo l2arc_crypt /dev/disk/by-id/ata-Samsung_SSD_850_EVO-part2 /dev/urandom cipher=aes-xts-plain64:sha512,size=512 >> /etc/crypttab
```

Затем нужно перезапустить демоны и включить подкачку:

```bash
echo 'vm.swappiness = 10' >> /etc/sysctl.conf
sysctl vm.swappiness=10
systemctl daemon-reload
systemctl start systemd-cryptsetup@swap_crypt.service
echo /dev/mapper/swap_crypt none swap sw,discard 0 0 >> /etc/fstab
swapon -av
```

Т.к. активного использования подкачки на SSD не планируется, параметр `swapiness`, который умолчанию 60, нужно установить в 10.

L2ARC на данном этапе ещё не используется, но раздел под него уже готов:

```bash
$ ls /dev/mapper/
control  l2arc_crypt root_crypt1  root_crypt2  slog0_crypt1  slog0_crypt2  swap_crypt  tank0_crypt0  tank0_crypt1  tank0_crypt2  tank0_crypt3
```


### Пулы tankN

Будет описано создание пула `tank0`,  `tank1` создаётся по аналогии.

Чтобы не заниматься созданием одинаковых разделов вручную и не допускать ошибок, я написал [скрипт](https://github.com/artiomn/NAS/blob/master/scripts/create_crypt_pool.sh) для создания шифрованных разделов под пулы:
<spoiler title="create_crypt_pool.sh">

```bash
#!/bin/bash

KEY_SIZE=512
POOL_NAME="$1"
KEY_FILE="/etc/keys/${POOL_NAME}.key"
LUKS_PARAMS="--verbose --cipher aes-xts-plain64:sha${KEY_SIZE} --key-size $KEY_SIZE"

[ -z "$1" ] && { echo "Error: pool name empty!" ; exit 1; }

shift

[ -z "$*" ] && { echo "Error: devices list empty!" ; exit 1; }

echo "Devices: $*"
read -p "Is it ok? " a

[ "$a" != "y" ] && { echo "Bye"; exit 1; }

dd if=/dev/urandom of=$KEY_FILE bs=1 count=4096

phrase="?"

read -s -p "Password: " phrase
echo
read -s -p "Repeat password: " phrase1
echo

[ "$phrase" != "$phrase1" ] && { echo "Error: passwords is not equal!" ; exit 1; }

echo "### $POOL_NAME" >> /etc/crypttab

index=0

for i in $*; do
  echo "$phrase"|cryptsetup $LUKS_PARAMS luksFormat "$i" || exit 1
  echo "$phrase"|cryptsetup luksAddKey "$i" $KEY_FILE || exit 1
  dev_name="${POOL_NAME}_crypt${index}"
  echo "${dev_name} $i $KEY_FILE luks" >> /etc/crypttab
  cryptsetup luksOpen --key-file $KEY_FILE "$i" "$dev_name" || exit 1
  index=$((index + 1))
done

echo "###" >> /etc/crypttab

phrase="====================================================="
phrase1="================================================="
unset phrase
unset phrase1
```
</spoiler>

Теперь, используя данный скрипт, надо создать пул для хранения данных:

```bash
./create_crypt_pool.sh

zpool create -o ashift=12 -O atime=off -O compression=lz4 -O normalization=formD  tank0 raidz1 /dev/disk/by-id/dm-name-tank0_crypt*
```

Замечания о параметре `ashift=12` смотрите в моих [предыдущих](https://habr.com/post/358914/) [статьях](https://habr.com/post/351932/) и комментариях к ним.

После создания пула, я выношу его журнал на SSD:

```bash
zpool add tank0 log mirror /dev/disk/by-id/dm-name-slog0_crypt1 /dev/disk/by-id/dm-name-slog0_crypt2
```

В дальнейшем, при установленном и настроенном OMV, возможно будет создавать пулы через GUI:

[![Создание ZFS пал в OMV WEB GUI](https://habrastorage.org/webt/bu/bc/qj/bubcqjn_frfc3plifb9ehgzxco0.png)](https://habrastorage.org/webt/bu/bc/qj/bubcqjn_frfc3plifb9ehgzxco0.png)


### Включение импорта пулов и автомонтирования томов при загрузке

Для того, чтобы гарантированно включить автомонтирование пулов, выполните следующие команды:

```bash
rm /etc/zfs/zpool.cache
systemctl enable zfs-import-scan.service
systemctl enable zfs-mount.service
systemctl enable zfs-import-cache.service
```

На данном этапе закончена настройка дисковой подсистемы.


Операционная система
--------------------

Первым делом надо установить и настроить OMV, чтобы наконец получить какую-то основу для NAS.


### Установка OMV

OMV будет установлен в виде deb-пакета. Для того, чтобы это сделать, возможно воспользоваться [официальной инструкцией](https://openmediavault.readthedocs.io/en/latest/installation/on_debian.html).

Скрипт `add_repo.sh` добавляет репозиторий OMV Arrakis в`/etc/apt/ sources.list.d`, чтобы пакетная система увидела репозиторий.

<spoiler title="add_repo.sh">
```bash
cat <<EOF >> /etc/apt/sources.list.d/openmediavault.list
deb http://packages.openmediavault.org/public arrakis main
# deb http://downloads.sourceforge.net/project/openmediavault/packages arrakis main
## Uncomment the following line to add software from the proposed repository.
# deb http://packages.openmediavault.org/public arrakis-proposed main
# deb http://downloads.sourceforge.net/project/openmediavault/packages arrakis-proposed main
## This software is not part of OpenMediaVault, but is offered by third-party
## developers as a service to OpenMediaVault users.
deb http://packages.openmediavault.org/public arrakis partner
# deb http://downloads.sourceforge.net/project/openmediavault/packages arrakis partner
EOF
```
</spoiler>

Обратите внимание, что по сравнению с оригиналом, репозиторий partner включен.

Для установки и первичной инициализации надо выполнить команды, приведённые ниже.

<spoiler title="Команды для установки OMV.">
```bash
./add_repo.sh
export LANG=C
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
apt-get update
apt-get --allow-unauthenticated install openmediavault-keyring
apt-get update
apt-get --yes --auto-remove --show-upgraded \
    --allow-downgrades --allow-change-held-packages \
    --no-install-recommends \
    --option Dpkg::Options::="--force-confdef" \
    --option DPkg::Options::="--force-confold" \
    install postfix openmediavault
# Initialize the system and database.
omv-initsystem
```
</spoiler>

OMV установлен. Он использует своё ядро, и после установки может потребоваться перезагрузка.

Перезагрузившись, интерфейс OpenMediaVault, будет доступен на порту 80 (зайдите в браузере на NAS по IP-адресу):

[![](https://habrastorage.org/webt/eo/sf/ra/eosfraeilpg2dn770ef5bvr-ple.png)](https://habrastorage.org/webt/eo/sf/ra/eosfraeilpg2dn770ef5bvr-ple.png)

Логин/пароль по умолчанию: `admin/openmediavault`.


### Настройка OMV

Далее большая часть настройки будет проходить через WEB-GUI.


#### Установка безопасного соединения

Сейчас надо сменить пароль WEB-администратора и сгенерировать сертификат для NAS, чтобы в дальнейшем работать по HTTPS.

Смена пароля производится на вкладке _"Система->Общие настройки->Пароль Web Администратора"_.
Для генерация сертификата на вкладке _"Система->Сертификаты->SSL"_ надо выбрать _"Добавить->Создать"_.

Созданный сертификат будет виден на той же вкладке:

[![Сертификат](https://habrastorage.org/webt/ld/6j/_m/ld6j_mgp4tx6auirzlkfnwium2c.png)](https://habrastorage.org/webt/ld/6j/_m/ld6j_mgp4tx6auirzlkfnwium2c.png)

После создания сертификата, на вкладке _"Система->Общие настройки"_ надо включить флажок _"Включить SSL/TLS"_.

Сертификат потребуется до завершения настройки. В окончательном варианте для обращения к OMV будет использоваться подписанный сертификат.

Теперь надо перелогиниться в OMV, на порт 443 или просто приписав в браузере префикс `https://` перед IP.

Если войти удалось, на вкладке _"Система->Общие настройки"_ надо включить флажок "Принудительно SSL/TLS".

**Измените порты 80 и 443 на 10080 и 10443**.
И попробуйте войти по следующему адресу: `https://IP_NAS:10443`.
Изменение портов важно, потому что порты 80 и 443 будет использовать docker контейнер с nginx-reverse-proxy.


### Первичные настройки

Минимальные настройки, которое надо сделать в первую очередь:
- На вкладке _"Система->Дата и Время"_ проверьте значение часового пояса и задайте сервер NTP.
- На вкладке _"Система->Мониторинг"_ включите сбор статистики производительности.
- На вкладке _"Система->Управление энергопотреблением"_ видимо стоит выключить "Мониторинг", чтобы OMV не пытался управлять вентиляторами.


### Сеть

Если второй сетевой интерфейс NAS ещё не был подключен, подключите его к роутеру.

Затем:

- На вкладке _"Система->Сеть"_ установите имя хоста в значение "nas" (или то, которые вам нравится).
- Настройте бондинг для интерфейсов, как показано на рисунке ниже: _"Система->Сеть->Интерфейсы->Добавить->Bond"_.
- Добавьте нужные правила файрволла на вкладке _"Система->Сеть->Брандмауэр"_. Для начала достаточно доступа на порты 10443, 10080, 443, 80, 22 для SSH и разрешения получения/отправки ICMP.

[![Настройка бондинга](https://habrastorage.org/webt/rb/fi/ab/rbfiabiimceoohildwosfu_egju.png)](https://habrastorage.org/webt/rb/fi/ab/rbfiabiimceoohildwosfu_egju.png)

В результате, должны появиться интерфейсы в бондинге, которые роутер будет видеть, как один интерфейс и присвоит ему один IP адрес:

[![Интерфейсы в бондинге](https://habrastorage.org/webt/ag/wr/y8/agwry8ynozq7dhgov16pzzwmrs0.png)](https://habrastorage.org/webt/ag/wr/y8/agwry8ynozq7dhgov16pzzwmrs0.png)

При желании, возможно дополнительно настроить SSH из WEB GUI:

[![Настройка SSH](https://habrastorage.org/webt/yk/oa/i4/ykoai4l9risd46whpuutbnyi1um.png)](https://habrastorage.org/webt/yk/oa/i4/ykoai4l9risd46whpuutbnyi1um.png)


### Репозитории и модули

На вкладке _"Система->Управление обновлениями->Настройки"_ включите _"Обновления поддерживаемые сообществом"_.

Сначала требуется добавить [репозитории OMV extras](http://omv-extras.org/).
Это возможно сделать просто установив плагин, либо пакет, как указано на [форуме](https://forum.openmediavault.org/index.php/Thread/5549-OMV-Extras-org-Plugin/).

На странице _"Система->Плагины"_ надо найти плагин "openmediavault-omvextrasorg" и установить его.

В результате, в меню системы появится значок "OMV-Extras" (его возможно видеть на скриншотах).

Зайдите туда и включите следующие репозитории:

- OMV-Extras.org. Стабильный репозиторий, содержащий много плагинов.
- OMV-Extras.org Testing. Некоторые плагины из этого репозитория отсутствуют в стабильном репозитории.
- Docker CE. Собственно, Docker.

На вкладке _"Система->OMV Extras->Ядро"_ вы можете выбрать нужное вам ядро, в том числе ядро от Proxmox (сам я его не ставил, т.к. мне пока не нужно, потому не рекомендую):

[![](https://habrastorage.org/webt/dq/se/jq/dqsejqlsyn0x6wdbyfeb2kvlwmc.png)](https://habrastorage.org/webt/dq/se/jq/dqsejqlsyn0x6wdbyfeb2kvlwmc.png)

Установите необходимые плагины (**жирным** выделены абсолютно необходимые, _курсивом_ - опциональные, которые я не устанавливал):
<spoiler title="Список плагинов.">
- openmediavault-apttool. Минимальный GUI для работы с пакетной системой. Добавляет _"Сервисы->Apttool"_.
- openmediavault-anacron. Добавляет возможность работы из GUI с асинхронным планировщиком. Добавляет _"Система->Anacron"_.
- openmediavault-backup. Обеспечивает резервное копирование системы в хранилище. Добавляет страницу _"Система->Резервное копирование"_.
- openmediavault-diskstats. Нужен для сбора статистики по производительности дисков.
- _openmediavault-dnsmasq_. Позволяет поднять на NAS сервер DNS и DHCP. Т.к., я делаю это на роутере, мне не требуется.
- **openmediavault-docker-gui**. Интерфейс управления Docker контейнерами. Добавляет _"Сервисы->Docker"_.
- **openmediavault-ldap**. Поддержка аутентификации через LDAP. Добавляет _"Управление правами доступа->Служба каталогов"_.
- _openmediavault-letsencrypt_. Поддержка Let's Encrypt из GUI. Не нужна, потому что используется встраивание в контейнер nginx-reverse-proxy.
- **openmediavault-luksencryption**. Поддержка шифрования LUKS. Нужен, чтобы в интерфейсе OMV были видны шифрованные диски. Добавляет _"Хранилище->Шифрование"_.
- **openmediavault-nut**. Поддержка ИБП. Добавляет _"Сервисы->ИБП"_.
- **openmediavault-omvextrasorg**. OMV Extras уже должен быть установлен.
- openmediavault-resetperms. Позволяет переустанавливать права и сбрасывать списки контроля доступа на общих каталогах. Добавляет _"Управление правами доступа->Общие каталоги->Reset Permissions"_.
- openmediavault-route. Полезный плагин для управления маршрутизацией. Добавляет _"Система->Сеть->Статический маршрут"_.
- openmediavault-symlinks. Предоставляет возможность создавать символические ссылки. Добавляет страницу _"Сервисы->Symlinks"_.
- openmediavault-unionfilesystems. Поддержка UnionFS. Может пригодиться в будущем, хотя докер и использует ZFS в качестве бэкэнда. Добавляет _"Хранилище->Union Filesystems"_.
- _openmediavault-virtualbox_. Может быть использован для встраивания в GUI возможности управления виртуальными машинами.
- **openmediavault-zfs**. Плагин добавляет поддержку ZFS в OpenMediaVault. После установки появится страница _"Хранилище->ZFS"_.
</spoiler>


### Диски

Все диски, которые есть в системе, должны быть видны OMV. Удостоверьтесь в этом, посмотрев на вкладке _"Хранилище->Диски"_. Если не все диски видны, запустите сканирование.

[![Диски в системе](https://habrastorage.org/webt/ju/i3/rs/jui3rsmgmatghluwuk0rknsqfrq.png)](https://habrastorage.org/webt/ju/i3/rs/jui3rsmgmatghluwuk0rknsqfrq.png)

Там же, на всех HDD надо включить кэширование записи (кликнув на диске из списка и нажав кнопку "Редактировать").

Удостоверьтесь, что видны все шифрованные разделы на вкладке _"Хранилище->Шифрование"_:

[![Шифрованные разделы](https://habrastorage.org/webt/dy/nw/kv/dynwkvuhbnglzeqe3sin_vqda7i.png)](https://habrastorage.org/webt/dy/nw/kv/dynwkvuhbnglzeqe3sin_vqda7i.png)

Теперь пора настроить S.M.A.R.T., указанный, как средство повышения надёжности:
- Перейдите на вкладку _"Хранилище->S.M.A.R.T->Настройки"_. Включите SMART.
- Там же выберите значения температурных уровней дисков (критический, как правило 60 C, а [оптимальный температурный режим диска](https://www.backblaze.com/blog/hard-drive-temperature-does-it-matter/) 15-45 C).
- Перейдите на вкладку _"Хранилище->S.M.A.R.T->Устройства"_. Включите мониторинг для каждого диска.
[![](https://habrastorage.org/webt/83/r-/dc/83r-dcwtrhth5icaketuw1zlis8.png)](https://habrastorage.org/webt/83/r-/dc/83r-dcwtrhth5icaketuw1zlis8.png)
- Перейдите на вкладку _"Хранилище->S.M.A.R.T->Запланированные тесты"_. Добавьте для каждого диска короткую самопроверку раз в сутки и длительную самопроверку раз в месяц. Причём так, чтобы периоды самопроверки не пересекались.
[![](https://habrastorage.org/webt/lh/u8/qf/lhu8qffcenb8utgcekfoy_j0oee.png)](https://habrastorage.org/webt/lh/u8/qf/lhu8qffcenb8utgcekfoy_j0oee.png)

На этом настройку дисков возможно считать оконченной.


### Файловые системы и общие каталоги

Надо создать файловые системы для предопределённых каталогов.
Сделать это возможно из консоли, либо из WEB-интерфейса OMV (_Хранилище->ZFS->Выбрать пул tank0->Кнопка "Добавить"->Filesystem_).

<spoiler title="Команды для создания ФС.">
```
zfs create -o utf8only=on -o normalization=formD -p tank0/user_data/books
zfs create -o utf8only=on -o normalization=formD -p tank0/user_data/music
zfs create -o utf8only=on -o normalization=formD -p tank0/user_data/pictures
zfs create -o utf8only=on -o normalization=formD -p tank0/user_data/downloads
zfs create -o compression=off -o utf8only=on -o normalization=formD -p tank0/user_data/videos
```
</spoiler>

В итоге должна получиться следующая структура каталогов:

[![](https://habrastorage.org/webt/ua/uy/yk/uauyykwki2nmmmpj6pe3-lqxrie.png)](https://habrastorage.org/webt/ua/uy/yk/uauyykwki2nmmmpj6pe3-lqxrie.png)

После этого, добавьте созданные ФС, как общие каталоги на странице _"Управление правами доступа->Общие каталоги->Добавить"_.
Обратите внимание, что параметр _"Устройство"_ равен пути к созданной в ZFS файловой системе, а параметр _"Путь"_ у всех каталогов равен "/".

[![](https://habrastorage.org/webt/xc/9v/da/xc9vdaubqewzyhqfm80k_751fo8.png)](https://habrastorage.org/webt/xc/9v/da/xc9vdaubqewzyhqfm80k_751fo8.png)


### Резервное копирование

Резервное копирование производится двумя инструментами:

- [OMV backup plugin](https://github.com/OpenMediaVault-Plugin-Developers/openmediavault-backup). Плагин OMV для резервного копирования системы.
- [zfs-auto-snapshot](https://github.com/zfsonlinux/zfs-auto-snapshot). Скрипт для автоматического создания снимков ZFS по расписанию и удаления старых.

Если вы воспользуетесь плагином, скорее всего получите ошибку:

```
lsblk: /dev/block/0:22: not a block device
```

Для того, чтобы её исправить, [по замечанию разработчиков OMV](https://github.com/OpenMediaVault-Plugin-Developers/openmediavault-backup/issues/16) в этой "очень нестандартной конфигурации", возможно было бы отказаться от плагина и воспользоваться средствами ZFS в виде [`zfs send/receive`](https://docs.oracle.com/cd/E19253-01/820-0836/gbchx/index.html).
Либо явно указать параметр "Root device" в виде физического устройства, с которого производится загрузка.
Мне удобнее использовать плагин и делать резервное копирование ОС из интерфейса, вместо того, чтобы городить что-то своё с zfs send, потому я предпочитаю второй вариант.

[![Настройка резервного копирования](https://habrastorage.org/webt/q8/hm/k9/q8hmk9guerk2it7d1xe4tuzvtak.png)](https://habrastorage.org/webt/q8/hm/k9/q8hmk9guerk2it7d1xe4tuzvtak.png)

Чтобы резервное копирование работало, сначала создайте через ZFS файловую систему `tank0/apps/backup`, затем в меню _"Система->Резервирование"_ кликните "+" в поле параметра _"Общая папка"_ и добавьте созданное устройство, как целевое, а поле _"Путь"_ установите в "/".

С zfs-auto-snapshot тоже есть проблемы. Если её не настроить, она будет делать снимки каждый час, каждый день, каждую неделю, каждый месяц в течение года.
В итоге получится то, что на скриншоте:

[![Много спама от zfs-auto-snapshot](https://habrastorage.org/webt/af/_j/gw/af_jgw_evodbuhm07iqwpjh-he8.png)](https://habrastorage.org/webt/af/_j/gw/af_jgw_evodbuhm07iqwpjh-he8.png)

Если вы уже на это натолкнулись, выполните следующий код для удаления автоматических снимков:

```
zfs list -t snapshot -o name -S creation | grep "@zfs-auto-snap" | tail -n +1500 | xargs -n 1 zfs destroy -vr
```

Затем настройте запуск zfs-auto-snapshot в cron.
Для начала, просто удалите `/etc/cron.hourly/zfs-auto-snapshot`, если вам не требуется делать снимки каждый час.


### E-mail уведомления

Нотификация по e-mail была указана, как одно из средств достижения надёжности.
Потому теперь надо настроить E-mail уведомления.
Для этого, зарегистрируйте на одном из публичных серверов ящик (ну либо настройте SMTP сервер самостоятельно, если у вас действительно есть причины это сделать).

После чего надо зайти на страницу _"Система->Уведомление"_ и вписать:

- Адрес SMTP сервера.
- Порт SMTP сервера.
- Имя пользователя.
- Адрес отправителя (обычно первая компонента адреса совпадает с именем).
- Пароль пользователя.
- В поле "Получатель" ваш обычный адрес, на который NAS будет отправлять уведомления.

Крайне желательно включить SSL/TLS.

Пример настройки для Yandex показан на скриншоте:

[![E-mail уведомления](https://habrastorage.org/webt/4j/pb/2m/4jpb2mwgystnu_3yc9vf9l16soo.png)](https://habrastorage.org/webt/4j/pb/2m/4jpb2mwgystnu_3yc9vf9l16soo.png)


## Настройка сети вне NAS

### IP-адрес

Я использую белый статический IP-адрес, который стоит плюсом 100 рублей в месяц. Если нет желания платить и ваш адрес динамический, но не за NAT, возможно корректировать внешние DNS записи через API выбранного сервиса.
Тем не менее, стоит иметь ввиду, что адрес не за NAT может внезапно стать адресом за NAT: как правило, провайдеры не дают никаких гарантий.


### Роутер

В качестве роутера у меня [Mikrotik RouterBoard](https://mikrotik.com/product/RB951Ui-2HnD), похожий на тот, что на картинке ниже.

[![Mikrotik Routerboard](https://habrastorage.org/webt/ni/mv/a8/nimva8ju1vg2doqcnwd7s0_xcmw.jpeg)](https://habrastorage.org/webt/ni/mv/a8/nimva8ju1vg2doqcnwd7s0_xcmw.jpeg)

На роутере требуется сделать три вещи:

- Настроить статические адреса для NAS. В моём случае, адреса выдаются по DHCP, и надо сделать так, чтобы адаптерам с определённым MAC адресом всегда выдавался один и тот же IP адрес. В RouterOS это делается на вкладке _"IP->DHCP Server"_ кнопкой _"Make static"_.
- Настроить DNS сервер так, чтобы он для имени "nas", а также имён, оканчивающихся на ".nas" и ".NAS.cloudns.cc" (где "NAS" - зона на ClouDNS или подобном сервисе) отдавал IP системы. Где это сделать в RouterOS, показано на скриншоте ниже. В моём случае, это реализовано путём сопоставления имени с регулярным выражением: "`^.*\.nas$|^nas$|^.*\.NAS.cloudns.cc$`"
- Настроить проброс портов. В RouterOS это делается на вкладке _"IP->Firewall"_, далее останавливаться я на этом не буду.

[![Настройка DNS в RouterOS](https://habrastorage.org/webt/wu/2d/3n/wu2d3ng2xlqaleslb__9a72vtpo.png)](https://habrastorage.org/webt/wu/2d/3n/wu2d3ng2xlqaleslb__9a72vtpo.png)


### ClouDNS

С CLouDNS всё просто. Заводите аккаунт, подтверждаете. NS записи уже у вас будут прописаны. Далее требуется минимальная настройка.

Во-первых, нужно создать необходимые зоны (зона с именем NAS, подчёркнутая на скриншоте красным - это то, что вы должны создать, с другим названием, конечно).

[![Создание зоны в ClouDNS](https://habrastorage.org/webt/wj/3k/0u/wj3k0ueaouj9tdslhubqtdz49os.png)](https://habrastorage.org/webt/wj/3k/0u/wj3k0ueaouj9tdslhubqtdz49os.png)

Во-вторых, в этой зоне вы должны прописать следующие [A-записи](http://www.wikireality.ru/wiki/A-запись):

- **nas**, **www**, **omv**, **control** и **пустое имя**. Для обращения к интерфейсу OMV.
- **ldap**. Интерфейс PhpLdapAdmin.
- **ssp**. Интерфейс для смены паролей пользователей.
- **test**. Тестовый сервер.

Остальные доменные имена будут добавляться по мере добавления служб.
Кликайте на зону, далее _"Add new record"_, выбираете A-тип, вводите имя зоны и IP адрес роутера, за которым стоит NAS.

[![Добавленные A-записи](https://habrastorage.org/webt/ym/9o/s2/ym9os2upazemboftovtmasp3h1u.png)](https://habrastorage.org/webt/ym/9o/s2/ym9os2upazemboftovtmasp3h1u.png)

Во-вторых, требуется получить доступ к API. В ClouDNS он платный, так что предварительно надо его оплатить. В других сервисах он бесплатный. Если знаете, что лучше, и это поддерживается [Lexicon](https://github.com/AnalogJ/lexicon), напишите пожалуйста в комментариях.

Получив доступ к API, туда надо добавить нового пользователя API.

[![Добавление пользователя API ClouDNS](https://habrastorage.org/webt/ah/tc/rp/ahtcrpidjt3gvlnuc-udwjj0no8.png)](https://habrastorage.org/webt/ah/tc/rp/ahtcrpidjt3gvlnuc-udwjj0no8.png)

В поле _"IP address"_ надо вписать IP роутера: это адрес, с которого будет доступен API. После того, как пользователь будет добавлен, вы сможете использовать API, авторизовавшись по **auth-id** и **auth-password**. Их надо будет передавать в Lexicon, как параметры.

[![](https://habrastorage.org/webt/z_/6k/yv/z_6kyvkyj9gqlbi_s-dudfoirzs.png)](https://habrastorage.org/webt/z_/6k/yv/z_6kyvkyj9gqlbi_s-dudfoirzs.png)

На этом настройка ClouDNS закончена.


Настройка контейнеризации
-------------------------

### Настройка Docker

Если вы установили плагин openmediavault-docker-gui, пакет docker-ce уже должен был подтянуться по зависимостям.

Дополнительно, установите пакет [docker-compose](https://docs.docker.com/compose/overview/), поскольку в дальнейшем он будет использован для управления контейнерами:

```bash
apt-get install docker-compose
```

Также создайте файловую систему под конфигурацию сервисов:

```bash
zfs create -p /tank0/docker/services
```

Все настройки, образы и контейнеры докера хранятся в `/var/lib/docker`. Он туда интенсивно пишет (надо помнить, что это SSD), но главное, создаёт снэпшоты, клоны и файловые системы с именами в виде хэшей.

Т.о., через некоторое время там скопится достаточно много мусора и будет не особенно удобно 
с ним разбираться. Пример на скриншоте.

[![](https://habrastorage.org/webt/wn/by/ec/wnbyecyxrlrsf0cssx78zqmoxdu.png)](https://habrastorage.org/webt/wn/by/ec/wnbyecyxrlrsf0cssx78zqmoxdu.png)

Чтобы этого избежать, надо локализовать каталог с данными на отдельной файловой системе.
Изменить расположение базового пути докера не сложно, это возможно сделать даже через GUI плагина, но тогда возникнет проблема: [пулы перестанут монтироваться при загрузке](https://github.com/OpenMediaVault-Plugin-Developers/openmediavault-zfs/issues/42#issuecomment-378410324), т.к. докер создаст свои каталоги в точке монтирования, и она будет не пуста.

Решается эта проблема заменой каталога докера в `/var/lib` на символическую ссылку:

```bash
service docker stop
zfs create -o com.sun:auto-snapshot=false -p /tank0/docker/lib
rm -rf /var/lib/docker
ln -s  /tank0/docker/lib /var/lib/docker
service docker start
```

В результате:

```bash
$ ls -l /var/lib/docker
lrwxrwxrwx 1 root root 17 Apr  7 12:35 /var/lib/docker -> /tank0/docker/lib
```

Теперь надо создать межконтейнерную сеть:

```bash
docker network create docker0
```

На этом первичная настройка Docker закончена и возможно приступать к созданию контейнеров.


### Настройка контейнера с nginx-reverse-proxy

После того как Docker настроен, возможно приступить к реализации диспетчера.

Найти все конфигурационные файлы вы можете [здесь](https://github.com/artiomn/NAS/tree/master/docker/services/nginx-proxy), либо под спойлерами.

Для него используются два образа: [nginx-proxy](https://github.com/jwilder/nginx-proxy) и [letsencrypt-dns](https://github.com/adferrand/docker-letsencrypt-dns).

Напомню, что порты интерфейса OMV требуется изменить на 10080 и 10443, потому что диспетчер будет работать на портах 80 и 443.

<spoiler title="/tank0/docker/services/nginx-proxy/docker-compose.yml">
```yaml
version: '2'

networks:
  docker0:
    external:
      name: docker0

services:
  nginx-proxy:
    networks:
      - docker0
    restart: always
    image: jwilder/nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./certs:/etc/nginx/certs:ro
      - ./vhost.d:/etc/nginx/vhost.d
      - ./html:/usr/share/nginx/html
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - ./local-config:/etc/nginx/conf.d
      - ./nginx.tmpl:/app/nginx.tmpl
    labels:
      - "com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy=true"

  letsencrypt-dns:
    image: adferrand/letsencrypt-dns
    volumes:
      - ./certs/letsencrypt:/etc/letsencrypt
    environment:
      - "LETSENCRYPT_USER_MAIL=MAIL@MAIL.COM"
      - "LEXICON_PROVIDER=cloudns"
      - "LEXICON_OPTIONS=--delegated NAS.cloudns.cc"
      - "LEXICON_PROVIDER_OPTIONS=--auth-id=CLOUDNS_ID --auth-password=CLOUDNS_PASSWORD"
```
</spoiler>

В данном конфиге настраиваются два контейнера:

- nginx-reverse-proxy - cам обратный прокси.
- letsencrypt-dns - [ACME клиент](https://letsencrypt.org/docs/client-options/) Let's Encrypt.

Для создания и запуска контейнера с nginx-reverse-proxy используется образ [jwilder/nginx-proxy](https://hub.docker.com/r/jwilder/nginx-proxy/).

`docker0` - межконтейнерная сеть, которая была создана ранее, ей не управляет docker-compose.
`nginx-proxy` - сервис обратного прокси, собственной персоной. Он смотрит в сеть docker0. При этом, порты 80 и 443 в секции ports пробрасываются на аналогичные порты хоста (значит, на хосте будут открыты такие же порты, а данные с них будут перенаправляться на порты в сети docker0, которые слушает прокси).
Параметр [`restart: always`](https://docs.docker.com/compose/compose-file/#restart) означает, что нужно запускать этот сервис при перезагрузке.

Тома:

- Внешний каталог **`certs`** отображается в **`/etc/nginx/certs`** - там лежат сертификаты, включая сертификаты, полученные от Let's Encrypt. Это общий каталог между контейнером с прокси и контейнером с ACME клиентом.
- `./vhost.d:/etc/nginx/vhost.d` - конфигурация отдельных виртуальных хостов. Сейчас не использую.
- `./html:/usr/share/nginx/html` - статичный контент. Там не нужно ничего настраивать.
- **`/var/run/docker.sock`**, отображаемый в **`/tmp/docker.sock`** - сокет для связи с демоном Docker на хосте. Нужен для работы docker-gen внутри оригинального образа.
- **`./local-config`**, отображаемый в **`/etc/nginx/conf.d`** - дополнительные конфигурационные файлы nginx. Требуется для тюнинга параметров, о которых ниже.
- **`./nginx.tmpl`**, отображаемый в **`/app/nginx.tmpl`** - шаблон для конфигурационного файла nginx, из которого docker-gen создаст конфиг.

Контейнер letsencrypt-dns создаётся из образа [adferrand/letsencrypt-dns](https://hub.docker.com/r/adferrand/letsencrypt-dns/). Он включает упомянутый выше ACME клиент и Lexicon, для общения с провайдером DNS зоны.

Общий каталог `certs/letsencrypt` отображается в `/etc/letsencrypt` внутри контейнера.

Чтобы это заработало, требуется настроить ещё несколько переменных окружения внутри контейнера:

- **`LETSENCRYPT_USER_MAIL=MAIL@MAIL.COM`** - почта пользователя Let's Encrypt. Лучше тут указать реальную почту, на которую будут приходить всякие сообщения.
- **`LEXICON_PROVIDER=cloudns`** - провайдер для Lexicon. В моём случае - `cloudns`.
- **`LEXICON_PROVIDER_OPTIONS=--auth-id=CLOUDNS_ID --auth-password=CLOUDNS_PASSWORD --delegated=NAS.cloudns.cc`** - CLOUDNS_ID на последнем скриншоте в секции по настройке ClouDNS подчёркнут красным. CLOUDNS_PASSWORD - это пароль, который вы задали для пользования API. NAS.cloudns.cc, где NAS - имя вашей DNS зоны. Для cloudns нужен потому, что по умолчанию будут передаваться первые два компонента домена (cloudns.cc), а ClouDNS API требует указывать зону в запросе.

После этой настройки будут два независимо работающих контейнера: прокси и агент для получения сертификата.
При этом, прокси будет искать сертификат в каталогах, указанных в конфиге, но не в структуре каталогов, которую создаст агент Let's encrypt:

```
$ ls ./certs/letsencrypt/
accounts  archive  csr  domains.conf  keys  live  renewal  renewal-hooks
```

Для того, чтобы прокси начал видеть полученные сертификаты, требуется немного исправить шаблон.

<spoiler title="/tank0/docker/services/nginx-proxy/nginx.tmpl">
```
{{ $CurrentContainer := where $ "ID" .Docker.CurrentContainerID | first }}

{{ define "upstream" }}
	{{ if .Address }}
		{{/* If we got the containers from swarm and this container's port is published to host, use host IP:PORT */}}
		{{ if and .Container.Node.ID .Address.HostPort }}
			# {{ .Container.Node.Name }}/{{ .Container.Name }}
			server {{ .Container.Node.Address.IP }}:{{ .Address.HostPort }};
		{{/* If there is no swarm node or the port is not published on host, use container's IP:PORT */}}
		{{ else if .Network }}
			# {{ .Container.Name }}
			server {{ .Network.IP }}:{{ .Address.Port }};
		{{ end }}
	{{ else if .Network }}
		# {{ .Container.Name }}
		{{ if .Network.IP }}
			server {{ .Network.IP }} down;
		{{ else }}
			server 127.0.0.1 down;
		{{ end }}
	{{ end }}
	
{{ end }}

# If we receive X-Forwarded-Proto, pass it through; otherwise, pass along the
# scheme used to connect to this server
map $http_x_forwarded_proto $proxy_x_forwarded_proto {
  default $http_x_forwarded_proto;
  ''      $scheme;
}

# If we receive X-Forwarded-Port, pass it through; otherwise, pass along the
# server port the client connected to
map $http_x_forwarded_port $proxy_x_forwarded_port {
  default $http_x_forwarded_port;
  ''      $server_port;
}

# If we receive Upgrade, set Connection to "upgrade"; otherwise, delete any
# Connection header that may have been passed to this server
map $http_upgrade $proxy_connection {
  default upgrade;
  '' close;
}

# Apply fix for very long server names
server_names_hash_bucket_size 128;

# Default dhparam
{{ if (exists "/etc/nginx/dhparam/dhparam.pem") }}
ssl_dhparam /etc/nginx/dhparam/dhparam.pem;
{{ end }}

# Set appropriate X-Forwarded-Ssl header
map $scheme $proxy_x_forwarded_ssl {
  default off;
  https on;
}

gzip_types text/plain text/css application/javascript application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;

log_format vhost '$host $remote_addr - $remote_user [$time_local] '
                 '"$request" $status $body_bytes_sent '
                 '"$http_referer" "$http_user_agent"';

access_log off;

{{ if $.Env.RESOLVERS }}
resolver {{ $.Env.RESOLVERS }};
{{ end }}

{{ if (exists "/etc/nginx/proxy.conf") }}
include /etc/nginx/proxy.conf;
{{ else }}
# HTTP 1.1 support
proxy_http_version 1.1;
proxy_buffering off;
proxy_set_header Host $http_host;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $proxy_connection;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $proxy_x_forwarded_proto;
proxy_set_header X-Forwarded-Ssl $proxy_x_forwarded_ssl;
proxy_set_header X-Forwarded-Port $proxy_x_forwarded_port;

# Mitigate httpoxy attack (see README for details)
proxy_set_header Proxy "";
{{ end }}

{{ $enable_ipv6 := eq (or ($.Env.ENABLE_IPV6) "") "true" }}
server {
	server_name _; # This is just an invalid value which will never trigger on a real hostname.
	listen 80;
	{{ if $enable_ipv6 }}
	listen [::]:80;
	{{ end }}
	access_log /var/log/nginx/access.log vhost;
	return 503;
}

{{ if (and (exists "/etc/nginx/certs/default.crt") (exists "/etc/nginx/certs/default.key")) }}
server {
	server_name _; # This is just an invalid value which will never trigger on a real hostname.
	listen 443 ssl http2;
	{{ if $enable_ipv6 }}
	listen [::]:443 ssl http2;
	{{ end }}
	access_log /var/log/nginx/access.log vhost;
	return 503;

	ssl_session_tickets off;
	ssl_certificate /etc/nginx/certs/default.crt;
	ssl_certificate_key /etc/nginx/certs/default.key;
}
{{ end }}

{{ range $host, $containers := groupByMulti $ "Env.VIRTUAL_HOST" "," }}

{{ $host := trim $host }}
{{ $is_regexp := hasPrefix "~" $host }}
{{ $upstream_name := when $is_regexp (sha1 $host) $host }}

# {{ $host }}
upstream {{ $upstream_name }} {

{{ range $container := $containers }}
	{{ $addrLen := len $container.Addresses }}

	{{ range $knownNetwork := $CurrentContainer.Networks }}
		{{ range $containerNetwork := $container.Networks }}
			{{ if (and (ne $containerNetwork.Name "ingress") (or (eq $knownNetwork.Name $containerNetwork.Name) (eq $knownNetwork.Name "host"))) }}
				## Can be connected with "{{ $containerNetwork.Name }}" network

				{{/* If only 1 port exposed, use that */}}
				{{ if eq $addrLen 1 }}
					{{ $address := index $container.Addresses 0 }}
					{{ template "upstream" (dict "Container" $container "Address" $address "Network" $containerNetwork) }}
				{{/* If more than one port exposed, use the one matching VIRTUAL_PORT env var, falling back to standard web port 80 */}}
				{{ else }}
					{{ $port := coalesce $container.Env.VIRTUAL_PORT "80" }}
					{{ $address := where $container.Addresses "Port" $port | first }}
					{{ template "upstream" (dict "Container" $container "Address" $address "Network" $containerNetwork) }}
				{{ end }}
			{{ else }}
				# Cannot connect to network of this container
				server 127.0.0.1 down;
			{{ end }}
		{{ end }}
	{{ end }}
{{ end }}
}

{{ $default_host := or ($.Env.DEFAULT_HOST) "" }}
{{ $default_server := index (dict $host "" $default_host "default_server") $host }}

{{/* Get the VIRTUAL_PROTO defined by containers w/ the same vhost, falling back to "http" */}}
{{ $proto := trim (or (first (groupByKeys $containers "Env.VIRTUAL_PROTO")) "http") }}

{{/* Get the NETWORK_ACCESS defined by containers w/ the same vhost, falling back to "external" */}}
{{ $network_tag := or (first (groupByKeys $containers "Env.NETWORK_ACCESS")) "external" }}

{{/* Get the HTTPS_METHOD defined by containers w/ the same vhost, falling back to "redirect" */}}
{{ $https_method := or (first (groupByKeys $containers "Env.HTTPS_METHOD")) "redirect" }}

{{/* Get the SSL_POLICY defined by containers w/ the same vhost, falling back to "Mozilla-Intermediate" */}}
{{ $ssl_policy := or (first (groupByKeys $containers "Env.SSL_POLICY")) "Mozilla-Intermediate" }}

{{/* Get the HSTS defined by containers w/ the same vhost, falling back to "max-age=31536000" */}}
{{ $hsts := or (first (groupByKeys $containers "Env.HSTS")) "max-age=31536000" }}

{{/* Get the VIRTUAL_ROOT By containers w/ use fastcgi root */}}
{{ $vhost_root := or (first (groupByKeys $containers "Env.VIRTUAL_ROOT")) "/var/www/public" }}


{{/* Get the first cert name defined by containers w/ the same vhost */}}
{{ $certName := (first (groupByKeys $containers "Env.CERT_NAME")) }}

{{/* Get the best matching cert  by name for the vhost. */}}
{{ $vhostCert := (closest (dir "/etc/nginx/certs") (printf "%s.crt" $host))}}

{{/* vhostCert is actually a filename so remove any suffixes since they are added later */}}
{{ $vhostCert := trimSuffix ".crt" $vhostCert }}
{{ $vhostCert := trimSuffix ".key" $vhostCert }}

{{/* Use the cert specified on the container or fallback to the best vhost match */}}
{{ $cert := (coalesce $certName $vhostCert) }}

{{ $is_https := (and (ne $https_method "nohttps") (ne $cert "") (or (and (exists (printf "/etc/nginx/certs/letsencrypt/live/%s/fullchain.pem" $cert)) (exists (printf "/etc/nginx/certs/letsencrypt/live/%s/privkey.pem" $cert))) (and (exists (printf "/etc/nginx/certs/%s.crt" $cert)) (exists (printf "/etc/nginx/certs/%s.key" $cert)))) ) }}

{{ if $is_https }}

{{ if eq $https_method "redirect" }}
server {
	server_name {{ $host }};
	listen 80 {{ $default_server }};
	{{ if $enable_ipv6 }}
	listen [::]:80 {{ $default_server }};
	{{ end }}
	access_log /var/log/nginx/access.log vhost;
	return 301 https://$host$request_uri;
}
{{ end }}

server {
	server_name {{ $host }};
	listen 443 ssl http2 {{ $default_server }};
	{{ if $enable_ipv6 }}
	listen [::]:443 ssl http2 {{ $default_server }};
	{{ end }}
	access_log /var/log/nginx/access.log vhost;

	{{ if eq $network_tag "internal" }}
	# Only allow traffic from internal clients
	include /etc/nginx/network_internal.conf;
	{{ end }}

	{{ if eq $ssl_policy "Mozilla-Modern" }}
	ssl_protocols TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
	{{ else if eq $ssl_policy "Mozilla-Intermediate" }}
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:!DSS';
	{{ else if eq $ssl_policy "Mozilla-Old" }}
	ssl_protocols SSLv3 TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:ECDHE-RSA-DES-CBC3-SHA:ECDHE-ECDSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:DES-CBC3-SHA:HIGH:SEED:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!RSAPSK:!aDH:!aECDH:!EDH-DSS-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA:!SRP';
	{{ else if eq $ssl_policy "AWS-TLS-1-2-2017-01" }}
	ssl_protocols TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:AES128-GCM-SHA256:AES128-SHA256:AES256-GCM-SHA384:AES256-SHA256';
	{{ else if eq $ssl_policy "AWS-TLS-1-1-2017-01" }}
	ssl_protocols TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA';
	{{ else if eq $ssl_policy "AWS-2016-08" }}
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA';
	{{ else if eq $ssl_policy "AWS-2015-05" }}
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA:DES-CBC3-SHA';
	{{ else if eq $ssl_policy "AWS-2015-03" }}
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA:DHE-DSS-AES128-SHA:DES-CBC3-SHA';
	{{ else if eq $ssl_policy "AWS-2015-02" }}
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA:DHE-DSS-AES128-SHA';
	{{ end }}

	ssl_prefer_server_ciphers on;
	ssl_session_timeout 5m;
	ssl_session_cache shared:SSL:50m;
	ssl_session_tickets off;

        {{ if (and (exists (printf "/etc/nginx/certs/letsencrypt/live/%s/fullchain.pem" $cert)) (exists (printf "/etc/nginx/certs/letsencrypt/live/%s/privkey.pem" $cert))) }}
	ssl_certificate /etc/nginx/certs/letsencrypt/live/{{ (printf "%s/fullchain.pem" $cert) }};
	ssl_certificate_key /etc/nginx/certs/letsencrypt/live/{{ (printf "%s/privkey.pem" $cert) }};
        {{ else if (and (exists (printf "/etc/nginx/certs/%s.crt" $cert)) (exists (printf "/etc/nginx/certs/%s.key" $cert))) }}
	ssl_certificate /etc/nginx/certs/{{ (printf "%s.crt" $cert) }};
	ssl_certificate_key /etc/nginx/certs/{{ (printf "%s.key" $cert) }};
	{{ end }}

	{{ if (exists (printf "/etc/nginx/certs/%s.dhparam.pem" $cert)) }}
	ssl_dhparam {{ printf "/etc/nginx/certs/%s.dhparam.pem" $cert }};
	{{ end }}

	{{ if (exists (printf "/etc/nginx/certs/%s.chain.pem" $cert)) }}
	ssl_stapling on;
	ssl_stapling_verify on;
	ssl_trusted_certificate {{ printf "/etc/nginx/certs/%s.chain.pem" $cert }};
	{{ end }}

	{{ if (and (ne $https_method "noredirect") (ne $hsts "off")) }}
	add_header Strict-Transport-Security "{{ trim $hsts }}" always;
	{{ end }}

	{{ if (exists (printf "/etc/nginx/vhost.d/%s" $host)) }}
	include {{ printf "/etc/nginx/vhost.d/%s" $host }};
	{{ else if (exists "/etc/nginx/vhost.d/default") }}
	include /etc/nginx/vhost.d/default;
	{{ end }}

	location / {
		{{ if eq $proto "uwsgi" }}
		include uwsgi_params;
		uwsgi_pass {{ trim $proto }}://{{ trim $upstream_name }};
		{{ else if eq $proto "fastcgi" }}
		root   {{ trim $vhost_root }};
		include fastcgi.conf;
		fastcgi_pass {{ trim $upstream_name }};
		{{ else }}
		proxy_pass {{ trim $proto }}://{{ trim $upstream_name }};
		{{ end }}

		{{ if (exists (printf "/etc/nginx/htpasswd/%s" $host)) }}
		auth_basic	"Restricted {{ $host }}";
		auth_basic_user_file	{{ (printf "/etc/nginx/htpasswd/%s" $host) }};
		{{ end }}
		{{ if (exists (printf "/etc/nginx/vhost.d/%s_location" $host)) }}
		include {{ printf "/etc/nginx/vhost.d/%s_location" $host}};
		{{ else if (exists "/etc/nginx/vhost.d/default_location") }}
		include /etc/nginx/vhost.d/default_location;
		{{ end }}
	}
}

{{ end }}

{{ if or (not $is_https) (eq $https_method "noredirect") }}

server {
	server_name {{ $host }};
	listen 80 {{ $default_server }};
	{{ if $enable_ipv6 }}
	listen [::]:80 {{ $default_server }};
	{{ end }}
	access_log /var/log/nginx/access.log vhost;

	{{ if eq $network_tag "internal" }}
	# Only allow traffic from internal clients
	include /etc/nginx/network_internal.conf;
	{{ end }}

	{{ if (exists (printf "/etc/nginx/vhost.d/%s" $host)) }}
	include {{ printf "/etc/nginx/vhost.d/%s" $host }};
	{{ else if (exists "/etc/nginx/vhost.d/default") }}
	include /etc/nginx/vhost.d/default;
	{{ end }}

	location / {
		{{ if eq $proto "uwsgi" }}
		include uwsgi_params;
		uwsgi_pass {{ trim $proto }}://{{ trim $upstream_name }};
		{{ else if eq $proto "fastcgi" }}
		root   {{ trim $vhost_root }};
		include fastcgi.conf;
		fastcgi_pass {{ trim $upstream_name }};
		{{ else }}
		proxy_pass {{ trim $proto }}://{{ trim $upstream_name }};
		{{ end }}
		{{ if (exists (printf "/etc/nginx/htpasswd/%s" $host)) }}
		auth_basic	"Restricted {{ $host }}";
		auth_basic_user_file	{{ (printf "/etc/nginx/htpasswd/%s" $host) }};
		{{ end }}
		{{ if (exists (printf "/etc/nginx/vhost.d/%s_location" $host)) }}
		include {{ printf "/etc/nginx/vhost.d/%s_location" $host}};
		{{ else if (exists "/etc/nginx/vhost.d/default_location") }}
		include /etc/nginx/vhost.d/default_location;
		{{ end }}
	}
}

{{ if (and (not $is_https) (exists "/etc/nginx/certs/default.crt") (exists "/etc/nginx/certs/default.key")) }}
server {
	server_name {{ $host }};
	listen 443 ssl http2 {{ $default_server }};
	{{ if $enable_ipv6 }}
	listen [::]:443 ssl http2 {{ $default_server }};
	{{ end }}
	access_log /var/log/nginx/access.log vhost;
	return 500;

	ssl_certificate /etc/nginx/certs/default.crt;
	ssl_certificate_key /etc/nginx/certs/default.key;
}
{{ end }}

{{ end }}
{{ end }}
```
</spoiler>

Видно, что по умолчанию nginx будет искать сертификаты типа `/etc/nginx/certs/%s.crt` и `/etc/nginx/certs/%s.pem`, где %s - имя сертификата (по умолчанию - имя хоста, но его возможно изменять через переменные).

Агент же хранит сертификаты в структуре каталогов `/etc/nginx/certs/letsencrypt/live/%s/{fullchain.pem, privkey.pem}`, и потому в нескольких местах шаблона дополнены условия для таких имён сертификатов:

```
{{
$is_https :=
(and
  (ne $https_method "nohttps")
  (ne $cert "")
  (or
    (and
      (exists (printf "/etc/nginx/certs/letsencrypt/live/%s/fullchain.pem" $cert))
      (exists (printf "/etc/nginx/certs/letsencrypt/live/%s/privkey.pem" $cert))
    )
    (and
      (exists (printf "/etc/nginx/certs/%s.crt" $cert))
      (exists (printf "/etc/nginx/certs/%s.key" $cert))
    )
  )
)
}}
```

Теперь остаётся указать агенту, для какого домена выдавать сертификат в файле `domains.conf`.

<spoiler title="/tank0/docker/services/nginx-proxy/certs/letsencrypt/domains.conf ">
```
*.NAS.cloudns.cc NAS.cloudns.cc
```
</spoiler>

И ещё один маленький нюанс. Для того, чтобы в будущем вы могли загружать файлы приемлемого размера в облако, и их не резал прокси, установите для него параметр `client_max_body_size` хотя бы гигабайт в 20, как это показано ниже.

<spoiler title="/tank0/docker/services/nginx-proxy/local-config/max_upload_size.conf">
```
client_max_body_size 20G;
```
</spoiler>

Настройка закончена, пора запустить контейнер:

```
docker-compose up
```

Проверьте работоспособность (всё скачалось и запустилось), нажмите Ctrl+C и запустите контейнер в отвязанном от консоли режиме:

```
docker-compose up -d
```


### Настройка контейнера с тестовым сервером

Тестовый сервер - это минимальный nginx, который должен выводить страницу приветствия. Нужно, чтобы он мог легко запускаться и останавливаться, а его контейнер быстро пересоздавался.
Он будет первым и пока единственным сервисом, который будет работать в составе NAS.

Файлы конфигурации находятся [здесь](https://github.com/artiomn/NAS/tree/master/docker/services/test_nginx).

Вот его docker-compose файл:

<spoiler title="/tank0/docker/services/test_nginx/docker-compose.yml">
```yaml
version: '2'

networks:
  docker0:
    external:
      name: docker0

services:
  nginx-local:
    restart: always
    image: nginx:alpine
    expose:
      - 80
      - 443
    environment:
      - "VIRTUAL_HOST=test.NAS.cloudns.cc"
      - "VIRTUAL_PROTO=http"
      - "VIRTUAL_PORT=80"
      - CERT_NAME=NAS.cloudns.cc
    networks:
      - docker0
```
</spoiler>

Каждому контейнеру со службой нужно указать следующие параметры:

- `docker0` - внешняя сеть. Это указано в заголовке.
- [`expose`](https://docs.docker.com/compose/compose-file/compose-file-v2/#expose) - выставить порты в сеть, где работает контейнер. Как правило, порт 80 для протокола HTTP и 443 для протокола HTTPS.
- `VIRTUAL_HOST=test.NAS.cloudns.cc` - в данной переменной указан виртуальный хост, по которому nginx-reverse-proxy будет перенаправлять запрос на этот контейнер.
- `VIRTUAL_PROTO=http` - протокол по которому nginx-reverse-proxy будет взаимодействовать с данным сервисом. Если сертификата нет, это HTTP.
- `VIRTUAL_PORT=80` - порт на который будет обращаться nginx-reverse-proxy.
- `CERT_NAME=NAS.cloudns.cc` - имя внешнего сертификата. В данном случае, у всех сервисов сертификат один, потому имя везде одинаковое. NAS - имя DNS зоны.
- `networks` - в данной секции для всех фронтэндов, которые общаются с nginx-reverse-proxy должна быть указана сеть `docker0`.

Контейнер настроен, теперь нужно его поднять. Выполнив `docker-compose up`, зайдите по адресу `test.NAS.cloudns.cc`.

На консоль должно быть выведено примерно следующее:

```bash
$ docker-compose up

Creating testnginx_nginx-local_1
Attaching to testnginx_nginx-local_1
nginx-local_1  | 172.22.0.5 - - [29/Jul/2018:15:32:02 +0000] "GET / HTTP/1.1" 200 612 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537 (KHTML, like Gecko) Chrome/67.0 Safari/537" "192.168.2.3"
nginx-local_1  | 2018/07/29 15:32:02 [error] 8#8: *2 open() "/usr/share/nginx/html/favicon.ico" failed (2: No such file or directory), client: 172.22.0.5, server: localhost, request: "GET /favicon.ico HTTP/1.1", host: "test.NAS.cloudns.cc", referrer: "https://test.NAS.cloudns.cc/"
nginx-local_1  | 172.22.0.5 - - [29/Jul/2018:15:32:02 +0000] "GET /favicon.ico HTTP/1.1" 404 572 "https://test.NAS.cloudns.cc/" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537 (KHTML, like Gecko) Chrome/67.0 Safari/537" "192.168.2.3"
```

А браузер покажет следующую страницу:

[![Запущенный Nginx](https://habrastorage.org/webt/wj/-v/q3/wj-vq3xwns34rsn_tr8zvycwiei.png)](https://habrastorage.org/webt/wj/-v/q3/wj-vq3xwns34rsn_tr8zvycwiei.png)

Если, в итоге, у вас появилась страница, как на скриншоте выше, могу вас поздравить: всё настроено и работает правильно.

Теперь этот контейнер больше не нужен, остановите по Ctrl+C, выполнив затем `docker-compose down`.


### Настройка контейнера с local-rpoxy

После настройки прокси, неплохо бы поднять контейнер с nginx-default с сервером, проксирующим запросы для хоста nas, omv и подобных через внешнюю сеть на порты 10080 и 10443 ОС хостовой машины.

Файлы конфигурации находятся [здесь](https://github.com/artiomn/NAS/tree/master/docker/services/nginx-local).

<spoiler title="/tank0/docker/services/nginx-local/docker-compose.yml">
```bash
version: '2'

networks:
  docker0:
    external:
      name: docker0

services:
  nginx-local:
    restart: always
    image: nginx:alpine
    expose:
      - 80
      - 443
    environment:
      - "VIRTUAL_HOST=NAS.cloudns.cc,nas,nas.*,www.*,omv.*,nas-controller.nas"
      - "VIRTUAL_PROTO=http"
      - "VIRTUAL_PORT=80"
      - CERT_NAME=NAS.cloudns.cc
    volumes:
      - ./local-config:/etc/nginx/conf.d
    networks:
      - docker0
```
</spoiler>

С конфигурацией docker-compose всё должно быть понятно, и останавливаться на её описании я не буду.
Единственное, что хочу заметить, это то, что один из доменов `NAS.cloudns.cc`. Это сделано для того, чтобы при обращении к NAS только по имени DNS зоны, запрос переводился на хост.

<spoiler title="/tank0/docker/services/nginx-local/local-config/default.conf">
```
# If we receive X-Forwarded-Proto, pass it through; otherwise, pass along the
# scheme used to connect to this server
map $http_x_forwarded_proto $proxy_x_forwarded_proto {
  default $http_x_forwarded_proto;
  ''      $scheme;
}

# If we receive X-Forwarded-Port, pass it through; otherwise, pass along the
# server port the client connected to
map $http_x_forwarded_port $proxy_x_forwarded_port {
  default $http_x_forwarded_port;
  ''      $server_port;
}

# Set appropriate X-Forwarded-Ssl header
map $scheme $proxy_x_forwarded_ssl {
  default off;
  https on;
}

access_log on;
error_log on;
# HTTP 1.1 support
proxy_http_version 1.1;
proxy_buffering off;
proxy_set_header Host $http_host;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $proxy_x_forwarded_proto;
proxy_set_header X-Forwarded-Ssl $proxy_x_forwarded_ssl;
proxy_set_header X-Forwarded-Port $proxy_x_forwarded_port;

# Mitigate httpoxy attack (see README for details)
proxy_set_header Proxy "";

server {
        server_name _; # This is just an invalid value which will never trigger on a real hostname.
        listen 80;
        return 503;
}


server {
        server_name www.* nas.* omv.* "";

        listen 80;
        location / {
                proxy_pass https://172.21.0.1:10443/;
        }
}

# nas-controller
server {
        server_name nas-controller.nas;

        listen 80 ;
        location / {
                proxy_pass https://nas-controller/;
        }
}
```
</spoiler>

- `172.21.0.1` - сеть хоста. Перенаправление запроса всегда производится на порт 443, потому что раньше был сгенерирован сертификат и OMV работает по HTTPS. Пусть также и останется даже для внутреннего общения.
- `https://nas-controller/` - по-идее, это интерфейс на котором работает IPMI, и если обратиться к nas, как к nas-controller.nas, запрос будет перенаправлен на внешний адрес nas-controller. Не особенно полезно.


Установка и настройка LDAP
--------------------------

### Настройка LDAP-сервера

[LDAP-сервер](https://ru.wikipedia.org/wiki/LDAP) - это центральный компонент системы управления пользователями.
Он также работает внутри Docker контейнера. В котором, помимо него, запущены интерфейсы для администрирования и смены паролей.

Файлы конфигурации и LDIF-файлы находятся [здесь](https://github.com/artiomn/NAS/tree/master/docker/services/ldap).

<spoiler title="/tank0/docker/services/ldap/docker-compose.yml">
```yaml
version: "2"

networks:
  ldap:
  docker0:
    external:
      name: docker0

services:
  open-ldap:
    image: "osixia/openldap:1.2.0"
    hostname: "open-ldap"
    restart: always
    environment:
      - "LDAP_ORGANISATION=NAS"
      - "LDAP_DOMAIN=nas.nas"
      - "LDAP_ADMIN_PASSWORD=ADMIN_PASSWORD"
      - "LDAP_CONFIG_PASSWORD=CONFIG_PASSWORD"
      - "LDAP_TLS=true"
      - "LDAP_TLS_ENFORCE=false"
      - "LDAP_TLS_CRT_FILENAME=ldap_server.crt"
      - "LDAP_TLS_KEY_FILENAME=ldap_server.key"
      - "LDAP_TLS_CA_CRT_FILENAME=ldap_server.crt"
    volumes:
      - ./certs:/container/service/slapd/assets/certs
      - ./ldap_data/var/lib:/var/lib/ldap
      - ./ldap_data/etc/ldap/slapd.d:/etc/ldap/slapd.d
    networks:
      - ldap
    ports:
      - 172.21.0.1:389:389
      - 172.21.0.1::636:636

  phpldapadmin:
    image: "osixia/phpldapadmin:0.7.1"
    hostname: "nas.nas"
    restart: always
    networks:
      - ldap
      - docker0
    expose:
      - 443
    links:
      - open-ldap:open-ldap-server
    volumes:
      - ./certs:/container/service/phpldapadmin/assets/apache2/certs
    environment:
      - VIRTUAL_HOST=ldap.*
      - VIRTUAL_PORT=443
      - VIRTUAL_PROTO=https
      - CERT_NAME=NAS.cloudns.cc

      - "PHPLDAPADMIN_LDAP_HOSTS=open-ldap-server"
      #- "PHPLDAPADMIN_HTTPS=false"
      - "PHPLDAPADMIN_HTTPS_CRT_FILENAME=certs/ldap_server.crt"
      - "PHPLDAPADMIN_HTTPS_KEY_FILENAME=private/ldap_server.key"
      - "PHPLDAPADMIN_HTTPS_CA_CRT_FILENAME=certs/ldap_server.crt"
      - "PHPLDAPADMIN_LDAP_CLIENT_TLS_REQCERT=allow"

  ldap-ssp:
    image: openfrontier/ldap-ssp:https
    volumes:
      #- ./ssp/mods-enabled/ssl.conf:/etc/apache2/mods-enabled/ssl.conf
      - /etc/ssl/certs/ssl-cert-snakeoil.pem:/etc/ssl/certs/ssl-cert-snakeoil.pem
      - /etc/ssl/private/ssl-cert-snakeoil.key:/etc/ssl/private/ssl-cert-snakeoil.key
    restart: always
    networks:
      - ldap
      - docker0
    expose:
      - 80
    links:
      - open-ldap:open-ldap-server
    environment:
      - VIRTUAL_HOST=ssp.*
      - VIRTUAL_PORT=80
      - VIRTUAL_PROTO=http
      - CERT_NAME=NAS.cloudns.cc

      - "LDAP_URL=ldap://open-ldap-server:389"
      - "LDAP_BINDDN=cn=admin,dc=nas,dc=nas"
      - "LDAP_BINDPW=ADMIN_PASSWORD"
      - "LDAP_BASE=ou=users,dc=nas,dc=nas"
      - "MAIL_FROM=admin@nas.nas"
      - "PWD_MIN_LENGTH=8"
      - "PWD_MIN_LOWER=3"
      - "PWD_MIN_DIGIT=2"
      - "SMTP_HOST="
      - "SMTP_USER="
      - "SMTP_PASS="
```
</spoiler>

В конфиге описано три сервиса:

- [`open-ldap`](https://github.com/osixia/docker-openldap) - LDAP-сервер.
- [`phpldapadmin`](https://github.com/osixia/docker-phpLDAPadmin) - WEB-интерфейс для его администрирования. Через него возможно добавлять и удалять пользователей, группы и т.п..
- [`ldap-ssp`](https://github.com/openfrontier/docker-ldap-ssp) - WEB-интерфейс для смены паролей пользователями.

LDAP-сервер требует настройки некоторых параметров, которые задаются через переменные окружения:

- `LDAP_ORGANISATION=NAS` - имя организации. Может быть произвольным.
- `LDAP_DOMAIN=nas.nas` - домен. Тоже произвольный. Указать лучше тот же, что и доменное имя.
- `LDAP_ADMIN_PASSWORD=ADMIN_PASSWORD` - пароль администратора.
- `LDAP_CONFIG_PASSWORD=CONFIG_PASSWORD` - пароль для конфигурации.

По-идее, не мешает добавить ещё и пользователя "только для чтения", но потом.

Тома:

- `/container/service/slapd/assets/certs` отображён в локальный каталог `certs` - сертификаты. Сейчас не используется.
- `./ldap_data/`- локальный каталог, подкаталоги которого проброшены в два каталога внутри контейнеров. Тут LDAP хранит свою базу.

Сервер работает во внутренней сети `ldap`, но его порты 389 (незащищённый LDAP) и 636 (LDAP по SSL, пока не используемый) проброшены в сеть хоста.

PhpLdapAdmin работает в двух сетях: он обращается к серверу LDAP в сети `ldap` и открывает порт 443 в сети `docker0`, для того, чтобы к нему мог обратиться nginx-reverse-proxy.

Настройки:

- `VIRTUAL_HOST=ldap.*` - хост, которому nginx-reverse-proxy будет сопоставлять контейнер.
- `VIRTUAL_PORT=443` - порт для nginx-reverse-proxy.
- `VIRTUAL_PROTO=https` - протокол для nginx-reverse-proxy.
- `CERT_NAME=NAS.cloudns.cc` - имя сертификата, одинаковое для всех.

Блок переменных после этого предназначен для настройки SSL и сейчас не обязателен.

SSP доступен по HTTP и тоже работает в двух сетях.
Тома, в этом контейнере не используются, и проброшенный сертификат остался от старых экспериментов.

Переменные для настройки - это ограничения на длину пароля и учётные данные для доступа к серверу LDAP.

- `LDAP_URL=ldap://open-ldap-server:389` - адрес и порт LDAP сервера (см. секцию `links`).
- `LDAP_BINDDN=cn=admin,dc=nas,dc=nas` - логин администратора и домен для аутентификации.
- `LDAP_BINDPW=ADMIN_PASSWORD` - пароль администратора, который должен совпадать с паролем, указанным для контейнера open-ldap.
- `LDAP_BASE=ou=users,dc=nas,dc=nas` - это базовый путь, по которому содержатся учётные данные пользователей.

Установите на хостовой машине утилиты для работы с LDAP и инициализируйте LDAP каталог:

```bash
apt-get install ldap-utils
ldapadd -x -H ldap://172.21.0.1  -D "cn=admin,dc=nas,dc=nas" -W -f ldifs/inititialize_ldap.ldif
ldapadd -x -H ldap://172.21.0.1  -D "cn=admin,dc=nas,dc=nas" -W -f ldifs/base.ldif
ldapadd -x -H ldap://172.21.0.1  -D "cn=admin,cn=config" -W -f ldifs/gitlab_attr.ldif
```

В `gitlab_attr.ldif` добавляется атрибут, по которому Gitlab (о нём потом) будет находить пользователей.
После этого вы можете выполнить следующую команду для проверки.

<spoiler title="Проверка работоспособности LDAP сервера">
```bash
$ ldapsearch -x -H ldap://172.21.0.1 -b dc=nas,dc=nas -D "cn=admin,dc=nas,dc=nas" -W

Enter LDAP Password: 
# extended LDIF
#
# LDAPv3
# base <dc=nas,dc=nas> with scope subtree
# filter: (objectclass=*)
# requesting: ALL
#

# nas.nas
dn: dc=nas,dc=nas
objectClass: top
objectClass: dcObject
objectClass: organization
o: NAS
dc: nas

# admin, nas.nas
dn: cn=admin,dc=nas,dc=nas
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: admin
description: LDAP administrator
...

# ldap_users, groups, nas.nas
dn: cn=ldap_users,ou=groups,dc=nas,dc=nas
cn: ldap_users
gidNumber: 500
objectClass: posixGroup
objectClass: top

# search result
search: 2
result: 0 Success

# numResponses: 12
# numEntries: 11
```
</spoiler>

На этом настройка LDAP сервера закончена. Управлять сервером вы можете через WEB-интерфейс.


### Настройка OMV для входа по LDAP

Если LDAP сервер настроен и работает, OMV настраивается на работу с ним очень просто: указываете хост, порт, данные для авторизации, корневой каталог для поиска пользователей и атрибут для определения того, что найденная запись - аккаунт пользователя.

LDAP плагин вы уже должны были установить.

Всё показано на скриншоте:

[![Настройка OMV для работы с LDAP](https://habrastorage.org/webt/0e/fq/yp/0efqypb4eevkfvm1dx5hccpxcae.png)](https://habrastorage.org/webt/0e/fq/yp/0efqypb4eevkfvm1dx5hccpxcae.png)


Взаимодействие с источником питания
-----------------------------------

Сначала настройте ИБП по инструкции, которая идёт вместе с ним, и подключите его к NAS по USB.
Плагин для работы с ИБП вы должны были установить ранее.
Теперь остаётся только настроить NUT через GUI OMV.
Зайдите на страницу _"Сервисы->ИБП"_, включите ИБП, в поле идентификатор введите любую строку, описывающую ИБП, например "eaton".

В поле _"Директивы конфигурации драйверов"_ введите следующее:

```
driver = usbhid-ups
port = auto
desc = "Eaton 9130 700 VA"
vendorid = 0463
pollinterval = 10
```

- `driver = usbhid-ups` - ИБП подключен по USB, потому используется драйвер USB HID.
- `vendorid` - это идентификатор производителя ИБП, который может быть получен командой `lsusb`.
- `pollinterval` - интервал опроса ИБП в cекундах.

Остальные параметры возможно посмотреть в [документации](https://networkupstools.org/docs/man/ups.conf.html).

Вывод `lsusb`, строка с ИБП указана стрелкой:

```bash
# lsusb 
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
--> Bus 001 Device 003: ID 0463:ffff MGE UPS Systems UPS
Bus 001 Device 004: ID 046b:ff10 American Megatrends, Inc. Virtual Keyboard and Mouse
Bus 001 Device 002: ID 046b:ff01 American Megatrends, Inc. 
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
```

_"Режим отключения"_ надо установить в "низкий заряд батареи".
Должно получиться примерно так, как показано на скриншоте:

[![Настройка ИБП](https://habrastorage.org/webt/0v/1e/5c/0v1e5ceg5axff7qac7gnqqlv5dc.png)](https://habrastorage.org/webt/0v/1e/5c/0v1e5ceg5axff7qac7gnqqlv5dc.png)

Выключите ИБП и снова включите. Если были настроены уведомления, вам на почту придёт письмо о потере питания.
На этом настройка ИБП окончена.


Заключение
-------------

На этом основа системы установлена и настроена. Несмотря на то, что многое тут было сделано из консоли, делать так вовсе не обязательно, просто я считаю, что это удобнее.
Но одно из достоинств системы - её гибкость.

Если хотите действовать по-другому, OMV позволит вам это.

Доступно управление сетями из WEB-интерфейса, причём в некотором плане это более удобно, чем через консоль:

[![](https://habrastorage.org/webt/tb/p3/ja/tbp3jabundd-ifinj76eimw-me0.png)](https://habrastorage.org/webt/tb/p3/ja/tbp3jabundd-ifinj76eimw-me0.png)

Для Docker тоже есть весьма понятный WEB-интерфейс:

[![](https://habrastorage.org/webt/ol/1o/h_/ol1oh_koe2adncdkhh9qozsufkm.png)](https://habrastorage.org/webt/ol/1o/h_/ol1oh_koe2adncdkhh9qozsufkm.png)

Кроме того, OMV может рисовать красивые графики.

График использования сети:

[![График использования сети](https://habrastorage.org/webt/fq/n7/v2/fqn7v20f3vq1ekj7ygcg1jbv2cu.png)](https://habrastorage.org/webt/fq/n7/v2/fqn7v20f3vq1ekj7ygcg1jbv2cu.png)

График использования памяти:

[![График использования памяти](https://habrastorage.org/webt/52/k4/3e/52k43eckcekf7bxfxqmsbnv4hlm.png)](https://habrastorage.org/webt/52/k4/3e/52k43eckcekf7bxfxqmsbnv4hlm.png)

График использования CPU:

[![График использования CPU](https://habrastorage.org/webt/qn/e8/ir/qne8ir6ndfbl17zyvzzl5vyexs0.png)](https://habrastorage.org/webt/qn/e8/ir/qne8ir6ndfbl17zyvzzl5vyexs0.png)


## Нереализованное

- Проблемы с настройкой - отдельная большая тема. Возможно, что с первого раза что-то не заработает. В таком случае, вам в помощь [`docker-compose exec`](https://docs.docker.com/compose/reference/exec/), а также внимательное изучение докуменатции и исходников.
- LDAP сервер не мешало бы настроить лучше, особенно в плане безопасности (использовать SSL везде, добавить пользователя для чтения и т.п.).
- Пока совершенно не затронуты вопросы доверенной загрузки и повышения безопасности, я об этом знаю, но в другой раз.
- Пользователь @ValdikSS дал очень полезный совет использовать DropbearSSH, внедрённый в initramfs для решения проблемы ненамеренных перезагрузок. Об этом будет другая статья.

На этом всё.
С Богом!

![](https://habrastorage.org/webt/n0/dy/xy/n0dyxyaz2tzyp5q1vvdskj1fr9c.jpeg)
