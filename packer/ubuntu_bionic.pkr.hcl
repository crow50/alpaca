packer {
  required_plugins {
    virtualbox = {
      version = "~> 1.1.5"
      source  = "github.com/hashicorp/virtualbox"
    }
    ansible = {
      version = "~> 1.1.6"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

source "virtualbox-iso" "ubuntu_bionic" {
  boot_command         = ["<esc><wait><esc><wait><enter><wait>/install/vmlinuz auto console-setup/ask_detect=false console-setup/layoutcode=us console-setup/modelcode=pc105 debconf/frontend=noninteractive debian-installer=en_US fb=false initrd=/install/initrd.gz kbd-chooser/method=us keyboard-configuration/layout=USA keyboard-configuration/variant=USA locale=en_US netcfg/get_domain=vm netcfg/get_hostname=vagrant grub-installer/bootdev=/dev/sda noapic preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg -- <enter><wait>"]
  boot_wait            = "10s"
  guest_additions_path = "VBoxGuestAdditions_{{.Version}}.iso"
  guest_os_type        = "Ubuntu_64"
  hard_drive_interface = "sata"
  sata_port_count      = 8
  headless             = true
  http_directory       = "packer/http"
  iso_checksum         = var.iso_checksum
  iso_url              = var.iso_url
  shutdown_command     = "echo 'shutdown -P now' > shutdown.sh; echo 'vagrant'|sudo -S sh 'shutdown.sh'"
  ssh_password         = "vagrant"
  ssh_port             = 22
  ssh_username         = "vagrant"
  ssh_wait_timeout     = "10000s"
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--memory", "2048"],
    ["modifyvm", "{{.Name}}", "--cpus", "1"],
  ]
  virtualbox_version_file = ".vbox_version"
  vm_name                 = "packer-virtualbox-iso-ubuntu-18.04.5"
}

build {
  sources = ["source.virtualbox-iso.ubuntu_bionic"]

  provisioner "shell" {
    execute_command   = "echo 'vagrant' | sudo -S sh '{{ .Path }}'"
    expect_disconnect = true
    scripts           = ["packer/setup_1.sh"]
  }

  provisioner "shell" {
    expect_disconnect = true
    scripts           = ["packer/setup_2.sh"]
  }

  provisioner "ansible" {
    playbook_file   = "./playbook.yml"
    extra_arguments = ["-e", "ansible_python_interpreter=/usr/bin/python3", "-vvvv"]
  }

  # Resets the vagrant/vagrant bootstrap account's SSH host keys and the NOPASSWD sudo grant
  # setup_1.sh made for it -- that account only ever exists to let Packer itself in; nothing
  # downstream needs it, and leaving it as-is would let anyone bypass the intended exploit
  # chain entirely. See packer/harden.sh.
  provisioner "shell" {
    execute_command   = "echo 'vagrant' | sudo -S sh '{{ .Path }}'"
    expect_disconnect = true
    scripts           = ["packer/harden.sh"]
  }
}
