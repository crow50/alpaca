#!/usr/bin/env bash
# Reports which tools each path (core / Packer+VirtualBox / Docker) actually needs and
# whether they're present. Doesn't install anything, doesn't fail the build -- you only need
# the group for whichever path you're using; see README.md.

check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf '  [ok]   %s\n' "$desc"
    else
        printf '  [MISS] %s\n' "$desc"
    fi
}

echo "Core (always needed):"
# A bare swipl binary isn't enough -- on Debian/Ubuntu, `apt install swi-prolog-core` gives
# you one that's missing library(uuid)/library(http/json), which output.pl needs; you want
# the full `swi-prolog` package, not `swi-prolog-core`.
check "SWI-Prolog, with the libraries Alpaca needs" \
    swipl -g "use_module(library(uuid)), use_module(library(http/json))" -t halt
check "Graphviz (dot)" command -v dot
check "zip"            command -v zip

echo
echo "Packer/VirtualBox path:"
check "Packer"                      command -v packer
check "VirtualBox (VBoxManage)"     command -v VBoxManage
check "Ansible (ansible-playbook)"  command -v ansible-playbook
check "community.mysql collection"  ansible-galaxy collection list community.mysql
check "passlib (for password_hash)" python3 -c "import passlib"

echo
echo "Docker path:"
check "Docker"                  command -v docker
check "Docker daemon reachable" docker info
