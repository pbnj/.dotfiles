-- Workspace project picker, built on plain Neovim primitives.
--
-- Evaluation-phase alternative to the `workspace_projects` Snacks source in
-- lua/plugins/snacks.lua (kept there, commented out). Differences worth
-- judging: no fuzzy matching / frecency / git-log preview, and no
-- multi-select -- `vim.ui.select()` returns one item, so the "open several
-- projects at once" path is gone. The <c-d> trash keymap becomes
-- `:Projects trash`.
--
-- Typing a GitHub `org/repo` that matches nothing and pressing <cr> clones it
-- into ~/Projects/github.com/<org>/<repo> and opens it. That path needs the
-- typed query, which only the Snacks picker exposes -- see `select()`.

local ROOTS = {
  vim.fn.expand("~/Projects"),
  vim.fn.expand("~/.dotfiles"),
}

local GITHUB_ROOT = vim.fn.expand("~/Projects/github.com")

---@return table[]
local function projects()
  local cmd = {
    "fd",
    "--hidden",
    "--no-ignore",
    "--type",
    "d",
    "--max-depth",
    "5",
    "^\\.git$",
  }
  vim.list_extend(cmd, ROOTS)
  local result = vim.system(cmd, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify(
      "fd failed: " .. vim.trim(result.stderr or ""),
      vim.log.levels.ERROR
    )
    return {}
  end
  local home = vim.fn.expand("~")
  local items = vim
    .iter(vim.split(result.stdout, "\n", { trimempty = true }))
    :map(function(gitdir)
      -- fd prints directories with a trailing slash; strip it so dirname
      -- yields the repo root instead of the .git dir.
      local dir = vim.fs.dirname((gitdir:gsub("/+$", "")))
      return {
        text = (dir:gsub("^" .. vim.pesc(home) .. "/", "~/")),
        dir = dir,
        label = vim.fs.basename(dir),
      }
    end)
    :totable()
  table.sort(items, function(a, b)
    return a.text < b.text
  end)
  return items
end

---Existing Herdr workspaces, keyed by label.
---@return table<string, string>
local function herdr_workspaces()
  local existing = {}
  local list = vim
    .system({ "herdr", "workspace", "list" }, { text = true })
    :wait()
  local ok, decoded = pcall(vim.json.decode, list.stdout or "")
  if ok and decoded and decoded.result then
    for _, ws in ipairs(decoded.result.workspaces or {}) do
      existing[ws.label] = ws.workspace_id
    end
  end
  return existing
end

---Existing tmux panes, keyed by their cwd.
---@return table<string, table>
local function tmux_panes_by_path()
  local existing = {}
  local panes = vim
    .system({
      "tmux",
      "list-panes",
      "-a",
      "-F",
      "#{session_name}\t#{window_index}\t#{pane_id}\t#{pane_current_path}",
    }, { text = true })
    :wait()
  if panes.code ~= 0 then
    return existing
  end
  for _, line in ipairs(vim.split(panes.stdout, "\n", { trimempty = true })) do
    local fields = vim.split(line, "\t", { plain = true })
    if #fields == 4 then
      existing[fields[4]] = {
        session_name = fields[1],
        window_index = fields[2],
        pane_id = fields[3],
      }
    end
  end
  return existing
end

---@param project table
local function open_project(project)
  -- Herdr exports HERDR_ENV for processes it manages. Prefer it when present
  -- in case a Herdr pane is itself running under tmux.
  if vim.env.HERDR_ENV == "1" then
    local existing = herdr_workspaces()[project.label]
    if existing then
      vim.system({ "herdr", "workspace", "focus", existing }):wait()
    else
      vim
        .system({
          "herdr",
          "workspace",
          "create",
          "--cwd",
          project.dir,
          "--label",
          project.label,
          "--focus",
        })
        :wait()
    end
  elseif vim.env.TMUX and vim.env.TMUX ~= "" then
    local pane = tmux_panes_by_path()[project.dir]
    if pane then
      vim
        .system({
          "tmux",
          "switch-client",
          "-t",
          string.format("%s:%s", pane.session_name, pane.window_index),
        })
        :wait()
      vim.system({ "tmux", "select-pane", "-t", pane.pane_id }):wait()
    else
      vim
        .system({
          "tmux",
          "new-window",
          "-c",
          project.dir,
          "-n",
          project.label,
        })
        :wait()
    end
  else
    vim.notify(
      "Workspace Projects requires Herdr or tmux",
      vim.log.levels.ERROR
    )
  end
end

---Clone `slug` into ~/Projects/github.com/<org>/<repo> and open it. Accepts a
---bare `org/repo` or a github.com URL, matching `fzf-gh-clone`'s normalization.
---@param slug string
---@param finish fun() called once the clone (and open) has settled
local function clone_and_open(slug, finish)
  slug =
    slug:gsub("^https?://github%.com/", ""):gsub("%.git$", ""):gsub("/+$", "")
  -- A half-typed query is not an error worth reporting; just bail.
  if not slug:match("^[%w][%w._%-]*/[%w._%-]+$") then
    finish()
    return
  end
  local dir = GITHUB_ROOT .. "/" .. slug
  local project = {
    dir = dir,
    label = vim.fs.basename(dir),
    text = (dir:gsub("^" .. vim.pesc(vim.fn.expand("~")) .. "/", "~/")),
  }
  -- A directory without a `.git` never shows up in `projects()`, so an existing
  -- path here means "already cloned" rather than "clone over it".
  if vim.fn.isdirectory(dir) == 1 then
    open_project(project)
    finish()
    return
  end
  vim.notify("Cloning " .. slug .. "...")
  -- Async: `finish` is the picker's `done()`, which quits Neovim in standalone
  -- mode -- deferring it keeps us alive until the window exists.
  vim.system(
    { "gh", "repo", "clone", slug, dir },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        vim.notify(
          string.format(
            "Failed to clone %s: %s",
            slug,
            vim.trim(result.stderr or "")
          ),
          vim.log.levels.ERROR
        )
        finish()
        return
      end
      vim.notify("Cloned " .. project.text)
      open_project(project)
      finish()
    end)
  )
