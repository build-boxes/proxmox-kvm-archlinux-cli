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
SUPERPASS='${var.superuser_password_plain}'
SSH_PUBKEY='${var.superuser_ssh_pub_key}'
SUPERUSER_GECOS='${var.superuser_gecos}'
ROOTPASS='${var.archlinux_root_new_password_plain}'
HOSTNAME=${var.hostname}
TIMEZONE=${var.timezone}
LOCALE=${var.locale}
KEYMAP=${var.keymap}
SWAPSIZE=${var.swap_size}
ROOTPASS=${var.archlinux_root_password}
MIRRORS_COUNTRY=${var.mirrors_country}
SEED_URL=${var.seed_url}
INSTALL_AUR_YAY=${var.install_aur_yay}
BUILD_DIR="/tmp/arch-build"

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

# Save Environment Variables for use in chroot
mkdir -p /mnt/root/
cat > /mnt/root/envvars.sh <<EOF_ENV
export VGNAME="$VGNAME"
export LVROOT="$LVROOT"
export LVSWAP="$LVSWAP"
export SUPERUSER="$SUPERUSER"
export SUPERPASS='$SUPERPASS'
export SSH_PUBKEY='$SSH_PUBKEY'
export SUPERUSER_GECOS='$SUPERUSER_GECOS'
export ROOTPASS='$ROOTPASS'
export HOSTNAME="$HOSTNAME"
export TIMEZONE="$TIMEZONE"
export LOCALE="$LOCALE"
export KEYMAP="$KEYMAP"
export SWAPSIZE="$SWAPSIZE"
export ROOTPASS="$ROOTPASS"
export MIRRORS_COUNTRY="$MIRRORS_COUNTRY"
export DISK="$DISK"
export SEED_URL="$SEED_URL"
export INSTALL_AUR_YAY="$INSTALL_AUR_YAY"
export BUILD_DIR="$BUILD_DIR"
EOF_ENV
chmod +x /mnt/root/envvars.sh

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
  networkmanager inetutils bind-tools alsa-utils alsa-plugins mpg123 pacman-contrib ntp qemu-guest-agent \
  tzdata cloud-guest-utils gptfdisk glibc ca-certificates shadow base-devel \
  grub efibootmgr
echo ">>> Done -- pacstrap...."

genfstab -U /mnt >> /mnt/etc/fstab
echo ">>> Done -- genfstab...."

# Chroot configuration
arch-chroot /mnt /bin/bash <<CHROOTEOF
echo ">>> Done -- Inside arch-chroot...."
set -eu
echo ">>> Done -- Inside arch-chroot - -eu...."

# Retrive environment variables from the file created before chroot
source /root/envvars.sh
echo ">>> Done -- Inside arch-chroot - sourced envvars.sh...."
echo ">>> EnvVars is: VGNAME=$VGNAME, LVROOT=$LVROOT, LVSWAP=$LVSWAP, SUPERUSER=$SUPERUSER, HOSTNAME=$HOSTNAME, TIMEZONE=$TIMEZONE, LOCALE=$LOCALE, KEYMAP=$KEYMAP, SWAPSIZE=$SWAPSIZE, ROOTPASS=******, MIRRORS_COUNTRY=$MIRRORS_COUNTRY"

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
grep -q "^HOOKS=.*lvm2" /etc/mkinitcpio.conf || sed -i '/^HOOKS=.*filesystems/s/filesystems/lvm2 &/' /etc/mkinitcpio.conf
echo ">>> --- HOOKS in mkinitcpio.conf after modification:"
cat /etc/mkinitcpio.conf
echo ">>> ------------------------------"
echo ">>> Done -- Inside arch-chroot - sed HOOKS...."

# Build initramfs images and capture output for debugging
mkinitcpio -P 2>&1 | tee /tmp/mkinitcpio.log
echo ">>> --- Build initramfs - mkinitcpio output:"
cat /tmp/mkinitcpio.log
echo ">>> ------------------------------"
echo ">>> Done -- Inside arch-chroot - Build initramfs - mkinitcpio...."

