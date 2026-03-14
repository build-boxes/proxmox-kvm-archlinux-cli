locals {
 
  # If the selected VM-list are templates or not, chose the first one from list.
  template_vm = [for vm in data.proxmox_virtual_environment_vms.archlinux_cli_templates.vms : vm if vm.template==true ][0]

  # Store the computed host IP address for reuse throughout the configuration
  host_ip = coalesce(try(split("/",proxmox_virtual_environment_vm.clone_edited_template.initialization[0].ip_config[0].ipv4[0].address)[0], null),proxmox_virtual_environment_vm.clone_edited_template.ipv4_addresses[1][0] )


  initialize_disks = templatefile("${path.module}/scripts/initialize-extra-disks.sh.tpl", {
    root_new_password        = var.root_new_password
    superuser_username       = var.superuser_username
    superuser_password       = var.superuser_password
    rsyslog_yay_aur_installed = var.rsyslog_yay_aur_installed
  })

  nm_static_ip = templatefile("${path.module}/scripts/nm-static-ip.sh.tpl", {
    ipv4_address = var.var_vm_fixed_ip
    ipv4_gateway = var.var_vm_fixed_gateway
    ipv4_dns     = join(",", var.var_vm_fixed_dns)
  })

}