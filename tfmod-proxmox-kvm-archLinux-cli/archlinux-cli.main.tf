
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

# the virtual machine cloudbase-init cloud-config.
# NB the parts are executed by their declared order.
# see https://github.com/cloudbase/cloudbase-init
# see https://cloudbase-init.readthedocs.io/en/1.1.6/userdata.html#cloud-config
# see https://cloudbase-init.readthedocs.io/en/1.1.6/userdata.html#userdata
# see https://registry.terraform.io/providers/hashicorp/cloudinit/latest/docs/data-sources/config.html
# see https://developer.hashicorp.com/terraform/language/expressions#string-literals
data "cloudinit_config" "initialize_sudo_disks" {
  gzip          = false
  base64_encode = false
  part {
    filename     = "initialize-disks.sh"
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #!
      #!/bin/bash
      set -eu

      echo ">>> Logged in cloned VM...."
      # Update Root password and prevent expiration
      echo "Resetting 'root' password expiration...";
      echo "root:${var.root_new_password}" | sudo chpasswd;
      sudo chage -I -1 -m 0 -M -1 -E -1 root;      

      # # Super-User
      # useradd -m -G wheel -s /bin/bash $SUPERUSER
      echo "${var.superuser_username}:${var.superuser_password}" | chpasswd
      echo ">>> Done -- Super-User creation...."
      # Super-User  - Prevent superuser password expiration
      chage -m 0 -M -1 -E -1 ${var.superuser_username}
      echo ">>> Done -- Prevent superuser password expiration...."
      # Super-User - Set up SSH key
      # mkdir -p /home/${var.superuser_username}/.ssh
      # chmod 700 /home/${var.superuser_username}/.ssh
      # echo "${var.pub_key_file}" >> /home/${var.superuser_username}/.ssh/authorized_keys
      # chmod 600 /home/${var.superuser_username}/.ssh/authorized_keys
      # chown -R ${var.superuser_username}:${var.superuser_username} /home/${var.superuser_username}/.ssh
      # echo ">>> Done -- SSH key...."
      # # Sudo rules Super User
      # printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "${var.superuser_username}" > /etc/sudoers.d/11-superuser
      # chmod 440 /etc/sudoers.d/11-superuser
      # echo ">>> Done -- Super-User SUDO rules...."

      # if INSTALL_AUR_YAY is true, install yay from AUR
      export BUILD_DIR="/tmp/arch-build"
      if [[ "${var.rsyslog_yay_aur_installed}" == "true" || "${var.rsyslog_yay_aur_installed}" == "True" || "${var.rsyslog_yay_aur_installed}" == "TRUE" ]]; then
        echo ">>> INSTALL_AUR_YAY is true, installing yay from AUR...."
        # Install yay from AUR
        # Create a temporary directory for building yay
        echo ">>> Temporary build directory for yay: $BUILD_DIR"
        sudo mkdir -p "$BUILD_DIR"
        sudo chown ${var.superuser_username}:${var.superuser_username} "$BUILD_DIR"
        # Install necessary dependencies for building yay  
        cd $BUILD_DIR && git clone 'https://aur.archlinux.org/yay.git' && cd yay && makepkg -si --noconfirm
        # Clean up the temporary build directory
        rm -rf "$BUILD_DIR"
        echo ">>> Done -- Installed yay from AUR...."
        echo ">>> Test Yay: Running 'yay --version' to verify installation...."
        yay --version
      else
        echo ">>> INSTALL_AUR_YAY is false, skipping yay installation...."
      fi
      #
      # if INSTALL_AUR_YAY is true, update mirrors and upgrade all packages to ensure yay is up to date
      if [[ "${var.rsyslog_yay_aur_installed}" == "true" || "${var.rsyslog_yay_aur_installed}" == "True" || "${var.rsyslog_yay_aur_installed}" == "TRUE" ]]; then
        echo ">>> INSTALL_AUR_YAY is true, updating mirrors and upgrading all packages...."  
        sudo pacman -Syy --noconfirm
        yay -Syu --noconfirm
        echo ">>> Done -- Updated mirrors and upgraded all packages with yay...."
      fi
      #
      # if INSTALL_AUR_YAY is true, install rsyslog from AUR using yay
      if [[ "${var.rsyslog_yay_aur_installed}" == "true" || "${var.rsyslog_yay_aur_installed}" == "True" || "${var.rsyslog_yay_aur_installed}" == "TRUE" ]]; then
        echo ">>> INSTALL_AUR_YAY is true, installing rsyslog from AUR using yay...."
        yay -S --noconfirm rsyslog
        echo ">>> Done -- Installed rsyslog from AUR using yay...."
      fi  

      # Setup additional Disks for LVM ---------
      # Identify all disks without partitions and initialize them for LVM
      echo "Starting non-boot disk initialization for LVM..."      
      n=2
      for disk in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'); do
        if ! sudo lsblk /dev/$disk | grep -q part; then
          echo "Found raw disk: /dev/$disk"
      
          # Create a GPT partition table
          sudo parted -s /dev/$disk mklabel gpt
          
          # Create a single partition that spans the entire disk
          sudo parted -s /dev/$disk mkpart ext4 0% 100%
      
          # Wait for the kernel to re-read partition table
          sudo partprobe /dev/$disk
      
          # Prepare the partition for LVM (create PV)
          sudo pvcreate /dev/$${disk}1
      
          # Optional: add to VG (example: vgname)
          sudo vgcreate my_vg_edisk$n /dev/$${disk}1
          ((n++))
      
          echo "Initialized /dev/$${disk}1 for LVM"
        fi
      done
      echo "... Non-boot disk initialization for LVM completed."
      EOF
  }
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
    ip_config {
      ipv4 {
        address = var.vm_fixed_ip
        gateway = var.vm_fixed_gateway
      }
    }
    dns {
      servers = var.vm_fixed_dns
    }    
    # >>> Fixed IP -- End
  }
}

resource "time_sleep" "wait_1_minutes_1" {
  depends_on = [proxmox_virtual_environment_vm.clone_edited_template]
  # 12 minutes sleep. I have a slow Proxmox Host :(
  create_duration = "1m"
}

# # NB this can only connect after about 3m15s (because the ssh service in the
# #    windows base image is configured as "delayed start").
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
      EOF
    ]
  }
}

resource "time_sleep" "wait_3_minutes_2" {
  depends_on = [null_resource.ssh_into_vm]
  # 12 minutes sleep. I have a slow Proxmox Host :(
  create_duration = "3m"
}

## Run Ansible Playbook to install and configure docker (if mandated by var.docker_installed).
## Assumes Ansible is installed on the local machine running Terraform.
## Also assumes the Ansible playbook is located in ./ansible-playbooks/ansible_main.yml
##
resource "null_resource" "run_ansible_playbook" {
  depends_on = [time_sleep.wait_3_minutes_2]
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
