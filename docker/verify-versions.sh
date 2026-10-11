#!/usr/bin/env bash
# Checks whether the vsftpd/openssh versions actually installed in a provisioned target
# container match what this lattice's generated config requires. A lattice with no
# version-coupled role (e.g. the apache/php/mysql-only web_admin_access) always passes --
# there's nothing to verify.
#
#   verify-versions.sh <lattice-dir> <container-name>
#
# Exit 0: verified (or nothing version-coupled to verify). Exit 1: a version-coupled role
# is present but the installed version doesn't match -- still safe to bake and use for the
# lattice's OTHER steps, just don't present the mismatched step as working on this image.
set -euo pipefail

lattice_dir="$(cd "$1" && pwd)"
container="$2"
lattice_id="$(basename "$lattice_dir")"
metadata="$lattice_dir/../range_metadata.json"

[ -f "$metadata" ] || { echo "no range_metadata.json found at $metadata" >&2; exit 2; }

read -r vsftpd_want openssh_want <<EOF
$(python3 -c "
import json
with open('$metadata') as f:
    data = json.load(f)
cfg = {}
for lat in data['lattices']:
    if lat['latticeId'] == '$lattice_id':
        cfg = {role: vals for entry in lat['config'] for role, vals in entry.items()}
        break
print(cfg.get('vsftpd', {}).get('version', [''])[0], cfg.get('openssh', {}).get('version', [''])[0])
")
EOF

ok=0

if [ -z "$vsftpd_want" ] && [ -z "$openssh_want" ]; then
    echo "  no version-coupled roles (vsftpd/openssh) in this lattice -- nothing to verify"
    exit 0
fi

if [ -n "$vsftpd_want" ]; then
    actual="$(docker exec "$container" dpkg-query -W -f='${Version}' vsftpd 2>/dev/null || echo '(not installed)')"
    if [ "$actual" = "$vsftpd_want" ]; then
        echo "  vsftpd: installed $actual, matches lattice requirement -- verified"
    else
        echo "  vsftpd: installed '$actual', lattice requires '$vsftpd_want' -- NOT verified; don't present this lattice's vsftpd-based step on this image"
        ok=1
    fi
fi

if [ -n "$openssh_want" ]; then
    actual="$(docker exec "$container" bash -c "sshd -V 2>&1 | grep -oE 'OpenSSH_[0-9]+\.[0-9]+p?[0-9]*' | head -1 | sed 's/OpenSSH_//'" || echo '(not installed)')"
    if [ "$actual" = "$openssh_want" ]; then
        echo "  openssh: installed $actual, matches lattice requirement -- verified"
    else
        echo "  openssh: installed '$actual', lattice requires '$openssh_want' -- NOT verified; don't present this lattice's openssh-based step on this image"
        ok=1
    fi
fi

exit "$ok"
