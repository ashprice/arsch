#!/bin/sh

pacman -Syyu --noconfirm
pacman -S linux linux-firmware --noconfirm
systemctl disable netctl || /bin/true
pacman -Rns --noconfirm netctl || /bin/true
pacman -S --noconfirm networkmanager grub
systemctl enable NetworkManager
echo 'HOOKS=(base systemd autodetect sd-vconsole modconf block keyboard keymap sd-encrypt sd-lvm2 fsck filesystems)' >> /etc/mkinitcpio.conf
rot=$(cryptsetup status luks|grep device|awk '{print $2}')
cryptrot="$(blkid $rot|awk '{print $2}'|sed 's/^.\{6\}//'|sed 's/.\{1\}$//')"
sed -i "s@GRUB_CMDLINE_LINUX_DEFAULT=\"logleveel=3 quiet\"@GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=${rot}:luks root=/dev/mapper/vg0-root loglevel=3 quiet\"@" /etc/default/grub
sed -i "s/^#GRUB_DISABLE_LINUX_UUID/GRUB_DISABLE_LINUX_UUID/" /etc/default/grub

mkinitcpio -p linux
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
echo 'MAKEFLAGS="-j$(nproc)"' >> /etc/makepkg.conf

ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc

echo 'store /dev/md127 none luks,timeout=180' >> /etc/crypttab
echo '/dev/mapper/vg1-store /store ext4 rw,relatime,noauto,x-systemd.automount 0 2' >> /etc/fstab

pacman -S --noconfirm git fakeroot
su ${user} && cd
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd .. && rm -r yay/

yay -S --noconfirm tlp tlp-rdw smartmontools ethtool tp-smapi acpi_call acpi
exit
cat << EOF > /etc/tlp.conf
TLP_ENABLE=1
DISK_IDLE_SECS_ON_AC=0
DISK_IDLE_SECS_ON_BAT=5
MAX_LOST_WORK_SECS_ON_AC=15
MAX_LOST_WORK_SECS_ON_BAT=60
CPU_SCALING_GOVERNOR_ON_AC=ondemand
CPU_SCALING_GOVERNOR_ON_BAT=conservative
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
SCHED_POWERSAVE_ON_AC=0
SCHED_POWERSAVE_ON_BAT=1
NMI_WATCHDOG=0
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="128 128"
SATA_LINKPWR_ON_AC=max_performance
SATA_LINKPWR_ON_BAT=min_power
PCIE_ASPM_ON_AC=performance
PCIE_ASPM_ON_BAT=powersave
EOF
tlp start
su vofan
yay -S --noconfirm abook adobe-source-han-mono-otc-fonts adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts adobe-source-serif-pro-fonts python-pyalsa pulseaudio pulseaudio-alsa android-tools arandr archiso-git arch-wiki-lite atool aurutils-git bashdb bat bc biber borg breeze-icons cmatrix colorz coreutils cronie cryptsetup cuetools device-mapper devtools dhcpcd dialog discord dmenu dmraid downgrade dunst dupeguru-git e2fsprogs ed efivar exfat-utils falkon ffmpeg-compat-57 ffmpeg-git ffnvcode-headers firefox fish fzf gentium-plus-font gettext ghostscript gimp gnome-keyring gtk-theme-arc-gruvbox-git htop-vim-git httrack hwinfo i3blocks i3-gaps i3lock i3status ibus ibus-grc-beta-code-git ibus-m17n ibus-mozc ibus-table ibus-table-others imagemagick intel-ucode iputils keyman kmfl-keyboard-eurolatin kmfl-keyboard-ipa less libopusenc libxft-bgra links logrotate lolcat lostfiles lrzip lsd lshw lsof
exit
echo << EOF > /etc/pulse/daemon.conf
high-priority = yes
nice-level = -15
realtime-scheduling = yes
realtime-priority = 9
resample-method = speex-float-5
avoid-resampling = yes
default-sample-format = float32le
default-sample-rate = 44100
alternate-sample-rate = 96000
default-sample-channels = 2
default-channel-map = front-left,front-right
deferred-volume-safety-margin-usec = 1
EOF
