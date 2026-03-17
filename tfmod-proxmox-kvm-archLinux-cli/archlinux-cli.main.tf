
# see https://registry.terraform.io/providers/bpg/proxmox/0.98.0/docs/data-sources/virtual_environment_vms
data "proxmox_virtual_environment_vms" "archlinux_cli_templates" {
  tags = var.proxmox_vm_template_tags
  node_name = var.proxmox_node_name
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.98.0/docs/data-sources/virtual_environment_vm
data "proxmox_virtual_environment_vm" "archlinux_cli_template" {
  node_name = local.template_vm.node_name
  vm_id     = local.template_vm.vm_id
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.98.0/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "clone_edited_template" {
  name      = var.prefix
  node_name = var.proxmox_node_name
  tags      = var.proxmox_vm_tags

  clone {
    vm_id = data.proxmox_virtual_environment_vm.archlinux_cli_template.vm_id
    full  = true
  }
  cpu {
    #type  = "host"
    type  = "x86-64-v2-AES"
    cores = var.cpu_core_count
  }
  memory {
    dedicated = endswith(var.memory_size, "G") ? 1024 * tonumber(replace(var.memory_size, "G", "")) : ( endswith(var.memory_size, "M") ? tonumber(replace(var.memory_size, "M", "")) : tonumber(var.memory_size) )
  }
  network_device {
    bridge = "vmbr0"
    mac_address = var.vm_mac_address
  }

  lifecycle {
    ignore_changes = [
      ipv4_addresses,
      initialization[0].ip_config,
    ]
  }

  disk {      # Boot Disk, Size can be increased here. Then manually Increase Volume size inside Windows-2025.
    datastore_id = var.proxmox_datastore_id
    interface   = "scsi0"
    file_format = "raw"
    iothread    = true
    ssd         = var.disk_boot_ssd_enabled
    discard     = "on"
    size        = endswith(var.disk_size_boot, "G") ? tonumber(replace(var.disk_size_boot, "G", "")) : ( endswith(var.disk_size_boot, "M") ? tonumber(replace(var.disk_size_boot, "M", "")) / 1024 : tonumber(var.disk_size_boot) / 1024 )
  }
  ## Add additional Disks here, if required.
  ##
  ##
  dynamic "disk" {
    for_each = (var.disk_size_extra != "" && var.disk_size_extra != "0M" && var.disk_size_extra != "0G") ? [1] : []
    content {
      datastore_id = var.proxmox_datastore_id
      interface   = "scsi1"
      file_format = "raw"
      iothread    = true
      ssd         = var.disk_extra_ssd_enabled
      discard     = "on"
      size        = endswith(var.disk_size_extra, "G") ? tonumber(replace(var.disk_size_extra, "G", "")) : ( endswith(var.disk_size_extra, "M") ? tonumber(replace(var.disk_size_extra, "M", "")) / 1024 : tonumber(var.disk_size_extra) / 1024 )
    }
  }
  
  agent {
    enabled = true
    #trim    = true
  }

  initialization {
    user_account {
      #keys     = [trimspace(file("${var.pvt_key_file}"))]
      keys     = [trimspace(file("${var.pub_key_file}"))]
      password = var.superuser_password
      username = var.superuser_username
    }    
    datastore_id = var.proxmox_datastore_id    
  }
}

resource "time_sleep" "wait_1_minutes_1" {
  depends_on = [proxmox_virtual_environment_vm.clone_edited_template]
  # 12 minutes sleep. I have a slow Proxmox Host :(
  create_duration = "1m"
}

resource "null_resource" "ssh_into_vm" {
  depends_on = [time_sleep.wait_1_minutes_1]
  provisioner "remote-exec" {
    connection {
      target_platform = "unix"
      type            = "ssh"
      host            = local.host_ip
      user            = var.superuser_username
      password        = var.superuser_password
      private_key = file("${var.pvt_key_file}")
      agent = false
      timeout = "2m"
    }
    # NB this is executed as a batch script by cmd.exe.
    inline = [
      <<-EOF
      echo "Sucessfully logged in as user: '$(whoami)'";
      # Set Hostname to prefix
      echo "Setting hostname to ${var.prefix}"
      sudo hostnamectl set-hostname ${var.prefix}
      sudo sed -i 's/127.0.1.1\s\+archlvm/127.0.1.1\t${var.prefix}/' /etc/hosts
      ##
      ## Extend Root filesystem to fill boot disk
      ##
      echo "Extending root filesystem to fill boot disk..."
      sudo growpart /dev/sda 2
      sudo pvresize /dev/sda2
      sudo lvextend -l +100%FREE /dev/vg0/lvmroot
      sudo resize2fs /dev/vg0/lvmroot
      echo "Extended root filesystem to fill boot disk."
      ## End Extend Root filesystem to fill boot disk
      #
      EOF
    ]
  }
}

resource "time_sleep" "wait_2_minutes_2" {
  depends_on = [null_resource.ssh_into_vm]
  create_duration = "2m"
}

resource "null_resource" "initialize_disks" {
  depends_on = [time_sleep.wait_2_minutes_2]
  triggers = {
    root_pw   = var.root_new_password
    superuser = var.superuser_username
    yay_flag  = var.rsyslog_yay_aur_installed
  }

  provisioner "file" {
    content = local.initialize_disks
    destination = "/tmp/initialize-disks.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/initialize-disks.sh",
      "/tmp/initialize-disks.sh"
    ]
  }

  connection {
    type     = "ssh"
    host     = local.host_ip
    user     = var.superuser_username
    password = var.superuser_password
    private_key = file("${var.pvt_key_file}")
  }
}

resource "time_sleep" "wait_2_minutes_3" {
  depends_on = [null_resource.initialize_disks]
  # 12 minutes sleep. I have a slow Proxmox Host :(
  create_duration = "2m"
}


resource "null_resource" "configure_network" {
  depends_on = [time_sleep.wait_2_minutes_3]
  triggers = {
    ipv4_address = var.vm_fixed_ip
    ipv4_gateway = var.vm_fixed_gateway
    ipv4_dns     = join(",", var.vm_fixed_dns)
  }

  provisioner "file" {
    content     = local.nm_static_ip
    destination = "/tmp/nm-static-ip.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/nm-static-ip.sh",
      "sudo /tmp/nm-static-ip.sh"
    ]
  }

  connection {
    type     = "ssh"
    host     = local.host_ip
    user     = var.superuser_username
    password = var.superuser_password
    private_key = file("${var.pvt_key_file}")
  }  
}

