# Expanding past 21: an OWASP Top 10 (2021) map for Alpaca's vulnerability database

> Companion to [`ALPACA-REVIEW.md`](ALPACA-REVIEW.md). Planning only — no repository files are changed by this
> document. Nothing here has been committed; per your instruction, you review and commit everything yourself.

**Goal, as you stated it:** (a) get all 21 original `vuln/4` entries working as described/intended — that's
Phase 1 of the review (B1-B6, C1), unchanged by this plan — and (b) grow past 21 with new exploitation paths,
here scoped to full coverage of the OWASP Top 10. Nothing below touches or weakens an existing exploit; it only adds.

I'm using the **2021** edition (the current official list) since nothing you said pins to 2017; say so if your
course syllabus uses the older numbering and I'll remap.

## Where the 21 already land, and where the authors already sketched more

Three things are true at once here, so the table marks which:

- **Covered** — an existing, active `vuln/4` entry already demonstrates the category.
- **Draft exists** — [`prolog/vulnDatabase.pl`](../prolog/vulnDatabase.pl) already has a `vuln/4` fact for this,
  written by the original authors, but it's **commented out** (and in two cases the Ansible role it needs was
  never built). Reviving these is the lowest-risk way to grow past 21: it's their own authored content, not new
  invention, and it directly serves "make sure the originally-intended paths work."
- **Gap** — nothing exists yet; would need a genuinely new `vuln/4` entry plus something to realize it in the VM.

| OWASP 2021 category | Status | Detail |
|---|---|---|
| A07 Identification & Authentication Failures | **Covered**, + drafts | `ssh-login-root`, `ssh-login-user`, `web-login-admin` already require real credentials. Commented-out variants `ssh-login-root(brute-force)`, `ssh-login(brute-force)`, `web-login-admin(brute-force)` (vulnDatabase.pl, SSH and Web sections) would add genuine *online* brute-forcing instead of "assume the password is known" |
| A03 Injection | **Covered** | `sql-injection` against the `loginpage1-badsql` app (once B2/B3 are fixed) |
| A06 Vulnerable & Outdated Components | Draft exists; also partly covered | `vsftpd-backdoor` (vsftpd 2.3.4) already covers this angle. The commented-out `scan-jboss` / `deserialization-attack` (CVE-2017-12149, Java section) is a second, cleaner example of this category — currently disabled because no `jboss` role exists |
| A08 Software & Data Integrity Failures | Draft exists + gap | That same `deserialization-attack` entry is *also* a textbook A08 (insecure deserialization). A second, web-native example — PHP `unserialize()` on a cookie value — would be a small, self-contained gap-filler |
| A05 Security Misconfiguration | Draft exists + gap | Commented-out `scan-for-root-cronjobs` / `hijack-root-cronjob` (end of vulnDatabase.pl) fits this well. True gaps: exposed `.git`/backup files, directory listing, a default/leftover admin page |
| A02 Cryptographic Failures | Partially covered | `crack-hashes` covers *weak passwords*; nothing yet covers a *weak algorithm* (e.g., an unsalted MD5 table) or a hardcoded secret key — both easy, self-contained gaps |
| A01 Broken Access Control | Gap | Nothing currently bypasses an authorization check directly. A classic IDOR (reading another user's record by changing an id) fits the existing PHP app with a small change |
| A04 Insecure Design | Gap (by nature) | This category is usually *demonstrated*, not exploited directly — e.g., a password-reset flow with no ownership check. Lowest priority; may end up illustrated by A01's IDOR rather than a separate entry |
| A10 Server-Side Request Forgery | Gap | Needs a new feature where the server fetches a user-supplied URL (e.g., "load avatar from URL") that can be pointed at an internal-only service. Self-contained but the most new code of the list |
| A09 Logging & Monitoring Failures | Gap, and an awkward fit | This is an *absence* of a control, not something to exploit step-by-step, so it fits Alpaca's pre/post-condition model poorly. Lowest priority; likely best expressed as a config flag ("no logging enabled") rather than a new `vuln/4` chain |

## Proposed order (smallest, most-authentic changes first)

**Phase A — revive the authors' own drafts.** Uncomment and complete `ssh-login-root(brute-force)`,
`ssh-login(brute-force)`, `web-login-admin(brute-force)`, `scan-for-root-cronjobs`/`hijack-root-cronjob`, and
`scan-jboss`/`deserialization-attack`. The `vuln/4` logic is already theirs; the work is building the one or two
small Ansible roles they never got to (a `cron` role; a minimal `jboss` role for the CVE-2017-12149 case). This
single phase covers A05, A06, A07 (reinforced), and A08 — four of the ten categories — using entirely the original
authors' own content.

**Phase B — fill the remaining gaps, one category at a time:**
1. A01 Broken Access Control (IDOR on the existing login app) — smallest gap-filler.
2. A02 Cryptographic Failures (a second, unsalted-MD5 credential store) — smallest gap-filler.
3. A10 SSRF (fetch-from-URL feature) — more new code, still self-contained.
4. A04 / A09 — revisit once A01 and the rest exist; both may end up riding on other entries rather than needing
   their own chain.

Each numbered item above would be one small PR: one or two `vuln/4` facts, the Ansible/app change to realize
them, and nothing else touched. I'd build and show you one at a time rather than all ten at once, consistent with
keeping changes small and reviewable.

## What this does *not* touch

No existing `vuln/4` entry, Ansible role, or app file is modified by this plan — only additions. The Phase 1
bug-fixes (making the current 21 actually build) are independent of this and don't block it either way.
