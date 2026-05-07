---
name: local-macos-fork-refresh
description: "Use when refreshing, rebasing, rebuilding, installing, or publishing the local STFC macOS integration branch (`wycats/local-play-macos`) or maintaining the fork stack against upstream `origin/dev`."
---

# Local macOS Fork Refresh

Use this workflow for the personal macOS integration branch in `wycats/stfc-mod`.

## Branch model

- `origin/dev` is the upstream development base.
- `wycats/local-play-macos` is the personal integration branch for local play builds.
- `wycats/local-play-macos` on the fork is a backup/continuity branch, not an upstream PR branch.
- Upstream PRs should use narrow topic branches, not the integration branch.

## Regular refresh

Run the script from the repository root:

```bash
scripts/local-macos-refresh.sh --install
```

The script fetches, rebases onto `origin/dev`, builds release, installs only when `--install` is passed, verifies code signing, compares bundle hashes, and never pushes.

Useful variants:

```bash
scripts/local-macos-refresh.sh
scripts/local-macos-refresh.sh --no-fetch --no-rebase
scripts/local-macos-refresh.sh --mode releasedbg --install
scripts/local-macos-refresh.sh --dry-run --install
```

## Rebase discipline

The branch is maintained by rebase, not merge:

```bash
git switch wycats/local-play-macos
git fetch origin dev
git rebase origin/dev
git log --oneline --decorate origin/dev..HEAD
```

When upstream merges a topic already in the integration branch, rebase and drop the now-upstream commits. The goal is for `origin/dev..HEAD` to show only local work that still matters.

## Publishing the integration branch

Publishing is optional. Use it for backup/continuity after a known-good rebase/build:

```bash
git push -u wycats HEAD:refs/heads/wycats/local-play-macos
```

After future rebases:

```bash
git push --force-with-lease wycats HEAD:refs/heads/wycats/local-play-macos
```

Never use plain `--force`. Never push this branch to `origin`.

## Safety checks

Before real refresh/build/install:

- Confirm current branch is `wycats/local-play-macos`.
- Confirm no tracked/staged changes are present.
- Leave unrelated untracked local artifacts alone.
- Do not include `.logs/`, `.static-export/`, raw captures, or generated static tables in commits.
- Abort install if the game, launcher, or loader is running.

## Reporting

When done, report:

- branch name
- upstream base SHA
- integration branch HEAD SHA
- whether install happened
- app path
- code signing status
- source/installed bundle hashes if installed
- remaining untracked files

For details, read `docs/FORK_MAINTENANCE.md` and use `scripts/local-macos-refresh.sh` as the source of truth.
