# Fork Maintenance for Local macOS Builds

This is the personal maintenance flow for keeping a macOS integration branch current with upstream `dev`, rebuilding the launcher bundle, and optionally installing it for local play.

## Branch roles

- `origin/dev` is upstream development from `netniv/stfc-mod`. Treat it as the rebase base.
- `wycats/local-play-macos` is the local integration branch used for personal macOS changes.
- `wycats/local-play-macos` on the fork is a backup/continuity branch for this local integration stack. Do not open it as an upstream PR.
- `wycats` is the fork remote. Push only when you intentionally want to publish branch changes.

The refresh script never pushes. It fetches the base branch, rebases the local branch, builds a release app, verifies code signing, prints bundle hashes, and installs only when `--install` is passed.

## Rebase model

The integration branch is rebuilt by rebasing, not merging. This keeps the local stack readable and makes it obvious which commits still differ from upstream `dev`.

Regular refresh flow:

```bash
git switch wycats/local-play-macos
git fetch origin dev
git rebase origin/dev
```

After a successful rebase, inspect the remaining local stack:

```bash
git log --oneline --decorate origin/dev..HEAD
```

When an upstream PR lands, rebase again and drop any local commits that are now upstream. The goal is for `origin/dev..HEAD` to contain only work still needed for local play.

If the integration branch is published to the fork, update it only after the rebase is known-good:

```bash
git push --force-with-lease wycats HEAD:refs/heads/wycats/local-play-macos
```

Never use plain `--force`. Never push this branch to `origin`.

## Topic branches vs integration branch

Use narrow topic branches for upstream PRs. Keep `wycats/local-play-macos` as the personal stack that combines topic branches plus local-only work.

When a topic branch changes:

1. Update the topic branch first.
2. Re-apply or rebase the integration branch so it contains the updated topic work.
3. Rebuild from the integration branch only after the stack is coherent.

When a topic branch merges upstream:

1. Fetch `origin/dev`.
2. Rebase `wycats/local-play-macos` onto it.
3. Drop the now-upstream commits during the rebase if Git does not do it automatically.
4. Confirm `git log --oneline origin/dev..HEAD` no longer contains the merged topic commits.

## Daily refresh

From the repository root:

```bash
scripts/local-macos-refresh.sh --install
```

Default settings:

- branch: `wycats/local-play-macos`
- base: `origin/dev`
- mode: `release`
- arch: native (`arm64` or `x86_64`; `universal` can be passed explicitly)
- install target: `/Applications/STFC Community Mod.app`

Use build-only mode when you want to verify the branch without touching `/Applications`:

```bash
scripts/local-macos-refresh.sh
```

Useful variants:

```bash
scripts/local-macos-refresh.sh --no-fetch --no-rebase
scripts/local-macos-refresh.sh --mode releasedbg --install
scripts/local-macos-refresh.sh --no-fetch --no-rebase --no-install --dry-run
scripts/local-macos-refresh.sh --dry-run --install
```

The script handles the fetch/rebase/build/install path for routine refreshes. Use manual `git rebase -i origin/dev` when you need to drop or reorder commits after upstream has absorbed part of the stack.

## Safety rules

The script is intentionally conservative:

- It only runs on macOS.
- It expects to run from `wycats/local-play-macos` unless `--branch` is provided.
- It aborts if tracked or staged changes are present before rebase/build.
- It allows untracked files and prints them before doing work.
- It never pushes.
- It installs only with `--install`.
- Before installing, it aborts if the game, launcher, or loader appears to be running.
- It verifies code signing for the built app and installed app.
- It compares the installed bundle hash with the build output after install.

The tracked/staged cleanliness check is there to keep rebases and local builds easy to reason about. If you have work in progress, commit it, stash it, or skip the refresh until the tree is clean.

## Publishing the integration branch

Publishing is optional. Use it when you want backup, continuity across machines, or another agent to pick up the exact integration stack.

First-time publish:

```bash
git push -u wycats HEAD:refs/heads/wycats/local-play-macos
```

After future rebases:

```bash
git push --force-with-lease wycats HEAD:refs/heads/wycats/local-play-macos
```

This branch is not a PR branch. Upstream review should happen through narrow topic branches.

## What the script builds

The refresh script delegates the actual macOS build to:

```bash
scripts/mac-build-test-debug.sh --mode release --arch <native> build
```

That script configures xmake, builds the macOS launcher, packages the final app bundle, and ad-hoc signs it. The built app is expected at:

```text
build/macosx/<arch>/<mode>/STFC Community Mod.app
```

When `--install` is passed, that app replaces:

```text
/Applications/STFC Community Mod.app
```

The install step copies to a temporary app first, verifies it, then swaps it into `/Applications`. If a previous app exists, it is moved aside during the swap and restored if the final move fails.

## Local generated files

Local capture/export runs can create `.logs/` and `.static-export/`. Those directories are ignored because they are generated personal artifacts, not branch content.

Do not use the refresh script as a substitute for PR validation. For code changes intended for upstream, run the normal narrow build/test path and review the final diff before pushing to the fork.
