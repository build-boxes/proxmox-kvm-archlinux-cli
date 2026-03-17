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
    disk_size_extra=var.disk_size_extra
    disk_extra_ssd_enabled=var.disk_extra_ssd_enabled
    docker_installed=var.docker_installed
    rsyslog_yay_aur_installed=var.rsyslog_yay_aur_installed
}

locals{
  host_ip = module.archlinux-cli.ip
  host_ip_fixed = module.archlinux-cli.ip_fixed

  install_hyperland_script = templatefile("${path.cwd}/scripts/install_hyprland.actual.sh.tpl", {
    USER        = var.superuser_username
    PASSWORD    = var.superuser_password
  })

  hyperland_config_file = templatefile("${path.cwd}/scripts/hyprland.conf.tpl", {
  })
}

resource "null_resource" "copy_and_execute_custom_template_script" {
  depends_on = [module.archlinux-cli]
  triggers = {
      USER        = var.superuser_username
      PASSWORD    = var.superuser_password
    }

  provisioner "file" {
    content     = local.install_hyperland_script
    destination = "/tmp/install_hyprland.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_hyprland.sh",
      "/tmp/install_hyprland.sh"
    ]
  }

  connection {
    type     = "ssh"
    host     = local.host_ip_fixed
    user     = var.superuser_username
    password = var.superuser_password
    private_key = file("${var.pvt_key_file}")
  }  
}

resource "null_resource" "copy_hyprland_config" {
  depends_on = [null_resource.copy_and_execute_custom_template_script]
  triggers = {
      always_run = timestamp()
    }

  provisioner "file" {
    content     = local.hyperland_config_file
    destination = "/home/${var.superuser_username}/.config/hypr/hyprland.conf"
  }

  connection {
    type     = "ssh"
    host     = local.host_ip_fixed
    user     = var.superuser_username
    password = var.superuser_password
    private_key = file("${var.pvt_key_file}")
  }  
}

resource "null_resource" "copy_waybar_folder" {
  depends_on = [null_resource.copy_hyprland_config]
  # Trigger re-run if folder contents change
  triggers = {
    always_run = timestamp()
  }

  provisioner "file" {
    source      = "${path.cwd}/scripts/waybar_resources/"   
    destination = "/home/${var.superuser_username}/.config/waybar/"

    connection {
      type        = "ssh"
      host        = local.host_ip_fixed  
      user        = var.superuser_username
      password    = var.superuser_password
      private_key = file(var.pvt_key_file)
    }
  }
}


resource "null_resource" "restart_vm_after_script" {
  depends_on = [null_resource.copy_waybar_folder]
  provisioner "remote-exec" {
    connection {
      target_platform = "unix"
      type            = "ssh"
      host            = local.host_ip_fixed
      user            = var.superuser_username
      password        = var.superuser_password
      private_key = file("${var.pvt_key_file}")
      agent = false
      timeout = "4m"
    }
    inline = [
      <<-EOF
      sudo reboot
      EOF
    ]
  }
}

output "vm1_fixed_ip_address" {
  value = module.archlinux-cli.ip_fixed
}

output "vm1_ip_address" {
  value = module.archlinux-cli.ip
}

output "script_output" {
    value = null_resource.copy_hyprland_config.*.triggers
}