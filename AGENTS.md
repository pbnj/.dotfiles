# Agent instructions

## Dev tools are managed by mise

The formatters, linters and hooks this repo uses are pinned in `mise.toml` and
installed by [mise](https://mise.jdx.dev). Don't install them with brew, npm or
pip, and don't skip a hook because its tool is missing.

- `mise install` installs every pinned tool.
- A shell where mise isn't activated won't have them on `PATH`. Run commands
  through mise instead, e.g. `mise exec -- git commit`, so the prek hooks find
  their tools.
- To add a tool, pin it under `[tools]` in `mise.toml`.

## Hooks

prek runs the hooks in `.pre-commit-config.yaml`.

- `mise run prek:install` installs the pre-commit and commit-msg hooks.
- `mise run prek:run` runs the hooks on every file.
