#!/bin/bash
set -eu
echo ">>> Starting Arch Linux bootstrap script...."

SSH_PUBKEY_RAW=$(printf %s "$SSH_PUBKEY_TEMP" | sed 's/^[ \t]*//;s/[ \t]*$//')
SSH_PUBKEY="$SSH_PUBKEY_RAW"
echo ">>> SSH_PUBKEY is: $SSH_PUBKEY" > /dev/null
BUILD_DIR="/tmp/arch-build"

echo ">> Environment Vars passed are:"
echo ">> DISK = $DISK"
echo ">> VGNAME = $VGNAME"
echo ">> LVROOT = $LVROOT"
echo ">> LVSWAP = $LVSWAP"
echo ">> SUPERUSER = $SUPERUSER"
echo ">> SUPERPASS = $SUPERPASS"
echo ">> SSH_PUBKEY = $SSH_PUBKEY"
echo ">> SUPERUSER_GECOS = $SUPERUSER_GECOS"
echo ">> ROOTPASSOLD = $ROOTPASSOLD"
echo ">> HOSTNAME = $HOSTNAME"
echo ">> TIMEZONE = $TIMEZONE"
echo ">> LOCALE = $LOCALE"
echo ">> KEYMAP = $KEYMAP"
echo ">> SWAPSIZE = $SWAPSIZE"
echo ">> ROOTPASSNEW = $ROOTPASSNEW"
echo ">> MIRRORS_COUNTRY = $MIRRORS_COUNTRY"
echo ">> SEED_URL = $SEED_URL"

# Partitioning
echo ">>> Starting disk partitioning...."
sgdisk --zap-all $DISK
parted -s $DISK mklabel gpt
parted -s $DISK mkpart ESP fat32 1MiB 513MiB
parted -s $DISK set 1 esp on
parted -s $DISK mkpart primary 513MiB 100%
parted -s $DISK set 2 lvm on
mkfs.fat -F32 "$DISK"1

# LVM
echo ">>> Setting up LVM2 ... pvcreate, vgcreate, lvcreate, mkfs.ext4, mkswap ...."
pvcreate "$DISK"2
vgcreate $VGNAME "$DISK"2
lvcreate -L $SWAPSIZE -n $LVSWAP $VGNAME
lvcreate -l 100%FREE -n $LVROOT $VGNAME
mkfs.ext4 /dev/$VGNAME/$LVROOT
mkswap /dev/$VGNAME/$LVSWAP

# Mounting
echo ">>> Mounting filesystems for installation.... for later use inside - chroot and then in systemd-nspawn...."
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
export SUPERUSER_GECOS="$SUPERUSER_GECOS"
export ROOTPASSOLD='$ROOTPASSOLD'
export HOSTNAME="$HOSTNAME"
export TIMEZONE="$TIMEZONE"
export LOCALE="$LOCALE"
export KEYMAP="$KEYMAP"
export SWAPSIZE="$SWAPSIZE"
export ROOTPASSNEW='$ROOTPASSNEW'
export MIRRORS_COUNTRY="$MIRRORS_COUNTRY"
export DISK="$DISK"
export SEED_URL="$SEED_URL"
export BUILD_DIR="$BUILD_DIR"
EOF_ENV
chmod +x /mnt/root/envvars.sh
echo ">>> Done -- Saved environment variables to /mnt/root/envvars.sh...."
echo ">>> Showing contents of envvars.sh ....+++++++++++++++"
cat /mnt/root/envvars.sh
echo ">>> Done -- Showed environment variables....+++++++++++++++"

# Update Mirrors
curl -o /etc/pacman.d/mirrorlist "https://archlinux.org/mirrorlist/?country=$MIRRORS_COUNTRY&protocol=https&use_mirror_status=on"
sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
pacman -Syy --noconfirm

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
  systemd dbus netplan \
  iwd linux-firmware rtl8821ce-dkms rtl88xxau-aircrack-dkms rtl8723bu-dkms broadcom-wl-dkms b43-fwcutter \
  bluez bluez-utils \
  networkmanager inetutils bind-tools alsa-utils alsa-plugins mpg123 pacman-contrib ntp qemu-guest-agent \
  tzdata cloud-guest-utils gptfdisk glibc ca-certificates shadow base-devel \
  grub efibootmgr