resource "null_resource" "restart_vm1" {
  depends_on = [null_resource.configure_network]
  provisioner "remote-exec" {
    connection {
      target_platform = "unix"
      type            = "ssh"
      host            = local.host_ip
      user            = var.superuser_username
      password        = var.superuser_password
      private_key = file("${var.pvt_key_file}")
      agent = false
      timeout = "4m"
    }
    # NB this is executed as a batch script by cmd.exe.
    inline = [
      <<-EOF
      sudo reboot
      EOF
    ]
  }
}

resource "time_sleep" "wait_60_seconds_4" {
  depends_on = [null_resource.restart_vm1]
  create_duration = "60s"
}

## Run Ansible Playbook to install and configure docker (if mandated by var.docker_installed).
## Assumes Ansible is installed on the local machine running Terraform.
## Also assumes the Ansible playbook is located in ./ansible-playbooks/ansible_main.yml
##
resource "null_resource" "run_ansible_playbook" {
  depends_on = [time_sleep.wait_60_seconds_4]
    provisioner "local-exec" {
    #interpreter = ["/bin/bash"]
    # Use the module path so the playbooks are found whether the module is local or fetched into .terraform/modules
    working_dir = "${path.module}/ansible-playbooks"
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u '${var.superuser_username}' -i '${local.host_ip_fixed},' --private-key ${var.pvt_key_file} -e 'pub_key=${var.pub_key_file}' ansible_main.yml -e 'install_docker=${var.docker_installed}' -e 'docker_user=${var.superuser_username}'"
  }
}


resource "null_resource" "restart_vm2" {
  depends_on = [null_resource.run_ansible_playbook]
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
    # NB this is executed as a batch script by cmd.exe.
    inline = [
      <<-EOF
      sudo reboot
      EOF
    ]
  }
}

resource "time_sleep" "wait_60_seconds_5" {
  depends_on = [null_resource.restart_vm2]
  create_duration = "60s"
}
