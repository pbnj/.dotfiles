-- Okta app launcher, built on plain Neovim primitives.
--
-- Evaluation-phase alternative to the `okta_apps` Snacks source in
-- lua/plugins/snacks.lua (kept there, commented out). No fuzzy matching or
-- frecency; otherwise identical (select an app, open its link).
--
-- `:Okta refresh` rebuilds the cache. Both Okta app endpoints reject anything
-- but a live browser session (403 E0000005 / 401), and this org runs Identity
-- Engine, so there is no credential to script with: instead the endpoint is
-- opened in the browser, where an existing Okta session renders the JSON, and
-- that JSON is handed back via the clipboard or a saved file.

local APPS = vim.fn.expand("~/.okta/apps.json")
local BACKUP = APPS .. ".bak"

-- Flat array of app links. The enduser dashboard endpoint
-- (/enduser/api/v1/sections?expand=items%2Citems.resource) is where the
-- original cache came from and imports fine too -- worth trying if this one
-- returns fewer apps than the dashboard shows, which Okta documents as
-- possible.
local APPLINKS_URL = "https://komodohealth.okta.com/api/v1/users/me/appLinks"

---Flatten any of the shapes Okta hands out into `{label, url}` pairs:
---  * flat `[{label, url}]`             -- what :Okta refresh writes
---  * `[{label, linkUrl}]`              -- /api/v1/users/me/appLinks
---  * `[{_embedded={items={...}}}]`     -- /enduser/api/v1/sections
---  * `{["0"]={_embedded={items=...}}}` -- the legacy hand-captured cache
---@param decoded table
---@return table[]
local function normalize(decoded)
  local items = {}
  local function visit(entry)
    if type(entry) ~= "table" then
      return
    end
    local resource = entry._embedded and entry._embedded.resource or entry
    local label = resource.label
    local url = resource.url or resource.linkUrl
    if label and url then
      items[#items + 1] = { label = label, url = url }
      return
    end
    -- A section (or the legacy wrapper): recurse into its items.
    local nested = entry._embedded and entry._embedded.items
    for _, child in ipairs(nested or {}) do
      visit(child)
    end
  end
  -- Object-keyed wrappers ("0") iterate with pairs, arrays with ipairs; pairs
  -- covers both.
  for _, entry in pairs(decoded) do
    visit(entry)
  end
  table.sort(items, function(a, b)
    if a.label == b.label then
      return a.url < b.url
    end
    return a.label < b.label
  end)
  -- The shell picker deduped with `sort -u`; keep parity.
  local seen, unique = {}, {}
  for _, item in ipairs(items) do
    local key = item.label .. "\0" .. item.url
    if not seen[key] then
      seen[key] = true
      unique[#unique + 1] = item
    end
  end
  return unique
end

---@param json string
---@param source string
---@return table[]?
local function parse(json, source)
  if vim.trim(json) == "" then
    vim.notify("Nothing to import from " .. source, vim.log.levels.WARN)
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, json)
  if not ok or type(decoded) ~= "table" then
    vim.notify("Could not parse JSON from " .. source, vim.log.levels.ERROR)
    return nil
  end
  -- A dead browser session renders an error payload rather than app links;
  -- surface it instead of overwriting the cache with nothing.
  if decoded.errorSummary or decoded.errorCode then
    vim.notify(
      "Okta says: " .. (decoded.errorSummary or decoded.errorCode),
      vim.log.levels.ERROR
    )
    return nil
  end
  return normalize(decoded)
end

---@return table[]
local function apps()
  if vim.fn.filereadable(APPS) ~= 1 then
    vim.notify(
      "No Okta app cache at " .. APPS .. " -- run :Okta refresh",
      vim.log.levels.WARN
    )
    return {}
  end
  return parse(vim.fn.join(vim.fn.readfile(APPS), "\n"), APPS) or {}
end

---@param items table[]
local function write_cache(items)
  if #items == 0 then
    vim.notify("No apps found; cache left alone", vim.log.levels.WARN)
    return
  end
  local before = #apps()
  if vim.fn.filereadable(APPS) == 1 then
    vim.fn.writefile(vim.fn.readfile(APPS), BACKUP)
  end
  vim.fn.mkdir(vim.fn.fnamemodify(APPS, ":h"), "p")
  vim.fn.writefile({ vim.json.encode(items) }, APPS)
  vim.notify(string.format("Cached %d Okta apps (was %d)", #items, before))
end

---@param path string
local function import_file(path)
  path = vim.fn.expand(path)
  if vim.fn.filereadable(path) ~= 1 then
    vim.notify("No readable file at " .. path, vim.log.levels.ERROR)
    return
  end
  local items = parse(vim.fn.join(vim.fn.readfile(path), "\n"), path)
  if items then
    write_cache(items)
  end
end

---Newest *.json in ~/Downloads, as a starting point for the file prompt.
---@return string
local function newest_download()
  local newest, newest_time = "", -1
  for _, path in ipairs(vim.fn.glob("~/Downloads/*.json", false, true)) do
    local time = vim.fn.getftime(path)
    if time > newest_time then
      newest, newest_time = path, time
    end
  end
  return newest
end

local function refresh()
  vim.ui.open(APPLINKS_URL)
  local choice = vim.fn.confirm(
    "Opened the Okta app list in your browser.\n"
      .. "Sign in if prompted, then copy the JSON "
      .. "(Firefox: the Raw Data tab) or save it.",
    "&Clipboard\n&File\n&Cancel",
    1,
    "Question"
  )
  if choice == 1 then
    local items = parse(vim.fn.getreg("+"), "clipboard")
    if items then
      write_cache(items)
    end
  elseif choice == 2 then
    local path = vim.fn.input({
      prompt = "JSON file: ",
      default = newest_download(),
      completion = "file",
    })
    if vim.trim(path) ~= "" then
      import_file(path)
    end
  end
end

local function okta()
  local items = apps()
  if #items == 0 then
    return
  end
  vim.ui.select(items, {
    prompt = "Okta Apps",
    format_item = function(item)
      return item.label
    end,
  }, function(item)
    if not item then
      return
    end
    if not item.url then
      vim.notify("No link for " .. item.label, vim.log.levels.WARN)
      return
    end
    vim.ui.open(item.url)
  end)
end

vim.api.nvim_create_user_command("Okta", function(opts)
  local args = opts.fargs
  if args[1] == "refresh" then
    if args[2] then
      import_file(args[2])
    else
      refresh()
    end
    return
  end
  okta()
end, {
  nargs = "*",
  desc = "Okta app launcher (`refresh [path]` to rebuild the cache)",
  complete = function(arglead, cmdline)
    if cmdline:match("refresh%s+%S*$") then
      return vim.fn.getcompletion(arglead, "file")
    end
    return { "refresh" }
  end,
})

vim.keymap.set("n", "<leader>wo", okta, { desc = "[W]ork [O]kta Apps" })
