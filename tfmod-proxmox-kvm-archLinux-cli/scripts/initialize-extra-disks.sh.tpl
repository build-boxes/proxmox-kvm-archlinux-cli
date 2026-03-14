#!/usr/bin/env bash
set -eu

echo ">>> Logged in cloned VM...."

echo "Resetting 'root' password expiration..."
echo "root:${root_new_password}" | sudo chpasswd
sudo chage -I -1 -m 0 -M -1 -E -1 root

echo "${superuser_username}:${superuser_password}" | chpasswd
echo ">>> Done -- Super-User creation...."

chage -m 0 -M -1 -E -1 ${superuser_username}
echo ">>> Done -- Prevent superuser password expiration...."

export BUILD_DIR="/tmp/arch-build"

if [[ "${rsyslog_yay_aur_installed}" =~ ^(true|True|TRUE)$ ]]; then
  echo ">>> INSTALL_AUR_YAY is true, installing yay from AUR...."
  sudo mkdir -p "$BUILD_DIR"
  sudo chown ${superuser_username}:${superuser_username} "$BUILD_DIR"

  cd $BUILD_DIR && git clone 'https://aur.archlinux.org/yay.git' && cd yay && makepkg -si --noconfirm
  rm -rf "$BUILD_DIR"

  echo ">>> Done -- Installed yay from AUR...."
  yay --version

  echo ">>> Updating mirrors and upgrading all packages...."
  sudo pacman -Syy --noconfirm
  yay -Syu --noconfirm

  echo ">>> Installing rsyslog from AUR...."
  yay -S --noconfirm rsyslog
fi

echo "Starting non-boot disk initialization for LVM..."
n=2

for disk in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'); do
  if ! sudo lsblk /dev/$disk | grep -q part; then
    echo "Found raw disk: /dev/$disk"

    sudo parted -s /dev/$disk mklabel gpt
    sudo parted -s /dev/$disk mkpart ext4 0% 100%
    sudo partprobe /dev/$disk

    sudo pvcreate /dev/${disk}1
    sudo vgcreate my_vg_edisk$n /dev/${disk}1
    ((n++))

    echo "Initialized /dev/${disk}1 for LVM"
  fi
done

echo "... Non-boot disk initialization for LVM completed."
