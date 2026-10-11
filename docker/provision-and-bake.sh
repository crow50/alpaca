#!/usr/bin/env bash
# Provisions an already-generated lattice into a Docker container instead of a Packer/
# VirtualBox VM, using the SAME unmodified ansible/roles/ via Ansible's community.docker
# connection plugin. See docker/README.md for the design and prerequisites.
#
#   docker/provision-and-bake.sh ranges/<range-id>/<lattice-id>
#
# Prints the resulting image tag and the ~1s command to reset a fresh instance from it.
set -euo pipefail

usage() { echo "usage: $0 <path-to-ranges/RANGE-ID/LATTICE-ID>" >&2; exit 2; }
[ $# -eq 1 ] || usage

lattice_dir="$(cd "$1" 2>/dev/null && pwd)" || { echo "no such directory: $1" >&2; exit 2; }
[ -f "$lattice_dir/playbook.yml" ] || { echo "no playbook.yml in $lattice_dir -- is this a lattice directory from ranges/?" >&2; exit 2; }

# The lattice's own "roles" symlink (made by output.pl) is an ABSOLUTE path back to this
# checkout's ansible/roles -- so the control container must see the repo at this same
# absolute path, not remapped to something like /repo, or that symlink dangles inside it.
repo_root="$(cd "$lattice_dir/../../.." && pwd)"
lattice_id="$(basename "$lattice_dir")"
target_name="alpaca-${lattice_id}"

# Pinned by digest (see docker/README.md for how to refresh this).
target_image="geerlingguy/docker-ubuntu2204-ansible@sha256:7c37bfb098b8f52d18ee730a65f946a2535acab19b6f491418c2ed788d51974a"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# A failed run used to leave the target container (and the host port it's holding) behind
# forever, blocking every retry until it was found and removed by hand -- clean up on ANY
# exit, not just the success path (which still explicitly removes it after commit, making
# this a harmless no-op there).
inventory=""
cleanup() {
    [ -n "$inventory" ] && rm -f "$inventory"
    docker rm -f "$target_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Without -p, this container is only reachable from inside itself -- useless for actually
# attacking it. Figure out which of the "front door" services this lattice's config touches
# and publish a fixed, memorable host port for each. (mysql/php aren't published: nothing in
# this repo's exploit chains reaches them except through apache, by design.)
metadata="$lattice_dir/../range_metadata.json"
roles_present="$(python3 -c "
import json
with open('$metadata') as f:
    data = json.load(f)
for lat in data['lattices']:
    if lat['latticeId'] == '$lattice_id':
        print(' '.join(sorted(set(role for entry in lat['config'] for role in entry))))
        break
")"

declare -A role_cport=( [apache]=80 [vsftpd]=21 [openssh]=22 )
declare -A role_hport=( [apache]=8080 [vsftpd]=2121 [openssh]=2222 )
declare -A role_label=( [apache]="HTTP (apache)" [vsftpd]="FTP (vsftpd)" [openssh]="SSH (openssh)" )
port_args=()
port_summary=()
for role in apache vsftpd openssh; do
    if [[ " $roles_present " == *" $role "* ]]; then
        port_args+=(-p "${role_hport[$role]}:${role_cport[$role]}")
        port_summary+=("  ${role_label[$role]} -> localhost:${role_hport[$role]}")
    fi
done
if [ "${#port_summary[@]}" -eq 0 ]; then
    port_summary+=("  (no apache/vsftpd/openssh in this lattice -- nothing externally reachable to publish)")
fi

echo "== starting target container ($target_name) =="
docker rm -f "$target_name" >/dev/null 2>&1 || true
docker run -d --name "$target_name" \
    --tmpfs /tmp --tmpfs /run --tmpfs /run/lock \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw --cgroupns=host \
    "${port_args[@]}" \
    "$target_image" /lib/systemd/systemd >/dev/null

echo "== waiting for systemd to come up =="
for _ in $(seq 1 30); do
    state="$(docker exec "$target_name" systemctl is-system-running 2>/dev/null || true)"
    case "$state" in
        running|degraded) break ;;
    esac
    sleep 1
done

# Compatibility steps the Packer path gets for free from preseed.cfg/setup_1.sh/setup_2.sh
# baking a prepared base image -- this target container starts from a generic upstream image
# instead, so each fresh instance needs them once, before any role's apt tasks run:
#   - force apt onto IPv4: some rootless-Docker/WSL2 networks resolve apt mirrors to AAAA
#     records whose IPv6 path isn't actually routed, which hangs rather than fails fast.
#   - refresh the apt cache: the base image's own cache is whatever was baked in when IT was
#     built, not this run's current package index.
#   - pre-install openssh-server if this lattice uses it: ansible/roles/openssh/tasks/main.yml
#     only ever CONFIGURES sshd (PermitRootLogin) -- it has no install task, because on the
#     Packer path preseed.cfg's own pkgsel already installs openssh-server before Ansible
#     ever runs. This target has no equivalent preseed step, so without this it fails with
#     "Destination /etc/ssh/sshd_config does not exist". Installing it here (not editing the
#     shared role) keeps the role untouched, matching DOCKER-PORT-PLAN.md's "don't rewrite
#     the roles" design.
echo "== apt compatibility pass (first run on a fresh container; can take a couple of minutes) =="
apt_cmds="echo 'Acquire::ForceIPv4 \"true\";' > /etc/apt/apt.conf.d/99force-ipv4 && apt-get update -qq"
if [[ " $roles_present " == *" openssh "* ]]; then
    apt_cmds="$apt_cmds && apt-get install -y -qq openssh-server"
fi
docker exec "$target_name" bash -c "$apt_cmds"

echo "== resolving the host's Docker socket (works for rootful and rootless Docker) =="
docker_host_uri="$(docker context inspect "$(docker context show)" --format '{{.Endpoints.docker.Host}}')"
docker_sock="${docker_host_uri#unix://}"

inventory="$(mktemp)"
echo "$target_name ansible_connection=community.docker.docker ansible_python_interpreter=/usr/bin/python3" > "$inventory"

echo "== provisioning via the real, unmodified ansible/roles/ =="
docker run --rm \
    -v "$repo_root":"$repo_root":ro \
    -v "$docker_sock":/var/run/docker.sock \
    -v "$inventory":/inventory.ini:ro \
    -e DOCKER_HOST=unix:///var/run/docker.sock \
    -w "$lattice_dir" \
    alpaca-control \
    ansible-playbook -i /inventory.ini playbook.yml

echo "== verifying installed package versions against this lattice's requirements =="
if "$here/verify-versions.sh" "$lattice_dir" "$target_name"; then
    tag_suffix=verified
else
    tag_suffix=unverified
fi

image_tag="alpaca-lattice-${lattice_id}:${tag_suffix}"
docker commit "$target_name" "$image_tag" >/dev/null
docker rm -f "$target_name" >/dev/null

port_args_str="${port_args[*]}"

cat <<EOF

Baked: $image_tag

Reachable at (give it ~10s after starting for systemd and the services to finish coming up):
$(printf '%s\n' "${port_summary[@]}")

Reset for a new instance (~1s to reset, then ~10s for services to be reachable):
  docker rm -f <name>
  docker run -d --name <name> --tmpfs /tmp --tmpfs /run --tmpfs /run/lock \\
      -v /sys/fs/cgroup:/sys/fs/cgroup:rw --cgroupns=host $port_args_str $image_tag /lib/systemd/systemd
EOF
