-- vim:ft=lua:sts=2:ts=2:sw=2:et:
-- Rex config: https://www.superlogical.com/rex/docs/customize/config.md
-- Check with `rex config check`; apply with `rex config reload`.

-- ctrl+b is a sequence prefix, like tmux's. Once it starts a sequence it no
-- longer reaches the terminal, so press it twice to send one to tmux running
-- inside Rex.
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- fai: pick a project with fai (utils/.local/bin/fai) in a floating layer,
-- like a tmux popup. fai opens each pick in a new Rex window named after its
-- repo, and the layer closes once fai exits.
-- bash -li loads the login and interactive profile, so fai and the agents it
-- starts have the usual PATH and environment. An
-- optional url is passed to fai, which picks a GitHub URL's repo (any other
-- URL leaves the pick to you) and types the link into the agent's prompt; the
-- browser hotkey (macos/.local/share/fai-send) runs this with the frontmost
-- tab's URL. Optional text (right-click → Send to fai… on a selection) goes
-- to fai as FAI_TEXT, shown under the picker and pasted into the agent's
-- prompt. Either way FAI_PICK keeps the picker open even on a unique match,
-- so TAB can still choose the agent before Enter. Both reach bash as
-- arguments, never as shell code.
rex.action({
  name = "fai",
  title = "Open fai",
  category = "Agents",
  keywords = "claude cloud copilot pi repo clone picker",
  args = { url = "string?", text = "string?" },
  run = function(_, args)
    local command = { "bash", "-lic", "fai", "bash" }
    if args and args.text and args.text ~= "" then
      command =
        { "bash", "-lic", 'FAI_PICK=1 FAI_TEXT="$1" fai', "bash", args.text }
    elseif args and args.url and args.url ~= "" then
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

-- ctrl+b g: grep every file under ~/Projects in a floating layer, with CTRL-T
-- in the picker toggling to a GitHub code search (see
-- utils/.local/bin/fzf-projects-grep). ENTER on a local hit starts an agent
-- in a new window with the hit's path:line in its prompt. bash -l puts ~/.local/bin on PATH and
-- loads the fzf options. ctrl+b ctrl+g works too, for when ctrl is still held.
rex.action({
  name = "grep_projects",
  title = "Grep Projects (Local or GitHub)",
  category = "Search",
  keywords = "ripgrep rg code search find text github",
  run = function()
    rex.session.new_layer({
      bounds = { 0.1, 0.1, 0.8, 0.8 },
      focus = true,
      layout = rex.layout.block({
        flavor = "com.superlogical.terminal.shell",
        label = "grep",
        options = {
          shell = "none",
          command = { "bash", "-lc", "fzf-projects-grep" },
        },
      }),
    })
    return true
  end,
})
rex.bind("ctrl+b>g", "grep_projects")
rex.bind("ctrl+b>ctrl+g", "grep_projects")

-- ctrl+b s: fuzzy-search the scrollback of every block in a floating layer,
-- and jump to the chosen line (see utils/.local/bin/fzf-rex-grep). ctrl+b
-- ctrl+s works too, for when ctrl is still held.
local function grep_scrollback()
  rex.session.new_layer({
    bounds = { 0.1, 0.1, 0.8, 0.8 },
    focus = true,
    layout = rex.layout.block({
      flavor = "com.superlogical.terminal.shell",
      label = "scrollback",
      options = { shell = "none", command = { "bash", "-lc", "fzf-rex-grep" } },
    }),
  })
  return true
end
rex.bind("ctrl+b>s", grep_scrollback)
rex.bind("ctrl+b>ctrl+s", grep_scrollback)

-- ctrl+b u: pick URL(s) from the focused block's scrollback with fzf and open
-- them, in a floating layer (see utils/.local/bin/fzf-urls). The layer's
-- own block is a new one, so the focused block is passed as an argument.
-- ctrl+b ctrl+u works too, for when ctrl is still held. An optional flag
-- narrows the list (e.g. "--linear", for Open Linear Issue in Browser below);
-- with one, a single match opens without the picker.
local function url_picker(flag)
  return function(ctx)
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
            'fzf-urls $1 "$0"',
            ctx.block_id or "",
            flag or "",
          },
        },
      }),
    })
    return true
  end
end
local pick_urls = url_picker()
rex.bind("ctrl+b>u", pick_urls)
rex.bind("ctrl+b>ctrl+u", pick_urls)

-- ctrl+b t: a floating scratch shell in the focused block's working
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
-- Also in the command palette. ctrl+b ctrl+t works too, for when ctrl is
-- still held. (It was cmd+shift+enter, which the app already binds.)
rex.action({
  name = "scratch",
  title = "Scratch Shell",
  category = "Terminal",
  keywords = "popup floating layer temporary terminal",
  run = scratch,
})
rex.bind("ctrl+b>t", "scratch")
rex.bind("ctrl+b>ctrl+t", "scratch")

