#!/usr/bin/env bash
# Re-runs the checks behind ../ALPACA-REVIEW.md inside a disposable container.
#
#   review/repro/run.sh                # everything
#   review/repro/run.sh yaml           # one check: env | goals | readme | cli | ansible | yaml | merge | api | undefined | tests
#
# The repo is mounted READ-ONLY and the container has NO network, so this cannot change your
# checkout or reach out to anything. Building the image (once) needs the network for apt.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

docker build -q -t alpaca-lab "$here" >/dev/null
exec docker run --rm --network none \
    -v "$repo":/repo:ro -v "$here":/checks:ro \
    alpaca-lab bash /checks/checks.sh "${1:-all}"
