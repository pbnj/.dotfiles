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

-- ctrl+b a: focus the block that most needs attention, switching windows if
-- needed. Programs such as Claude Code report a status with OSC 7501; blocked
-- (waiting for input) beats error beats done, and the most recent wins.
-- Pressing it again from the block it jumped to goes back to where you were,
-- so it toggles between the two. ctrl+b ctrl+a works too, for when ctrl is
-- still held.
local terminal = "com.superlogical.terminal"
local attention_rank = { blocked = 1, error = 2, done = 3 }

-- The last jump, as { from = block, to = block }. Lua state lives until the
-- config is reloaded.
local attention_jump

local function focus(ctx, block)
  rex.session.focus_block({
    session_id = ctx.session_id,
    block_id = block.block_id,
  })
  -- Focusing on the server doesn't move the app's view, so ask the app to
  -- show the block's window too.
  pcall(
    rex.client.queue,
    "session.select",
    { session_id = ctx.session_id, window_id = block.window_id }
  )
end

rex.action({
  name = "focus_attention",
  title = "Focus Block Needing Attention",
  run = function(ctx)
    local blocks = rex.session.list_blocks({ session_id = ctx.session_id })
    local placed = {}
    for _, b in ipairs((blocks and blocks.blocks) or {}) do
      if b.placement == "placed" then
        placed[b.block_id] = b
      end
    end

    local jump = attention_jump
    attention_jump = nil
    if jump and jump.to == ctx.block_id and placed[jump.from] then
      focus(ctx, placed[jump.from])
      return
    end

    local best
    for id, b in pairs(placed) do
      if b.creator_name == terminal and id ~= ctx.block_id then
        local status = rex.block.call(
          terminal,
          "program_status",
          { session_id = ctx.session_id, block_id = id }
        )
        for _, rec in ipairs((status and status.records) or {}) do
          local rank = attention_rank[rec.state]
          if
            rank
            and (
              not best
              or rank < best.rank
              or (rank == best.rank and rec.updated_at > best.at)
            )
          then
            best = { block = b, rank = rank, at = rec.updated_at }
          end
        end
      end
    end
    if not best then
      return
    end
    if ctx.block_id then
      attention_jump = { from = ctx.block_id, to = best.block.block_id }
    end
    focus(ctx, best.block)
  end,
})
rex.bind("ctrl+b>a", "focus_attention")
rex.bind("ctrl+b>ctrl+a", "focus_attention")
