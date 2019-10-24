mount /dev/mapper/vg0-root /mnt/gentoo
ntpd -q -g
cd /mnt/gentoo
echo "If wget fails, go to lynx https://www.gentoo.org/downloads/mirrors/"
wget https://mirror.bytemark.co.uk/gentoo/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-20191013T214502Z.tar.xz # this WILL change
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
nano -w /mnt/gentoo/etc/portage/make.conf

