# legacy/

Material from the original Stetson Math/CS `alpaca` project that no longer has a working home in the active
codebase, archived here rather than deleted (see `AGENTS.md`). Each subdirectory mirrors where its contents used
to live, so `git log --follow` still finds the history.

- `docs/` — design notes for components no longer present in the repo (a web dashboard, a report generator, a
  JDBC-based database layer, a devops/HTTP-API deployment doc, an older algorithms writeup).
- `prolog/cliques.pl` — not loaded by `alpaca.pl`; superseded by the current planner.
- `scripts/` — one-off QA/test scripts. `apples.sh`/`qaTest.sh`/`qaExpect.sh`/`expectDatabase.sh`/
  `test_website.sh`/`final_jenkins_pipeline`/`httpd.log` are course scratch work with hardcoded paths.
  `alpaca_tests.pl`/`simple_tests.pl` are an earlier test suite: the former references predicates
  (`allPossiblePaths`, `createAllPaths`) that no longer exist anywhere in `prolog/`, and both depend on
  `library(test_cover)`, which no longer exists in current SWI-Prolog. Superseded by `prolog/alpaca_tests.pl`.
- `Vagrantfile` (originally at the repo root) — referenced `ansible/playbook.yml` and `ansible/inventories/dev`,
  neither of which exists in this repo; used an Ubuntu 14.04 box.

`scripts/testDatabase.sh` was removed rather than archived here, since it hardcoded a credential — see git
history if you need it.