echo ">>> Done -- pacstrap...."

genfstab -U /mnt >> /mnt/etc/fstab
echo ">>> Done -- genfstab...."

# Chroot configuration
echo ">>> Entering arch-chroot to configure LVM2, GRUB, (users), ...."
arch-chroot /mnt /bin/bash <<"CHROOTEOF"
echo ">>> Done -- Inside arch-chroot...."
set -eu
echo ">>> Done -- Inside arch-chroot - -eu...."

# Retrive environment variables from the file created before chroot
source /root/envvars.sh
echo ">>> Done -- Inside arch-chroot - sourced envvars.sh...."
echo ">>> EnvVars are:"
echo ">>> VGNAME=$VGNAME"
echo ">>> LVROOT=$LVROOT"
echo ">>> LVSWAP=$LVSWAP"
echo ">>> SUPERUSER=$SUPERUSER"
echo ">>> SUPERPASS=$SUPERPASS"
echo ">>> SUPERUSER_GECOS=$SUPERUSER_GECOS"
echo ">>> SSH_PUBKEY=$SSH_PUBKEY"
echo ">>> HOSTNAME=$HOSTNAME"
echo ">>> TIMEZONE=$TIMEZONE"
echo ">>> LOCALE=$LOCALE"
echo ">>> KEYMAP=$KEYMAP"
echo ">>> SWAPSIZE=$SWAPSIZE"
echo ">>> ROOTPASSNEW=$ROOTPASSNEW"
echo ">>> MIRRORS_COUNTRY=$MIRRORS_COUNTRY"

# System config (timezone, locale, vconsole)
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
locale-gen
echo ">>> Done -- Inside arch-chroot - hwclock, locale-gen...."

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

## Disable below section when Cloud-init starts working ok.
# # Super-User
# useradd -m -G wheel -s /bin/bash $SUPERUSER
# echo "$SUPERUSER:$SUPERPASS" | chpasswd
# echo ">>> Done -- Inside arch-chroot - User creation...."
# # Super-User  - Prevent superuser password expiration
# chage -m 0 -M -1 -E -1 $SUPERUSER
# echo ">>> Done -- Inside arch-chroot - Prevent superuser password expiration...."
# # Super-User - Set up SSH key
# mkdir -p /home/$SUPERUSER/.ssh
# chmod 700 /home/$SUPERUSER/.ssh
# echo "$SSH_PUBKEY" > /home/$SUPERUSER/.ssh/authorized_keys
# chmod 600 /home/$SUPERUSER/.ssh/authorized_keys
# chown -R $SUPERUSER:$SUPERUSER /home/$SUPERUSER/.ssh
# echo ">>> Done -- Inside arch-chroot - SSH key...."

# Set root password and prevent expiration
echo "root:$ROOTPASSNEW" | chpasswd
chage -m 0 -M -1 -E -1 root
echo ">>> Done -- Inside arch-chroot - Root password setup...."
# passwd -d root
# echo ">>> Done -- Inside arch-chroot - Root password deleted...."

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

## Disable below section when Cloud-init starts working ok.
# # Sudo rules Super User
# printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$SUPERUSER" > /etc/sudoers.d/11-superuser
# chmod 440 /etc/sudoers.d/11-superuser
# echo ">>> Done -- Inside arch-chroot - Super-User SUDO rules...."

systemctl enable NetworkManager
systemctl enable sshd
CHROOTEOF
# swapoff /dev/$VGNAME/$LVSWAP
# umount -R /mnt
echo ">>> Done -- chroot - Outside chroot now..."
sleep 8

