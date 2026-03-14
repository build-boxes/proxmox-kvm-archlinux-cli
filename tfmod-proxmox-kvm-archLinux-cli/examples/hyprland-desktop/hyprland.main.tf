terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.98.0"
    }
  }
}

provider "proxmox" {
    endpoint = var.PROXMOX_VE_ENDPOINT
    username = var.PROXMOX_VE_USERNAME
    password = var.PROXMOX_VE_PASSWORD
    insecure = var.PROXMOX_VE_INSECURE
  ssh {
    agent = true
    node {  
      name    = var.proxmox_node_name
      address = var.proxmox_node_address
    }
  }
} 

module "archlinux-cli" {
    source = "git::https://github.com/build-boxes/proxmox-kvm-archlinux-cli.git//tfmod-proxmox-kvm-archLinux-cli?ref=develop"
    #source = "../.."

    pub_key_file=var.pub_key_file
    pvt_key_file=var.pvt_key_file
    superuser_username=var.superuser_username
    superuser_password=var.superuser_password
    #superuser_new_password=var.superuser_new_password
    root_new_password=var.root_new_password
    prefix=var.prefix

    proxmox_node_address=var.proxmox_node_address
    proxmox_node_name=var.proxmox_node_name
    proxmox_datastore_id=var.proxmox_datastore_id

    proxmox_vm_template_tags=var.proxmox_vm_template_tags
    proxmox_vm_tags=var.proxmox_vm_tags

    vm_fixed_ip=var.vm_fixed_ip
    vm_fixed_gateway=var.vm_fixed_gateway
    vm_fixed_dns=var.vm_fixed_dns
    cpu_core_count=var.cpu_core_count
    memory_size=var.memory_size
    disk_size_boot=var.disk_size_boot
    disk_boot_ssd_enabled=var.disk_boot_ssd_enabled
    docker_installed=var.docker_installed
    rsyslog_yay_aur_installed=var.rsyslog_yay_aur_installed
}

locals{
  host_ip = module.archlinux-cli.ip
}

## Example of copying and running a custom script on the created VM.
## Assumes the custom script is located in ../scripts/install_ahc.sh
##
resource "null_resource" "call_custom_script" {
  depends_on = [module.archlinux-cli]  
  provisioner "local-exec" {
    command = <<EOT
      scp -o StrictHostKeyChecking=no -i ${var.pvt_key_file} ./scripts/install_hyprland.actual.sh ${var.superuser_username}@${local.host_ip}:/home/${var.superuser_username}/install_hyprland.sh
      ssh -o StrictHostKeyChecking=no -i ${var.pvt_key_file} ${var.superuser_username}@${local.host_ip} "chmod +x /home/${var.superuser_username}/install_hyprland.sh && /home/${var.superuser_username}/install_hyprland.sh"
    EOT
  }
}

output "vm1_ip_address" {
  value = module.archlinux-cli.ip
}

output "script_output" {
    value = null_resource.call_custom_script.*.triggers
}