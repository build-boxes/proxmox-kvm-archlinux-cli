# INSTRUCTIONS: Make a copy of this file named "archlinux.actual.pkvars.hcl" and fill in the Actual values.
##
# This is a Shadow file, illustrating what the actual file should contain.
#
proxmox_host      = "10.0.0.10:8006"
proxmox_node      = "shackvm01"
vm_name           = "template-archlinux-cli"
vmid              = "9300"
cpu_type          = "x86-64-v2-AES"
cores             = "1"
memory            = "1024M"      # For Initial Boot less than 1024M causes Kernel-Panic. Can reduce the size when copying the template.
storage_pool      = "vmdata"
disk_size         = "8192M"
disk_format       = "raw"
disk_ssd_enabled  = false
vm_image_tags     = ["template", "archlinux", "cli", "minimal"]

iso_storage_pool = "vmdata"
#iso_url          = "https://cdimage.debian.org/debian-cd/13.3.0/amd64/iso-cd/debian-13.3.0-amd64-netinst.iso"
## If Using Pre Downloaded image use following line, and comment iso_url line and dont use 
##    dynamic_iso_url or 'fetch-latest-debian13-iso-details.sh' script.
#iso_file         = "vmdata:iso/archlinux-2026.02.01-x86_64.iso"
iso_file         = ""
## If Using Pre Downloaded image use following line, and update value accodingly.
#iso_checksum     = "sha512:1ada40e4c938528dd8e6b9c88c19b978a0f8e2a6757b9cf634987012d37ec98503ebf3e05acbae9be4c0ec00b52e8852106de1bda93a2399d125facea45400f8"
##

archlinux_root_password = "simplePassW0rd" # Used during initial Packer login. It will be changed later on.
# encoded password for "packer". Used $ echo "packer" | mkpasswd --method=SHA-512 --rounds=4096
archlinux_root_password = "$6$rounds=4096$fjTsVA3mR6pErezN$TmCYfzgj/xHuPQzkOtpg6sqdZRl5ZPWpHpj2k4316wkm4jiTiAzk8h2AUSUhypKndrGfqrJpLVo6FH/aFurIC1"

# superuser details for (cloud-cfg file)
superuser_name     = "terraform"
superuser_gecos    = "Terra Admin"
# encoded password for "packer". Used $ echo "packer" | mkpasswd --method=SHA-512 --rounds=4096
superuser_password = "$6$rounds=4096$fjTsVA3mR6pErezN$TmCYfzgj/xHuPQzkOtpg6sqdZRl5ZPWpHpj2k4316wkm4jiTiAzk8h2AUSUhypKndrGfqrJpLVo6FH/aFurIC1"
superuser_ssh_pub_key = "ssh-rsa AAAAB3NzaC1ycXXXXXzRs= terraform@ServerName"
swap_size="750M"
timezone="America/Toronto"
hostname="archlvm"
mirrors_country="US"
