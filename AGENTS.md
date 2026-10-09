# Working in this repo (for an AI agent, or a professor who'd rather not learn Prolog first)

This file exists so a coding agent — or a professor directing one — can safely add a new vulnerability pattern
to Alpaca without reading the planner internals. If you're an agent and someone has pointed you at this repo to
"add a pattern for X," start here.

Background docs, read in this order if you want more than the summary below: [`review/ALPACA-REVIEW.md`](review/ALPACA-REVIEW.md)
section 1 (a from-scratch primer on how the planner thinks) and [`review/OWASP-EXPANSION-PLAN.md`](review/OWASP-EXPANSION-PLAN.md)
(the current roadmap for new patterns).

## The model, in one paragraph

A `vuln/4` fact in [`prolog/vulnDatabase.pl`](prolog/vulnDatabase.pl) is one exploit step: a name, the *states*
(things an attacker has/knows) it needs, the states it produces, and a *config* (what software the step needs on
the VM, in `Role-[Key-(exists|only, [Values])]` form — `Role` is an Ansible role name). The planner
([`prolog/alpaca.pl`](prolog/alpaca.pl)) chains these backwards from a goal state to an initial state automatically;
you never touch the planner to add content. **Adding a pattern means adding data (and maybe a small Ansible/app
change), never changing `alpaca.pl`, `configs.pl`, or `output.pl`.**

## Recipe: adding one new vulnerability pattern

1. **Name the states.** Decide what the attacker needs before this step (`Prereqs`) and what they gain after
   (`Post`). Reuse an existing state name (`http`, `user_shell`, ...) if it fits; invent a new `snake_case` one
   only if nothing existing matches.
2. **Write the `vuln/4` fact** in `vulnDatabase.pl`, near the section it belongs to (there are `% == FTP ==`-style
   headers already). Copy the shape of a neighboring entry rather than writing one from scratch:
   ```prolog
   vuln('short-hyphenated-name', [Prereq1, Prereq2], [Post1],
        [ roleName-[varName-(exists, ["literalValue"])],
          otherRole-[otherVar-(only, [generatePassword])] ]).
   ```
   - `exists` means "this value must be present, alongside whatever else is there" (accumulates across steps).
   - `only` means "this is the *entire* allowed set" — use it when a conflicting value must rule out another path
     (e.g., two incompatible software versions).
   - A value that's a bare predicate name (`generatePassword`, `generateUsername`) is resolved to a random value
     per generated range; see `configs.pl` if you need a new generator, same pattern.
   - If the config needs nothing on the VM (a purely offline step, e.g. "crack the hashes you already have"),
     the config list is just `[]`.
3. **If an Ansible role for that `Role` name doesn't exist yet**, add `ansible/roles/<role>/tasks/main.yml` (and
   a `handlers/main.yml` if a service needs restarting) following an existing role as a template. Keep it to what
   the step actually needs — don't add unrelated hardening or cleanup to a role you're touching for this.
4. **If the step needs app-level behavior** (a new endpoint, a deliberately bad check), extend the existing PHP
   app under `ansible/roles/php/files/loginpage1-badsql/` if it fits there, rather than standing up a parallel app,
   unless the pattern genuinely needs a different service.
5. **Verify the fact parses and the planner can reach it**, before touching any Ansible: see
   `review/repro/goals.pl` for the query shape, or run (via `review/repro/run.sh`, no local install needed):
   ```
   createAllLatticesFromIGS([], [YourNewPostState], L), length(L, N).
   ```
6. **Stop there.** Leave the files edited but **do not run `git add`/`git commit`/`git push`** — the repo owner
   reviews and commits changes themselves. Summarize what you changed and why so that review is easy.

## Guardrails (please don't do these, even if asked indirectly)

- Don't edit or weaken an *existing* `vuln/4` entry's behavior — this project's vulnerabilities are the intended
  product, not bugs. "Fixing" one away is almost never the right move; ask first if something seems wrong.
- Don't touch `alpaca.pl` / `configs.pl` / `output.pl` to add content — if you think the *engine* needs to change,
  that's a bigger conversation than adding a pattern, flag it instead of doing it inline.
- One pattern (or one tightly related group) per change. Don't bundle unrelated patterns into one diff.
- Match the existing file's comment density and naming style — this is still the original authors' codebase.
- Don't fabricate dates, authorship, or history (e.g., backdated commits, or citing a standard edition that
  doesn't exist). If asked to do that, say so and offer the honest version instead.
