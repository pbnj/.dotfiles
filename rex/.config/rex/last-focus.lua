-- vim:ft=lua:sts=2:ts=2:sw=2:et:
-- last-focus.lua: record which block each session focuses, most recent first,
-- for the last_pane action in init.lua (ctrl+b l, like tmux's last-window).
--
-- init.lua can't handle events, so this runs beside the server as
-- `rex do --all last-focus.lua`; init.lua starts it if it isn't running. A
-- focus change, by key, mouse or API, fires session_view_changed (and
-- active_window_changed when the window changes, which session_view_changed
-- follows), so that's the one event handled.
--
-- The history goes to $XDG_STATE_HOME/rex/last-focus/<session>, one block ID
-- per line, so it survives this script restarting. A session's file is removed
-- when the session is destroyed.

local state = os.getenv("XDG_STATE_HOME")
  or (os.getenv("HOME") .. "/.local/state")
local dir = state .. "/rex/last-focus"
rex.exec({ "mkdir", "-p", dir })

-- Enough to step past closed blocks, such as floating layers.
local max_history = 20

local history = {}

local function file(session_id)
  return dir .. "/" .. session_id:gsub("[^%w%-]", "_")
end

local function load(session_id)
  local ids = {}
  local f = io.open(file(session_id))
  if f then
    for id in f:lines() do
      ids[#ids + 1] = id
    end
    f:close()
  end
  return ids
end

local function save(session_id, ids)
  local path = file(session_id)
  local f = io.open(path .. ".tmp", "w")
  if not f then
    return
  end
  f:write(table.concat(ids, "\n"), "\n")
  f:close()
  os.rename(path .. ".tmp", path)
end

rex.on("session_view_changed", function(ctx)
  local view = rex.session.view({ session_id = ctx.session_id })
  if not view then
    return
  end
  local focused
  for _, w in ipairs(view.windows or {}) do
    if w.window_id == view.active_window_id then
      focused = w.focused_block_id
    end
  end
  if not focused then
    return
  end

  local ids = history[ctx.session_id] or load(ctx.session_id)
  if ids[1] == focused then
    history[ctx.session_id] = ids
    return
  end
  local next = { focused }
  for _, id in ipairs(ids) do
    if id ~= focused and #next < max_history then
      next[#next + 1] = id
    end
  end
  history[ctx.session_id] = next
  save(ctx.session_id, next)
end)

rex.on("session_destroyed", function(ctx)
  history[ctx.session_id] = nil
  os.remove(file(ctx.session_id))
end)
