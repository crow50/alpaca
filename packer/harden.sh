#!/bin/bash
# Final provisioner: the vagrant/vagrant account exists only so Packer can bootstrap this
# build over SSH (packer/http/preseed.cfg creates it; setup_1.sh grants it passwordless sudo
# so later provisioners can run unattended). Nothing downstream -- no Vagrantfile, no Ansible
# role -- consumes this account afterward, so undo both before the VM is considered done:
# the passwordless-sudo grant, and the SSH host keys that have been sitting on disk since
# this VM's very first boot.
set -e

# setup_1.sh backed up the pre-edit file to this exact path before making its changes.
cp /etc/sudoers.orig /etc/sudoers

rm -f /etc/ssh/ssh_host_*
ssh-keygen -A

for u in vagrant root; do
    home=$(getent passwd "$u" | cut -d: -f6)
    rm -f "$home/.bash_history"
done
