# Docker backend

An alternative to `packer/` for turning a generated lattice into something you can actually
log into and attack. Same unmodified `ansible/roles/`, same generated `playbook.yml` -- just
pointed at a container instead of a VirtualBox VM, via Ansible's `community.docker` connection
plugin instead of SSH. See [`../review/DOCKER-PORT-PLAN.md`](../review/DOCKER-PORT-PLAN.md) for
the original proof-of-concept this was built from.

**This does not replace Packer/VirtualBox** -- that path is untouched and still the one to use
if you need a real VM (e.g. to test something container escapes would make unrealistic). This
is for the common case: standing up a lattice quickly, resetting it instantly between students,
and not needing VirtualBox at all (handy if your own machine can't run it, e.g. under WSL2).

## Prerequisites

Just Docker. Ansible, its collections, and everything else needed to provision a target live
inside `control.Dockerfile`, built automatically the first time you run this.

## Usage

One command (generates a range, provisions it, bakes the image):

```
docker/generate-and-provision.sh '[web_admin_access]'
# or: make docker-range GOAL='[web_admin_access]'
```

Or the two steps separately, if you already have a generated lattice:

```
swipl prolog/main.pl createRangeFromIGS '[]' '[web_admin_access]' '[paramPasswordLength-8]'
docker/provision-and-bake.sh ranges/<range-id>/<lattice-id>
# or: make docker-provision LATTICE=ranges/<range-id>/<lattice-id>
```

Either way, this builds the control image (cached after the first run), starts a target
container, waits for it to boot, **publishes a host port for each "front door" service the
lattice actually uses** (apache/vsftpd/openssh -- see below), provisions it with the lattice's
own `ansible/roles/`, verifies package versions where that matters (further below), and bakes
the result into an image:

```
Baked: alpaca-lattice-<lattice-id>:verified

Reachable at (give it ~10s after starting for systemd and the services to finish coming up):
  HTTP (apache) -> localhost:8080

Reset for a new instance (~1s to reset, then ~10s for services to be reachable):
  docker rm -f <name>
  docker run -d --name <name> --tmpfs /tmp --tmpfs /run --tmpfs /run/lock \
      -v /sys/fs/cgroup:/sys/fs/cgroup:rw --cgroupns=host -p 8080:80 \
      alpaca-lattice-<lattice-id>:verified /lib/systemd/systemd
```

Confirmed from the host (not just `docker exec`): `curl http://localhost:8080/loginpage1-badsql/`
returns the real, live, vulnerable login page. The published ports are fixed per service
(apache -> 8080, vsftpd -> 2121, openssh -> 2222) rather than randomly assigned, so you don't
need to look anything up to connect -- the tradeoff is that running two lattices that both use
the same service at once will conflict on that port; running multiple students at once from
one host is the fleet script's job (below), not this script's.

First run (cold, nothing cached yet) takes a few minutes -- mostly a one-time `apt-get update`
on the target (see below). Resetting a baked image to a fresh instance measured **~1.6s** in
testing (the proof-of-concept's own run measured ~1.1s) -- that gap is the entire point: bake
once per lattice, ahead of class if you like, then give each student a fresh reset in about a
second instead of a ~25 minute Packer/VirtualBox build.

## The version-verification gate

Some exploit steps are pinned to a specific vulnerable package version (`vsftpd` 2.3.4/3.0.3,
OpenSSH 7.6p1) that the Ansible roles install generically (`apt: state=present`) -- the actual
version installed depends on whatever the base image's package snapshot carries, not an
explicit pin anywhere in this repo. The Packer path's Ubuntu 18.04 base is known to still carry
the right versions; this path's base image is Ubuntu 22.04, which is not guaranteed to.

So after provisioning, `verify-versions.sh` checks the *actual installed* version against what
the lattice's config requires, for any role where that's version-coupled, and the baked image
gets tagged accordingly:

- `:verified` -- either nothing version-coupled was involved, or everything that was matched.
- `:unverified` -- provisioning still succeeded and the image is still usable, but don't present
  a version-coupled step (e.g. the vsftpd backdoor, or SSH root-enable) as working on this
  specific image; the printed output says exactly which step(s) to avoid.

See [`../review/EXPECTED-SOLUTIONS.md`](../review/EXPECTED-SOLUTIONS.md) for the full
pattern-by-pattern verification status (all 21 active `vuln/4` facts, not just the ones below).

**Current scope**: apache/php/mysql-based lattices (flagship: `web_admin_access`) are the
launched, Docker-verified set -- confirmed end-to-end, including the actual vulnerable login
page serving correctly (real SQL injection against `app/Models/Access.php`, verified with raw
POSTs: `' OR '1'='1` as username + the seeded `test`/`password` credential logs in).

vsftpd/OpenSSH-version-coupled lattices provision successfully (both roles now install their
own package -- see below) but come back `:unverified`, confirmed: Ubuntu 22.04 apt gives
vsftpd `3.0.5-0ubuntu1.1` and OpenSSH `8.9p1`, not the `2.3.4`/`7.6p1` these lattices need.
For OpenSSH 7.6p1 that's "an older apt snapshot would probably fix it" -- a real open follow-up.
**For the vsftpd 2.3.4 backdoor (CVE-2011-2523) specifically, that framing doesn't apply**: the
backdoor was injected into one compromised 2011 source tarball, never into any Debian/Ubuntu
package, on any Ubuntu version, ever -- there is no apt snapshot, old or new, that would give
you the actual backdoored binary. Confirmed empirically, not just by version number: against a
provisioned instance, sending `USER x:)` + `PASS y` over FTP does not open the 6200 backdoor
shell (verified from inside the container, since the host's own port-forwarding proxy will
accept a TCP connection on a published port regardless of whether anything's listening behind
it -- checking from outside alone would have been a false positive). Getting this specific step
genuinely working would mean sourcing the actual historical compromised tarball out-of-band;
that's a deliberate content decision for the repo owner, not a build-tooling fix, and is exactly
as true on the Packer/VirtualBox path as it is here.

**`:unverified` doesn't mean "nothing in this lattice works" -- it's per-role, not per-step.**
`ssh-login-root` (`PermitRootLogin yes` + the generated root password) doesn't actually depend
on the specific OpenSSH version at all -- unlike `scan-ssh`'s user-enumeration step, which
genuinely needs 7.6p1 for its timing behavior. Confirmed with a real login, not a dry-run: on
a lattice that came back `:unverified` (OpenSSH `8.9p1` installed, `7.6p1` required), `ssh -p
2222 root@localhost` with the generated password authenticated and returned a real root shell
(`whoami` -> `root`, `uid=0(root)`). If you're checking whether a *specific* step works, test
that step directly rather than trusting the lattice-level tag alone. Same story for
`ssh-login-user`: logged in as a generated non-root user on an `:unverified` image and got a
real shell (`whoami` -> that user, `uid=1000`).

## Known characteristics of this path (not bugs)

- **`openssh-server` is pre-installed by `provision-and-bake.sh` when a lattice uses the
  `openssh` role.** `ansible/roles/openssh/tasks/main.yml` only ever configures `sshd`
  (`PermitRootLogin`) -- it has no install task, because on the Packer path
  `packer/http/preseed.cfg` already installs `openssh-server` as part of the base VM image,
  before Ansible ever runs. This target has no equivalent preseed step, so without this it
  fails with `Destination /etc/ssh/sshd_config does not exist`. Fixed in the script, not the
  shared role, per this feature's "don't rewrite the roles" design (see top of this file).
- **Occasionally, a run fails partway with `Module result deserialization failed` / `rc=137`**
  on a machine that's under memory pressure -- `rc=137` means a module got SIGKILLed, almost
  always the OOM killer. Showed up intermittently after extended, heavy, concurrent Docker use
  on one test machine, not on a clean run. If a run fails this way, check memory headroom and
  just retry -- the script always cleans up its own target container on exit now (success or
  failure), so a retry won't collide with the previous attempt's container or port.
  (An earlier version of this note also blamed a MySQL "Access denied" failure on the import
  task on memory pressure -- that one turned out to be a real, deterministic bug, not a
  resource flake: see the next bullet.)
- **`ansible/roles/mysql/templates/my.cnf.j2` quotes the root password.** The generator's
  charset (`prolog/configs.pl`) includes `#`, which MySQL's `.cnf` file format treats as a
  comment starter -- an unquoted `password={{ mysql.root.0 }}` silently truncated any
  generated password at its first `#`, so `~/.my.cnf` held the wrong password and the very
  next task (`Import MySQL databases`) failed with "Access denied... (using password: YES)".
  This wasn't rare: with this password charset, any given password has roughly a 1-in-6 chance
  of containing at least one `#`. Confirmed by reproducing it, inspecting the live container's
  `mysql.user` table and the literal bytes Ansible wrote to `.my.cnf`, and fixing it with a
  quoted `password="{{ mysql.root.0 }}"`. This affects every path that reads this template, not
  just Docker -- the same fix applies on the Packer/VirtualBox VM.
  (`geerlingguy/docker-ubuntu2204-ansible`) ships a `policy-rc.d` that blocks the
  package-manager's own auto-start hooks, which is normal for Ansible-testing images --
  automated provisioning wants services started deterministically by the playbook, not raced by
  dpkg. Every role here already has its own explicit `service: state=started` (or a notify
  handler), which calls `systemctl` directly and isn't affected by this. Nothing to do here.
- **The first `apt-get update` on a fresh target can be slow, and on some rootless-Docker/WSL2
  networks will hang rather than fail** if DNS returns only AAAA records for a mirror whose
  IPv6 path isn't actually routed in that setup. `provision-and-bake.sh` forces apt onto IPv4
  before touching the network, which resolved this in testing. If you see a hang anyway, that's
  the first thing to check.
- **The control container reaches your Docker daemon through whatever socket your current
  `docker context` points at** (rootful or rootless), detected automatically. It does not start
  a nested Docker daemon of its own.

## Not in this phase

A fleet script (generate + bake one image per student from a class roster), an instructor
dashboard, connection/command logging, and a flag system are all natural next steps, listed but
intentionally not started in `DOCKER-PORT-PLAN.md` -- this phase is the provisioning mechanism
they'd be built on, not those tools themselves.
