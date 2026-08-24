# macOS Configuration

This directory contains macOS-specific configurations managed via GNU Stow.

## Setup

To symlink the configurations to your home directory:

```bash
stow macos
```

## Opening JSON (and friends) in Neovim inside Ghostty

Launch Services can only hand a document to an `.app` bundle, never to a bare
CLI binary, so `macos/.local/share/nvim-ghostty/` builds a small AppleScript app
that receives the file from Finder and forwards it to Ghostty running Neovim.

```bash
make macos-nvim-ghostty           # build ~/Applications/NvimGhostty.app
make macos-nvim-ghostty-register   # ...and set it as the default JSON handler
make macos-nvim-ghostty-uninstall  # remove it and reset Launch Services
```

Pieces:

| File                       | Role                                                                               |
| -------------------------- | ---------------------------------------------------------------------------------- |
| `nvim-ghostty.applescript` | `on open` handler; the only thing Finder can talk to                               |
| `open-in-nvim`             | shell wrapper doing `open -na Ghostty.app --args -e /bin/sh -c "exec nvim <file>"` |
| `build.sh`                 | compiles the bundle, patches `Info.plist`, optionally registers via `duti`         |

The registered types are the `public.json` UTI plus the `json`, `jsonc`,
`json5`, `ndjson` and `jsonl` extensions. To set the association by hand instead
of with `duti`, use Finder's _Get Info → Open With → Change All_.

### Caveats

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
