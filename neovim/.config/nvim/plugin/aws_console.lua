-- AWS Console account picker, built on plain Neovim primitives.
--
-- Evaluation-phase alternative to the `aws_console` Snacks source in
-- lua/plugins/snacks.lua (kept there, commented out). Differences worth
-- judging: no fuzzy matching / frecency / preview, no `jc` dependency (the
-- ini is parsed in Lua), and the alt-key actions become a second
-- `vim.ui.select()` step instead of picker keymaps.

local CONFIG = vim.fn.expand("~/.aws/config")
local ROLES = { "ReadOnlyAccess", "AdministratorAccess" }

---Minimal ini reader: `{ [section] = { [key] = value } }`.
---@param path string
---@return table<string, table<string, string>>?
local function read_ini(path)
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end
  local ini, section = {}, nil
  for _, raw in ipairs(vim.fn.readfile(path)) do
    local line = vim.trim(raw)
    local name = line:match("^%[(.+)%]$")
    if name then
      section = name
      ini[section] = ini[section] or {}
    elseif section ~= nil and line ~= "" and not line:match("^[;#]") then
      local key, value = line:match("^([^=]+)=(.*)$")
      if key then
        ini[section][vim.trim(key)] = vim.trim(value)
      end
    end
  end
  return ini
end

---One item per account, sorted by alias.
---@return table[]
local function accounts()
  local ini = read_ini(CONFIG)
  if not ini then
    vim.notify("No readable AWS config at " .. CONFIG, vim.log.levels.WARN)
    return {}
  end
  local default = ini.default or {}
  local items = {}
  for section, cfg in pairs(ini) do
    -- Each account appears twice: once as `[profile <account_id>]` and once
    -- as `[profile <alias>]`. Keep only the numeric sections to dedupe.
    if section:match("^profile %d+$") and cfg.sso_account_id then
      items[#items + 1] = {
        profile = string.format(
          "%s/%s/%s",
          cfg.sso_account_id,
          cfg.sso_account_alias or "",
          cfg.sso_role_name or ""
        ),
        account_id = cfg.sso_account_id,
        account_alias = cfg.sso_account_alias or "",
        account_url = cfg.sso_account_url,
        default = default,
      }
    end
  end
  table.sort(items, function(a, b)
    if a.account_alias == b.account_alias then
      return a.account_id < b.account_id
    end
    return a.account_alias < b.account_alias
  end)
  return items
end

---@param value string
---@param what string
local function yank(value, what)
  if value == nil or value == "" then
    vim.notify("No " .. what .. " to yank", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg('"', value)
  vim.fn.setreg("+", value)
  vim.notify("Yanked " .. what .. ": " .. value)
end

---Swap (or append) `role_name` in an SSO console URL.
---@param url string
---@param role string
---@return string
local function with_role(url, role)
  if url:find("role_name=") then
    return (url:gsub("role_name=[^&]*", "role_name=" .. role))
  end
  return url .. (url:find("?") and "&" or "?") .. "role_name=" .. role
end

---@param item table
local function open_console(item)
  if not item.account_url then
    vim.notify(
      "No sso_account_url for " .. item.account_id,
      vim.log.levels.WARN
    )
    return
  end
  vim.ui.select(ROLES, { prompt = "Select Role:" }, function(role)
    if not role then
      return
    end
    vim.ui.open(with_role(item.account_url, role))
  end)
end

---Open the account's user list in the IAM Identity Center console, via the
---SSO start URL so the redirect lands authenticated.
---@param item table
local function open_sso_account(item)
  local base = item.default.sso_account_url
  local instance = item.default.sso_instance
  if not base or not instance then
    vim.notify(
      "[default] needs sso_account_url and sso_instance in " .. CONFIG,
      vim.log.levels.WARN
    )
    return
  end
  local destination = string.format(
    -- luacheck: no max line length
    "https://us-west-2.console.aws.amazon.com/singlesignon/organization/home?region=us-west-2#/instances/%s/accounts/details/%s?section=users",
    instance,
    item.account_id
  )
  local encoded = vim.fn.substitute(
    vim.fn.iconv(destination, "latin1", "utf-8"),
    "[^A-Za-z0-9_.~-]",
    '\\="%".printf("%02X",char2nr(submatch(0)))',
    "g"
  )
  vim.ui.open(base .. "&destination=" .. encoded)
end

---@param item table
local function pick_action(item)
  local actions = {
    {
      label = "Open Console",
      run = function()
        open_console(item)
      end,
    },
    {
      label = "Open SSO Account (users)",
      run = function()
        open_sso_account(item)
      end,
    },
    {
      label = "Yank Alias",
      run = function()
        yank(item.account_alias, "alias")
      end,
    },
    {
      label = "Yank ID",
      run = function()
        yank(item.account_id, "id")
      end,
    },
    {
      label = "Yank Profile",
      run = function()
        yank(item.profile, "profile")
      end,
    },
  }
  vim.ui.select(actions, {
    prompt = string.format("%s  %s", item.account_id, item.account_alias),
    format_item = function(action)
      return action.label
    end,
  }, function(action)
    if action then
      action.run()
    end
  end)
end

local function aws_console()
  local items = accounts()
  if #items == 0 then
    vim.notify("No AWS SSO accounts found in " .. CONFIG, vim.log.levels.WARN)
    return
  end
  vim.ui.select(items, {
    prompt = "AWS Console",
    format_item = function(item)
      return string.format("%s  %s", item.account_id, item.account_alias)
    end,
  }, function(item)
    if item then
      pick_action(item)
    end
  end)
end

vim.api.nvim_create_user_command(
  "AWSConsole",
  aws_console,
  { desc = "AWS Console account picker" }
)

vim.keymap.set(
  "n",
  "<leader>wa",
  aws_console,
  { desc = "[W]ork [A]WS Console" }
)
