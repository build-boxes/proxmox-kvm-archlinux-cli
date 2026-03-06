# proxmox-kvm-archlinux-cli

ArchLinux CLI VM Packer Builder and Terraform Instance Manager (Module and Module Usage Examples) scripts.

## Pre-requisites
1. You need a Linux computer, Debian, Ubuntu, RHEL,  Fedora, WSL2 on Windows. [WSL2 on Windows](https://learn.microsoft.com/en-us/windows/wsl/install)
2. You need to install Terraform (client) [Terraform](https://developer.hashicorp.com/terraform/install)
3. You will need to install Ansible client. [Ansible control node](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html)
4. You will need to install Git client. [Git](https://git-scm.com/install/linux)
5. Other then the above computer, you will need a Proxmox VE 8 or 9 Server to host the Virtual Machine. [Proxmox VE](https://www.proxmox.com/en/proxmox-ve), [Enabling Proxmox No-Subscription Library](https://www.youtube.com/watch?v=5j0Zb6x_hOk&t=720s)

## Collecting Build Logs & Debugging
In HashiCorp Packer, you can record the build output (including logs) to a file in a few different ways, depending on whether you want normal output or debug logs.

1. Using PACKER_LOG and PACKER_LOG_PATH
Packer has built-in environment variables for logging:
    ```Bash
    # Enable logging (1 = basic, debug = verbose)
    export PACKER_LOG=1

    # Save logs to a file
    export PACKER_LOG_PATH=packer_build.log

    # Run your build
    packer build template.pkr.hcl
    ```

    * PACKER_LOG=1 → Enables logging (set to debug for more detail).  
    * PACKER_LOG_PATH → Path to the file where logs will be written.  
    * Output will still appear in the terminal and be saved to the file.  


1. Redirecting Standard Output and Error
If you just want to capture exactly what you see in the terminal:
    ```Bash
    packer build template.pkr.hcl | tee packer_output.log
    ```

    * tee writes output to both the terminal and the file.
    * To capture errors too:

    ```Bash
    packer build template.pkr.hcl 2>&1 | tee packer_output.log
    ```

1. Using Debug Mode for Detailed Tracing
If you need step-by-step execution details:
    ```Bash
    export PACKER_LOG=debug
    export PACKER_LOG_PATH=packer_debug.log
    packer build template.pkr.hcl
    ```
    * This will produce a very verbose log file, useful for troubleshooting.  

## Usage 
1. Preparing for Image Build
    1. For faster build times, the ISO was pre-downloaded into Proxmox server. The ArchLinux Source code binary(iso) used in the Packer script was downloaded from following, and its SHA256 Sum link.
        - General Repo Page, scroll to the bottom to see the artifacts. [https://mirrors.mit.edu/archlinux/iso/2026.02.01/](https://mirrors.mit.edu/archlinux/iso/2026.02.01)
        - ISO Link Base - [https://mirrors.mit.edu/archlinux/iso/](https://mirrors.mit.edu/archlinux/iso/)
        - SHA256 Sum Link - [https://mirrors.mit.edu/archlinux/iso/2026.02.01/sha256sums.txt](https://mirrors.mit.edu/archlinux/iso/2026.02.01/sha256sums.txt)
> **❗ Important:**
> 
> - By default this Packer code assumes that the Bash Script "[./pkr-proxmox-kvm-archLinux-cli-grub/scripts/ fetch-latest-archLinux-iso-details.sh](./pkr-proxmox-kvm-archLinux-cli-grub/scripts/ fetch-latest-archLinux-iso-details.sh)" will be executed before the following steps.
> - This script automatically updates the ISO download link and SHA256 Checksum value, used in iso file verification.
> - This script assumes we are downloading 'archlinux-2026.XX.XX-x86_64.iso"
> - After 2026 you will need to update this script to reflect other iso names.
  
    1. An actual WebServer was available and used in Packer Preseeding, rather then using the default Packer mechanism of inbuilt temporary webserver.
        - To do the same for yourself, just copy all files in the subfolder ./pkr-proxmox-kvm-archLinux-cli-grub/http to the actual webserver. Then change the ./pkr-proxmox-kvm-archLinux-cli-grub/vars/archlinux.actual.pkrvars.hcl file accordingly.
1. Image (KVM Template)  Build - Using Packer
    1. Change Directory into ./pkr-proxmox-kvm-archLinux-cli-grub
        ```
        cd ./pkr-proxmox-kvm-archLinux-cli-grub
        ```
    1. Initialize Packer.
        ```
        packer init .
        ```
    1. Launch Packer Build of Image (KVM Template) with your custom parameters or the Default sample.
        ```
        packer build -var-file vars/archlinux.actual.pkrvars.hcl -var "proxmox_api_password=Password#01" .
        ```
        OR, when using dynamic ISO download:
        ```
        packer build -var-file vars/archlinux.actual.pkrvars.hcl -var-file vars/generated-archlinux-vars.pkrvars.hcl -var "proxmox_api_password=Password#01" .
        ```
    1. The Image (KVM Template) should now be ready on the Proxmox server.
---
## Following is ToDo. Not Implemented Yet.
1. VM Instance Creation - Using Terraform
    1. Change Directory into ../tfmod-proxmox-kvm-archlinux-cli/examples/<<any-one>>
        ```
        cd ../tf-proxmox-kvm-archlinux-cli/examples/bash-ahc
        ```
        OR

        Copy the contents of the Directory /tfmod-proxmox-kvm-archlinux-cli/examples/<<any-one>> into a new sub-folder anywhere (let us assume it is /home/${USER}/tf-example ) on your host computer. Change into your sub-folder.
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
