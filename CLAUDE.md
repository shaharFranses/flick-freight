# Flick Freight: how we work

A Godot 4.3 game, exported for the web and published on GitHub Pages.

## Where things are published

- `main` is the live game, published at the site root. A push or merge to `main`
  deploys to players right away.
- `staging` is the test build, published under `/staging/` on the same site. Use it
  to try changes on a phone or share them before they go live.
- `.github/workflows/pages.yml` builds both. A push to `staging` triggers
  `staging-push.yml`, which then triggers the Pages rebuild.

## Branch rules

1. **Never push to `main` and never merge into it.** Not directly, and not by
   merging a PR, unless the user explicitly says to ship that change to main.
   Words like "push", "deploy", "publish" or "let me test it" mean staging, not main.
2. Do the work on your own feature branch (the `claude/...` branch the session gives
   you, or a new descriptive one).
3. To let the user test a change, merge the feature branch into `staging` and push
   `staging`. Tell the user that `/staging/` rebuilds in a few minutes.
4. If `staging` is behind `main`, merge `main` into `staging` first, so the test
   build includes everything that's already live.
5. When the user approves a change on staging, open a PR into `main` (from the
   feature branch, or from `staging` if the user asks for everything on staging).
   Leave the merge to the user.
6. Don't force-push `main` or `staging`.

## Checks before pushing

CI (`.github/workflows/bot.yml`) runs on every branch except `main`. It covers the
layout checks, cab tests, frozen data for levels 1-40, parity, the save test, the
bot playing every level, replay determinism, performance, and the web export.
If a level or a physics file changes, run the matching script in `tools/` locally
when you can (for example `godot --headless -s res://tools/layout_check.gd`).
Never skip or disable a check to make CI pass.
