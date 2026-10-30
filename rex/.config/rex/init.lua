-- vim:ft=lua:sts=2:ts=2:sw=2:et:
-- Rex config: https://www.superlogical.com/rex/docs/customize/config.md
-- Check with `rex config check`; apply with `rex config reload`.

-- ctrl+b is a sequence prefix, like tmux's. Once it starts a sequence it no
-- longer reaches the terminal, so press it twice to send one to tmux running
-- inside Rex.
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- ctrl+b f: pick a project with fai (see bash/.functions) in a floating
-- layer, like a tmux popup. fai opens each pick in a new Rex window, and the
-- layer closes once fai exits. bash -l loads ~/.profile, which sources fai;
-- -i makes it an interactive shell. ctrl+b ctrl+f works too, for when ctrl is
-- still held.
local function pick_project()
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
end
rex.bind("ctrl+b>f", pick_project)
rex.bind("ctrl+b>ctrl+f", pick_project)

-- ctrl+b g: fuzzy-grep the scrollback of every block in a floating layer,
-- and jump to the chosen line (see utils/.local/bin/fzf-rex-grep). bash -l
-- puts ~/.local/bin on PATH and loads the fzf options. ctrl+b ctrl+g works
-- too, for when ctrl is still held.
local function grep_scrollback()
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
end
rex.bind("ctrl+b>g", grep_scrollback)
rex.bind("ctrl+b>ctrl+g", grep_scrollback)
