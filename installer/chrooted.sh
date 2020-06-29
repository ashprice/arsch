#!/bin/sh

pacman -Syyu --noconfirm
pacman -S linux linux-firmware --noconfirm
systemctl disable netctl || /bin/true
pacman -Rns --noconfirm netctl || /bin/true
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager
echo 'HOOKS=(base systemd autodetect sd-vconsole modconf block keyboard keymap sd-encrypt sd-lvm2 fsck filesystems' >> /etc/mkinitcpio.conf
rot=$(cryptsetup status luks|grep device|awk '{print $2}')
cryptrot="$(blkid $rot|awk '{print $2}'|sed 's/^.\{6\}//'|sed 's/.\{1\}$//')"
cat <<EOF > /boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options rd.luks.uuid=${cryptrot} rd.luks.options=discard root=/dev/mapper/vg0-root quiet loglevel=3 rd.udev.log_priority=3 rd.systemd.show_status=auto vga=current fan_control=1
EOF

mkinitcpio -p linux
bootctl --path=/boot/ install
echo 'MAKEFLAGS="-j$(nproc)"' >> /etc/makepkg.conf

ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc

