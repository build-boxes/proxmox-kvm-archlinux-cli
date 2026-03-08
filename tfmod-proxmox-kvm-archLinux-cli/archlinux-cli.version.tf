# Adapted from: https://github.com/build-boxes/terraform-proxmox-windows-example/blob/main/main.tf
#
#
# see https://github.com/hashicorp/terraform
terraform {
  
  #required_version = ">= 1.12.1, <= 1.14.4"
  required_version = ">= 1.12.1"

  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/random
    random = {
      source  = "hashicorp/random"
      version = "3.7.1"
    }
    # see https://registry.terraform.io/providers/hashicorp/cloudinit
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.6"
    }
    # see https://registry.terraform.io/providers/bpg/proxmox
    # see https://github.com/bpg/terraform-provider-proxmox
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.98.0"
    }
    time = {
          source = "hashicorp/time"
          version = "0.13.1"
    }
  }
}

