#!/bin/sh
# License: MIT

set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
MIRRORLIST_URL="https://www.archlinux.org/mirrorlist/?country=GB&protocol=https&use_mirror_status=on"

pacman -Sy --noconfirm pacman-contrib dialog archlinux-keyring
pacman-key --refresh-keys

curl -s "$MIRRORLIST_URL" | \
	sed -e 's/^#Server/Server/' -e '/^#/d' | \
	rankmirrors -n 5 - > /etc/pacman.d/mirrorlist

hostname=$(dialog --stdout --inputbox "Enter hostname" 0 0) || exit 1
clear
: ${hostname:?"hostname cannot be empty"}

user=$(dialog --stdout --inputbox "Enter admin username" 0 0) || exit 1
clear
: ${user:?"user cannot be empty"}

password=$(dialog --stdout --passwordbox "Enter admin password" 0 0) || exit 1
clear
: ${password:?"password cannot be empty"}
password2=$(dialog --stdout --passwordbox "Enter again" 0 0) || exit 1
clear
[[ "$password" == "$password2" ]] || ( echo "Passwords did not match"; exit 1; )
clear

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Select installation disk" 0 0 0 ${devicelist}) || exit 1
clear

timedatectl set-ntp true

umount --force -R /mnt || /bin/true

wipefs -af ${device}
wipefs -f -a ${device}
dd if=/dev/zero of=${device} bs=1M count=1024

parted --script "${device}" mklabel msdos \
	mkpart primary ext4 1Mib 98% \
    mkpart primary ext4 98% 100% \
	set 2 boot on \

part_boot="$(ls ${device}* | grep -E "^${device}p?2$")"
part_crypt="$(ls ${device}* | grep -E "^${device}p?1$")"

wipefs "${part_boot}"
wipefs "${part_crypt}"

mkfs.ext4 "${part_boot}"

cryptsetup -c aes-xts-plain64 -y --use-random luksFormat "${part_crypt}"

cryptsetup luksOpen "${part_crypt}" luks

pvcreate /dev/mapper/luks
vgcreate vg0 /dev/mapper/luks
lvcreate --size 6G vg0 --name swap
lvcreate -l +100%FREE vg0 --name root

mkswap /dev/mapper/vg0-swap

mkfs.ext4 /dev/mapper/vg0-root

swapon /dev/mapper/vg0-swap
mount /dev/mapper/vg0-root /mnt
mkdir /mnt/boot
mount "${part_boot}" /mnt/boot
#mkdir -p /mnt/boot/loader/entries

pacman -Syy
pacstrap /mnt base base-devel mkinitcpio lvm2 sudo intel-ucode
genfstab -pU /mnt >> /mnt/etc/fstab
echo "${hostname}" > /mnt/etc/hostname
cat <<EOF > /mnt/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 $(echo $hostname).local $(echo $hostname)
EOF
mkdir /mnt/scripts &>/dev/null
cp *.sh /mnt/scripts &>/dev/null
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/

echo "LANG=en_GB.UTF-8" > /mnt/etc/locale.conf
echo "en_GB.UTF-8 UTF-8" > /mnt/etc/locale.gen
echo "en_GB ISO-8859-1" > /mnt/etc/locale.gen

arch-chroot /mnt useradd -mU -s /usr/bin/bash -G wheel "$user"
echo "$user:$password" | chpasswd --root /mnt
echo "root:$password" | chpasswd --root /mnt
echo "$user ALL=(ALL:ALL) ALL' >> /etc/sudoers"

arch-chroot /mnt /scripts/chrooted.sh

