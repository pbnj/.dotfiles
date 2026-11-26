---
name: prune-system
description:
  Reclaim disk space on this Mac. Measures with mo (Mole), then prunes
  package-manager caches (brew, npm, go, cargo/rust, uv, mise, docker, podman,
  pipenv virtualenvs), Xcode DerivedData, ~/.cache, orphaned ~/.local/share
  data, and finished git worktrees under ~/Projects. Use when the user asks to
  prune, clean up, free space, or reclaim disk, or says the disk is full.
---

# Prune system

Work in three phases: measure, preview, then delete. Ask before anything that is
not a cache. Report the space freed per step.

## 1. Measure

- Measure with Mole's `mo analyze --json <dir>`, never plain `mo analyze`:
  without `--json` it opens an interactive TUI. It lists the directory's
  entries, largest first. Print them readably with:
  `mo analyze --json <dir> | jq -r '.entries[] | "\(.size / 1048576 | floor)M\t\(.path)"' | head -20`
- Start with `~` for top-level home usage, then drill into `~/.cache`,
  `~/.local`, `~/Library/Caches` and `~/Library/Developer`, one call each. Fall
  back to `du -sh` if `mo` is missing (`brew install mole`).
- Note the free space before and after: `df -h /`.

## 2. Caches (safe to clear; re-downloaded on demand)

Preview first where the tool supports it, then run the real command.

| Target             | Measure                                                                                                       | Preview                       | Prune                                                                                                                    |
| ------------------ | ------------------------------------------------------------------------------------------------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Homebrew           | `du -sh "$(brew --cache)"`                                                                                    | `brew cleanup -n --prune=all` | `brew cleanup --prune=all`                                                                                               |
| npm                | `du -sh ~/.npm`                                                                                               | (none)                        | `npm cache clean --force` (leaves about 2G; that is normal)                                                              |
| Go modules         | `du -sh "$(go env GOMODCACHE)"`                                                                               | (none)                        | `go clean -modcache`                                                                                                     |
| Go build           | `du -sh "$(go env GOCACHE)"`                                                                                  | (none)                        | `go clean -cache`                                                                                                        |
| Rust registry      | `du -sh ~/.cargo/registry`                                                                                    | (none)                        | `rm -rf ~/.cargo/registry/cache ~/.cargo/registry/src` (re-extracted on build)                                           |
| uv                 | `uv cache dir` then `du -sh`                                                                                  | `uv cache prune --dry-run`    | `uv cache prune` (or `uv cache clean` for everything)                                                                    |
| mise               | `du -sh ~/.local/share/mise ~/Library/Caches/mise`                                                            | `mise prune --dry-run`        | `mise prune --yes` (plain `mise prune` fails without a TTY); `mise cache prune`                                          |
| Docker             | `docker system df` (skip if the daemon is down)                                                               | `docker system df -v`         | `docker builder prune` and `docker image prune -a` after confirming; never `--volumes` without asking                    |
| Podman             | `podman machine list`                                                                                         |                               | If the CLI is absent but `~/.local/share/containers/podman` exists, that data is orphaned: confirm, then delete          |
| pipenv virtualenvs | `du -sh ~/.local/share/virtualenvs`                                                                           | (see section 3)               | Orphans only by default (see section 3); all envs only if asked. Rebuild a live one with `pipenv install` in its project |
| Xcode              | `du -sh ~/Library/Developer/Xcode/DerivedData`                                                                |                               | Delete DerivedData (rebuilt automatically)                                                                               |
| Browser caches     | `du -sh ~/Library/Caches/{BraveSoftware,Firefox,Google,Mozilla,com.apple.Safari,Microsoft\ Edge} 2>/dev/null` | (none)                        | See "Browser caches" below                                                                                               |
| ~/.cache           | `mo analyze --json ~/.cache`                                                                                  |                               | List the largest entries and ask before deleting any                                                                     |

Note: `brew prune` is not a Homebrew command. Use `brew cleanup`.

### Browser caches

Only the cache under `~/Library/Caches` is cleared. Never touch
`~/Library/Application Support/<browser>` or a Firefox profile in
`~/Library/Application Support/Firefox`: those hold history, cookies, logins and
extensions.

1. Check whether each browser is running:
   `pgrep -x "Brave Browser" "Google Chrome" firefox "Microsoft Edge" Safari`. A
   running browser rewrites its cache as you delete it, and may misbehave. Ask
   the user to quit it, or skip that browser and say so.