# Install GRUB for UEFI
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
echo ">>> Done -- Inside arch-chroot - grub-install...."

# Configure GRUB kernel parameters
sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="root=\/dev\/'"$VGNAME"'\/'"$LVROOT"' rw console=ttyS0,115200n8"/' /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub
echo ">>> Done -- Inside arch-chroot - Configure GRUB...."

# Optional: speed up boot by disabling OS prober
sed -i "s/^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=true/" /etc/default/grub
echo ">>> --- GRUB_CMDLINE_LINUX After modification:"
cat /etc/default/grub
echo ">>> ------------------------------"
echo ">>> Done -- Inside arch-chroot - Disable OS prober...."

# Generate GRUB config
grub-mkconfig -o /boot/grub/grub.cfg
echo ">>> --- GRUB.CFG generated:"
cat /boot/grub/grub.cfg
echo ">>> ------------------------------"

echo ">>> Done -- Inside arch-chroot - Generate GRUB config...."

# Super-User
useradd -m -G wheel -s /bin/bash $SUPERUSER
echo "$SUPERUSER:$SUPERPASS" | chpasswd
echo ">>> Done -- Inside arch-chroot - User creation...."
# Super-User  - Prevent superuser password expiration
chage -m 0 -M -1 -E -1 $SUPERUSER
echo ">>> Done -- Inside arch-chroot - Prevent superuser password expiration...."
# Super-User - Set up SSH key
mkdir -p /home/$SUPERUSER/.ssh
chmod 700 /home/$SUPERUSER/.ssh
echo "$SSH_PUBKEY" > /home/$SUPERUSER/.ssh/authorized_keys
chmod 600 /home/$SUPERUSER/.ssh/authorized_keys
chown -R $SUPERUSER:$SUPERUSER /home/$SUPERUSER/.ssh
echo ">>> Done -- Inside arch-chroot - SSH key...."

# Set root password and prevent expiration
echo "root:$ROOTPASS" | chpasswd
chage -m 0 -M -1 -E -1 root
echo ">>> Done -- Inside arch-chroot - Root password setup...."

# Setup root SSH public key authentication
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$SSH_PUBKEY" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
echo ">>> Done -- Inside arch-chroot - Root SSH key setup...."

# Allow Root to login at Prompt or SSH (enable all auth methods for root)
cat >> /etc/ssh/sshd_config <<SSHTOFF

# Allow root login with password and keys
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem	sftp	/usr/lib/openssh/sftp-server
SSHTOFF
echo ">>> Done -- Inside arch-chroot - Permit root login with password and pubkey...."

# Ensure PAM allows root password login on console
# Completely replace /etc/pam.d/login to ensure root can authenticate
cat > /etc/pam.d/login <<PAMBOFF
#%PAM-1.0

auth       required    pam_securetty.so
auth       required    pam_unix.so     try_first_pass nullok
auth       optional    pam_permit.so
auth       required    pam_env.so      envfile=/etc/environment

account    required    pam_unix.so
account    optional    pam_permit.so

password   required    pam_unix.so     try_first_pass nullok sha512 shadow

session    required    pam_unix.so
session    optional    pam_permit.so
PAMBOFF
chmod 644 /etc/pam.d/login
echo ">>> Done -- Inside arch-chroot - Configured PAM /etc/pam.d/login for root console login...."

# Sudo rules Wheel/Sudo Group
printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
echo ">>> Done -- Inside arch-chroot - Wheel group SUDO rules...."

# Sudo rules Super User
printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$SUPERUSER" > /etc/sudoers.d/11-superuser
chmod 440 /etc/sudoers.d/11-superuser
echo ">>> Done -- Inside arch-chroot - Super-User SUDO rules...."

