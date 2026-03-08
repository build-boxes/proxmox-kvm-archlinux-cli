
output "ip" {
  value = local.host_ip
  #proxmox_virtual_environment_vm.example.ipv4_addresses[index(proxmox_virtual_environment_vm.example.network_interface_names, "Ethernet")][0]
}
