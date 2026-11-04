# Agent instructions

## Dev tools are managed by mise

The formatters, linters and hooks this repo uses are pinned in `mise.toml` and
installed by [mise](https://mise.jdx.dev). Don't install them with brew, npm or
pip, and don't skip a hook because its tool is missing.

- `mise install` installs every pinned tool.
- `bash/.exports` puts mise's shims on `PATH`, so plain commands such as
  `git commit` run the pinned tools, even in non-interactive shells like git
  hooks and agents. Only a shell that didn't load `.exports` needs
  `mise exec --`, e.g. `mise exec -- git commit`.
- To add a tool, pin it under `[tools]` in `mise.toml`.

## Hooks

prek runs the hooks in `.pre-commit-config.yaml`.

- `mise run prek:install` installs the pre-commit and commit-msg hooks.
- `mise run prek:run` runs the hooks on every file.
