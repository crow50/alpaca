# Alpaca: Building Dynamic Cyber Ranges with Procedurally-Generated Vulnerability Lattices

<img align="right" src="logo.png">

*(This fork, informally "alpaca-docker," adds a containerized provisioning backend alongside
the original VirtualBox/Packer pipeline, plus the usability fixes below. See
[`AGENTS.md`](AGENTS.md) if you're adding a vulnerability pattern, or
[`CONTRIBUTING.md`](CONTRIBUTING.md) for everything else.)*

## Publications

- J. Eckroth, K. Chen, H. Gatewood, B. Belna. "Alpaca: Building Dynamic Cyber Ranges with Procedurally-Generated Vulnerability Lattices," Proceedings of the Annual ACM Southeast Conference, 2019. [PDF](publications/acmse-2019-alpaca.pdf)

## Two ways to run it

1. **Packer + VirtualBox** (original) -- builds a real VM, ~20-25 minutes.
   [`packer/README.md`](packer/README.md).
2. **Docker** (new) -- provisions a container with the exact same, unmodified
   `ansible/roles/`, in a couple of minutes the first time and about a second to reset after
   that. No VirtualBox needed (handy under WSL2, where VirtualBox can't run at all). One
   caveat: a few exploit steps are pinned to a specific vulnerable package version, and this
   path's base image isn't guaranteed to reproduce all of them -- see
   [`docker/README.md`](docker/README.md) for exactly which ones are currently verified.

## Quickstart

```
make doctor                              # see what's installed and what's missing for each path above
make graph                               # Step 0 below
make range GOAL='[root_shell]'           # Step 1 below
make docker-range GOAL='[web_admin_access]'  # Steps 1+2 (Docker path) in one shot --
                                              # generates, provisions, bakes, and prints
                                              # exactly which host port to attack
```

## Requirements

**Core** (either path):
- [SWI-Prolog](http://www.swi-prolog.org/) -- tested with 10.1.16, works down to 9.0.4.
  On Debian/Ubuntu, install the **`swi-prolog`** package, not `swi-prolog-core` -- the
  latter is missing `library(uuid)` and `library(http/json)`, which this project needs.
- [Graphviz](https://www.graphviz.org/) (`dot`)
- `zip`

**Packer/VirtualBox path, additionally:**
- [Packer](https://packer.io/) 1.16.x + its `virtualbox` and `ansible` plugins (`packer init`
  installs these automatically)
- [VirtualBox](https://www.virtualbox.org/)
- [Ansible](https://www.ansible.com/) (`ansible-core` 2.19+) with the `community.mysql`
  collection (bundled with the full `ansible` package)
- Python's `passlib` (the `users` role hashes passwords with it)

**Docker path, additionally:**
- [Docker](https://www.docker.com/) -- that's it; `docker/control.Dockerfile` carries
  everything else (Ansible, `community.docker`, `community.mysql`) in a built image.

Run `make doctor` to check all of the above at once.

## Running Alpaca

### Step 0 (optional): Visualize the vulnerabilities

Generate an image of the vulnerabilities defined in the system:

<pre>
$ swipl prolog/main.pl graphAllVulns vulns.dot
$ open vulns.dot.png
</pre>

Or: `make graph`.

### Step 1: Generate range configuration files

In order to build a range, one must first find/generate lattices and create Packer and Ansible files. The first `[...]` argument is the starting state, the second argument is the goal state, and the third is any required parameters.

<pre>
$ swipl prolog/main.pl createRangeFromIGS '[]' '[root_shell]' '[paramPasswordLength-5]'
</pre>

Or,

<pre>
$ swipl prolog/main.pl createRangeFromIGS '[db_access]' '[root_shell]' '[paramPasswordLength-5]'
</pre>

Or: `make range GOAL='[root_shell]'` (defaults `INIT` to `[]` and `PARAMS` to
`[paramPasswordLength-8]`; override either if you need to).

The system will generate a subfolder and set of files in the `ranges/` folder. The generated range will have a unique ID that is reported by the system. A ZIP file will contain all the range configuration files.

Information about the range and its lattices are found in the `range_metadata.json` file and the lattice subfolders.

### Step 2: Generate a virtual machine for a lattice in the range

Switch to a specific lattice in a range:

<pre>
$ cd ranges/64374c93-697f-46eb-9f3f-58cf6c48e676/e38d2277-6f1d-4b22-a9aa-c93781da1c39/
</pre>

Then run the Packer script:

<pre>
$ bash run_packer.sh
</pre>

Or: `make build LATTICE=ranges/<range-id>/<lattice-id>`.

Or, build it into a Docker container instead of a VM -- no VirtualBox required, and resettable
to a fresh instance in about a second once baked. See [`docker/README.md`](docker/README.md),
or run `make docker-provision LATTICE=ranges/<range-id>/<lattice-id>` (or
`make docker-range GOAL='[web_admin_access]'` to generate and provision in one step).

## Adding a vulnerability

See [`AGENTS.md`](AGENTS.md) -- it's written as a self-contained recipe (for a person or an
agent) and isn't duplicated here.

## Does each vulnerability actually work?

See [`review/EXPECTED-SOLUTIONS.md`](review/EXPECTED-SOLUTIONS.md) -- a walkthrough of all 21
active patterns, checked against live instances: 13 verified working with the actual exploit
steps, 2 that can't work on any current package (version-specific CVEs, patched upstream), and
6 with no concrete mechanism in the codebase yet (empty-config steps nothing currently
provisions).

## Running this safely

The generated VMs/containers are *deliberately* vulnerable. Build and run them on a host-only
or otherwise isolated network, and don't hand out a range's ZIP or `range_metadata.json` to
anyone who shouldn't see its (randomly generated, but still real) credentials.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License / Acknowledgments

Apache 2.0 -- see [`LICENSE`](LICENSE). Original authors: J. Eckroth, K. Chen, H. Gatewood,
B. Belna, and the other contributors in `git log`. Maintainers and contributors to this fork
are tracked the same way, in `git log` on this branch.
