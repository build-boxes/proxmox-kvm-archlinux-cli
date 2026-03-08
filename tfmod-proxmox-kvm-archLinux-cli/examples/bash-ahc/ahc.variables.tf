# Variables used by the docker-dockhand example

variable "PROXMOX_VE_ENDPOINT" {
  type = string
}

variable "PROXMOX_VE_USERNAME" {
  type = string
  #sensitive = true
}

variable "PROXMOX_VE_PASSWORD" {
  type = string
  #sensitive = true
}

variable "PROXMOX_VE_INSECURE" {
  type = bool
}

variable "proxmox_node_name" {
  type = string
}

variable "proxmox_node_address" {
  type = string
}

variable "pub_key_file" {
  type = string
}

variable "pvt_key_file" {
  type = string
  #sensitive = true
}

variable "superuser_username" {
  type = string
}

variable "superuser_password" {
  type = string
  #sensitive = true
}

# variable "superuser_new_password" {
#   type = string
#   sensitive = true
# }

variable "root_new_password" {
  type = string
  #sensitive = true
}

variable "prefix" {
  type = string
}

variable "proxmox_datastore_id" {
  type = string
}

variable "proxmox_vm_template_tags" {
  type = list(string)
}

variable "proxmox_vm_tags" {
  type = list(string)
}

variable "vm_fixed_ip" {
  type = string
  default = ""
}

variable "vm_fixed_gateway" {
  type = string
  default = ""
}

variable "vm_fixed_dns" {
  type = list(string)
  default = []
}

variable "cpu_core_count" {
  type = number
}

variable "memory_size" {
  type = string
}

variable "disk_size_boot" {
  type = string
}

variable "disk_boot_ssd_enabled" {
  type = bool
}

variable "docker_installed" {
  type = bool
}

variable "rsyslog_yay_aur_installed" {
  type = bool
}
