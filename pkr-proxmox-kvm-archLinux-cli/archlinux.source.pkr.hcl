
source "proxmox-iso" "archlinux" {
  proxmox_url              = "https://${var.proxmox_host}/api2/json"
  username                 = var.proxmox_api_user
  password                 = var.proxmox_api_password
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  vm_name                 = var.vm_name
  template_description    = "Archlinux CLi Packer, minimal  -- Created: ${formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())}"
  tags                    = join(";", var.vm_image_tags)
  vm_id                   = var.vmid
  os                      = "l26"
  cpu_type                = var.cpu_type
  sockets                 = "1"
  cores                   = var.cores
  memory                  = endswith(var.memory, "G") ? convert(1024*parseint(replace(var.memory, "G", ""),10),string) : ( endswith(var.memory, "M") ? replace(var.memory, "M", "") : var.memory )
  #machine                 = "i440fx"
  machine                 = "pc-i440fx-7.1"
  bios                    = "ovmf"
  efi_config {
      efi_storage_pool  = var.storage_pool
      pre_enrolled_keys = false
      efi_format        = "raw"
      efi_type          = "4m"
  }
  scsi_controller         = "virtio-scsi-single"
  qemu_agent              = true
  cloud_init              = true
  cloud_init_storage_pool = var.storage_pool

  network_adapters {
    bridge   = "vmbr0"
    firewall = true
    model    = "virtio"
    vlan_tag = var.network_vlan
  }

  disks {
    disk_size         = var.disk_size
    format            = var.disk_format
    storage_pool      = var.storage_pool
    ssd               = var.disk_ssd_enabled
    type              = "scsi"
  }

  boot_iso {
    type              = "sata"
    #iso_file          = var.iso_file
    iso_url           = var.dynamic_iso_url
    iso_storage_pool  = var.iso_storage_pool
    #iso_checksum      = var.iso_checksum
    iso_checksum      = var.dynamic_iso_checksum
    unmount           = true
  }

  http_directory = "http"
  http_port_min  = 8100
  http_port_max  = 8100

  boot_wait = "5s"
  # boot_command = [
  #   "<enter><wait>"
  # ]
  boot_command = [
    "<enter><wait20>",
    "/usr/bin/bash<enter><wait5>",
    "echo 'root:${var.archlinux_root_password}' | chpasswd<enter><wait5>",
    "exit<enter><wait5>",
    "exit<enter>"
  ]
  # boot_command = [
  #   "<enter><wait>",
  #   "/usr/bin/bash<enter>",
  #   "linux /arch/boot/x86_64/vmlinuz archisobasedir=arch archisolabel=ARCH_2023 console=ttyS0,115200n8 ip=dhcp ",
  #   "initrd=/arch/boot/x86_64/archiso.img ",
  #   "quiet<enter><wait10>",
  #   # after kernel boots to live environment, fetch and run installer
  #   "curl -sS https://hexword.ca/packer-preseed-dir/install.sh -o /tmp/install.sh && chmod +x /tmp/install.sh && /tmp/install.sh<enter>"
  # ]


  # ssh_username     = var.superuser_name
  # ssh_password     = var.superuser_password
  # ssh_timeout      = "30m"

  ssh_username = "root"
  ssh_password = var.archlinux_root_password
  #ssh_timeout  = "60m"

}