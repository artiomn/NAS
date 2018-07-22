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

