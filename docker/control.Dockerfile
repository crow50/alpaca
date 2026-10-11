# Control-node image for provision-and-bake.sh: runs Ansible against a sibling container
# (via community.docker) over the host's Docker socket, mounted in at run time.
# The `ansible` apt package already bundles the community.docker and community.mysql
# collections this needs -- confirmed, no `ansible-galaxy collection install` required.
FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ansible python3-docker python3-passlib docker-cli ca-certificates \
 && rm -rf /var/lib/apt/lists/*