# if INSTALL_AUR_YAY is true, install yay from AUR
if [ "$INSTALL_AUR_YAY" = "true" ]; then
  echo ">>> INSTALL_AUR_YAY is true, installing yay from AUR...."
  # Install yay from AUR
  # Create a temporary directory for building yay
  echo ">>> Temporary build directory for yay: $BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  chown $SUPERUSER:$SUPERUSER "$BUILD_DIR"
  # Install necessary dependencies for building yay  
  sudo -u $SUPERUSER bash -c "cd $BUILD_DIR && git clone 'https://aur.archlinux.org/yay.git' && cd yay && makepkg -si --noconfirm"
  # Clean up the temporary build directory
  rm -rf "$BUILD_DIR"
  echo ">>> Done -- Installed yay from AUR...."
  echo ">>> Test Yay: Running 'yay --version' to verify installation...."
  sudo -u $SUPERUSER bash -c "yay --version"
else
  echo ">>> INSTALL_AUR_YAY is false, skipping yay installation...."
fi

# if INSTALL_AUR_YAY is true, update mirrors and upgrade all packages to ensure yay is up to date
if [ "$INSTALL_AUR_YAY" = "true" ]; then
  echo ">>> INSTALL_AUR_YAY is true, updating mirrors and upgrading all packages...."  
  pacman -Syy --noconfirm
  sudo -u $SUPERUSER bash -c "yay -Syu --noconfirm"
  echo ">>> Done -- Updated mirrors and upgraded all packages with yay...."
fi

# if INSTALL_AUR_YAY is true, install rsyslog from AUR using yay
if [ "$INSTALL_AUR_YAY" = "true" ]; then
  echo ">>> INSTALL_AUR_YAY is true, installing rsyslog from AUR using yay...."
  sudo -u $SUPERUSER bash -c "yay -S --noconfirm rsyslog"
  echo ">>> Done -- Installed rsyslog from AUR using yay...."
fi  

# Enable services
systemctl enable NetworkManager
systemctl enable sshd
# systemctl enable alsa-restore
# systemctl enable alsa-state
echo ">>> Done -- Inside arch-chroot - Enable services...."

# Enable Qemu Guest Agent if installed
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
  echo ">>> Done -- Inside arch-chroot - Enable qemu-guest-agent (if installed)...."
else
  echo ">>> WARNING: qemu-guest-agent is not installed; skipping enable"
fi

