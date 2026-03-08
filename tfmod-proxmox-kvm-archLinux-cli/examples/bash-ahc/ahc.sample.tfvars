## INSTRUCTIONS: Make a copy of this file named "ahc.auto.tfvars" and fill in the Actual values.
##
# This is a Shadow file, illustrating what the actual file should contain.
# 
pub_key_file="/home/XXXX/.ssh/id_rsa.pub"
pvt_key_file="/home/XXXX/.ssh/id_rsa"
superuser_username="terraform"
# Password with @ symbol has issues in cloudbase-init scripts escape-sequencing in terraform ".tf" files
superuser_password="XXXXXXXX"
#superuser_new_password="XXXXXXXX"
root_new_password="XXXXXXXX"
# prefix is actually Proxmox KVM Name, and hostname.
prefix="ahc"
# Proxmox vars
proxmox_node_address="192.168.4.20"
proxmox_node_name="pve"
PROXMOX_VE_ENDPOINT="https://192.168.4.20:8006/api2/json"
PROXMOX_VE_USERNAME="terraform-prov@pve"
PROXMOX_VE_PASSWORD="XXXXXXXX"
PROXMOX_VE_INSECURE=true
# Following specifies which datastore this VM and its artifacts will be on.
proxmox_datastore_id="local"
# Tags to identify Proxmox VM Template
proxmox_vm_template_tags=["template","archlinux","cli", "minimal"]
# Tags to give to created VM
proxmox_vm_tags=["archlinux", "cli", "ahc", "minimal"]
vm_fixed_ip="192.168.0.23/24"
vm_fixed_gateway="192.168.0.1"
vm_fixed_dns=["192.168.0.1"]
cpu_core_count=1
memory_size="512M"
disk_size_boot="8G"
disk_boot_ssd_enabled=false
docker_installed=false
rsyslog_yay_aur_installed=false
