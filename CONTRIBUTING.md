# Contributing

This is a fork of the original Stetson Math/CS `alpaca` project, with the eventual goal of
upstreaming improvements. A few things that matters here more than in a typical repo:

- **Topic branches, no history rewrites.** Don't force-push, rebase-and-squash someone else's
  commits, or otherwise rewrite history that isn't yours -- the original authors' `git blame`
  is part of what this project is trying to preserve.
- **One pattern (or one tightly related group) per change.** Don't bundle unrelated fixes,
  especially not alongside a new vulnerability pattern. See [`AGENTS.md`](AGENTS.md) for the
  recipe for adding one.
- **The vulnerabilities in the generated ranges are the product, not bugs.** If something
  about an exploit chain looks "wrong," ask before "fixing" it -- it's almost always
  intentional. Bugs in the *build tooling itself* (a missing file, a role that never loads, a
  dead URL) are fair game.
- **Never fabricate dates, authorship, or history.** If you're not sure what's accurate, say
  so instead of guessing.
- **Archive, don't delete,** material that no longer has a working home (see `legacy/`) --
  unless it's something that shouldn't have been committed in the first place (e.g. a
  credential), which is the one case where removing it from `HEAD` is the right call.

Beyond that: open a PR, explain what you changed and why, and expect questions if the change
touches an existing vulnerability's behavior.
