# Список статей и литературы про NAS

![](images/sr0yhmtnyqleva0x_wttzsmxvco.jpeg)

В рамках [цикла статей по построению NAS, либо домашнего сервера](https://habr.com/post/359346/), по просьбам [пользователей](https://habr.com/post/359346/#comment_18916421) я погуглил за вас и сделал небольшой обзор информационных источников.

В этой статье собраны ссылки на большую часть материалов, которые я использовал. По мере накопления и обработки материалов, тут может появиться что-то новое.

<cut/>

# Немного теории и общих соображений

Совсем базовая статья от DELL ["Введение в системы хранения данных"](https://habr.com/company/dellemc/blog/125828/) 2011 года, позволит определиться с терминологией.

Для общего развития по СХД возможно почитать статью ["Работа с Незнайкой — технологии упреждающего чтения и гибридные СХД"](https://habr.com/company/raidix/blog/328078/) 2017 года.

В маленькой статье ["NAS для нас: от дорогого к простому и бюджетному"](https://habr.com/company/icover/blog/382589/) 2015 года есть несколько общих слов на тему своего NAS.


# Примеры

## На русском

Чтобы понять, нужно ли строить и что, посмотрите на картинку, взятую из цикла "классических" статей 2013 года на iXBT:

<a href=images/rt1eklikzi3_r-9fg0dvg8swo7i.jpeg><img src=images/rt1eklikzi3_r-9fg0dvg8swo7i.jpeg width=70% height=70%></a>

Эти статьи к прочтению крайне рекомендуются.
[Первая статья](https://www.ixbt.com/storage/nas-howto-part1.shtml) о выборе железа, [вторая](https://www.ixbt.com/storage/nas-howto-part2.shtml) о программном обеспечении.

[Есть ещё более старая статья](http://bazhenov.me/blog/2010/11/14/nas.html) 2010 года, но достаточно грамотная. И в своём NAS автор уже использует ZFS.

В статье ["Эволюция домашнего NAS. Итог шести лет"](https://habr.com/post/386169/) представлен обзор некоторых моделей NAS и кое-что по поводу железа. Может, будет интересно.

В статье 2011 года ["NAS своими руками. Или? Поиск сбалансированного решения"](http://www.f1cd.ru/storage/reviews/nas_svoimi_rukami_freenas/) используется любопытный корпус Eolize и плата Zotac. ОС - FreeNAS.

В следующем цикле статей автор достаточно полно рассматривает NAS Synology:

1. [Выбор, установка, настройка](https://beardycast.com/article/gadget/accessories/nas-1/)
2. [Фильмы, фотографии, музыка ](https://beardycast.com/article/gadget/accessories/nas-2/)
3. [Работа, бэкапы и финальные впечатления ](https://beardycast.com/article/gadget/accessories/nas-3/).

О построении домашнего сервера возможно почитать здесь:

1. [Вводная теория](http://dmitrysnotes.ru/domashnij-server-chast-1-vvodnaya-teoriya).
2. [Локальная сеть](http://dmitrysnotes.ru/domashnij-server-chast-2-lokalnaya-set).
3. [Жесткие диски](http://dmitrysnotes.ru/domashnij-server-chast-3-zhestkie-diski).

В двух следующих статьях автор построил программную часть на Nas4free.
Рекомендую к прочтению:
1. ["Черный ящик для дома: собираем NAS своими руками, часть 1"](https://habr.com/post/309558/).
2. ["Черный ящик для дома: собираем NAS своими руками, часть 2 – великолепный NAS4Free"](https://habr.com/post/397575/).

В статье ["Как я дома NAS строил"](https://habr.com/post/327104/) построена NAS в неплохом корпусе Chenbro, с использованием FreeNAS в качестве ОС. Приложения установлены в контейнерах.

Михаил Кулеш в статье ["Домашний сервер на платформе Intel Atom и ОС Centos 7"](https://habr.com/post/268197/) 2015 года описал построение сервера с GNOME, который доступен по VNC. Не вполне одобряю использование графики на сервере, но почитать стоит.

В статье ["Скромный NAS для дома"](https://habr.com/post/387379/) 2015 года некий "Windows-администратор" построил NAS на OC Windows. Так делать, пожалуй, не надо, если безопасность NAS для вас имеет значение.

Возможно также прочитать маленькую статейку ["Накопитель своими руками"](https://ichip.ru/nas-nakopitel-svoimi-rukami.html).

И наконец, ещё один цикл статей по самодельному NAS 2014 года, который стоит почитать:

- ["Еще один NAS своими руками, часть 1: из того, что было"](https://habr.com/post/214707/).
- ["Хорошие воспоминания (Флэш-память для загрузки FreeNAS и прочих embedded OS)"](https://habr.com/post/214803/)
- ["Ещё один NAS своими руками: приключения XXX в старой башне"](https://habr.com/post/218387/).
- ["Призрак Чернобыля" (Контроллер дистанционного управления для ПК-сервера с текстовой консолью, без паяльника и Arduino)](https://habr.com/post/217299/).


## На английском

Начну со статьи в трёх частях от Ridwan, 2017 года:

- ["Building an Open Media Vault NAS (Part 1 — Choosing Hardware)"](https://ridwankhan.com/building-an-open-media-vault-nas-part-1-hardware-cc34ce824f5).
- ["Building an Open Media Vault NAS (Part 2— Choosing and Installing OMV)"](https://ridwankhan.com/building-an-open-media-vault-nas-part-2-choosing-and-installing-omv-301ac4ed333e).
- ["Building an Open Media Vault NAS (Part 3— Configuring OMV)"](https://ridwankhan.com/building-an-open-media-vault-nas-part-3-configuring-omv-ee15322602be).

В статье ["Should I Build a NAS or Buy One?"](https://store.rossmanngroup.com/blog/should-i-build-a-nas-or-buy-one/) американцы выбирают вариант решения.

Nick Touran описывает построение нечто среднего между NAS на ZFS и сервером с X.org в публикации ["Building a NAS server/home server in 2017"](https://partofthething.com/thoughts/building-a-nas-serverhome-server-in-2017/) .

[Здесь](https://blog.briancmoses.com/2017/03/diy-nas-2017-edition.html) NAS реализуется на базе платы Supermicro, дисков WD Red и корпуса Silverstone DS30B, такого же как у меня.
Автор тоже получил проблему, связанную с плохим охлаждением. И решил её, разграничив воздушные потоки перегородкой, тогда как я просто насверлил дырок и сменил вентиляторы.
Рекомендую статью, т.к. подход достаточно грамотный: выбор дисков на основе статистики BackBlaze, послесборочная проверка компонентов, плата Supermicro и т.п.
Закончилось всё установкой FreeNAS.
Мне в статье не понравилось, ОС установленная на USB flash, что не очень надёжно (хотя и приемлемо для FreeNAS, у OMV с этим хуже).

Это не единственная статья Brian Moses. [Вот, например](https://blog.briancmoses.com/2017/12/diy-nas-econonas-2017.html) эконом вариант. Вообще, автор занимается построением NAS из года в год, имеет большой опыт и статьи, ссылки на которые даны в его статье, я рекомендую почитать.

На Reddit также [поднимали тему постройки и использования NAS](www.reddit.com/r/DataHoarder).

[Здесь](www.reddit.com/r/JDM_WAAAT/comments/8zgkfj/server_build_nas_killer_v_20_the_terminator_dual) есть пошаговая инструкцию по построению мощного NAS сервера за пару сотен долларов со ссылками на все комплектующие на eBay.


# Аппаратура

На Youtube есть пара **видео** ["NAS для дома"](https://www.youtube.com/watch?v=LBGlqs4xmzg&list=PLvSsgttjMHumNE9P1RACbfYh5BkrC1X2g), в котором автор даёт некоторые рекомендации по железу и проводит небольшой обзор корпусов.

Очень хорошим документом по аппаратному обеспечению является [FreeNAS Hardware Recommendations Guide](https://forums.freenas.org/index.php?resources/hardware-recommendations-guide.12/). По ссылке вы можете скачать последнюю версию в PDF. Там же ссылка на форум с обсуждениями, где некоторые вопросы рассматриваются подробнее.

Подбор компонентов для домашнего NAS рассматривается в статье Виталия Шундрина от 2012-го года ["Сборка домашнего NAS сервера самостоятельно | Обзор компонентов для NAS"](https://mediapure.ru/domashnij-server-nas/sborka-domashnego-nas-servera-s-nulya-obzor-komponentov-dlya-nas/). В какой-то степени статья до сих пор может быть интересна.


# Диски

Для выбора дисков я рекомендую отталкиваться от всем известной [статистики BackBlaze](https://www.backblaze.com/blog/hard-drive-stats-for-q1-2018/), которая обновляется каждый квартал и показывает, какие диски более надёжны.

В статье ["Дешевые способы поддать жару системе хранения с помощью SSD"](https://habr.com/company/pc-administrator/blog/319214/) 2017 года, возможно почитать некоторые любопытные соображения насчёт использования SSD.


# Корпуса

По корпусам данных не столь много, пришлось провести самостоятельное изучение рынка.

Есть статья ["Корпус для домашнего сервера/NAS"](https://habr.com/post/150505/) 2012 года.
И ещё любопытный пример самодельного корпуса показан в статье ["Старым хламом NAS не удивить"](https://habr.com/post/83961/).


# Платы

Собственно, обзор серверных плат требуемого мне формата дан [в моей статье по железу](https://habr.com/post/353012/). Отдельных статей с обзорами я не нашёл, да и кандидатов для обзора не так много.


# Программное обеспечение

При построении архитектуры я руководствовался [статьёй от некоего Cloud Architect](https://habr.com/post/328048/) 2017 года. Весьма грамотно, за исключением некоторых излишеств, которые я убрал в своём варианте.
Однозначно, данная статья рекомендуется к прочтению.

Желательно также почитать ["FreeNAS: A Worst Practices Guide"](http://www.freenas.org/blog/freenas-worst-practices/).

Ещё несколько мелких улучшений есть в статье ["Реализация некоторых задач для самосборного NAS"](https://habr.com/post/256173/) 2015 года.


## Файловые системы в общем и ZFS

Вообще, я использую ZFS, но стоит почитать тему ["Помогите выбрать файловую систему"](https://forums.freenas.org/index.php?threads/Помогите-выбрать-файловую-систему.48929/), чтобы увидеть некоторые её недостатки.


### Теория

В работе ["End-to-end Data Integrity for File Systems: A ZFS Case Study"](http://research.cs.wisc.edu/adsl/Publications/zfs-corruption-fast10.pdf) показано где и как происходят повреждения данных и каким образом от них возможно защититься, на примере ZFS.

Чтобы понять, как устроена и функционирует ZFS на высоком уровне, есть статья ["Архитектура ZFS"](https://www.opennet.ru/soft/fs/zfs_arch.pdf) 2008 года, но до сих пор актуальная.
На более низком уровне, это позволит сделать статья ["Как ZFS хранит данные"](https://habr.com/post/348354/) 2018 года.

Статья ["ZFS RAIDZ stripe width, or: How I Learned to Stop Worrying and Love RAIDZ"](https://www.delphix.com/blog/delphix-engineering/zfs-raidz-stripe-width-or-how-i-learned-stop-worrying-and-love-raidz) даёт понимание некоторых особенностей RAIDZ.

По ZoL есть статья ["ZFS on Linux: вести с полей 2017"](https://habr.com/post/314506/).

["FreeNAS Guide, 27. ZFS PrimerЭ](https://doc.freenas.org/9.10/zfsprimer.html) содержит общее описание ZFS и ссылки на полезные статьи.


### Практика

Работа с ZFS достаточно хорошо описана в [Oracle Solaris ZFS Administration Guide](https://docs.oracle.com/cd/E26505_01/html/E37384/index.html).
Есть также небольшой полезный [Cheat Sheet](http://www.datadisk.co.uk/html_docs/sun/sun_zfs_cs.htm).

В статьях ниже описаны возможные проблемы и накладные расходы, при использовании ZFS:

- ["ZFS Storage Overhead"](https://wintelguy.com/2017/zfs-storage-overhead.html).
- ["The 'Hidden' Cost of Using ZFS for Your Home NAS"](http://louwrentius.com/the-hidden-cost-of-using-zfs-for-your-home-nas.html)

Некоторые улучшения производительности описаны в статьях:

- ["Performance tuning"](http://open-zfs.org/wiki/Performance_tuning).
- ["FreeBSD ZFS Tuning Guide"](https://wiki.freebsd.org/ZFSTuningGuide).
- ["ZFS Evil Tuning Guide"](https://www.solaris-cookbook.eu/solaris/solaris-10-zfs-evil-tuning-guide/).

[Руководство по ZFS](https://docs.oracle.com/cd/E19253-01/820-0836/index.html) от Oracle.


### SLOG и L2ARC

Обязательно стоит почитать статью ["The ZFS ZIL and SLOG Demystified"](http://www.freenas.org/blog/zfs-zil-and-slog-demystified/) 2015 года, чтобы понять, для чего вообще нужен SLOG и чем отличается от ZIL.
Неплохое описание есть на форуме в теме ["Some insights into SLOG/ZIL with ZFS on FreeNAS"](https://forums.freenas.org/index.php?threads/some-insights-into-slog-zil-with-zfs-on-freenas.13633/).

В процессе настройки ZFS возникает много вопросов по поводу выбора размера под служебные разделы и оборудования под SLOG и L2ARC.

На них позволят ответить следующие статьи и темы форума:

- ["To SLOG or not to SLOG: How to best configure your ZFS Intent Log"](https://www.ixsystems.com/blog/o-slog-not-slog-best-configure-zfs-intent-log/).
- ["Calculation of SSD size for SLOG/ZIL device"](https://forums.freenas.org/index.php?threads/calculation-of-ssd-size-for-slog-zil-device.17515/).
- ["Formula for size of L2ARC needed"](https://forums.freenas.org/index.php?threads/formula-for-size-of-l2arc-needed.17947/).
- [ZFS and SSD cache size (log (zil) and L2ARC)](https://forums.freenas.org/index.php?threads/zfs-and-ssd-cache-size-log-zil-and-l2arc.6345/).
- [Why ZIL Size Matters or Doesn't](https://bsdmag.org/zil-size/).
- [ZFS L2ARC sizing and memory requirements](https://forum.proxmox.com/threads/zfs-l2arc-sizing-and-memory-requirements.23601/).


## Backup

### Теория

Есть полезные статьи:

- ["Практические рекомендации по политике резервного копирования"](https://habr.com/company/veeam/blog/176927/) 2013 года.
- ["12 заповедей про бэкап, за которые я чуть не заплатил пальцем"](https://habr.com/company/croc/blog/230153/) 2014 года.

И тема Debian рассылки, где обсуждались вопросы резервного копирования, защиты от деградации носителей и использования ZFS: ["Стратегия поддержания резервных копий, деградация носителей"](https://lists.debian.org/debian-russian/2017/06/msg00551.html)


### Примеры

Стоит ознакомиться с некоторыми примерами того, как резервное копирование производится в организациях:

- ["Типовой регламент резервного копирования данных"](http://securitypolicy.ru/шаблоны/резервирование).
- ["Положение о системе резервного копирования (финансовые организации)"](https://webhamster.ru/mytetrashare/index/mtb0/1406025395vis8u209pw)
- ["Разработка политики резервного копирования в компании"](http://info-bryansk.ru/about_the_software/backup/development_of_backup_policy_in_the_company/).


### Программное обеспечение

Ссылки на статьи про разное ПО вразнобой:

- ["22 Outstanding Backup Utilities for Linux Systems in 2018"](https://www.tecmint.com/linux-system-backup-tools/).
- ["Быстрая настройка резервного копирования под Linux и не только (UrBackup)"](https://habr.com/post/262499/) 2015 года. Я решил использовать UrBackup, рекомендую почитать.
- ["О том, как я неделю вдуплял в Bareos"](https://habr.com/post/272869/) 2015 года.
- ["Bareos: ленты, Hyper-V и ещё всякое"](https://habr.com/post/275259/) 2017 года.
- ["BTSync на службе у админа"](http://vasilisc.com/btsync).
- ["BTSync как средство бэкапа"](https://habr.com/post/303950/).
- ["BackupPC Information"](http://backuppc.sourceforge.net/info.html). BackupPC неплохая безагентная система, хотя и старовата.
- [lsyncd(1) - Linux man page](https://linux.die.net/man/1/lsyncd).
- ["Box Backup: горячие резервные копии"](https://habr.com/post/8156/) 2007 года.
- ["Syncthing: свободная программа для синхронизации и резервного копирования"](https://xakep.ru/2014/05/12/62487/).


### Сервисы

Небольшое исследование ["Options regarding 'CrashPlan for Home' closure"](https://forums.freenas.org/index.php?threads/options-regarding-%E2%80%9Ccrashplan-for-home%E2%80%9D-closure-my-research-so-far.57243/) 2017


## Cloud

Есть краткие статьи Коротаева Руслана от  2017 года:

- ["Как создать персональное объектное хранилище"](https://blog.kr.pp.ru/post/2017-07-25/).
- ["Контейнеры. Как создать персональное облачное хранилище"](https://blog.kr.pp.ru/post/2017-03-01/).

И цикл статей по созданию облака:

- ["История создания домашнего облака. Часть 1. Настройка среды Debian для повседневного использования"](https://habr.com/post/371159/).
- ["История создания домашнего облака. Часть 2. Создание сервера — настройка LAMP в Debian"](https://habr.com/post/409915/).
- ["История создания домашнего облака. Часть 3. Создание персонального облака — установка и настройка Nextcloud"](https://habr.com/post/410011/).
- ["История создания домашнего облака. Часть 4. Актуализация 2018 – Debian 9 и Nextcloud 13"](https://habr.com/post/371515/).


### Seafile

Изначально я хотел использовать [Seafile](https://en.wikipedia.org/wiki/Seafile), т.к. штука достаточно быстрая и компактная, но затем переключился на [Nextcloud](https://ru.wikipedia.org/wiki/Nextcloud), у которого больше возможностей.

По Seafile возможно почитать следующее:

- [Seafile для домашнего облака](https://p.umputun.com/p/2013/03/26/seafile-dlia-domashniegho-oblaka/) 2013 года.
- [Собственный Dropbox на базе Seafile](https://xakep.ru/2014/10/08/own-dropbox/) 2014 года.
- [Wiki Arch Linux](https://wiki.archlinux.org/index.php/Seafile).


### NextCloud

По Nextcloud немного материалов, в основном обзоры функциональности:

- ["Релиз облачного хранилища Nextcloud 12, форка ownCloud"](https://www.opennet.ru/opennews/art.shtml?num=46582) 2017 года.
- ["Nextcloud Talk"](https://habr.com/post/349556/).


# Заключение

Тут упомянуты материалы не по всем подсистемам, потому что часть из них ещё не готова.
Статья будет дополняться.
Предлагайте свои материалы к добавлению.


# Благодарности

Спасибо @sevmax за интересную ссылку на пошаговую инструкцию по построению достаточно мощного NAS с большой экономией.