# prepare the container for systemd-nspawn
echo ">>> Preparing for 'systemd-nspawn', (advanced chroot) for installing/configuring qemu-guest-agent, cloud-init, dependencies on NetworkManager & systemd."
# # Mounting
# mount /dev/$VGNAME/$LVROOT /mnt
# mount "$DISK"1 /mnt/boot
# swapon /dev/$VGNAME/$LVSWAP
cp /etc/resolv.conf /mnt/etc/resolv.conf
## systemd-nspawn --- start
## For testing use following use: ## systemd-nspawn --console=pipe -D /mnt <<"NSPAWN" 2>&1 | tee /tmp/nspawn.log
##
##
##
cat > /mnt/root/script_nspawn.sh <<"NSPAWN"
#!/bin/bash
echo ">>> Inside systemd‑nspawn…"
set -eu
echo ">>> Done -- Inside systemd-nspawn - -eu...."

# Retrive environment variables from the file created before chroot
source /root/envvars.sh
echo ">>> Done -- Inside systemd-nspawn - sourced envvars.sh...."
echo ">>> EnvVars are:"
echo ">>> VGNAME=$VGNAME"
echo ">>> LVROOT=$LVROOT"
echo ">>> LVSWAP=$LVSWAP"
echo ">>> SUPERUSER=$SUPERUSER"
echo ">>> SUPERPASS=$SUPERPASS"
echo ">>> SUPERUSER_GECOS=$SUPERUSER_GECOS"
echo ">>> SSH_PUBKEY=$SSH_PUBKEY"
echo ">>> HOSTNAME=$HOSTNAME"
echo ">>> TIMEZONE=$TIMEZONE"
echo ">>> LOCALE=$LOCALE"
echo ">>> KEYMAP=$KEYMAP"
echo ">>> SWAPSIZE=$SWAPSIZE"
echo ">>> ROOTPASSNEW=$ROOTPASSNEW"
echo ">>> MIRRORS_COUNTRY=$MIRRORS_COUNTRY"

#-------------------------- Install cloud-init and configure for NoCloud datasource --------------------------
# Enable services
# # systemctl enable shd
# # systemctl enable NetworkManager
# systemctl enable alsa-restore
# systemctl enable alsa-state
# echo ">>> Done - Inside systemd‑nspawn… - Enable services...."

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
  echo ">>> Done - Inside systemd‑nspawn… - Enable qemu-guest-agent (if installed)...."
else
  echo ">>> WARNING: qemu-guest-agent is not installed; skipping enable"
fi

# Install cloud-init
systemd-machine-id-setup
mkdir -p /etc/cloud
touch /etc/cloud/cloud.cfg
systemctl daemon-reload
pacman --noconfirm -S cloud-init cloud-guest-utils
systemctl daemon-reload
echo ">>> Done - Installed cloud-init..."
# Setup a basic cloud-init.conf
echo "datasource_list: [ NoCloud, ConfigDrive ]" > /etc/cloud/cloud.cfg.d/90_dpkg.cfg
cat > /etc/cloud/cloud.cfg <<EOF_CLOUD
#cloud-config
users:
  - default
cloud_init_modules:
  - seed_random
  - bootcmd
  - write_files
  - growpart
  - resizefs
  - disk_setup
  - mounts
  - set_hostname
  - update_hostname
  - update_etc_hosts
  - ca_certs
  - rsyslog
  - users_groups
  - ssh
  - set_passwords
cloud_config_modules:
  - ssh_import_id
  - keyboard
  - ntp
  - timezone
  - disable_ec2_metadata
  - runcmd
cloud_final_modules:
  - package_update_upgrade_install
  - write_files_deferred
  - puppet
  - chef
  - mcollective
  - salt_minion
  - reset_rmc
  - scripts_vendor
  - scripts_per_once
  - scripts_per_boot
  - scripts_per_instance
  - scripts_user
  - ssh_authkey_fingerprints
  - keys_to_console
  - install_hotplug
  - phone_home
  - final_message
  - power_state_change
