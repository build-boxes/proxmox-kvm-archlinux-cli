# proxmox-kvm-archlinux-cli

ArchLinux CLI VM Packer Builder and Terraform Instance Manager (Module and Module Usage Examples) scripts.

## Pre-requisites
1. You need a Linux computer, Debian, Ubuntu, RHEL,  Fedora, WSL2 on Windows. [WSL2 on Windows](https://learn.microsoft.com/en-us/windows/wsl/install)
2. You need to install Terraform (client) [Terraform](https://developer.hashicorp.com/terraform/install)
3. You will need to install Ansible client. [Ansible control node](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html)
4. You will need to install Git client. [Git](https://git-scm.com/install/linux)
5. Other then the above computer, you will need a Proxmox VE 8 or 9 Server to host the Virtual Machine. [Proxmox VE](https://www.proxmox.com/en/proxmox-ve), [Enabling Proxmox No-Subscription Library](https://www.youtube.com/watch?v=5j0Zb6x_hOk&t=720s)

---
# Update Needed Below This

## Usage 
1. Preparing for Image Build
    1. For faster build times, the ISO was pre-downloaded into Proxmox server. The Debian13 Source code binary(iso) used in the Packer script was downloaded from following, and its SHA512 Sum link.
        - General Repo Page, scroll to the bottom to see the artifacts. [https://get.debian.org/images/release/13.0.0/amd64/iso-cd/](https://get.debian.org/images/release/13.0.0/amd64/iso-cd/)
        - ISO Link - [https://get.debian.org/images/release/13.0.0/amd64/iso-cd/debian-13.0.0-amd64-netinst.iso](https://get.debian.org/images/release/13.0.0/amd64/iso-cd/debian-13.0.0-amd64-netinst.iso)
        - SHA512 Sum Link - [https://get.debian.org/images/release/13.0.0/amd64/iso-cd/SHA512SUMS](https://get.debian.org/images/release/13.0.0/amd64/iso-cd/SHA512SUMS)
    1. An actual WebServer was available and used in Packer Preseeding, rather then using the default Packer mechanism of inbuilt temporary webserver.
        - To do the same for yourself, just copy all files in the subfolder ./pkr-proxmox-kvm-debian13/http to the actual webserver. Then change the ./pkr-proxmox-kvm-debian13/vars/debian_13.pkrvars.hcl file accordingly.
1. Image (KVM Template)  Build - Using Packer
    1. Change Directory into ./pkr-proxmox-kvm-debian13-cli
        ```
        cd ./pkr-proxmox-kvm-debian13-cli
        ```
    1. Initialize Packer.
        ```
        packer init .
        ```
    1. Launch Packer Build of Image (KVM Template) with your custom parameters or the Default sample.
        ```
        packer build -var-file vars/debian_13.actual.pkrvars.hcl -var "proxmox_api_password=Password#01" .
        ```
        OR, when using dynamic ISO download:
        ```
        packer build -var-file vars/debian_13.actual.pkrvars.hcl -var-file vars/generated-debian13-vars.pkrvars.hcl  -var "proxmox_api_password=Password#01" .
        ```
    1. The Image (KVM Template) should now be ready on the Proxmox server.
1. VM Instance Creation - Using Terraform
    1. Change Directory into ../tfmod-proxmox-kvm-debian13-cli/examples/<<any-one>>
        ```
        cd ../tf-proxmox-kvm-debian13-cli/examples/bash-ahc
        ```
        OR

        Copy the contents of the Directory /tfmod-proxmox-kvm-debian13-cli/examples/<<any-one>> into a new sub-folder anywhere (let us assume it is /home/${USER}/tf-example ) on your host computer. Change into your sub-folder.
        ```
        cd /home/${USER}/tf-example
        ```
        You do not need other files in the Module on your computer, by default the module will be downloaded from its Github repository.

    1. Note that the Terraform script (coming up next) uses the Tags to identify the Image (KVM Template). So if you have changed the tags in the Packer configuration, you should also change them in the Terraform configuration.
    1. Launch Terraform to create an Instance of this Image, that you will actually use.
        ```
        terraform init -upgrade
        terraform plan
        terraform apply -auto-approve
        ```
    1. Your instance VM should now be ready.
        a. You can SSH login to the server.
        ```
        ssh terraform@<<IP_Address_of_instance>>
        ```
        a. End your SSH session on the VM.
        ```
        exit
        ```
    1. To Destroy the Instance use the following command, in the ./tf-proxmox-kvm-debian13-cli/examples/bash-ahc folder:
        ```
        terraform destroy -auto-approve
        ```
  