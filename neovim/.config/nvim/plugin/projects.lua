-- Workspace project picker, built on plain Neovim primitives.
--
-- Evaluation-phase alternative to the `workspace_projects` Snacks source in
-- lua/plugins/snacks.lua (kept there, commented out). Differences worth
-- judging: no fuzzy matching / frecency / git-log preview, and no
-- multi-select -- `vim.ui.select()` returns one item, so the "open several
-- projects at once" path is gone. The <c-d> trash keymap becomes
-- `:Projects trash`.

local ROOTS = {
  vim.fn.expand("~/Projects"),
  vim.fn.expand("~/.dotfiles"),
}

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

---@param action fun(project: table)
---@param prompt string
local function pick(action, prompt)
  local items = projects()
  if #items == 0 then
    vim.notify("No projects found", vim.log.levels.WARN)
    return
  end
  vim.ui.select(items, {
    prompt = prompt,
    format_item = function(item)
      return item.text
    end,
  }, function(item)
    if item then
      action(item)
    end
  end)
end

vim.api.nvim_create_user_command("Projects", function(opts)
  if opts.args == "trash" then
    pick(trash_project, "Trash Project")
    return
  end
  pick(open_project, "Workspace Projects")
end, {
  nargs = "?",
  desc = "Workspace project picker (`trash` to delete a project directory)",
  complete = function()
    return { "trash" }
  end,
})

vim.keymap.set("n", "<leader>wp", function()
  pick(open_project, "Workspace Projects")
end, { desc = "[W]orkspace [P]rojects" })
