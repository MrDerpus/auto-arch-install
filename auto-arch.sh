#!/bin/bash

##################################################
# Author: MrDerpus
# v0.0.2
# archlinux-2025.07.1-x86_64
#
# Experimental ONLY!
# This should not be used to install Arch Linux
# outside of a virtual machine.
# 
# https://www.youtube.com/watch?v=68z11VAYMS8
# This script was written following this tutorial,
# but I have also made it easier for automation.
#
# This is for UEFI systems only.
#
# MAKE SURE YOU HAVE ETHERNET PLUGGED IN TO YOUR
# COMPUTER! This is required to install essential
# and user defined packages.
#
# Make sure you have backed up all your files
# you, yourself have deemed worth keeping.
#
# Make sure you understand what this script does.
# Make sure you know what you are doing.
##################################################

#username@hostname
username="" # The users name.
hostname="" # Computers name.
password="" # Make it secure!
root_password="" # It's best practice to have root password and user password different. 

region=""   # Australia
city=""     # Sydney
keyboard="" # US by default

# As root type this into the terminal to get your desired locale:
# nano -l /etc/local.gen
#line 146: en_AU.UTF-8, line 154: en_GB.UTF-8, line: 171 en_US.UTF-8
locale_gen_line="" # [ en_AU.UTF-8 ] 

### Packages to pacstrap ###
pacstrap_pacs=(
	base
	linux
	linux-firmware
	sof-firmware
	base-devel
	grub
	efibootmgr
	nano
	networkmanager
	amd-ucode    # swap between CPU arch depending on system.
	#intel-ucode #
	)

### Desktop packages ###
#gui_pacs=(
#	hyprland
#	hyprpaper
#	kitty
#	)



# Only after reading the info declared above, should you
# change the variable to 'Yes'.
# By changing this to 'Yes', you acknowledge that you are responsible
# for extra set up and potential damages done.
read="Do you understand what this file does and what this means?"



# simple colour declaration
RESET="\e[0m"
BOLD="\e[1m"
RED="${BOLD}\e[31m"
YEL="${BOLD}\e[33m"
GRN="${BOLD}\e[32m"
BLU="${BOLD}\e[36m" # cyan actually, blue is \e[34m
WHT="${BOLD}\e[37m"


_echo()
{
	text=$1
	echo -e "${text} ${RESET}"
}
#_echo "${RED} HELLO WORLD"
#exit



# Validate is user has read disclaimer.
if [[ "${read}" != "Yes" ]]; then
	_echo "\n${RED} Please make sure you read the file contents!"
	_echo "${WHT} the variable 'read' is case sensitive and\n requires you to write as: 'Yes'. \n"
	exit
fi



_echo "${YEL}* Checking for internet connectivity . . ."
# check for internet connectivity
ping -c 1 8.8.8.8 > /dev/null 2>&1
if [ $? -eq 0 ]; then

	# yes internet, run script.
	_echo "${GRN} Internet established!"
	
	if [[ "${keyboard}" != ""]]; then
		_echo "${YEL}* Setting keyboard layout to '${keyboard}' . . ."
		loadkeys "${keyboard}"

	target="/dev/sda"
	_echo "${YEL}* Zapping and creating partitions: ${WHT}'${target}1', '${target}2' & '${target}3' . . ."
	sgdisk -Z "${target}"
	sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" "${target}"
	sgdisk -n 2:0:+4G   -t 2:8200 -c 2:"Linux Swap" "${target}"
	sgdisk -n 3:0:0     -t 3:8300 -c 3:"Linux Root" "${target}"


	_echo "${YEL}* Formatting partitions . . ."
	mkfs.fat -F 32 "${target}1"
	mkswap         "${target}2"
	mkfs.ext4      "${target}3"


	_echo "${YEL}* Mounting drives . . ."
	efi_boot="/boot/efi"
	mkdir -p "/mnt${efi_boot}"
	mount  /dev/sda3  /mnt
	mount  /dev/sda1 "/mnt${efi_boot}"
	swapon /dev/sda2


	_echo "${YEL}* installing predefined pacstrap packages.\n This may take some time to install . . ."
	sleep 2
	pacstrap /mnt "${pacstrap_pacs[@]}"
	genfstab /mnt > /mnt/etc/fstab


	_echo "${YEL}* Setting: zoneinfo, system clock, locale, user & hostname as ${BLU}arch-root${YEL} . . ."
	arch-chroot /mnt /bin/bash -c "
		ln -sf /usr/share/zoneinfo/${region}/${city} /etc/localtime &&
		hwclock --systohc &&
		sed -i '/^#${locale_gen_line}/s/^#//' /etc/locale.gen &&
		locale-gen &&
		echo 'LANG=${locale_gen_line}' > /etc/locale.conf &&
		echo '${hostname}' > /etc/hostname &&
		echo -e '127.0.0.1\\tlocalhost\\n::1\\tlocalhost\\n127.0.1.1\\t${hostname}.localdomain\\t${hostname}' > /etc/hosts &&
		echo 'root:${root_password}' | chpasswd &&
		useradd -m -G wheel -s /bin/bash ${username} &&
		echo '${username}:${password}' | chpasswd &&
		sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers &&
		systemctl enable NetworkManager &&
		grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB &&
		grub-mkconfig -o /boot/grub/grub.cfg
	"

	_echo "${YEL}* Safely unmounting drives . . ."
	umount -a

	_echo "${GRN} SUCCESSFULLY RAN ALL COMMANDS!\n ${WHT} You may now:${YEL} 'sudo reboot now'\n Exiting script . . ."
	exit

else
	# no internet, exit script.
	_echo "${RED} You are not connected to the internet.\n You are required to be connected to the internet for this script to: download essential & defined packages."
	exit
fi
