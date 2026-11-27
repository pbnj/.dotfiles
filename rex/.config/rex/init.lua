-- vim:ft=lua:sts=2:ts=2:sw=2:et:
-- Rex config: https://www.superlogical.com/rex/docs/customize/config.md
-- Check with `rex config check`; apply with `rex config reload`.

-- ctrl+b is a sequence prefix, like tmux's. Once it starts a sequence it no
-- longer reaches the terminal, so press it twice to send one to tmux running
-- inside Rex.
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- The bash for commands that load the profile. Rex's server PATH lacks
-- /opt/homebrew/bin, so a bare "bash" is macOS's bash 3.2, which rejects
-- bash 4+ syntax in the profile (e.g. `complete -o nosort`).
local BASH = "/opt/homebrew/bin/bash"

-- fai: pick a project with fai (utils/.local/bin/fai) in a floating layer,
-- like a tmux popup. fai opens each pick in a new Rex window named after its
-- repo (a best-fit split of that window's tiled blocks when it's already
-- open, never this layer), and the layer closes once fai exits.
-- bash -li loads the login and interactive profile, so fai and the agents it
-- starts have the usual PATH and environment. An
-- optional url is passed to fai, which picks a GitHub URL's repo (any other
-- URL leaves the pick to you) and types the link into the agent's prompt; the
-- browser hotkey (macos/.local/share/fai-send) runs this with the frontmost
-- tab's URL, and the text highlighted on the page if any. Optional text
-- (that, or right-click → Send to fai… on a selection) goes to fai as
-- FAI_TEXT, shown under the picker and pasted into the agent's prompt, below
-- the URL when there is one. Either way FAI_PICK keeps the picker open even on a unique match,
-- so TAB can still choose the agent before Enter. Both reach bash as
-- arguments, never as shell code.
rex.action({
  name = "fai",
  title = "Open fai",
  category = "Agents",
  keywords = "claude cloud copilot pi repo clone picker",
  args = { url = "string?", text = "string?" },
  run = function(_, args)
    local url = args and args.url or ""
    local text = args and args.text or ""
    local command = { BASH, "-lic", "fai", "bash" }
    if text ~= "" and url ~= "" then
      -- Both (Hyper+A with text highlighted on the page): fai types the
      -- URL into the agent's prompt, then the text below it.
      command = {
        BASH,
        "-lic",
        'FAI_PICK=1 FAI_TEXT="$1" fai "$2"',
        "bash",
        text,
        url,
      }
    elseif text ~= "" then
      command = { BASH, "-lic", 'FAI_PICK=1 FAI_TEXT="$1" fai', "bash", text }
    elseif url ~= "" then
      command = { BASH, "-lic", 'FAI_PICK=1 fai "$@"', "bash", url }
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
          command = { BASH, "-lc", "fzf-projects-grep" },
        },
      }),
    })
    return true
  end,
})
rex.bind("ctrl+b>g", "grep_projects")
rex.bind("ctrl+b>ctrl+g", "grep_projects")

-- ctrl+b y: yt (~/.local/bin/yt) in a floating layer: your subscriptions
-- feed, or search results for a query (rex do youtube --args '{"query":"…"}'). The
-- picks play in their own mpv window, and the layer closes once yt exits.
-- bash -l puts ~/.local/bin on PATH. ctrl+b ctrl+y works too, for when ctrl
-- is still held.
rex.action({
  name = "youtube",
  title = "YouTube: Watch Videos",
  category = "Media",
  keywords = "yt youtube video watch mpv yt-dlp subscriptions search",
  args = { query = "string?" },
  run = function(_, args)
    local command = { BASH, "-lc", "yt" }
    if args and args.query and args.query ~= "" then
      command = { BASH, "-lc", 'yt "$@"', "bash", args.query }
    end
    local _, err = rex.session.new_layer({
      bounds = { 0.1, 0.1, 0.8, 0.8 },
      focus = true,
      layout = rex.layout.block({
        flavor = "com.superlogical.terminal.shell",
        label = "yt",
        options = { shell = "none", command = command },
      }),
    })
    if err ~= nil then
      error(err, 0)
    end
    return true
  end,
})
rex.bind("ctrl+b>y", "youtube")
rex.bind("ctrl+b>ctrl+y", "youtube")

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
      options = { shell = "none", command = { BASH, "-lc", "fzf-rex-grep" } },
    }),
  })
  return true
