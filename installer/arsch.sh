#!/bin/sh
# License: MIT

set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
REPO_URL="https://raw.githubusercontent.com/ashprice/arsch/master/x86_64"
MIRRORLIST_URL="https://www.archlinux.org/mirrorlist/?country=GB&protocol=https&use_mirror_status=on"

wifi-menu

wait 30

pacman -Sy --noconfirm pacman-contrib dialog

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
[[ "$password" == "$passowrd2" ]] || ( echo "Passwords did not match"; exit 1; )

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Select installation disk" 0 0 0 ${devicelist}) || exit 1
clear

exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")

timedatectl set-ntp true

parted --script "${device}" --mklabel gpt \
	mkpart ESP fat32 1Mib 129Mib \
	set 1 boot on \
	mkpart primary ext4 129MIB 100%

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

cat >> /etc/pacman.conf <<EOF
[arsch]
SigLevel = Optional TrustAll
Server = https://raw.githubusercontent.com/ashprice/arsch/master/x86_64
EOF

pacstrap /mnt arsch-desktop
genfstab -t PARTUUID /mnt >> /mnt/etc/fstab
echo "${hostname}" > /mnt/etc/hostname

cat >>/mnt/etc/pacman.conf <<EOF
[arsch]
SigLevel = Optional TrustAll
Server = https://raw.githubusercontent.com/ashprice/arsch/master/x86_64
EOF

arch-chroot /mnt bootctl install

cat <<EOF > /mnt/boot/loader/loader.conf
default arch
EOF

cat <<EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value "$part_root") rw
EOF

echo "LANG=en_GB.UTF-8" > /mnt/etc/locale.conf

arch-chroot /mnt useradd -mU -s /usr/bin/bash -G wheel "$user"

echo "$user:$password" | chpasswd --root /mnt
echo "$root:$password" | chpasswd --root /mnt

# below assumes admin user is setup
dialog --infobox "Refreshing Arch keyring..." 4 40
pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1
dialog --infobox "Installing /`basedevel\` and \`git\`." 5 70
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

