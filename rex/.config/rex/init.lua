-- vim:ft=lua:sts=2:ts=2:sw=2:et:
-- Rex config: https://www.superlogical.com/rex/docs/customize/config.md
-- Check with `rex config check`; apply with `rex config reload`.

-- ctrl+b is a sequence prefix, like tmux's. Once it starts a sequence it no
-- longer reaches the terminal, so press it twice to send one to tmux running
-- inside Rex.
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- fai: pick a project with fai (utils/.local/bin/fai) in a floating layer,
-- like a tmux popup. fai opens each pick in a new Rex window, and the layer
-- closes once fai exits. bash -li loads the login and interactive profile, so
-- fai and the agents it starts have the usual PATH and environment. An
-- optional url is passed to fai, which picks a GitHub URL's repo (any other
-- URL leaves the pick to you) and types the link into the agent's prompt; the
-- browser hotkey (macos/.local/share/agent-url) runs this with the frontmost
-- tab's URL. With a url, FAI_PICK keeps the picker open even on a
-- unique match, so TAB can still choose the agent before Enter.
rex.action({
  name = "fai",
  title = "Pick a Project with fai",
  args = { url = "string?" },
  run = function(_, args)
    local command = { "bash", "-lic", "fai", "bash" }
    if args and args.url and args.url ~= "" then
      command = { "bash", "-lic", 'FAI_PICK=1 fai "$@"', "bash", args.url }
    end
    local _, err = rex.session.new_layer({
      bounds = { 0.1, 0.1, 0.8, 0.8 },
      focus = true,
      layout = rex.layout.block({
        flavor = "com.superlogical.terminal.shell",
        label = "fai",
        -- shell = "none": bash -lic already loads the profile; without it,
        -- Rex would run the command through the login shell too, loading
        -- the profile twice and delaying the picker by ~0.2s.
        options = { shell = "none", command = command },
      }),
    })
    if err ~= nil then
      error(err, 0)
    end
    return true
  end,
})

-- ctrl+b f: fai with no URL. ctrl+b ctrl+f works too, for when ctrl is still
-- held.
rex.bind("ctrl+b>f", "fai")
rex.bind("ctrl+b>ctrl+f", "fai")

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
      options = { shell = "none", command = { "bash", "-lc", "fzf-rex-grep" } },
    }),
  })
  return true
end
rex.bind("ctrl+b>g", grep_scrollback)
rex.bind("ctrl+b>ctrl+g", grep_scrollback)

-- ctrl+b u: pick URL(s) from the focused block's scrollback with fzf and open
-- them, in a floating layer (see utils/.local/bin/fzf-urls). The layer's
-- own block is a new one, so the focused block is passed as an argument.
-- ctrl+b ctrl+u works too, for when ctrl is still held.
local function pick_urls(ctx)
  rex.session.new_layer({
    bounds = { 0.1, 0.1, 0.8, 0.8 },
    focus = true,
    layout = rex.layout.block({
      flavor = "com.superlogical.terminal.shell",
      label = "urls",
      options = {
        shell = "none",
        command = {
          "bash",
          "-lc",
          'fzf-urls "$0"',
          ctx.block_id or "",
        },
      },
    }),
  })
  return true
end
rex.bind("ctrl+b>u", pick_urls)
rex.bind("ctrl+b>ctrl+u", pick_urls)

-- cmd+shift+enter: a floating scratch shell in the focused block's working
-- directory. The terminal's pwd is what the shell last reported with OSC 7;
-- bash doesn't report it by default, so fall back to the foreground process's
-- cwd. With neither (e.g. a non-terminal block), the shell starts in $HOME.
local function block_cwd(ctx)
  if not ctx.block_id then
    return nil
  end
  local ok, pwd = pcall(rex.block.call, "com.superlogical.terminal", "pwd", {
    session_id = ctx.session_id,
    block_id = ctx.block_id,
  })
  local dir = ok and pwd and (pwd.pwd or pwd.path or pwd.cwd)
  if dir and dir ~= "" then
    return dir
  end
  local ok2, proc =
    pcall(rex.block.call, "com.superlogical.terminal", "process", {
      session_id = ctx.session_id,
      block_id = ctx.block_id,
    })
  if ok2 and proc and proc.foreground and proc.foreground.cwd then
    return proc.foreground.cwd
  end
  return nil
end

local function scratch(ctx)
  rex.session.new_layer({
    bounds = { 0.1, 0.1, 0.8, 0.8 },
    focus = true,
    layout = rex.layout.block({
      flavor = "com.superlogical.terminal.shell",
      label = "scratch",
      options = { cwd = block_cwd(ctx) },
    }),
  })
  return true
end
rex.bind("cmd+shift+enter", scratch)

-- ctrl+b c: a coding agent (Claude Code, or $REX_AGENT) in a split to the
-- right of the focused block, in that block's working directory. bash -lic
-- loads the profile so the agent has the usual PATH; shell = "none" keeps Rex
-- from loading it a second time. ctrl+b ctrl+c works too, for when ctrl is
-- still held.
local function agent_split(ctx)
  local _, err = rex.session.new_split({
    session_id = ctx.session_id,
    anchor_id = ctx.block_id,
    direction = "horizontal",
    side = "after",
    ratio = 0.5,
    focus = true,
    layout = rex.layout.block({
      flavor = "com.superlogical.terminal.shell",
      label = "agent",
      options = {
        shell = "none",
        cwd = block_cwd(ctx),
        command = { "bash", "-lic", 'exec "${REX_AGENT:-claude}"' },
      },
    }),
  })
  if err ~= nil then
    error(err, 0)
  end
  return true
end
rex.bind("ctrl+b>c", agent_split)
rex.bind("ctrl+b>ctrl+c", agent_split)

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
