# Repro kit for `ALPACA-REVIEW.md`

Every "verified" claim in the review can be re-checked with one command. You need Docker; nothing else
(no SWI-Prolog, Ansible, Packer, or Graphviz on your machine).

```bash
review/repro/run.sh            # all checks (~3 minutes; the first run also builds the image)
review/repro/run.sh readme     # or one at a time: env | goals | readme | cli | ansible | yaml | merge | api | undefined
```

| Check | What it shows |
|---|---|
| `goals` | Which lattices each goal produces (the table in section 1.3 of the review) |
| `cli` | The silent-failure table: exit codes, and how much the user is told |
| `readme` | Following the README literally writes the range *outside* the repo and leaves dangling links |
| `ansible` | The `users` role loads zero tasks; the `my.cnf.j2` and `loginpage1.tar.gz` files are missing; root SSH login is never enabled |
| `yaml` | About 8-9% of generated random passwords corrupt the playbook YAML; `Yes` becomes a boolean |
| `merge` | Where the configuration-merge code differs from the rule in the 2019 paper |
| `api` | The HTTP API accepts shell commands in a filename argument (run in a sealed container) |
| `undefined` | Predicates the code calls that don't exist (the broken complexity / required-vulnerability features) |

**Safety:** the repo is mounted read-only, each check works on a throw-away copy in `/tmp` inside the
container, and the container has networking disabled. The `api` check starts the vulnerable server and attacks
it *inside that sealed container* only.

Tested with SWI-Prolog 10.1.16, ansible-core 2.19, Graphviz 2.42 (see `Dockerfile`). The generator itself
(README steps 0 and 1, run from `prolog/`) was also confirmed on Ubuntu 24.04 with `apt install swi-prolog` (9.0.4).

To remove the image afterwards: `docker rmi alpaca-lab` (and `swipl:latest`, the base image it pulls in).

These scripts are deliberately small and independent of the Alpaca code they test. They are a good seed for a
real regression-test suite (see section 3.6 of the review).
