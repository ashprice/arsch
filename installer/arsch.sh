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

umount --force -R /mnt 2>/dev/null || /bin/true

wipefs -af ${device}
wipefs -f -a ${device} &>/dev/null
dd if=/dev/zero of=${device} bs=1M count=1024 &>/dev/null

parted --script "${device}" mklabel gpt \
	mkpart ESP fat32 1Mib 256Mib \
	set 1 boot on \
	mkpart primary ext4 256MIB 100% || /bin/true

part_boot="$(ls ${device}* | grep -E "^${device}p?1$")"
part_crypt="$(ls ${device}* | grep -E "^${device}p?2$")"

wipefs "${part_boot}"
wipefs "${part_crypt}"

mkfs.vfat -F32 "${part_boot}"

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
mkdir -p /mnt/boot/loader/entries &>/dev/null

pacman -Syy &>/dev/null
pacstrap /mnt base pacman-contrib mkinitcpio lvm2 sudo intel-ucode
genfstab -pU /mnt >> /mnt/etc/fstab
echo "${hostname}" > /mnt/etc/hostname
cat <<EOF > /mnt/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 $(echo $hostname).local $(echo $hostname)
EOF
mkdir /mnt/scripts &>/dev/null
cp *.sh /mnt/scripts &>/dev/null
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/ &>/dev/null

cat <<EOF > /mnt/boot/loader/loader.conf
default arch
EOF

cat <<EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value /dev/mapper/vg0-root) rw
EOF

echo "LANG=en_GB.UTF-8" > /mnt/etc/locale.conf

arch-chroot /mnt useradd -mU -s /usr/bin/bash -G wheel "$user"

echo "$user:$password" | chpasswd --root /mnt
echo "root:$password" | chpasswd --root /mnt

# below assumes admin user is setup
arch-chroot /mnt

MIRRORLIST_URL="https://www.archlinux.org/mirrorlist/?country=GB&protocol=https&use_mirror_status=on"
curl -s "$MIRRORLIST_URL" | \
	sed -e 's/^#Server/Server/' -e '/^#/d' | \
	rankmirrors -n 5 - > /etc/pacman.d/mirrorlist
pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1
dialog --infobox "Installing \`basedevel\` and \`git\`." 5 70
pacman --noconfirm --needed -S base-devel git >/dev/null 2>&1
[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"
grep "^Color" /etc/pacman.conf >/dev/null || sed -i "s/^#Color/Color/" /etc/pacman.conf
grep "ILoveCandy" /etc/pacman.conf >/dev/null || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
[ -z "$aurhelper" ] && aurhelper="yay"
[ -f "/usr/bin/$aurhelper" ] || (
dialog --infobox "Installing \"$aurhelper\"..." 4 50
cd /tmp || exit
rm -rf /tmp/"$aurhelper"*
curl -s0 https://aur.archlinux.org/cgit/aur.git/snapshot/"$aurhelper".tar.gz &&
	sudo -u "$name" tar -xvf "$aurhelper".tar.gz >/dev/null 2>&1 &&
	cd "$aurhelper" &&
	sudo -u "$name" makepkg --noconfirm -si >/dev/null 2>&1
cd /tmp || return

