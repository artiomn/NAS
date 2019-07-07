# /boot на ZFS зеркале

![](https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTEv3P-9688WEqvC8Sy9PNECbZcPsw5edLCQWc-XEl3Txi2purP)

Небольшая заметка, в дополнение к [статье о корневом разделе на ZFS](https://habr.com/post/351932/).
<cut />
В предыдущей статье /boot был продублирован на двух ext4 разделах, и в будущем планировалось сделать нормально.

Ядро обновляется достаточно часто и каждый раз приходилось монтировать оба /boot, обновлять ядро, копировать содержимое, делать update-grub, update-initramfs и т.п..

Это порядком надоело.

Будущее настало.

Возможно сделать это скриптом, но grub2 поддерживает загрузку с ZFS.

Потому, правильный и менее затратный вариант - это сделать /boot на ZFS зеркале. Предполагается, что условия те же, что описаны в [предыдущей статье](https://habr.com/post/351932/): Debian, root на ZFS.

## Предварительные шаги

Необходимо скопировать образы разделов, например на флешку, чтобы в случае неудачи, возможно было восстановиться к предыдущему рабочему состоянию:

```
mount /dev/disk/by-id/usb-Corsair_Flash_Voyager-0\:0-part1 /mnt/usb/
dd if=/dev/disk/by-id/ata-Micron_1100-part2 of=/mnt/usb/micron_boot.img bs=4M
dd if=/dev/disk/by-id/ata-Samsung_SSD_850_PRO-part2 of=/mnt/usb/samsung_boot.img bs=4M
umount /mnt/usb
```

**Обязательно извлеките флешку из USB после этого.**

Надо проверить загружается ли модуль zfs в grub:

```
grep -R zfs /boot/grub/grub.cfg 
```

В результате должна быть выведена строка `insmod zfs`.
Если её там нет, надо добавить такую строку в /etc/default/grub:

```
GRUB_PRELOAD_MODULES="zfs"
```

В принципе, grub сам добавит нужный модуль, когда обнаружит установку на ZFS, но лучше перестраховаться.

Теперь потребуется скопировать содержимое загрузочного раздела, которое потребуется в будущем:

```
mount /dev/disk/by-id/ata-Micron_1100-part2 /boot
tar -C / -cf ~/boot.tar /boot
tar tf ~/boot.tar
```

В результате, на экран должен быть выведен список файлов из /boot.

Теперь ФС возможно отмонтировать:

```
umount /boot
```


## Создание ZFS пула и загрузочной ФС

```
rm -rf /boot
zpool create -f -o ashift=12 \
  -O atime=off -O compression=lz4 -O normalization=formD \
  -O mountpoint=none \
  boot_pool mirror /dev/disk/by-id/ata-Micron_1100-part2 /dev/disk/by-id/ata-Samsung_SSD_850_PRO-part2
zfs create -o mountpoint=/boot boot_pool/boot
zpool set bootfs=boot_pool/boot boot_pool
zfs mount|grep /boot
```

<spoiler title="Примечание о параметре ashift">
`ashift` - степень, в которую надо возвести двойку, чтобы получить указанный размер блока.
12 - это блок 4K.
Получить размер блока возможно командой `blockdev --getbsz /dev/<disk>`, либо из технической спецификации на устройство.
</spoiler>

Если в результате, появится строка `boot_pool                       /boot`, пул был создан корректно, а dataset примонтирован.

```
zpool list boot_pool  -v
```

Должен вывести что-то подобное:

```
NAME   SIZE  ALLOC   FREE  EXPANDSZ   FRAG    CAP  DEDUP  HEALTH  ALTROOT
boot_pool  1008M   220M   788M         -     7%    21%  1.00x  ONLINE  -
  mirror  1008M   220M   788M         -     7%    21%
    /dev/disk/by-id/ata-Micron_1100-part2      -      -      -         -      -      -
    /dev/disk/by-id/ata-Samsung_SSD_850_PRO-part2      -      -      -         -      -      -
```


## Установка загрузчика

Предварительно надо проверить, что grub понимает ФС:

```
grub-probe /boot
```

Должна быть выведена строка `zfs`.

```
tar -C / -xf ~/boot.tar
ls /boot
```

После завершения распаковки на экран будет выведен список файлов в /boot.

Далее, обновление initramfs и установка загрузчика:

```
update-initramfs -k all -u
grub-install --bootloader-id=debian1 --recheck --no-floppy /dev/disk/by-id/ata-Samsung_SSD_850_PRO
grub-install --bootloader-id=debian2 --recheck --no-floppy /dev/disk/by-id/ata-Micron_1100
ZPOOL_VDEV_NAME_PATH=YES update-grub
```

Процесс займёт некоторое время. Загрузчик, по-идее возможно не переустанавливать, но у меня без этого не заработало.

Теперь надо перезагрузиться:

```
reboot
```

После перезагрузки `zfs mount|grep /boot` выведет `boot_pool/boot                  /boot`, что означает: всё прошло корректно.


## Если что-то пошло не так

Достаточно загрузиться с [Live USB](https://www.debian.org/CD/live/) и скопировать один из образов обратно:

```
mount /dev/disk/by-id/usb-Corsair_Flash_Voyager-0\:0-part1 /mnt/usb/
dd if=micron_boot of=/dev/disk/by-id/ata-Micron_1100-part2 bs=4M
umount /boot
```

После этого возможно грузиться с восстановленного загрузочного раздела.
