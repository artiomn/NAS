# Bonding и SSH-сервер в initramfs

![](https://habrastorage.org/webt/mc/mz/-h/mcmz-h3bsxctbh1ka8wxdtdnvqs.png)

Всякая система является компромиссом между безопасностью и удобством использования.

[В построенном NAS](https://habr.com/post/359344), существовала серьёзная проблема: нельзя было перезагрузить систему, не присутствуя на месте, что понижало уровень доступности данных.

Эта проблема не была критичной, до того момента, как начали аварийно отключать электричество: за три месяца два раза на несколько часов. ИБП рассчитан на кратковременные сбои и не предполагается работа от батарей более получаса (хотя реально - около часа), и при каждом таком отключении, чтобы снова включить систему, приходилось ездить в другой город.

<cut/>

Благодаря [подсказке](https://habr.com/post/359344/#comment_18916925) от @ValdikSS, эту проблема была решена. Но...

![](https://habrastorage.org/webt/l0/xu/c3/l0xuc38iobnzstjrcx204y9opeg.jpeg)

Мне был нужен бондинг интерфейсов и удалённая разблокировка по SSH. А мануала, по которому возможно сделать сразу так, чтобы работало как мне надо, я не нашёл.

Поэтому, я привожу свой вариант решения с бондингом и динамическим IP, в котором систему возможно разблокировать, как локально, так и удалённо.

**Напоминаю, что для выполнения этих настроек, вы должны иметь локальный физический доступ к NAS и резервные возможности для загрузки.**


# Бондинг в initramfs

Поскольку, в NAS два интерфейса объединены в один канал, решено было также сделать и при загрузке.

Из вопроса ["Using NFS-root with bonded interfaces"](https://serverfault.com/questions/472349/using-nfs-root-with-bonded-interfaces) я взял скрипт. Статья ["How to manage linux bonding without ifenslave using sysfs"](https://backdrift.org/manage-linux-bonding-without-ifenslave-using-sysfs) помогла в настройке бондинга.

Сначала нужно включить в initramfs модули, которые используются для работы сети. Делается это следующей командой:

```bash
while read m _; do
  /sbin/modinfo -F filename "$m";
done </proc/modules | sed -nr "s@^/lib/modules/`uname -r`/kernel/drivers/net(/.*)?/([^/]+)\.ko\$@\2@p" >> /etc/initramfs-tools/modules
```

Теперь скопируйте два скрипта в `/etc/initramfs-tools/scripts/`.

Первый нужен для того, чтобы поднять интерфейсы в бондинге:
<spoiler title="/etc/initramfs-tools/scripts/init-premount/00_bonding_init">
```bash
#!/bin/sh -e

PREREQS=""

case $1 in
    prereqs) echo "${PREREQS}"; exit 0;;
esac

BOND_MASTER=${BOND_MASTER:-bond0}

echo "Network interfaces loaded: "
echo `ls /sys/class/net`

if [ ! -e "/sys/class/net/${BOND_MASTER}" ]; then
    echo "Creating bonding master 'bond0'..."
    echo "+${BOND_MASTER}" > /sys/class/net/bonding_masters
fi

echo "Master interface: ${BOND_MASTER}"

for x in $cmdline; do
    case $x in
    bondslaves=*)
            bondslaves="${x#bondslaves=}"
            ;;
    esac
done

IFS=","
for x in $bondslaves; do
    echo "+$x" > "/sys/class/net/${BOND_MASTER}/bonding/slaves"
done
```
</spoiler>

Второй, чтобы деактивировать бондинг-интерфейс при продолжении загрузки:
<spoiler title="/etc/initramfs-tools/scripts/init-bottom/iface_down">
```bash
#!/bin/sh -e

PREREQS=""
case $1 in
        prereqs) echo "${PREREQS}"; exit 0;;
esac

if [ ! -d /sys/class/net/bond0 ]; then
  exit 0
fi

echo "Remove bonding interface..."

for x in $cmdline; do
    case $x in
    bondslaves=*)
            bondslaves="${x#bondslaves=}"
            ;;
    esac
done

IFS=","
for x in $bondslaves; do
    echo "-$x" > /sys/class/net/bond0/bonding/slaves
done

echo "-bond0" > /sys/class/net/bonding_masters
```
</spoiler>

Если этого не сделать, сеть после загрузки не будет работать.

Не забудьте дать скриптам права на выполнение:
```bash
chmod +x /etc/initramfs-tools/scripts/init-premount/00_bonding_init /etc/initramfs-tools/scripts/init-bottom/iface_down
```

Остаётся только задать интерфейсы, которые войдут в бондинг и параметры получения адреса.
Адрес будет получаться по DHCP, т.к. бондинг будет иметь тот же MAC, что и после загрузки, потому роутер выдаст фиксированный IP и осуществит проброс портов.

Интерфейсы я получаю автоматически из тех, которые входят в бондинг `bond0` при работающем NAS:

```bash
sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\)\"\(.*\)\"/\1\"\2 $(echo -n ip=:::::bond0:dhcp bondslaves=$(sed -e 's/ /,/' /sys/class/net/bond0/bonding/slaves))\"/" /etc/default/grub
```

Ну и напоследок обновите конфиг GRUB и образ initramfs:

```bash
update-grub
update-initramfs -u -k $(uname -r)
```

На этом всё. Если всё настроено корректно, после перезагрузки и запуска стартового скрипта в initrmafs, пинги на IP NAS будут идти, несмотря на то, что ОС ещё не загружена.

Замечу, что настройка бондинга в Dracut делается гораздо легче, потому что [уже есть скрипты в поставке](https://github.com/zfsonlinux/dracut/blob/master/modules.d/40network/parse-bond.sh).


# SSH-сервер в initramfs

Установите пакет для включения Dropbear SSH в initramfs:

```bash
apt-get install dropbear-initramfs
```

Dropbear SSH будет включен в initrmafs автоматически, и он запустится, если на раннем этапе загрузки будет поднят хотя бы один сетевой интерфейс с IP адресом.

После этого сконвертируйте ключ Dropbear в формат OpenSSH и закройте его паролем:

```bash
/usr/lib/dropbear/dropbearconvert dropbear openssh               \
  /etc/dropbear/dropbear_rsa_host_key                            \
  id_rsa dropbearkey -y -f /etc/dropbear/dropbear_rsa_host_key | \
  grep "^ssh-rsa " > id_rsa.pub
ssh-keygen -p -f id_rsa
```

Ключ `id_rsa` скопируйте на машину, с которой будет осуществляться разблокировка. Я буду предполагать, что он будет скопирован в каталог `~/.ssh/dropbear`.

В `/etc/dropbear-initramfs/authorized_keys` должен быть указаны отпечатки ключа и параметры для каждого ключа.

Пока достаточно добавить отпечаток одного ключа, для чего надо выполнить следующую команду:

```bash
echo 'no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command="/bin/unlock"' $(cat id_rsa.pub) >> /etc/dropbear-initramfs/authorized_keys
```

Никакие обёртки, упомянутые в статьях не нужны, `/bin/unlock` - системный скрипт (cryptroot-unlock).

Примерно так должен выглядеть `/etc/dropbear-initramfs/authorized_keys` в конечном итоге:

```
no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command="/bin/unlock" ssh-rsa AAAA...XDa root@nas
```

Обновите конфиг GRUB и образ initramfs и перезагрузитесь:

```bash
update-grub
update-initramfs -u -k $(uname -r)
reboot
```

_С машины, куда вы скопировали ключ_ теперь возможно подключиться к NAS и выполнить разблокировку:

```
$ ssh -i .ssh/dropbear/id_rsa_initram -o UserKnownHostsFile=.ssh/dropbear/known_hosts root@nas.NAS.cloudns.cc
Enter passphrase for key '.ssh/dropbear/id_rsa_initram':
X11 forwarding request failed on channel 0 
Please unlock disk root_crypt1 (/dev/disk/by-id/ata-Samsung_SSD_850_PRO_256GB-part3):
```

После этого в консоль будет постоянно выдаваться ошибка об отсутствии аргумента (`ash: -gt: argument expected`), но разблокировка пойдёт. Это ошибка в системном скрипте разблокировки, которая ни на что не влияет (правится ошибка легко, но обёртки её не лечат).

Подробнее возможно посмотреть в этих статьях:

- [Remote unlocking of LUKS-encrypted root in Ubuntu/Debian](https://hamy.io/post/0005/remote-unlocking-of-luks-encrypted-root-in-ubuntu-debian).
- [Разблокировка через SSH полностью зашифрованного ubuntu-server 12.04](https://help.ubuntu.ru/wiki/unlock_luks_ssh).
- [Remote unlocking LUKS encrypted LVM using Dropbear SSH in Ubuntu Server 14.04.1](https://stinkyparkia.wordpress.com/2014/10/14/remote-unlocking-luks-encrypted-lvm-using-dropbear-ssh-in-ubuntu-server-14-04-1-with-static-ipst/).
- [Unlock full-encrypted system via SSH](https://www.virtono.com/community/tutorial-how-to/unlock-full-encrypted-system-via-ssh/).


# Отладка

Для отладки можете вставить вызов `/bin/sh` в скрипт `00_bonding_init` после:

```
case $1 in
        prereqs) echo "${PREREQS}"; exit 0;;
esac
```

Когда с бондингом проблемы будут решены, замените в `authorized_keys` команду `command="/bin/unlock"` на `command="/bin/sh"`.

После соединения по SSH вам будет предоставлен шелл, который вы можете использовать для отладки.