end

---@param project table
local function trash_project(project)
  local choice = vim.fn.confirm(
    string.format("Trash project?\n%s", project.text),
    "&Yes\n&No",
    2,
    "Question"
  )
  if choice ~= 1 then
    return
  end
  local result = vim.system({ "trash", project.dir }, { text = true }):wait()
  if result.code == 0 then
    vim.notify("Trashed " .. project.text)
  else
    vim.notify(
      string.format(
        "Failed to trash %s: %s",
        project.text,
        vim.trim(result.stderr or "")
      ),
      vim.log.levels.ERROR
    )
  end
end

---Snacks installs its `vim.ui.select` override when its picker is set up on
---UIEnter, which fires *after* `-c` startup commands -- so `nvim -c 'Projects'`
---would otherwise get the builtin prompt. Resolve the picker at call time and
---prefer Snacks, falling back to the builtin when it isn't available.
---`on_choice` is called with the chosen item, or -- when <cr> is pressed with
---nothing matching -- with the typed query as the second argument. Only the
---Snacks picker exposes its query, so the builtin fallback never passes one.
---@param items table[]
---@param opts table
---@param on_choice fun(item?: table, query?: string)
local function select(items, opts, on_choice)
  local ok, snacks = pcall(require, "snacks")
  if ok then
    local picker = snacks.config.get("picker", { ui_select = true })
    if picker.enabled and picker.ui_select then
      -- Overriding `actions.confirm` replaces the shim's, whose `completed`
      -- flag is a local we can't set -- so closing the picker still runs its
      -- `on_close`, which schedules `on_choice(nil)`. Fire once, and claim the
      -- guard *synchronously* before `p:close()`: the shim's cancel path is
      -- queued while we close, so a deferred claim would lose the race and our
      -- choice would arrive as a cancellation.
      local completed = false
      local function finish(item, query)
        if completed then
          return
        end
        completed = true
        -- Defer the work itself so it runs after the picker has closed.
        vim.schedule(function()
          on_choice(item, query)
        end)
      end
      opts.snacks = vim.tbl_deep_extend("force", opts.snacks or {}, {
        actions = {
          confirm = function(p, item)
            local query = vim.trim((p:filter() or {}).pattern or "")
            finish(item and item.item or nil, query)
            p:close()
          end,
        },
      })
      return snacks.picker.select(items, opts, finish)
    end
  end
  return vim.ui.select(items, opts, on_choice)
end

---@param action fun(project: table)
---@param prompt string
---@param standalone? boolean picker owns the screen and `nvim` exits with it
---@param on_query? fun(query: string, done: fun()) handles <cr> on no match
local function pick(action, prompt, standalone, on_query)
  local function done()
    if standalone then
      vim.cmd("qa!")
    end
  end
  local items = projects()
  -- With `on_query` the picker is still useful when empty -- a slug can be
  -- typed into it.
  if #items == 0 and not on_query then
    vim.notify("No projects found", vim.log.levels.WARN)
    done()
    return
  end
  select(items, {
    prompt = prompt,
    format_item = function(item)
      return item.text
    end,
    -- Snacks' `vim.ui.select` shim builds its own layout, so overrides have to
    -- ride along under `snacks` rather than the usual top-level `layout` key.
    -- Its `layout.config` fits the list box to the item count with a possibly
    -- fractional row count -- harmless while the box is sized relative to a
    -- float, fatal once fullscreen makes it absolute ("Invalid 'height'").
    -- Replace it with a no-op and let the list fill the screen.
    snacks = standalone and {
      layout = {
        preset = "vscode",
        fullscreen = true,
        config = function() end,
      },
    } or nil,
  }, function(item, query)
    if item then
      action(item)
    elseif query and query ~= "" and on_query then
      -- <cr> with nothing matching: `on_query` owns `done()` so an async clone
      -- can finish before a standalone picker quits Neovim.
      return on_query(query, done)
    end
    -- Both branches quit: `item` is nil when the picker was cancelled, and a
    -- standalone picker has nothing left to show either way.
    done()
  end)
end

vim.api.nvim_create_user_command("Projects", function(opts)
  if opts.args == "trash" then
    pick(trash_project, "Trash Project", opts.bang)
    return
  end
  pick(open_project, "Workspace Projects", opts.bang, clone_and_open)
end, {
  bang = true,
  nargs = "?",
  desc = "Workspace project picker (<cr> on an unmatched `org/repo` clones it "
    .. "from GitHub; `trash` to delete a project directory; `!` for a "
    .. "fullscreen picker that quits Neovim when it closes)",
  complete = function()
    return { "trash" }
  end,
})

vim.keymap.set("n", "<leader>wp", function()
  pick(open_project, "Workspace Projects", false, clone_and_open)
end, { desc = "[W]orkspace [P]rojects" })