end
rex.bind("ctrl+b>s", grep_scrollback)
rex.bind("ctrl+b>ctrl+s", grep_scrollback)

-- ctrl+b u: pick URL(s) from the focused block's scrollback with fzf in a
-- floating layer, and view each in a best-fit split of that block: Linear issues
-- with linear issue view, GitHub PRs, issues and repos with gh, Jira issues and
-- Confluence pages with twg; CTRL-B, or a URL with no viewer, opens the browser,
-- and CTRL-/ toggles a preview (see utils/.local/bin/fzf-urls). The layer's
-- own block is a new one, so the focused block is passed as an argument.
-- ctrl+b ctrl+u works too, for when ctrl is still held. An optional flag
-- narrows the list (e.g. "--pr", for GitHub: Open PR in Browser below);
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
            BASH,
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

-- The best-fit direction to split the focused block: along its longer side in
-- pixels, "horizontal" (beside it) when it is at least as wide as it is tall,
-- else "vertical" (below it). Beside it when its size can't be read. The
-- shell scripts use utils/.local/bin/rex-best-fit, the same rule.
local function best_fit(ctx)
  if not ctx.block_id then
    return "horizontal"
  end
  local ok, size = pcall(rex.block.call, "com.superlogical.terminal", "size", {
    session_id = ctx.session_id,
    block_id = ctx.block_id,
  })
  if
    ok
    and size
    and size.columns
    and size.rows
    and size.cell_width_px
    and size.cell_height_px
    and size.rows * size.cell_height_px > size.columns * size.cell_width_px
  then
    return "vertical"
  end
  return "horizontal"
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

