packer {
  required_plugins {
    proxmox = {
      version = "~> 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }

    # ansible = {
    #   version = "~> 1.1.4"
    #   source  = "github.com/hashicorp/ansible"
    # }
  }
}