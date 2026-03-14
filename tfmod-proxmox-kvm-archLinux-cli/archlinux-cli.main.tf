
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

# see https://registry.terraform.io/providers/bpg/proxmox/0.98.0/docs/resources/virtual_environment_file
resource "proxmox_virtual_environment_file" "initialize_ci_user_data" {
  content_type = "snippets"
  datastore_id = var.proxmox_datastore_id
  node_name    = var.proxmox_node_name
  source_raw {
    file_name = "${var.prefix}-ci-user-data.txt"
    data      = data.cloudinit_config.initialize_sudo_disks.rendered
  }
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
  # disk {      # Boot Disk, Size can be increased here. Then manually Increase Volume size inside Windows-2025.
  #   datastore_id = var.proxmox_datastore_id
  #   interface   = "scsi1"
  #   file_format = "raw"
  #   iothread    = true
  #   ssd         = true
  #   discard     = "on"
  #   size        = 16     # minimum size of the Template image disk.
  # }

  agent {
    enabled = true
    #trim    = true
  }
  # NB we use a custom user data because this terraform provider initialization
  #    block is not entirely compatible with cloudbase-init (the cloud-init
  #    implementation that is used in the windows base image).
  # see https://pve.proxmox.com/wiki/Cloud-Init_Support
  # see https://cloudbase-init.readthedocs.io/en/latest/services.html#openstack-configuration-drive
  # see https://registry.terraform.io/providers/bpg/proxmox/0.98.0/docs/resources/virtual_environment_vm#initialization
  initialization {
    user_account {
      #keys     = [trimspace(file("${var.pvt_key_file}"))]
      keys     = [trimspace(file("${var.pub_key_file}"))]
      password = var.superuser_password
      username = var.superuser_username
    }    
    user_data_file_id = proxmox_virtual_environment_file.initialize_ci_user_data.id
    datastore_id = var.proxmox_datastore_id    
    # >>> Fixed IP -- Start
    # # Use following if need fixed IP Address, otherwise comment out   
    # # dynamic "ip_config" {
    # #   for_each = (var.vm_fixed_ip != "" && var.vm_fixed_gateway != "" && length(var.vm_fixed_dns) > 0 ? [1] : [])
    # #   content {
    # #     ipv4 {
    # #       address = var.vm_fixed_ip
    # #       gateway = var.vm_fixed_gateway
    # #     }
    # #   }
    # # }
    # # dynamic "dns" {
    # #   for_each = (var.vm_fixed_ip != "" && var.vm_fixed_gateway != "" && length(var.vm_fixed_dns) > 0 ? [1] : [])
    # #   content {
    # #     servers = var.vm_fixed_dns
    # #   }
    # # }
    # ip_config {
    #   ipv4 {
    #     address = var.vm_fixed_ip
    #     gateway = var.vm_fixed_gateway
    #   }
    # }
    # dns {
    #   servers = var.vm_fixed_dns
    # }    
    # >>> Fixed IP -- End
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
      # echo "Resetting password expiration...";
      # echo "${var.superuser_username}:${var.superuser_password}" | sudo chpasswd;
      # sudo chage -I -1 -m 0 -M -1 -E -1 ${var.superuser_username};
      # echo "Resetting 'root' password expiration...";
      # echo "root:${var.root_new_password}" | sudo chpasswd;
      # sudo chage -I -1 -m 0 -M -1 -E -1 root;
      # echo "Configuring passwordless sudo for ${var.superuser_username}...";
      # echo "${var.superuser_username} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${var.superuser_username};
      # sudo chmod 0440 /etc/sudoers.d/${var.superuser_username};
      # echo "Password reset and sudo configuration completed";      
      # USERID="${var.superuser_username}";
      # BASHRC="/home/${var.superuser_username}/.bashrc";
      # if [ -d "/home/${var.superuser_username}" ] && [ -f "$BASHRC" ]; then
      #   grep -q "/usr/sbin" "$BASHRC" || echo 'export PATH="/usr/sbin:$PATH"' >> "$BASHRC"
      #   echo "Added /usr/sbin to user PATH variable"
      # fi;
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

data "templatefile" "initialize_disks" {
  depends_on = [time_sleep.wait_2_minutes_2]
  template = "${path.module}/scripts/initialize-extra-disks.sh.tpl"

  vars = {
    root_new_password        = var.root_new_password
    superuser_username       = var.superuser_username
    superuser_password       = var.superuser_password
    rsyslog_yay_aur_installed = var.rsyslog_yay_aur_installed
  }
}

resource "null_resource" "initialize_disks" {
  depends_on = [data.templatefile.initialize_disks]
  triggers = {
    root_pw   = var.root_new_password
    superuser = var.superuser_username
    yay_flag  = var.rsyslog_yay_aur_installed
  }

  provisioner "file" {
    content     = data.templatefile.initialize_disks.rendered
    destination = "/tmp/initialize-disks.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/initialize-disks.sh",
      "sudo /tmp/initialize-disks.sh"
    ]
  }

  connection {
    type     = "ssh"
    host     = var.vm_ip
    user     = "root"
    password = var.root_new_password
  }
}

resource "time_sleep" "wait_2_minutes_3" {
  depends_on = [null_resource.initialize_disks]
  # 12 minutes sleep. I have a slow Proxmox Host :(
  create_duration = "2m"
}

data "templatefile" "nm_static_ip" {
  depends_on = [time_sleep.wait_2_minutes_3]
  template = "${path.module}/scripts/nm-static-ip.sh.tpl"
  vars = {
    ipv4_address = var.var_vm_fixed_ip
    ipv4_gateway = var.var_vm_fixed_gateway
    ipv4_dns     = join(",", var.var_vm_fixed_dns)
  }
}

resource "null_resource" "configure_network" {
  depends_on = [data.templatefile.nm_static_ip]
  triggers = {
    ipv4_address = var.var_vm_fixed_ip
    ipv4_gateway = var.var_vm_fixed_gateway
    ipv4_dns     = join(",", var.var_vm_fixed_dns)
  }

  provisioner "file" {
    content     = data.templatefile.nm_static_ip.rendered
    destination = "/tmp/nm-static-ip.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/nm-static-ip.sh",
      "sudo /tmp/nm-static-ip.sh",
      "sleep 30"
    ]
  }
}

## Run Ansible Playbook to install and configure docker (if mandated by var.docker_installed).
## Assumes Ansible is installed on the local machine running Terraform.
## Also assumes the Ansible playbook is located in ./ansible-playbooks/ansible_main.yml
##
resource "null_resource" "run_ansible_playbook" {
  depends_on = [null_resource.configure_network]
    provisioner "local-exec" {
    #interpreter = ["/bin/bash"]
    # Use the module path so the playbooks are found whether the module is local or fetched into .terraform/modules
    working_dir = "${path.module}/ansible-playbooks"
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u '${var.superuser_username}' -i '${local.host_ip},' --private-key ${var.pvt_key_file} -e 'pub_key=${var.pub_key_file}' ansible_main.yml -e 'install_docker=${var.docker_installed}' -e 'docker_user=${var.superuser_username}'"
  }
}


resource "null_resource" "restart_vm" {
  depends_on = [null_resource.run_ansible_playbook]
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

resource "time_sleep" "wait_3_minutes_3" {
  depends_on = [null_resource.restart_vm]
  create_duration = "3m"
}
