#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "[*] This script must be run as root"
   exit 1
fi

if [[ -f "/sys/bus/wmi/devices/7A4DDFE7-5B5D-40B4-8595-4408E0CC7F56/" ]]; then
    echo "[*] Sorry but your device doesn't have the required WMI module"
    exit 1
fi

# Remove previous chr devices if any exists
rm /dev/acer-gkbbl-0 /dev/acer-gkbbl-static-0 -f

fix_missing_make() {
    if [[ -f /etc/debian_version ]]; then
        echo "Detected Debian-based system. Proceeding with installation..."
        apt install make
        apt-get install linux-headers-$(uname -r) gcc make
        
        make || echo "Failed to install Make dependencies. Please install them manually." && exit 1
    else
        echo "Not a supported system, you'll have to resolve Make dependencies yourself."
    fi
}
# compile the kernel module
make || fix_missing_make

# check if the profile headers are exported
if [[ $(grep platform_profile_register /proc/kallsyms) == "" ]]; then
    echo "[*] Your kernel doesn't seem to export the required symbols."
    read -p "[*] Do you want to continue (if you know what you're doing)? (y/n): " -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[*] Exiting..."
        exit 1
    fi
    
    echo ""

    # check if the modinfo platform_profile returns a valid output
    modinfo platform_profile || echo "[*] Your kernel doesn't seem to have the required module" && exit 1
    modprobe platform_profile || echo "[*] Found but failed to load the platform_profile module" && exit 1

fi

# remove previous acer_wmi module
rmmod acer_wmi

# install required modules
modprobe wmi
modprobe sparse-keymap
modprobe video

# install facer module
insmod src/facer.ko || echo "[*] Failed to install facer module" && (dmesg | tail -n 10) && exit 1
dmesg | tail -n 10
echo "[*] Done"