2. Delete only the cache contents:
   - Chromium browsers (Brave, Chrome, Edge): `rm -rf` the `Cache` and
     `Code Cache` dirs in each profile, e.g.
     `~/Library/Caches/BraveSoftware/Brave-Browser/*/{Cache,"Code Cache"}`,
     `~/Library/Caches/Google/Chrome/*/{Cache,"Code Cache"}`,
     `~/Library/Caches/Microsoft\ Edge/*/{Cache,"Code Cache"}`.
   - Firefox:
     `rm -rf ~/Library/Caches/Firefox/Profiles/*/{cache2,startupCache,thumbnails}`.
     Leave `safebrowsing` and `settings`.
   - Safari: `~/Library/Caches/com.apple.Safari` is protected by macOS privacy
     controls and is usually small. Skip it unless it is large, and then tell
     the user to use Safari > Settings > Advanced > Show features for web
     developers, then Develop > Empty Caches.
3. Report the space freed per browser. Pages load slower until the cache
   refills.

## 3. Build output and project dirs (ask first)

- Find `target/`, `node_modules/`, and `.venv/` under `~/Projects` with
  `mo analyze --json ~/Projects` (then drill into the largest repos) or
  `find ~/Projects -maxdepth 4 -name node_modules -prune`.
- Show sizes and the owning repo. Delete only on confirmation. Prefer
  `cargo clean` and `npm prune` where those tools apply.

### Trash (`~/.Trash`)

Emptying the Trash is permanent, and the Trash holds user files, not caches.
List what is in it before asking.

1. Size it and list the largest items: `du -sh ~/.Trash` then
   `du -sh ~/.Trash/* ~/.Trash/.[!.]* 2>/dev/null | sort -h | tail`.
2. Show the list and ask for confirmation. Skip this when the user asked to
   empty the Trash.
3. Empty it through Finder so locked items and items on external volumes are
   handled: `osascript -e 'tell application "Finder" to empty trash'`. If Finder
   is unavailable or the call fails, fall back to
   `rm -rf ~/.Trash/* ~/.Trash/.[!.]*`. That needs Full Disk Access for the
   terminal, and it does not touch `/Volumes/*/.Trashes`.
4. Report the space freed.

### Rust build output (`cargo clean`)

`target/` is build output: untracked, rebuilt by the next `cargo build`, so it
is safe to clear even in a worktree with uncommitted changes or unpushed
commits. The only cost is a slow first rebuild.

1. Find every Cargo `target/` under `~/Projects`, worktrees included. Worktrees
   sit at `<owner>/<repo>/.worktrees/<name>/`, deeper than a shallow `find`
   reaches, so do not cap the depth:
   `find ~/Projects -type d -name target -prune -exec test -f '{}/../Cargo.toml' \; -print`
2. Size each with `du -sh` and report the total.
3. Run `cargo clean --manifest-path <dir>/Cargo.toml` for each (where `<dir>` is
   the parent of `target/`). If `cargo` is missing or fails (for example a
   toolchain in `rust-toolchain.toml` that is not installed), fall back to
   `rm -rf <dir>/target`.
4. Report the space freed per repo.

### Pipenv virtualenvs (`~/.local/share/virtualenvs`)

Each env has a `.project` file holding the project path it was made for.

1. Flag orphans: an env is an orphan when its `.project` path no longer exists
   (often `/tmp` probes or deleted worktrees). Loop over
   `~/.local/share/virtualenvs/*/`, read `.project`, and test `[ ! -e "$p" ]`.
2. Show orphan count and size. On confirmation, `rm -rf` the orphan dirs only.
3. Live envs (project exists) are not caches. Remove them only if the user asks
   for all of them. A removed env is rebuilt with `pipenv install` in its
   project, using `Pipfile.lock`.
4. Do not use `pipenv --rm` for orphans: it needs the project to still exist.

## 4. Git worktrees (ask first; never force)

Worktrees live under `<repo>/.worktrees/`.

1. List them: `git -C <repo> worktree list --porcelain`, and size each with
   `du -sh`.
2. For each candidate, check safety:
   - `git -C <wt> status --porcelain` must be empty (no uncommitted changes).
   - Its branch has been merged or pushed: `git -C <repo> branch -vv` should
     show no `[ahead N]`, and `gh pr view <branch> --json state` should show
     MERGED or CLOSED.
3. Show the list of safe-to-remove worktrees with sizes. Ask for confirmation.
4. Remove with `git -C <repo> worktree remove <path>` (no `--force`). Then
   `git -C <repo> worktree prune`.
5. Never delete a worktree that has uncommitted changes or unpushed commits.
   Report it and skip it.

## 5. Report

Give before and after `df -h /` and a short per-step table of space freed. Name
anything skipped and why.
