#!/bin/sh
# License: MIT

pacman -S dialog
name=$(dialog --inputbox "Enter username" 10 60 3>&1 1>&2 2>&3 3>&1) || exit
while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
	name=$(dialog --no-cancel --inputbox "Username not valid" 10 60 3>&1 1>&2 2>&3 3>&1)
done
pass1=$(dialog --no-cancel --passwordbox "Enter a password" 10 60 3>&1 1>&2 2>&3 3>&1)
pass2=$(dialog --no-cancel --passwordbox "Retype" 10 60 3>&1 1>&2 2>&3 3>&1)
while ! [ "$pass1" = "$pass2" ]; do
	unset pass2
	pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter again." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
done
! (id -u "$name" >/dev/null) 2>&1 ||
	dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists. Installing will \\Zboverwrite\\Zn any conflicting files.\\n\\n$name's password will also be changed to the one just given." 14 70
dialog --infobox "Adding user \"name\"..." 4 50
useradd -m -g wheel -s /bin/bash "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
echo "$name:$pass1" | chpasswd
unset pass1 pass2
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