-- A program (a coding agent, or nvim) in the focused block's working
-- directory, opened where `where` says:
--   split   a best-fit split of the focused block (best_fit: beside it, or
--           below it when it is taller than wide)
--   window  a new window (tab), labelled `label`
--   float   a floating layer, like a tmux popup
-- bash -lic loads the profile so the program has the usual PATH; shell =
-- "none" keeps Rex from loading it a second time. The program and its
-- arguments reach bash as arguments, never as shell code.
local function program_open(where, label, ...)
  local command = { BASH, "-lic", 'exec "$@"', "bash" }
  for _, arg in ipairs({ ... }) do
    command[#command + 1] = arg
  end
  return function(ctx)
    local layout = rex.layout.block({
      flavor = "com.superlogical.terminal.shell",
      label = label,
      options = {
        shell = "none",
        cwd = block_cwd(ctx),
        command = command,
      },
    })
    local _, err
    if where == "window" then
      _, err = rex.session.new_window({
        session_id = ctx.session_id,
        window_label = label,
        focus = true,
        layout = layout,
      })
    elseif where == "float" then
      _, err = rex.session.new_layer({
        bounds = { 0.1, 0.1, 0.8, 0.8 },
        focus = true,
        layout = layout,
      })
    else
      _, err = rex.session.new_split({
        session_id = ctx.session_id,
        anchor_id = ctx.block_id,
        direction = best_fit(ctx),
        side = "after",
        ratio = 0.5,
        focus = true,
        layout = layout,
      })
    end
    if err ~= nil then
      error(err, 0)
    end
    return true
  end
end

-- A coding agent in the focused block's working directory, picked with fzf
-- in the new window, split or floating layer. Esc closes it without starting
-- one. ctrl+b a or Hyper+Enter opens it in a split (ctrl+b ctrl+a for when
-- ctrl is still held). Rex has no hyper modifier, so Hyper is written as
-- Tinycast's, ctrl+alt+cmd.
local AGENT_PICKER = [[agent=$(printf '%s\n' claude pi copilot |
  fzf --reverse --no-multi --prompt='agent> ') || exit 0
exec "$agent"]]
for _, a in ipairs({
  {
    where = "window",
    name = "agent_window",
    title = "New Window",
    keywords = "tab",
  },
  {
    where = "split",
    name = "agent_split",
    title = "Split Window",
    keywords = "split pane",
  },
  {
    where = "float",
    name = "agent_float",
    title = "Floating Window",
    keywords = "floating layer popup",
  },
}) do
  rex.action({
    name = a.name,
    title = "Open Agent in " .. a.title,
    category = "Agents",
    keywords = "claude code anthropic pi copilot github cli coding agent picker fzf cwd here "
      .. a.keywords,
    run = program_open(a.where, "agent", "bash", "-c", AGENT_PICKER),
  })
end
rex.bind("ctrl+b>a", "agent_split")
rex.bind("ctrl+b>ctrl+a", "agent_split")
rex.bind("ctrl+alt+cmd+enter", "agent_split")

rex.action({
  name = "nvim_cwd",
  title = "Open Neovim in Current Directory",
  category = "Editor",
  keywords = "nvim vim editor edit files cwd split here",
  run = program_open("split", "nvim", "nvim", "."),
})

-- A pane that runs script (bash -lc) in cwd, then waits for a key and
-- closes, so its output stays readable once it finishes (or fails, e.g.
-- when there's no PR). A script that exits 130, stopped by the user (Esc),
-- closes it at once. Any further arguments reach the script as $0, $1, …,
-- never as shell code.
local function watch_pane(label, script, cwd, ...)
  local command = {
    BASH,
    "-lc",
    script .. "; (($? == 130)) || read -rsn1 -p 'Press any key to close'",
  }
  for _, arg in ipairs({ ... }) do
    command[#command + 1] = arg
  end
  return rex.layout.block({
    flavor = "com.superlogical.terminal.shell",
    label = label,
    options = { shell = "none", cwd = cwd, command = command },
  })
end

-- The focused block's branch's PR, watched in a best-fit split, in that
-- block's working directory: its comments, reviews and inline review
-- comments, then its CI checks and Scalr plans (or, once merged, applies) at
-- the bottom, redrawn as they change
-- (utils/.local/bin/gh-pr-watch). Without a PR on the branch,
-- the split takes focus to pick one of the repo's open PRs with fzf, then
-- hands focus back to the focused block, which is passed to it.
rex.action({
  name = "gh_pr_watch_split",
  title = "GitHub: Watch PR in Split Pane",
  category = "GitHub",
  keywords = "github pull request ci checks actions comments reviews feedback watch pane worktree",
  run = function(ctx)
    local _, err = rex.session.new_split({
      session_id = ctx.session_id,
      anchor_id = ctx.block_id,
      direction = best_fit(ctx),
      side = "after",
      ratio = 0.67, -- the anchor keeps 67%; the watch split gets 33%
      focus = false,
      layout = watch_pane(
        "gh-pr",
        "gh-pr-watch '" .. (ctx.block_id or "") .. "'",
        block_cwd(ctx)
      ),
    })
    if err ~= nil then
      error(err, 0)
    end
    return true
  end,
})
rex.bind("ctrl+b>w", "gh_pr_watch_split")
rex.bind("ctrl+b>ctrl+w", "gh_pr_watch_split")

-- Git in the focused block's working directory, in a floating layer.
-- Command palette only, no keys.
--   git_status    git status
--   git_diff      git diff (unstaged changes), always paged with less; q
--                 closes the layer
--   git_pull      git pull
--   git_checkout  pick a local or remote branch with fzf and check it out
--                 (utils/.local/bin/git-fzf-checkout; ALT-F fetches, ALT-D
--                 deletes); Esc closes the layer at once
-- All but git_diff wait for a key once git is done, so its output stays
-- readable (see watch_pane).
for _, a in ipairs({
  {
    name = "git_status",
    title = "Git Status",
    keywords = "git status changes modified staged untracked working tree",
    script = "git status",
    bounds = { 0.2, 0.2, 0.6, 0.6 },
  },
  {
    name = "git_diff",
    title = "Git Diff",
    keywords = "git diff changes patch unstaged working tree",
    -- less without -F, so even a short diff stays up until q
    command = { BASH, "-lc", "GIT_PAGER='less -R' git diff" },
    bounds = { 0.1, 0.1, 0.8, 0.8 },
  },
  {
    name = "git_pull",
    title = "Git Pull",
    keywords = "git pull fetch update sync upstream remote",
    script = "git pull",
    bounds = { 0.2, 0.2, 0.6, 0.6 },
  },
  {
    name = "git_checkout",
    title = "Git Checkout Branch",
    keywords = "git checkout switch branch fzf picker remote",
    script = "git-fzf-checkout",
    bounds = { 0.1, 0.1, 0.8, 0.8 },
  },
}) do
  rex.action({
    name = a.name,
    title = a.title,
    category = "Git",
    keywords = a.keywords,
    run = function(ctx)
      local label, cwd = a.name:gsub("_", "-"), block_cwd(ctx)
      local layout
      if a.command then
        layout = rex.layout.block({
          flavor = "com.superlogical.terminal.shell",
          label = label,
          options = { shell = "none", cwd = cwd, command = a.command },
        })
      else
        layout = watch_pane(label, a.script, cwd)
      end
      local _, err = rex.session.new_layer({
        bounds = a.bounds,
        focus = true,
        layout = layout,
      })
      if err ~= nil then
        error(err, 0)
      end
      return true
    end,
  })
end

-- Homebrew in a floating layer. Command palette only, no keys.
--   brew_upgrade  brew upgrade (brew updates itself first), then brew cleanup
--                 --prune=all, which removes old versions and the whole
--                 download cache
--   brew_search   search formulae and casks by name and description as you
--                 type (an empty query lists what's installed); ENTER
--                 installs the picks, ALT-D uninstalls them
--                 (utils/.local/bin/fzf-brew-search)
-- brew_search takes an optional starting query (rex do brew_search --args
-- '{"query":"…"}'), which reaches bash as an argument, never as shell code.
-- Each waits for a key once brew is done, so its output stays readable; Esc
-- in the picker closes the layer at once (see watch_pane).
for _, a in ipairs({
  {
    name = "brew_upgrade",
    title = "Homebrew: Upgrade Packages",
    keywords = "brew homebrew upgrade update outdated formulae casks packages cleanup prune cache",
    script = "brew upgrade && brew cleanup --prune=all",
  },
  {
    name = "brew_search",
    title = "Homebrew: Search Packages",
    keywords = "brew homebrew search find description formula cask package install uninstall remove delete fzf picker",
    script = 'fzf-brew-search "$0"',
  },
}) do
  rex.action({
    name = a.name,
    title = a.title,
    category = "Homebrew",
    keywords = a.keywords,
    args = { query = "string?" },
    run = function(_, args)
      local _, err = rex.session.new_layer({
        bounds = { 0.1, 0.1, 0.8, 0.8 },
        focus = true,
        -- The query is the script's $0 (brew_upgrade ignores it).
        layout = watch_pane(
          (a.name:gsub("_", "-")),
          a.script,
          nil,
          (args and args.query) or ""
        ),
      })
      if err ~= nil then
        error(err, 0)
      end
      return true
    end,
  })
end

-- Send to Agent: pick work items with fzf in a floating layer and send each
-- in turn to fai, which picks a directory and starts an agent there with the
-- item's URL in its prompt. bash -li, as for fai, so the agents get the usual
-- PATH and environment.
--   linear_agent  open Linear tasks, filtered by team, assignee and status
--                 with ALT-T, ALT-A and ALT-S (utils/.local/bin/linear-agent)
--   gh_agent      PRs that need your attention (gh attention), filtered by
--                 section, repo and author with ALT-S, ALT-R and ALT-A
--                 (utils/.local/bin/gh-attention-agent)
local function agent_picker(label, script)
  return function()
    local _, err = rex.session.new_layer({
      bounds = { 0.05, 0.05, 0.9, 0.9 },
      focus = true,
      layout = rex.layout.block({
        flavor = "com.superlogical.terminal.shell",
        label = label,
        options = { shell = "none", command = { BASH, "-lic", script } },
      }),
    })
    if err ~= nil then
      error(err, 0)
    end
    return true
  end
end

rex.action({
  name = "linear_agent",
  title = "Linear: Send Task to Agent",
  category = "Linear",
  keywords = "linear ticket task bug issue fai claude agent repo team assignee status",
  run = agent_picker("linear", "linear-agent"),
})

-- linear_cycle  my Linear tasks in my teams' active cycles, filtered by
--               status with ALT-S (utils/.local/bin/linear-cycle)
rex.action({
  name = "linear_cycle",
  title = "Linear: View My Tasks in Floating Window",
  category = "Linear",
  keywords = "linear my tasks issues tickets assigned me cycle sprint current active status fai claude agent",
  run = agent_picker("linear-cycle", "linear-cycle"),
})

-- linear_search  Linear tasks across the workspace whose text matches the
--                query, searched as you type (utils/.local/bin/linear-search)
rex.action({
  name = "linear_search",
  title = "Linear: Search Tasks in Floating Window",
  category = "Linear",
  keywords = "linear search find query text tasks issues tickets full-text fai claude agent",
  run = agent_picker("linear-search", "linear-search"),
})

rex.action({
  name = "gh_agent",
  title = "GitHub: Send Attention to Agent",
  category = "GitHub",
  keywords = "github pull request pr review failing ci approved feedback attention fai claude agent",
  run = agent_picker("gh-attention", "gh-attention-agent"),
})

-- ctrl+b v …: view an issue or page from the focused block's scrollback in a
-- best-fit split of it, picked with fzf-urls and a flag (see pick_urls): a
-- single match opens without the picker, and CTRL-B opens the browser instead.
--   l  a Linear issue, from issue URLs and IDs (fzf-urls --linear)
--   j  a Jira issue, from browse URLs and issue keys (fzf-urls --jira)
--   c  a Confluence page or blog post (fzf-urls --confluence)
for _, a in ipairs({
  {
    key = "l",
    name = "linear_view_split",
    title = "Linear: View Task in Split Pane",
    category = "Linear",
    keywords = "linear ticket task bug issue show read scrollback url",
    flag = "--linear",
  },
  {
    key = "j",
    name = "jira_view_split",
    title = "View Jira Issue in Split Pane",
    category = "Atlassian",
    keywords = "jira atlassian twg ticket work item issue show read scrollback url",
    flag = "--jira",
  },
  {
    key = "c",
    name = "confluence_view_split",
    title = "View Confluence Page in Split Pane",
    category = "Atlassian",
    keywords = "confluence atlassian twg wiki page doc blog show read scrollback url",
    flag = "--confluence",
  },
}) do
  rex.action({
    name = a.name,
    title = a.title,
    category = a.category,
    keywords = a.keywords,
    run = url_picker(a.flag),
  })
  rex.bind("ctrl+b>v>" .. a.key, a.name)
end

-- ctrl+b o …: open something in the browser. u, r, p and c fuzzy-pick
-- from the focused block's scrollback (fzf-urls with a flag, see pick_urls);
-- f and l pick from the block's git repo.
--   u  any URL, each listed once (fzf-urls --url)
--   r  a GitHub repo, from any GitHub URL or reference (fzf-urls --repo)
--   p  a GitHub PR, from PR URLs and references (fzf-urls --pr)
--   c  a PR's checks tab (fzf-urls --checks)
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
          command = { BASH, "-lc", 'fzf-gh-browse "$0"', mode },
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
    title = "GitHub: Open Repo in Browser",
    category = "GitHub",
    keywords = "github repository browse",
    run = url_picker("--repo"),
  },
  {
    key = "p",
    name = "gh_open_pr",
    title = "GitHub: Open PR in Browser",
    category = "GitHub",
    keywords = "github pull request review",
    run = url_picker("--pr"),
  },
  {
    key = "c",
    name = "gh_open_checks",
    title = "GitHub: Open PR Checks in Browser",
    category = "GitHub",
    keywords = "github ci actions build status failing",
    run = url_picker("--checks"),
  },
  {
    key = "f",
    name = "gh_open_file",
    title = "GitHub: Open File in Browser (Permalink)",
    category = "GitHub",
    keywords = "source link share",
    run = gh_pick("files"),
  },
  {
    key = "l",
    name = "gh_open_line",
    title = "GitHub: Open Line in Browser (Permalink)",
    category = "GitHub",
    keywords = "source link share blame",
    run = gh_pick("lines"),
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

-- ctrl+b [: enter copy mode in the focused pane, as in tmux. ctrl+b ctrl+[
-- works too, for when ctrl is still held.
rex.bind("ctrl+b>[", "pane.copy_mode.enter")
rex.bind("ctrl+b>ctrl+[", "pane.copy_mode.enter")

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
          command = { BASH, "-lc", "rex keymap --color always | less -R" },
        },
      }),
    })
    return true
  end,
})
rex.bind("ctrl+b>shift+/", "show_keymap")
