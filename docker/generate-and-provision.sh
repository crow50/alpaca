#!/usr/bin/env bash
# One-shot convenience: generates a range via the Prolog planner, then provisions and bakes
# the resulting lattice into a Docker image -- equivalent to running
# `swipl prolog/main.pl createRangeFromIGS ...` yourself, finding the lattice directory it
# printed, and passing that to provision-and-bake.sh, minus the copy-pasting.
#
#   docker/generate-and-provision.sh GOAL
#   docker/generate-and-provision.sh INIT GOAL PARAMS
#
#   docker/generate-and-provision.sh '[web_admin_access]'
#   docker/generate-and-provision.sh '[]' '[root_shell]' '[paramPasswordLength-8]'
set -euo pipefail

if [ $# -eq 1 ]; then
    init='[]'; goal="$1"; params='[paramPasswordLength-8]'
elif [ $# -eq 3 ]; then
    init="$1"; goal="$2"; params="$3"
else
    echo "usage: $0 GOAL                      (INIT defaults to '[]', PARAMS to '[paramPasswordLength-8]')" >&2
    echo "       $0 INIT GOAL PARAMS" >&2
    exit 2
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"

echo "== generating a range for goal $goal =="
docker build -q -t alpaca-lab "$repo_root/review/repro" >/dev/null
before="$(ls "$repo_root/ranges" 2>/dev/null | sort || true)"
docker run --rm --network none -v "$repo_root":"$repo_root" -w "$repo_root/prolog" alpaca-lab \
    swipl main.pl createRangeFromIGS "$init" "$goal" "$params"

range_id="$(comm -13 <(printf '%s\n' "$before") <(ls "$repo_root/ranges" | sort) | grep -v '\.zip$')"
lattice_id="$(ls "$repo_root/ranges/$range_id" | grep -v json)"
lattice_dir="$repo_root/ranges/$range_id/$lattice_id"
echo "== generated: $lattice_dir =="

exec "$here/provision-and-bake.sh" "$lattice_dir"
