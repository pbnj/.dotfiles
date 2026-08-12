-- Scalr workspace picker, built on plain Neovim primitives.
--
-- Evaluation-phase alternative to the `scalr_workspaces` Snacks source in
-- lua/plugins/snacks.lua (kept there, commented out). The <c-o>/<c-r> picker
-- keymaps become a second `vim.ui.select()` step plus `:Scalr refresh`.
-- Selecting "Runs" still hands off to the `scalr_runs` Snacks source, which
-- is untouched.

local CACHE = vim.fn.expand("~/.cache/scalr/workspaces.json")

---@return table[]
local function read_cache()
  if vim.fn.filereadable(CACHE) ~= 1 then
    return {}
  end
  local ok, decoded =
    pcall(vim.json.decode, vim.fn.join(vim.fn.readfile(CACHE), "\n"))
  if ok and type(decoded) == "table" and #decoded > 0 then
    return decoded
  end
  return {}
end

---@return table[]
local function fetch()
  local result = vim
    .system({ "scalr", "get-workspaces" }, { text = true })
    :wait()
  if result.code ~= 0 then
    vim.notify(
      "scalr get-workspaces failed: " .. vim.trim(result.stderr or ""),
      vim.log.levels.ERROR
    )
    return {}
  end
  local ok, all = pcall(vim.json.decode, result.stdout)
  if not ok or type(all) ~= "table" then
    vim.notify("Could not parse scalr get-workspaces", vim.log.levels.ERROR)
    return {}
  end
  local workspaces = vim
    .iter(all)
    :map(function(ws)
      return { name = ws.name, id = ws.id, environment = ws.environment }
    end)
    :totable()
  vim.fn.mkdir(vim.fn.fnamemodify(CACHE, ":h"), "p")
  vim.fn.writefile({ vim.json.encode(workspaces) }, CACHE)
  return workspaces
end

---@return table[]
local function workspaces()
  local cached = read_cache()
  if #cached > 0 then
    return cached
  end
  return fetch()
end

local CONF = vim.fn.expand("~/.scalr/scalr.conf")

---SCALR_HOSTNAME if exported, else `.hostname` from scalr.conf (the same
---place utils/.local/bin/fzf-scalr reads it from).
---@return string?
local function hostname()
  local env = vim.env.SCALR_HOSTNAME
  if env and env ~= "" then
    return env
  end
  if vim.fn.filereadable(CONF) ~= 1 then
    return nil
  end
  local ok, conf =
    pcall(vim.json.decode, vim.fn.join(vim.fn.readfile(CONF), "\n"))
  if ok and type(conf) == "table" and conf.hostname ~= "" then
    return conf.hostname
  end
  return nil
end

---@param item table
local function open_browser(item)
  local host = hostname()
  if not host then
    vim.notify(
      "No Scalr hostname: set SCALR_HOSTNAME or run `scalr -configure`",
      vim.log.levels.WARN
    )
    return
  end
  vim.ui.open(
    string.format(
      "%s/v2/e/%s/workspaces/%s/",
      host,
      item.environment.id,
      item.id
    )
  )
end

---@param item table
local function open_runs(item)
  -- The runs picker is still the Snacks source; only the workspace list is
  -- being evaluated here.
  Snacks.picker.scalr_runs({
    workspace_id = item.id,
    workspace_name = item.name,
    environment_id = item.environment.id,
    title = string.format("Scalr Runs (%s)", item.name),
  })
end

---@param item table
local function pick_action(item)
  local actions = {
    {
      label = "Runs",
      run = function()
        open_runs(item)
      end,
    },
    {
      label = "Open in Browser",
      run = function()
        open_browser(item)
      end,
    },
    {
      label = "Yank ID",
      run = function()
        vim.fn.setreg('"', item.id)
        vim.fn.setreg("+", item.id)
        vim.notify("Yanked id: " .. item.id)
      end,
    },
  }
  vim.ui.select(actions, {
    prompt = item.name,
    format_item = function(action)
      return action.label
    end,
  }, function(action)
    if action then
      action.run()
    end
  end)
end

local function scalr()
  local items = workspaces()
  if #items == 0 then
    vim.notify("No Scalr workspaces found", vim.log.levels.WARN)
    return
  end
  table.sort(items, function(a, b)
    return a.name < b.name
  end)
  vim.ui.select(items, {
    prompt = "Scalr Workspaces",
    format_item = function(item)
      return item.name
    end,
  }, function(item)
    if item then
      pick_action(item)
    end
  end)
end

vim.api.nvim_create_user_command("Scalr", function(opts)
  if opts.args == "refresh" then
    vim.fn.delete(CACHE)
    local fetched = fetch()
    vim.notify(string.format("Cached %d Scalr workspaces", #fetched))
    return
  end
  scalr()
end, {
  nargs = "?",
  desc = "Scalr workspace picker (`refresh` to rebuild the cache)",
  complete = function()
    return { "refresh" }
  end,
})

vim.keymap.set("n", "<leader>ws", scalr, { desc = "[W]ork [S]calr Workspaces" })
