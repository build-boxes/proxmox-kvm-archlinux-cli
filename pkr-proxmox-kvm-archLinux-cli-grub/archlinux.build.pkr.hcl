locals {
  dynamic_vars_file = "${path.root}/vars/generated-archlinux-vars.pkrvars.hcl"
}

build {
  name    = "arch-proxmox-lvm-template"
  sources = ["source.proxmox-iso.archlinux"]
  
  provisioner "shell" {
    script = "${path.root}/scripts/build_archlinux_bootstrap.sh"
    env = {
      DISK = var.disk
      VGNAME = var.vgname
      LVROOT = var.lvm_root
      LVSWAP = var.lvm_swap
      SUPERUSER = var.superuser_name
      SUPERPASS = var.superuser_password_plain
      SSH_PUBKEY_TEMP = var.superuser_ssh_pub_key
      SUPERUSER_GECOS = var.superuser_gecos
      ROOTPASSOLD = var.archlinux_root_password
      HOSTNAME = var.hostname
      TIMEZONE = var.timezone
      LOCALE = var.locale
      KEYMAP = var.keymap
      SWAPSIZE = var.swap_size
      ROOTPASSNEW = var.archlinux_root_new_password_plain
      MIRRORS_COUNTRY = var.mirrors_country
      SEED_URL = var.seed_url
    }
  }

  # # Copy default cloud-init config
  # provisioner "file" {
  #   destination = "/etc/cloud/cloud.cfg"
  #   source      = "http/cloud.cfg"
  # }

  # # Replace superuser_name placeholder in cloud.cfg
  # provisioner "shell" {
  #   inline = ["awk -v old='<<superuser_name>>' -v new='${var.superuser_name}' '{gsub(old, new); print}' /etc/cloud/cloud.cfg > /tmp/cloud.cfg && mv /tmp/cloud.cfg /etc/cloud/cloud.cfg"]
  # }

  # # Replace superuser_gecos placeholder in cloud.cfg
  # provisioner "shell" {
  #   inline = ["awk -v old='<<superuser_gecos>>' -v new='${var.superuser_gecos}' '{gsub(old, new); print}' /etc/cloud/cloud.cfg > /tmp/cloud.cfg && mv /tmp/cloud.cfg /etc/cloud/cloud.cfg"]
  # }

  # # Replace superuser_password placeholder in cloud.cfg
  # provisioner "shell" {
  #   inline = ["awk -v old='<<superuser_password>>' -v new='${var.superuser_password}' '{gsub(old, new); print}' /etc/cloud/cloud.cfg > /tmp/cloud.cfg && mv /tmp/cloud.cfg /etc/cloud/cloud.cfg"]
  # }

  # # Replace superuser_ssh_pub_key placeholder in cloud.cfg
  # provisioner "shell" {
  #   inline = ["awk -v old='<<superuser_ssh_pub_key>>' -v new='${var.superuser_ssh_pub_key}' '{gsub(old, new); print}' /etc/cloud/cloud.cfg > /tmp/cloud.cfg && mv /tmp/cloud.cfg /etc/cloud/cloud.cfg"]
  # }

  # # Copy Proxmox cloud-init config
  # provisioner "file" {
  #   destination = "/etc/cloud/cloud.cfg.d/99-pve.cfg"
  #   source      = "http/99-pve.cfg"
  # }

}