variable "proxmox_node_name" {
  type    = string
  default = "pve"
}

variable "proxmox_node_address" {
  type = string
}

variable "PROXMOX_VE_ENDPOINT" {
    type = string
    default = "https://192.168.4.20:8006/api2/json"
}

variable "PROXMOX_VE_USERNAME" {
    type = string
    #sensitive = true
    default = "admin@pve"
}

variable "PROXMOX_VE_PASSWORD" {
    type = string
    #sensitive = true
    default = "PassW0rd123!!"
}

variable "PROXMOX_VE_INSECURE" {
    type = bool
    default = false
}

variable "prefix" {
  # This is used to rename the host to this name.description
  # also used as a prefix for text and log files names.
  type    = string
  default = "Archie01"
}

variable "pub_key_file" {
  type = string
  #default = "~/.ssh/id_rsa.pub"
}

variable "pvt_key_file" {
  type = string
  #default = "~/.ssh/id_rsa"
  #sensitive = true
}

variable "superuser_username" {
  type    = string
  default = "terraform"
}

variable "superuser_password" {
  type      = string
  #sensitive = true
  # NB the password will be reset by the cloudbase-init SetUserPasswordPlugin plugin.
  # NB this value must meet the Windows password policy requirements.
  #    see https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements
  # Password with @ symbol has issues in cloudbase-init scripts escape-sequencing in terraform ".tf" files
  default = "HeyH0Password"
}


# variable "superuser_new_password" {
#   type      = string
#   sensitive = true
#   # NB the password will be reset by the cloudbase-init SetUserPasswordPlugin plugin.
#   # NB this value must meet the Windows password policy requirements.
#   #    see https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements
#   # Password with @ symbol has issues in cloudbase-init scripts escape-sequencing in terraform ".tf" files
#   default = "HeyH0Password"
# }

variable "root_new_password" {
  type      = string
  #sensitive = true
  default = "HeyH0Password"
}

variable "proxmox_vm_template_tags" {
  type        = list(string)
  description = "Tags to filter Proxmox VM templates"
  default     = ["archlinux", "cli", "minimal", "template"]
}

variable "proxmox_vm_tags" {
  type        = list(string)
  description = "Tags to assign to created Proxmox VMs"
  default     = ["archlinux", "cli", "minimal", "terraform"]
}

variable "proxmox_datastore_id" {
  type        = string
  description = "Proxmox Datastore ID where VM disks are stored"
  default     = "local-lvm"
}

variable "vm_mac_address" {
  type        = string
  description = "Optional custom MAC address for the created VM"
  default     = null
}

variable "vm_fixed_ip" {
  type        = string
  description = "Fixed IP address with CIDR notation for the created VM"
  default     = ""
}

variable "vm_fixed_gateway" {
  type        = string
  description = "Fixed Gateway IP address for the created VM"
  default     = ""
}

variable "vm_fixed_dns" {
  type        = list(string)
  description = "Fixed DNS server IP addresses for the created VM"
  #default     = ["192.168.0.1"]
  default     = []
}

variable "cpu_core_count" {
  type        = number
  description = "Number of CPU cores for the created VM"
  default     = 1
  validation {
    condition     = var.cpu_core_count >= 1 && var.cpu_core_count <= 8
    error_message = "CPU core count must be at least 1, and at most 8."
  }
}

variable "memory_size" {
  type        = string
  description = "Memory size in GB/MB for the cloned/created VM"
  default     = "512M"
  validation {
    condition     = (tonumber(replace(var.memory_size, "M", "")) >= 512 && tonumber(replace(var.memory_size, "M", "")) <= 15360) || (tonumber(replace(var.memory_size, "G", "")) >= 1 && tonumber(replace(var.memory_size, "G", "")) <= 15 )
    error_message = "Memory size must be at least 0.5G (512M), and at most 15G (15360M). Also note that is a String value inside Double-Quotes with 'G' or 'M' at its end."
  }
}

variable "disk_size_boot" {
  type        = string
  description = "Boot disk size in GB for the created VM. Default is '8G'."
  default     = "8G"
  validation {
    condition     = (tonumber(replace(var.disk_size_boot, "G", "")) >= 4 && tonumber(replace(var.disk_size_boot, "G", "")) <= 200 ) || (tonumber(replace(var.disk_size_boot, "M", "")) >= 4096 && tonumber(replace(var.disk_size_boot, "M", "")) <= 204800)
    error_message = "Boot disk size must be at least '4G'/ '4096M' , and at most '200G' / '204800M'. Also note that is a String value inside Double-Quotes with 'G' or 'M' at its end."
  }
}

variable "disk_boot_ssd_enabled" {
  type        = bool
  description = "Enable SSD flag for the boot disk of the created VM"
  default     = true
  validation {
    condition     = var.disk_boot_ssd_enabled == true || var.disk_boot_ssd_enabled == false
    error_message = "Disk_boot_ssd_enabled must be a boolean value (true or false)."
  }
}

variable "docker_installed" {
  type        = bool
  description = "Install Docker on the created VM"
  default     = false
  validation {
    condition     = var.docker_installed == true || var.docker_installed == false
    error_message = "docker_installed must be a boolean value (true or false)."
  }
} 

variable "rsyslog_yay_aur_installed" {
  type    = bool
  description = "Whether to install 'yay' AUR helper and 'rsyslog' during the build process"
  default = false
  validation {
    condition     = var.rsyslog_yay_aur_installed == true || var.rsyslog_yay_aur_installed == false
    error_message = "rsyslog_yay_aur_installed must be a boolean value (true or false)."
  }

}