#!/bin/sh

pacman -Syyu --noconfirm
pacman -S linux linux-firmware --noconfirm
systemctl disable netctl
pacman -Rns --noconfirm netctl
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager

hwclock --systohc
