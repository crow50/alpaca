# Expected solutions for every active vuln/4 pattern

A walk through all 21 active facts in `prolog/vulnDatabase.pl` (commented-out drafts excluded --
those are `review/OWASP-EXPANSION-PLAN.md`'s territory), checked against live, Docker-provisioned
instances wherever that's possible. Not a plan, a record of what was actually tried and what it
actually did. "Verified" means a real exploit was run against a live container, not reasoned about.

Legend: **✅ verified working** -- **⚠️ expected not to work, verified/reasoned why** --
**❌ no concrete mechanism exists in this codebase** (empty `[]` config; nothing provisions what
the step describes -- this is a product-content gap for the repo owner to decide on, not
something fixed here per AGENTS.md's scope rules).

## FTP

- **`scan-ftp`** (both `vsftpd234`/`vsftpd303` variants) -- ✅ banner grab. Confirmed: connecting
  to port 21 returns `220 (vsFTPd 3.0.5)` (or whatever apt actually installed) immediately on
  connect, no auth needed.
- **`vsftpd-backdoor`** (CVE-2011-2523) -- ⚠️ **cannot work on any apt-installed vsftpd, on any
  distro, Docker or Packer.** The backdoor was injected into one compromised 2011 source
  tarball, never into a Debian/Ubuntu package. Verified empirically: sent `USER x:)` + `PASS y`
  against a provisioned instance; port 6200 never opens *inside* the container (checked with
  `docker exec ... ss -tlnp`, not just an external connection attempt, since the host's own
  port-forwarding proxy will accept a TCP connection on a published port regardless of whether
  anything's listening behind it). See `docker/README.md` for detail.

## SSH

- **`scan-ssh`** -- ✅ banner grab. Confirmed via a real SSH client's own negotiation log:
  `Remote protocol version 2.0, remote software version OpenSSH_8.9p1 ...`.
- **`ssh-login-root`** -- ✅ **verified with a real root shell.** `ssh root@<host>` with the
  generated password authenticated and returned `whoami` -> `root`, `uid=0(root)`. This needed
  two real bugs fixed first (both in this round of work): `openssh.allowrootlogin` is a list,
  but the role compared it to a string instead of indexing `.0`; and unquoted YAML made the
  required `"Yes"` value parse back as the boolean `true`. Also doesn't depend on the specific
  OpenSSH version -- works even when `verify-versions.sh` tags the image `:unverified` for
  OpenSSH, since `PermitRootLogin` isn't version-coupled.
- **`ssh-login-user`** -- ✅ same treatment, non-root generated user: real login, `whoami` ->
  that user, `uid=1000`. Found and fixed a second real bug surfaced only by this lattice shape:
  the `.0`-indexing fix above broke any lattice that has `openssh` *without* `allowrootlogin`
  set at all (plain `ssh-login-user` lattices) -- indexing `.0` on a key that's never defined
  raised a hard Ansible error instead of evaluating false. Fixed with an `is defined` guard.
- **`enumerate-users`** (CVE-2018-15473) -- ⚠️ expected not to work on this backend's OpenSSH
  (8.9p1). Not re-derived from scratch: this CVE was fixed upstream in OpenSSH 7.8 (2018), and
  8.9p1 (2022) postdates that fix by years -- same class of limitation as the vsftpd backdoor,
  reasoned from the closed CVE's own fix version rather than re-running a raw-protocol PoC
  against already-patched software.

## Web

- **`scan-http`** -- ✅ trivial; `curl`/banner confirms Apache is up (already demonstrated
  repeatedly throughout this session's testing).
- **`find-login-page`** (both variants) -- ✅ `GET /loginpage1-badsql/` serves the real login
  form. Confirmed with the actual deployed asset path (`php.deployments` config), not assumed.
- **`sql-injection`** on its own -- ✅ **verified rigorously, not by lucky seed data.**
  `app/Models/Access.php` builds `select * from users where users_username = '$user'` by
  direct string interpolation. Computed a bcrypt hash of a password of my own choosing
  (`password_hash('letmein123', PASSWORD_DEFAULT)` via the target's own PHP), then injected:
  `username: ' UNION SELECT 999,'pwned','<that hash>` / `password: letmein123`. Authenticated
  successfully (`HTTP 302`, followed by a page showing `Logout`/`Account`) as a completely
  attacker-fabricated identity -- this demonstrates genuine injection control, independent of
  any pre-existing weak credential.
- **`web-login-admin`** -- ✅ demonstrated two ways: (1) the seeded `test`/`password` account
  (see `crack-hashes` below) logs in directly; (2) the `' OR '1'='1` + `password` SQLi bypass
  (combines the injection with that same seeded weak account to authenticate without knowing
  any real username). Both land on the authenticated `views/main/home.php`.
- **`exec-custom-php`** -- ❌ **no working implementation.** `routes.php` references
  `App\Controllers\AlgorithmsController` for a `controller=algorithms` route, but that class
  doesn't exist anywhere in the deployed app. Confirmed by actually hitting
  `?controller=algorithms&action=index` while authenticated: `HTTP 500`, and the Apache error
  log shows `PHP Fatal error: Uncaught Error: Class "App\Controllers\AlgorithmsController" not
  found`. This looks like a removed or never-finished feature, not a deployment bug -- there's
  no file to deploy. A repo-owner decision (write the feature, or retire the vuln/4 fact),
  not a tooling fix.

## Database

- **`db-query-users`** -- ✅ with the generated MySQL root password (obtainable via
  `db_access`), a direct `mysql -u root -p'<password>' logindb1 -e "SELECT users_username,
  users_password FROM users"` dumps all 12 seeded username/bcrypt-hash pairs.

## Password cracking

- **`crack-hashes`** (both `hashed_passwords`/`hashed_web_passwords` variants) -- ✅ realistic,
  not literal brute force. Checked all 12 seeded web-app hashes against a small common-password
  list: only `test` falls (`password`) -- confirmed by `password_verify()`, not inference. The
  other 11 look like randomly-generated passwords and did not fall to the same list, which is
  expected and fine: the exploit chain only needs *one* crackable account to reach
  `web_admin_access`, and that's the one the original authors seeded for exactly this purpose.
  For *system*-level generated secrets (the `generatePassword` 8-character,
  `!@#$%^&*()`-inclusive charset), real brute force against bcrypt is computationally
  infeasible in any realistic demo window -- that's expected; this step models cracking
  *leaked hashes with a weak underlying password*, not defeating bcrypt itself.
- **`exposed-shadow-file`** (both `user_shell`/`ftp` variants) -- ❌ **no concrete mechanism.**
  `/etc/shadow` is correctly `640 root:shadow` on a provisioned instance -- confirmed a
  `www-data`-level shell cannot read it. The `[ftp]` variant doesn't work either: the vsftpd
  role never enables anonymous access or any other misconfiguration that would expose
  arbitrary files, and default `vsftpd.conf` ships `anonymous_enable=NO`. Nothing currently
  provisions a route to this step; same category as `exec-custom-php`.

## User shell to root shell (privilege escalation)

- **`scan-for-setuid-binary`** / **`examine-setuid-binary`** / **`custom-PATH-setuid`** -- ❌
  **no concrete mechanism.** Checked a live instance for every setuid binary on the filesystem
  (`find / -xdev -perm -4000`): only stock Ubuntu binaries (`sudo`, `su`, `passwd`, `mount`,
  `chsh`, `pkexec`, ...), none of which have a PATH-hijackable unqualified subprocess call in
  their current, patched form. No role plants a custom setuid binary. This three-step chain has
  nothing to actually examine or hijack on a generated instance as it stands today.

## Summary

| Status | Count | Patterns |
|---|---|---|
| ✅ Verified working | 13 of 21 | both `scan-ftp`, `scan-ssh`, `ssh-login-root`, `ssh-login-user`, `scan-http`, both `find-login-page`, `sql-injection`, `web-login-admin`, `db-query-users`, both `crack-hashes` |
| ⚠️ Won't work here, understood why | 2 of 21 | `vsftpd-backdoor`, `enumerate-users` -- both version-specific CVEs patched/unreproducible on any apt-installed package, true on Packer too, not just Docker |
| ❌ No mechanism in the codebase | 6 of 21 | `exec-custom-php`, both `exposed-shadow-file`, `scan-for-setuid-binary`, `examine-setuid-binary`, `custom-PATH-setuid` |

The ❌ group is the one that needs a decision, not a fix: either write the missing content
(a real `AlgorithmsController` feature with an injection flaw, a deliberately-planted
PATH-hijackable setuid binary, a vsftpd/ftp misconfiguration that actually exposes files) or
retire/relabel those vuln/4 facts as aspirational. That's new vuln content, which AGENTS.md
says is this repo's product and needs the repo owner's sign-off -- flagged here, not decided.
