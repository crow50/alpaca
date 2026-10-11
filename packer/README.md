Based on https://github.com/CpuID/packer-ubuntu-virtualbox (MIT License)


Run (from the repo root, so the relative script/role paths in `ubuntu_bionic.pkr.hcl` resolve;
point at the `packer/` directory, not a single file, so `variables.pkr.hcl` is picked up too):

    packer init packer/
    packer build packer/


