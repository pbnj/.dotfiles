-- vim:ft=lua:sts=2:ts=2:sw=2:et:
-- Rex config: https://www.superlogical.com/rex/docs/customize/config.md
-- Check with `rex config check`; apply with `rex config reload`.

-- Cmd chords, not a ctrl+b prefix: ctrl+b is tmux's prefix, and a Rex
-- sequence on it would stop it reaching tmux running inside Rex.

-- cmd+shift+o: pick a project with fai (see bash/.functions) in a floating
-- layer, like a tmux popup. fai opens each pick in a new Rex window, and the
-- layer closes once fai exits. bash -l loads ~/.profile, which sources fai;
-- -i makes it an interactive shell.
rex.bind("cmd+shift+o", function()
  rex.session.new_layer({
    bounds = { 0.1, 0.1, 0.8, 0.8 },
    focus = true,
    layout = rex.layout.block({
      flavor = "com.superlogical.terminal.shell",
      label = "fai",
      options = { command = { "bash", "-lic", "fai" } },
    }),
  })
  return true
end)

-- cmd+shift+g: fuzzy-grep the scrollback of every block in a floating layer,
-- and jump to the chosen line (see utils/.local/bin/fzf-rex-grep). bash -l
-- puts ~/.local/bin on PATH and loads the fzf options.
rex.bind("cmd+shift+g", function()
  rex.session.new_layer({
    bounds = { 0.1, 0.1, 0.8, 0.8 },
    focus = true,
    layout = rex.layout.block({
      flavor = "com.superlogical.terminal.shell",
      label = "grep",
      options = { command = { "bash", "-lc", "fzf-rex-grep" } },
    }),
  })
  return true
end)
