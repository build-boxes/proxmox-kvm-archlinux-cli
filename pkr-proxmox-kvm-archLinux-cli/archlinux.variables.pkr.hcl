variable "vm_name" {
  type = string
  default = "pckr-tmpl-archlinux"
}

variable "vmid" {
  type = string
  description = "Proxmox Template ID"
  default = "9300"
}

variable "cpu_type" {
  type    = string
  default = "x86-64-v2-AES"
}

variable "cores" {
  type    = string
  default = "1"
}

variable "disk_format" {
  type    = string
  default = "raw"
}

variable "disk_size" {
  type    = string
  default = "8G"
}

variable "disk_ssd_enabled" {
  type        = bool
  description = "Enable SSD flag for the disk"
  default     = true
  validation {
    condition     = var.disk_ssd_enabled == true || var.disk_ssd_enabled == false
    error_message = "Disk_ssd_enabled must be a boolean value (true or false)."
  }
}

variable "storage_pool" {
  type    = string
  default = ""
}

variable "memory" {
  type    = string
  default = "1024M"
}

variable "network_vlan" {
  type    = string
  default = ""
}

variable "proxmox_api_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "proxmox_api_user" {
  type    = string
  default = "root@pam"
}

variable "proxmox_host" {
  type    = string
  default = ""
}

variable "proxmox_node" {
  type    = string
  default = ""
}

variable "archlinux_root_password" {
  type      = string
  #sensitive = true
  default   = "packer"
}

variable "iso_file" {
  type    = string
  description = "ISO file path in Proxmox storage"
}

variable "dynamic_iso_url" {
  type    = string
  description = "Dynamically fetched ISO URL for ArchLinux"
}

variable "iso_storage_pool" {
  type    = string
  default = ""
}

variable "dynamic_iso_checksum" {
  type    = string
  description = "Dynamically fetched ISO checksum"
}

variable "iso_storage" {
  type    = string
  default = "local"
}

variable "ssh_pubkey" {
  type    = string
  default = "YOUR_SSH_PUBLIC_KEY_HERE"
}

variable "swap_size" {
  type    = string
  default = "1G"
}

variable "vgname" {
  type    = string
  default = "vg0"
}

variable "disk" {
  type    = string
  default = "/dev/sda"
}

variable "hostname" {
  type    = string
  default = "archlvm"
}

variable "timezone" {
  type    = string
  default = "Canada/Eastern"
}

variable "locale" {
  type    = string
  default = "en_CA.UTF-8"
}

variable "keymap" {
  type    = string
  default = "us"
}

variable "vm_image_tags" {
  type        = list(string)
  description = "Tags for the Packer template"
  default     = ["template", "archlinux", "minimal", "cli"]
}

variable "superuser_name" {
  type        = string
  description = "Superuser name for cloud-init configuration"
  default     = ""
}

variable "superuser_gecos" {
  type        = string
  description = "Superuser GECOS/full name for cloud-init configuration"
  default     = ""
}

variable "superuser_password" {
  type        = string
  description = "Superuser password hash for cloud-init configuration"
  #sensitive   = true
  default     = ""
}

variable "superuser_ssh_pub_key" {
  type        = string
  description = "Superuser SSH public key for cloud-init configuration"
  default     = ""
}