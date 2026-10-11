# Throw-away lab image used to verify the findings in ../ALPACA-REVIEW.md.
# Tested with: SWI-Prolog 10.1.16, ansible-core 2.19, Graphviz 2.42, Zip 3.0, PyYAML 6.0 (Debian "trixie" base).
# Nothing here is needed to *use* Alpaca on your own machine -- it only makes the checks repeatable.
# Pinned by digest, not :latest -- a floating tag drifted out from under this exact image during
# this round of changes, which is the whole reason to pin.
FROM swipl@sha256:7c5f436905b725ced323818c96b07b1e971fe52dbcc25de91b9332cb20f98615

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        zip unzip graphviz python3 python3-yaml ansible git ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