-- A program (a coding agent, or nvim) in a split to the right of the focused
-- block, in that block's working directory. bash -lic loads the profile so the
-- program has the usual PATH; shell = "none" keeps Rex from loading it a
-- second time. The program and its arguments reach bash as arguments, never as
-- shell code.
local function program_split(label, ...)
  local command = { "bash", "-lic", 'exec "$@"', "bash" }
  for _, arg in ipairs({ ... }) do
    command[#command + 1] = arg
  end
  return function(ctx)
    local _, err = rex.session.new_split({
      session_id = ctx.session_id,
      anchor_id = ctx.block_id,
      direction = "horizontal",
      side = "after",
      ratio = 0.5,
      focus = true,
      layout = rex.layout.block({
        flavor = "com.superlogical.terminal.shell",
        label = label,
        options = {
          shell = "none",
          cwd = block_cwd(ctx),
          command = command,
        },
      }),
    })
    if err ~= nil then
      error(err, 0)
    end
    return true
  end
end

-- Each agent in the command palette.
for _, a in ipairs({
  {
    agent = "claude",
    title = "Open Claude",
    keywords = "claude code anthropic",
  },
  { agent = "pi", title = "Open Pi", keywords = "pi coding agent" },
  {
    agent = "copilot",
    title = "Open Copilot",
    keywords = "github copilot cli",
  },
}) do
  rex.action({
    name = "agent_" .. a.agent,
    title = a.title .. " in Current Directory",
    category = "Agents",
    keywords = a.keywords .. " cwd split here",
    run = program_split("agent", a.agent),
  })
end

rex.action({
  name = "nvim_cwd",
  title = "Open Neovim in Current Directory",
  category = "Editor",
  keywords = "nvim vim editor edit files cwd split here",
  run = program_split("nvim", "nvim", "."),
})

-- The CI of the focused block's branch's PR, in a split to the right, in that
-- block's working directory: gh pr checks --watch on top, and below it the
-- Actions runs' steps and then the failed jobs' logs
-- (utils/.local/bin/gh-pr-logs). Once each finishes (or there's no PR), its
-- pane waits for a key and closes.
local function watch_pane(label, script, cwd)
  return rex.layout.block({
    flavor = "com.superlogical.terminal.shell",
    label = label,
    options = {
      shell = "none",
      cwd = cwd,
      command = {
        "bash",
        "-lc",
        script .. "; read -rsn1 -p 'Press any key to close'",
      },
    },
  })
end

rex.action({
  name = "gh_pr_checks_split",
  title = "Watch GitHub PR Checks and Logs in Split",
  category = "GitHub",
  keywords = "github ci actions build status failing pull request watch pane run logs",
  run = function(ctx)
    local cwd = block_cwd(ctx)
    local _, err = rex.session.new_split({
      session_id = ctx.session_id,
      anchor_id = ctx.block_id,
      direction = "horizontal",
      side = "after",
      ratio = 0.5,
      focus = true,
      layout = rex.layout.vertical(
        0.4,
        watch_pane("checks", "gh pr checks --watch", cwd),
        watch_pane("logs", "gh-pr-logs", cwd)
      ),
    })
    if err ~= nil then
      error(err, 0)
    end
    return true
  end,
})

-- ctrl+b o …: open something in the browser. u, r, p, c and i fuzzy-pick
-- from the focused block's scrollback (fzf-urls with a flag, see pick_urls);
-- f and l pick from the block's git repo.
--   u  any URL, each listed once (fzf-urls --url)
--   r  a GitHub repo, from any GitHub URL or reference (fzf-urls --repo)
--   p  a GitHub PR, from PR URLs and references (fzf-urls --pr)
--   c  a PR's checks tab (fzf-urls --checks)
--   i  a Linear issue, from issue URLs and IDs of known team keys
--      (fzf-urls --linear)
--   f  a fuzzy-picked file, as a permalink (utils/.local/bin/fzf-gh-browse)
--   l  a fuzzy-picked line, as a permalink

local function gh_pick(mode)
  return function(ctx)
    rex.session.new_layer({
      bounds = { 0.1, 0.1, 0.8, 0.8 },
      focus = true,
      layout = rex.layout.block({
        flavor = "com.superlogical.terminal.shell",
        label = "gh-" .. mode,
        options = {
          shell = "none",
          cwd = block_cwd(ctx),
          command = { "bash", "-lc", 'fzf-gh-browse "$0"', mode },
        },
      }),
    })
    return true
  end
end

-- Each one is an action too, so it's listed in the command palette (with its
-- keys) as well as bound. The palette groups them under their category, and
-- its search also matches their keywords (e.g. "ci" finds the checks tab).
for _, a in ipairs({
  {
    key = "u",
    name = "open_url",
    title = "Open URL in Browser",
    category = "Browser",
    keywords = "url link http web",
    run = url_picker("--url"),
  },
  {
    key = "r",
    name = "gh_open_repo",
    title = "Open GitHub Repo in Browser",
    category = "GitHub",
    keywords = "github repository browse",
    run = url_picker("--repo"),
  },
  {
    key = "p",
    name = "gh_open_pr",
    title = "Open GitHub PR in Browser",
    category = "GitHub",
    keywords = "github pull request review",
    run = url_picker("--pr"),
  },
  {
    key = "c",
    name = "gh_open_checks",
    title = "Open GitHub PR Checks in Browser",
    category = "GitHub",
    keywords = "github ci actions build status failing",
    run = url_picker("--checks"),
  },
  {
    key = "f",
    name = "gh_open_file",
    title = "Open GitHub File in Browser (Permalink)",
    category = "GitHub",
    keywords = "source link share",
    run = gh_pick("files"),
  },
  {
    key = "l",
    name = "gh_open_line",
    title = "Open GitHub Line in Browser (Permalink)",
    category = "GitHub",
    keywords = "source link share blame",
    run = gh_pick("lines"),
  },
  {
    key = "i",
    name = "linear_open_issue",
    title = "Open Linear Issue in Browser",
    category = "Linear",
    keywords = "linear ticket task bug",
    run = url_picker("--linear"),
  },
}) do
  rex.action({
    name = a.name,
    title = a.title,
    category = a.category,
    keywords = a.keywords,
    run = a.run,
  })
  rex.bind("ctrl+b>o>" .. a.key, a.name)
end

-- ctrl+b l: go back to the block focused before this one, switching windows
-- if needed, like tmux's last-window (prefix+l) but for panes too. Pressing it
-- again comes back, so it toggles between the two. ctrl+b ctrl+l works too,
-- for when ctrl is still held.
--
-- Config can't handle events, so last-focus.lua records each session's focus
-- history, from keys, the mouse and the API alike, in a `rex do --all` beside
-- the server. It's started here unless it's already running; after editing
-- it, kill it (pkill -f last-focus.lua) and reload the config.
local last_focus_script = os.getenv("HOME") .. "/.config/rex/last-focus.lua"
local last_focus_dir = (
  os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
) .. "/rex/last-focus"

-- rex isn't on the server's PATH (it's inside the app), so the launcher runs
-- its parent's binary: the server's own rex, which also keeps the watcher's
-- version in step with the server's. REX_SERVER, set in the server's
-- environment, points it at this server. The script's path reaches bash as
-- an argument, so the pgrep pattern in bash's own command line never matches
-- bash itself.
rex.exec.start({
  "bash",
  "-c",
  'pgrep -qf "rex do --all $1" || exec "$(ps -o comm= -p "$PPID")" do --all "$1"',
  "bash",
  last_focus_script,
}, { detach = true, stdout = false, stderr = false })

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
  name = "last_pane",
  title = "Go to Last Pane/Window",
  category = "Navigation",
  keywords = "previous recent back toggle tmux last-window last-pane jump",
  run = function(ctx)
    local f =
      io.open(last_focus_dir .. "/" .. ctx.session_id:gsub("[^%w%-]", "_"))
    if not f then
      return
    end
    local blocks = rex.session.list_blocks({ session_id = ctx.session_id })
    local placed = {}
    for _, b in ipairs((blocks and blocks.blocks) or {}) do
      if b.placement == "placed" then
        placed[b.block_id] = b
      end
    end
    -- The most recent block that isn't this one and is still open.
    for id in f:lines() do
      if id ~= ctx.block_id and placed[id] then
        f:close()
        focus(ctx, placed[id])
        return
      end
    end
    f:close()
  end,
})
rex.bind("ctrl+b>l", "last_pane")
rex.bind("ctrl+b>ctrl+l", "last_pane")

-- ctrl+b ?: list every binding (rex keymap) in a floating layer, paged with
-- less; q closes it. Rex has no "?" key name, so it's bound as shift+/.
-- Bindings to a Lua function show as client.key.forward.
rex.action({
  name = "show_keymap",
  title = "Show Keybindings",
  category = "Help",
  keywords = "keys keymap shortcuts bindings cheat sheet which-key",
  run = function()
    rex.session.new_layer({
      bounds = { 0.1, 0.1, 0.8, 0.8 },
      focus = true,
      layout = rex.layout.block({
        flavor = "com.superlogical.terminal.shell",
        label = "keymap",
        options = {
          shell = "none",
          command = { "bash", "-lc", "rex keymap --color always | less -R" },
        },
      }),
    })
    return true
  end,
})
rex.bind("ctrl+b>shift+/", "show_keymap")
