locals {
  dynamic_vars_file = "${path.root}/vars/generated-archlinux-vars.pkrvars.hcl"
}

build {
  name    = "arch-proxmox-lvm-template"
  sources = ["source.proxmox-iso.archlinux"]

  provisioner "shell" {
    inline_shebang= "/bin/bash -eu"
    inline = [<<EOF
DISK=${var.disk}
VGNAME=${var.vgname}
LVROOT=${var.lvm_root}
LVSWAP=${var.lvm_swap}
SUPERUSER=${var.superuser_name}
SUPERPASS='${var.superuser_password}'
SSH_PUBKEY='${var.superuser_ssh_pub_key}'
HOSTNAME=${var.hostname}
TIMEZONE=${var.timezone}
LOCALE=${var.locale}
KEYMAP=${var.keymap}
SWAPSIZE=${var.swap_size}
ROOTPASS=${var.archlinux_root_password}
MIRRORS_COUNTRY=${var.mirrors_country}

# Partitioning
sgdisk --zap-all $DISK
parted -s $DISK mklabel gpt
parted -s $DISK mkpart ESP fat32 1MiB 513MiB
parted -s $DISK set 1 esp on
parted -s $DISK mkpart primary 513MiB 100%
parted -s $DISK set 2 lvm on
mkfs.fat -F32 "$DISK"1

# LVM
pvcreate "$DISK"2
vgcreate $VGNAME "$DISK"2
lvcreate -L $SWAPSIZE -n $LVSWAP $VGNAME
lvcreate -l 100%FREE -n $LVROOT $VGNAME
mkfs.ext4 /dev/$VGNAME/$LVROOT
mkswap /dev/$VGNAME/$LVSWAP

# Mounting
mount /dev/$VGNAME/$LVROOT /mnt
mkdir -p /mnt/boot
mount "$DISK"1 /mnt/boot
swapon /dev/$VGNAME/$LVSWAP

# Update Mirrors
curl -o /etc/pacman.d/mirrorlist "https://archlinux.org/mirrorlist/?country=$MIRRORS_COUNTRY&protocol=https&use_mirror_status=on"
sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
pacman -Syy --noconfirm

# System config (timezone, locale, vconsole)
# ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
# hwclock --systohc
mkdir -p /mnt/etc
echo "$LOCALE UTF-8" >> /mnt/etc/locale.gen
#locale-gen
echo "LANG=$LOCALE" > /mnt/etc/locale.conf
echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
echo "$HOSTNAME" > /mnt/etc/hostname
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s.localdomain %s\n' "$HOSTNAME" "$HOSTNAME" > /mnt/etc/hosts
echo ">>> Done -- System config (timezone, locale, vconsole)....."

# Base install + networking + audio + guest agent + auto-update support
pacstrap -K /mnt \
  base linux linux-firmware lvm2 python curl wget mc sed gawk htop tree grep less tar which git nano bash sudo openssh \
  networkmanager inetutils bind-tools alsa-utils alsa-plugins mpg123 pacman-contrib qemu-guest-agent

echo ">>> Done -- pacstrap...."

genfstab -U /mnt >> /mnt/etc/fstab
echo ">>> Done -- genfstab...."

# Chroot configuration
arch-chroot /mnt /bin/bash <<CHROOTEOF
echo ">>> Done -- Inside arch-chroot...."
set -eu
echo ">>> Done -- Inside arch-chroot - -eu...."


# System config (timezone, locale, vconsole)
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
# echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
# echo "LANG=$LOCALE" > /etc/locale.conf
# echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
# echo "$HOSTNAME" > /etc/hostname
# printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s.localdomain %s\n' "$HOSTNAME" "$HOSTNAME" > /etc/hosts
echo ">>> Done -- Inside arch-chroot - hwclock, locale-gen...."

# Ensure lvm2 is in mkinitcpio HOOKS before filesystems
# This inserts lvm2 if not already present and ensures correct order.
#sed -i 's/^HOOKS=(\(.*\)filesystems/\1lvm2 filesystems/' /etc/mkinitcpio.conf || true
grep -q "lvm2" /etc/mkinitcpio.conf || sed -i 's/filesystems/lvm2 filesystems/' /etc/mkinitcpio.conf
echo ">>> Done -- Inside arch-chroot - sed HOOKS...."

# Build initramfs images and capture output for debugging
mkinitcpio -P 2>&1 | tee /tmp/mkinitcpio.log
echo ">>> Done -- Inside arch-chroot - mkinitcpio...."

# systemd-boot bootloader
bootctl install
echo ">>> Done -- Inside arch-chroot - bootctl install...."

cat > /boot/loader/loader.conf <<EOF_LOADER
default arch
timeout 3
editor no
EOF_LOADER

cat > /boot/loader/entries/arch.conf <<EOF_ARCH
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=/dev/$VGNAME/$LVROOT rw console=ttyS0,115200n8
EOF_ARCH


# User
useradd -m -G wheel -s /bin/bash $SUPERUSER
echo "$SUPERUSER:$SUPERPASS" | chpasswd

# Sudo rules
printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$SUPERUSER" > /etc/sudoers.d/11-superuser
chmod 440 /etc/sudoers.d/11-superuser

# SSH key
mkdir -p /home/$SUPERUSER/.ssh
chmod 700 /home/$SUPERUSER/.ssh
echo "$SSH_PUBKEY" > /home/$SUPERUSER/.ssh/authorized_keys
chmod 600 /home/$SUPERUSER/.ssh/authorized_keys
chown -R $SUPERUSER:$SUPERUSER /home/$SUPERUSER/.ssh

# Enable services
systemctl enable NetworkManager
systemctl enable sshd
# systemctl enable alsa-restore
# systemctl enable alsa-state
# systemctl enable qemu-guest-agent
# ensure qemu-guest-agent unit exists
if [ -f /usr/lib/systemd/system/qemu-guest-agent.service ]; then
  # if unit has an [Install] section, use systemctl enable
  if grep -q '^\[Install\]' /usr/lib/systemd/system/qemu-guest-agent.service; then
    systemctl enable qemu-guest-agent.service || true
  else
    # create the symlink manually so it starts at boot
    mkdir -p /etc/systemd/system/multi-user.target.wants
    ln -sf /usr/lib/systemd/system/qemu-guest-agent.service \
          /etc/systemd/system/multi-user.target.wants/qemu-guest-agent.service
  fi
fi
echo ">>> Done -- Inside arch-chroot - enable NetworkManager, sshd...."

# # Install cloud-init
# systemd-machine-id-setup
# mkdir -p /etc/cloud
# touch /etc/cloud/cloud.cfg
# systemctl daemon-reload
# pacman --noconfirm -S cloud-init
# systemctl daemon-reload
# echo ">>> Done -- Inside arch-chroot - Installed cloud-init..."
# # Enable cloud-init services only if installed
# if pacman -Q cloud-init >/dev/null 2>&1; then
#     systemctl enable cloud-init-local.service
#     systemctl enable cloud-init.service
#     systemctl enable cloud-config.service
#     systemctl enable cloud-final.service
# else
#     echo "WARNING: cloud-init is not installed; skipping enable"
# fi

# Prepare NoCloud datasource directory for Proxmox
mkdir -p /var/lib/cloud/seed/nocloud-net
chmod 755 /var/lib/cloud/seed
chmod 755 /var/lib/cloud/seed/nocloud-net

# Ensure DHCP is default for all interfaces (cloud-init expects this)
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/10-dhcp-default.conf <<EOF_NM
[main]
plugins=keyfile

[connection]
ipv4.method=auto
ipv6.method=auto
EOF_NM

systemctl restart NetworkManager

# Automatic updates
cat > /etc/systemd/system/auto-update.service <<EOF2
[Unit]
Description=Automatic system update

[Service]
Type=oneshot
ExecStart=/usr/bin/pacman -Syu --noconfirm
EOF2

cat > /etc/systemd/system/auto-update.timer <<EOF3
[Unit]
Description=Run automatic updates daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF3

systemctl enable auto-update.timer

CHROOTEOF
echo ">>> Done -- chroot - Outside CHROOT now..."

# # Start - Handle Cloud-init inside the New CHRooted Filesystem.
# arch-chroot /mnt /bin/bash -c 'systemd-machine-id-setup'
# mkdir -p /mnt/etc/cloud
# touch /mnt/etc/cloud/cloud.cfg
# # reload generators and unit files for the target root
# systemctl --root=/mnt daemon-reload || true
# # enable cloud-init units on the target root (creates the symlinks)
# systemctl --root=/mnt enable cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service || true
# # if generator exists in the installed tree, run it inside the chroot to create units
# if [ -x /mnt/usr/lib/systemd/system-generators/cloud-init ]; then
#   chroot /mnt /usr/lib/systemd/system-generators/cloud-init
#   # then reload and enable again
#   systemctl --root=/mnt daemon-reload || true
#   systemctl --root=/mnt enable cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service || true
# fi
# ls -l /mnt/usr/lib/systemd/system | grep cloud || true
# ls -l /mnt/etc/systemd/system/cloud-init.target.wants || true
# systemctl --root=/mnt list-unit-files | grep cloud || true
# echo ">>> Done -- Cloud-init handling..."
# # End - Handle Cloud-init inside the New CHRooted Filesystem.

swapoff /dev/$VGNAME/$LVSWAP
umount -R /mnt
EOF
]
  }

  # # Copy default cloud-init config
  # provisioner "file" {
  #   destination = "/etc/cloud/cloud.cfg"
  #   source      = "http/cloud.cfg"
  # }

  # # Replace superuser_name placeholder in cloud.cfg
  # provisioner "shell" {
  #   inline = [
  #     "awk -v old='<<superuser_name>>' -v new='${var.superuser_name}' '{gsub(old, new); print}' /etc/cloud/cloud.cfg > /tmp/cloud.cfg && mv /tmp/cloud.cfg /etc/cloud/cloud.cfg"
  #   ]
  # }

  # # Replace superuser_gecos placeholder in cloud.cfg
  # provisioner "shell" {
  #   inline = [
  #     "awk -v old='<<superuser_gecos>>' -v new='${var.superuser_gecos}' '{gsub(old, new); print}' /etc/cloud/cloud.cfg > /tmp/cloud.cfg && mv /tmp/cloud.cfg /etc/cloud/cloud.cfg"
  #   ]
  # }

  # # Replace superuser_password placeholder in cloud.cfg
  # provisioner "shell" {
  #   inline = [
  #     "awk -v old='<<superuser_password>>' -v new='${var.superuser_password}' '{gsub(old, new); print}' /etc/cloud/cloud.cfg > /tmp/cloud.cfg && mv /tmp/cloud.cfg /etc/cloud/cloud.cfg"
  #   ]
  # }

  # # Replace superuser_ssh_pub_key placeholder in cloud.cfg
  # provisioner "shell" {
  #   inline = [
  #     "awk -v old='<<superuser_ssh_pub_key>>' -v new='${var.superuser_ssh_pub_key}' '{gsub(old, new); print}' /etc/cloud/cloud.cfg > /tmp/cloud.cfg && mv /tmp/cloud.cfg /etc/cloud/cloud.cfg"
  #   ]
  # }

  # # Copy Proxmox cloud-init config
  # provisioner "file" {
  #   destination = "/etc/cloud/cloud.cfg.d/99-pve.cfg"
  #   source      = "http/99-pve.cfg"
  # }
}