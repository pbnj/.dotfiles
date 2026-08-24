# macOS Configuration

This directory contains macOS-specific configurations managed via GNU Stow.

## Setup

To symlink the configurations to your home directory:

```bash
stow macos
```

## Opening text files in Neovim inside Ghostty

Launch Services can only hand a document to an `.app` bundle, never to a bare
CLI binary, so `macos/.local/share/nvim-ghostty/` builds a small AppleScript app
that receives the file from Finder and forwards it to Ghostty running Neovim.

```bash
make macos-nvim-ghostty                                   # build ~/Applications/NvimGhostty.app
make macos-nvim-ghostty-status                            # who handles what right now
make macos-nvim-ghostty-register GROUPS="data config"      # set defaults for named groups
make macos-nvim-ghostty-uninstall                          # remove it and reset Launch Services
```

Pieces:

| File                       | Role                                                                               |
| -------------------------- | ---------------------------------------------------------------------------------- |
| `filetypes.conf`           | the claimed types, as data: one `group : role : values` row per line               |
| `nvim-ghostty.applescript` | `on open` handler; the only thing Finder can talk to                               |
| `open-in-nvim`             | shell wrapper doing `open -na Ghostty.app --args -e /bin/sh -c "exec nvim <file>"` |
| `build.sh`                 | compiles the bundle, patches `Info.plist`, optionally registers via `duti`         |
| `status.sh`                | prints the current handler for every claimed extension                             |

### Type groups

Groups are disjoint, so each is a meaningful unit to register on its own. Add or
remove types by editing `filetypes.conf` and rebuilding — no script changes.

| Group    | Extensions                                        |
| -------- | ------------------------------------------------- |
| `data`   | json, jsonc, json5, ndjson, jsonl                 |
| `text`   | txt, text, log, csv, tsv                          |
| `docs`   | md, markdown, xml                                 |
| `config` | yaml, yml, toml, ini, conf, env, tfvars, hcl      |
| `source` | py, sh, bash, zsh, js, lua, go, rs, sql, nix, zig |

Extensions macOS has no real UTI for (toml, lua, go, ini, …) resolve to a
per-machine `dyn.*` type that is not a stable registration target, so the bundle
declares an _imported_ type for each — `com.peterbenjamin.nvim-ghostty.toml` and
friends, conforming to `public.plain-text`. Verify a claim before adding it:

```bash
printf x > /tmp/f.toml && mdls -raw -name kMDItemContentType /tmp/f.toml
```

### Caveats

- **Declaring a type is often enough to become its default.** For any type no
  other app already owns, Launch Services picks the sole claimant, so `.md`,
  `.py`, `.toml`, `.yaml`, `.lua` and the rest route to Neovim straight after
  `make macos-nvim-ghostty`, with no `duti` step. Registration only matters for
  types with an incumbent: `.txt` (TextEdit), `.log` (Console), `.csv` (Excel),
  `.xml` (Word), `.sh`/`.zsh` (Ghostty itself, which _runs_ them). Run
  `make macos-nvim-ghostty-status` to see where things stand.
- `.ts` is deliberately not claimed: macOS maps it to
  `public.mpeg-2-transport-stream`, a video type, not TypeScript.
- The file paths are wrapped in a single `sh -c` argument on purpose. Passed as
  bare arguments after `-e`, Ghostty also treats each existing path as a
  _document_, opening a second window that tries to execute the file as a
  command (`<path>; exit` → `Permission denied`). The `sh` layer `exec`s away.
- Each open spawns a **separate Ghostty instance** rather than a tab in the
  existing window. On macOS `ghostty +new-window` is unsupported and `open` only
  passes `--args` at launch, so `-n` is required. Reusing a running editor would
  mean starting Neovim with `--listen` and remoting in via
  `nvim --server <addr> --remote`.
- Launch Services caches aggressively. If a change does not take effect, run
  `make macos-nvim-ghostty-uninstall` and rebuild, or log out and back in.
- Editing `Info.plist` invalidates `osacompile`'s ad-hoc signature, so
  `build.sh` re-signs the bundle. Gatekeeper may still prompt on first launch.