system_info:
  distro: arch
  default_user:
    name: $SUPERUSER
    password: $SUPERPASS
    lock_passwd: True
    gecos: $SUPERUSER_GECOS
    groups: [users, wheel, adm]
    sudo: ["ALL=(ALL) NOPASSWD: ALL"]
    shell: /bin/bash
    authorized_keys:
      - $SSH_PUBKEY
  paths:
    cloud_dir: /var/lib/cloud/
    templates_dir: /etc/cloud/templates/
  ssh_svcname: sshd
network_data:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      optional: true
EOF_CLOUD
#
if [ -f /etc/cloud/cloud.cfg ]; then
  echo ">>> Cloud.cfg exists, showing content:"
  cat /etc/cloud/cloud.cfg
  echo ">>> Done - Inside systemd‑nspawn… - cloud.cfg content ..."
else
  echo ">>> Cloud.cfg does not exist ..."
fi
#
echo ">>> Done - Inside systemd‑nspawn… - End of Cloud.cfg setup...."

# Prepare NoCloud datasource directory for Proxmox
mkdir -p /var/lib/cloud/seed/nocloud-net
chmod 755 /var/lib/cloud/seed
chmod 755 /var/lib/cloud/seed/nocloud-net
echo ">>> Done - Inside systemd‑nspawn… - Prepare NoCloud datasource directory for Proxmox...."

# Add NetworkManager dependencies to cloud-init services to ensure NM is running
if pacman -Q cloud-init >/dev/null 2>&1; then
    #for service in cloud-init-local.service cloud-init-main.service cloud-config.service cloud-final.service; do
    for service in cloud-init-main.service cloud-config.service cloud-final.service; do
        mkdir -p /etc/systemd/system/$service.d
        cat > /etc/systemd/system/$service.d/10-networkmanager.conf <<"NETMANNOFF"
[Unit]
After=NetworkManager.service
Wants=NetworkManager.service
NETMANNOFF
    done
    systemctl daemon-reload
    echo ">>> Done - Inside systemd‑nspawn… - Added NetworkManager dependencies to cloud-init services"
fi

# Enable cloud-init services only if installed
if pacman -Q cloud-init >/dev/null 2>&1; then
    #systemctl enable cloud-init-generator || true
    systemctl enable cloud-init-local.service || true
    systemctl enable cloud-init-main.service || true
    systemctl enable cloud-config.target || true
    systemctl enable cloud-config.service || true
    systemctl enable cloud-final.service || true
    systemctl enable cloud-init.target || true
    systemctl enable cloud-init.service || true
else
    echo ">>> WARNING: cloud-init is not installed; skipping enable"
fi

# Ensure DHCP is default for all interfaces
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/10-dhcp-default.conf <<EOF_NM
[main]
plugins=keyfile

[connection]
ipv4.method=auto
ipv6.method=auto
EOF_NM
echo ">>> Done - Inside systemd‑nspawn… - NetworkManager changes...."

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
echo ">>> Done - Inside systemd‑nspawn… - Automatic updates...."

# Cleanup
rm -rf /var/cache/pacman/pkg/* /root/envvars.sh
echo ">>> exiting Nswap container and poweroff inside it..."
poweroff && exit 0
NSPAWN
chmod +x /mnt/root/script_nspawn.sh
cp /mnt/root/script_nspawn.sh /root/script_nspawn.sh
systemd-nspawn -bD /mnt 2> /tmp/nspawn_container.log &
sleep 12
#pacman -S --noconfirm systemd
systemd-run -P --machine=mnt /root/script_nspawn.sh 1>&2 | tee /tmp/nspawn.log
echo ">>> script_nspawn.sh launched, sleeping 20 seconds"
sleep 20
echo ">>> Going to turn off swap and unmount filesystems after nspawn...."
swapoff /dev/$VGNAME/$LVSWAP
umount -R /mnt
echo ">>> Done -- systemd-nspawn - Cleanly Outside NSPAWN now... File systems unmounted, swapoff done...."
sleep 4