# # Install cloud-init
# systemd-machine-id-setup
# mkdir -p /etc/cloud
# touch /etc/cloud/cloud.cfg
# systemctl daemon-reload
# pacman --noconfirm -S cloud-init cloud-guest-utils
# systemctl daemon-reload
# echo ">>> Done -- Inside arch-chroot - Installed cloud-init..."
# # Setup a basic cloud-init.conf
# cat > /etc/cloud/cloud.cfg <<EOF_CLOUD
# users:
#   - default
# disable_root: false
# cloud_init_modules:
#   - seed_random
#   - bootcmd
#   - write_files
#   - growpart
#   - resizefs
#   - disk_setup 
#   - mounts 
#   - set_hostname 
#   - update_hostname 
#   - update_etc_hosts 
#   - ca_certs 
#   - rsyslog 
#   - users_groups 
#   - ssh 
#   - set_passwords 
# cloud_config_modules: 
#   - ssh_import_id 
#   - keyboard 
#   - locale 
#   - ntp 
#   - timezone 
#   - disable_ec2_metadata 
#   - runcmd 
# cloud_final_modules: 
#   - package_update_upgrade_install 
#   - write_files_deferred 
#   - puppet 
#   - chef 
#   - mcollective 
#   - salt_minion 
#   - reset_rmc 
#   - scripts_vendor 
#   - scripts_per_once 
#   - scripts_per_boot 
#   - scripts_per_instance 
#   - scripts_user 
#   - ssh_authkey_fingerprints 
#   - keys_to_console 
#   - install_hotplug 
#   - phone_home 
#   - final_message 
#   - power_state_change 
# # datasource_list: [ NoCloud, ConfigDrive, None ]
# # datasource:
# #   NoCloud:
# #     seedfrom: $SEED_URL
# #   None:
# #     users:
# #       - default
# #     system_info:
# #       default_user:
# #         name: $SUPERUSER
# #         password: $SUPERPASS
# #         chpasswd:
# #           expire: False
# #         lock_passwd: true
# #         gecos: $SUPERUSER_GECOS
# #         groups: [wheel, adm]
# #         sudo: ["ALL=(ALL) NOPASSWD: ALL"]
# #         shell: /bin/bash
# #         authorized_keys:
# #           - $SSH_PUBKEY
# #       disable_root: false
# #     meta_data: |
# #       #cloud-config
# #       instance_id: $HOSTNAME
# #       local-hostname: $HOSTNAME
# #     user_data: |
# #       #cloud-config
# #       runcmd:
# #         - echo 'user_data' >> /var/tmp/mydata.txt
# #         - mv /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.delete_me
# #     network_data: |
# #       #cloud-config
# #       version: 2
# #       ethernets:
# #         eth0:
# #           dhcp4: true
# #           dhcp6: false
# #           optional: true
# #     vendor_data: |
# #       #cloud-config
# #       runcmd:
# #         - echo 'vendor_data' >> /var/tmp/mydata.txt
# # Arch linux specific settings
# system_info:
#   distro: arch
#   default_user:
#     name: $SUPERUSER
#     password: $SUPERPASS
#     lock_passwd: True
#     gecos: $SUPERUSER_GECOS
#     groups: [users, wheel, adm]
#     sudo: ["ALL=(ALL) NOPASSWD: ALL"]
#     shell: /bin/bash
#     authorized_keys:
#       - $SSH_PUBKEY	
#   # Other config here will be given to the distro class and/or path classes
#   paths:
#     cloud_dir: /var/lib/cloud/
#     templates_dir: /etc/cloud/templates/
#   ssh_svcname: sshd
# EOF_CLOUD
# #
# if [ -f /etc/cloud/cloud.cfg ]; then
#   echo ">>> Cloud.cfg exists, showing content:"
#   cat /etc/cloud/cloud.cfg
#   echo ">>> Done -- Inside arch-chroot - cloud.cfg content ..."
# else
#   echo ">>> Cloud.cfg does not exist, inside arch-chroot ..."
# fi
# #
# echo ">>> Done -- Inside arch-chroot - End of Cloud.cfg setup...."
# # Enable cloud-init services only if installed
# if pacman -Q cloud-init >/dev/null 2>&1; then
#     #systemctl enable cloud-init-generator || true
#     systemctl enable cloud-init-local.service || true
#     systemctl enable cloud-init-main.service || true
#     systemctl enable cloud-config.target || true
#     systemctl enable cloud-config.service || true
#     systemctl enable cloud-final.service || true
#     systemctl enable cloud-init.target || true
# else
#     echo ">>> WARNING: cloud-init is not installed; skipping enable"
# fi
# # Prepare NoCloud datasource directory for Proxmox
# mkdir -p /var/lib/cloud/seed/nocloud-net
# chmod 755 /var/lib/cloud/seed
# chmod 755 /var/lib/cloud/seed/nocloud-net
# echo ">>> Done -- Inside arch-chroot - Prepare NoCloud datasource directory for Proxmox...."

# Ensure DHCP is default for all interfaces
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/10-dhcp-default.conf <<EOF_NM
[main]
plugins=keyfile

[connection]
ipv4.method=auto
ipv6.method=auto
EOF_NM

systemctl restart NetworkManager
echo ">>> Done -- Inside arch-chroot - NetworkManager...."

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
echo ">>> Done -- Inside arch-chroot - Automatic updates...."

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