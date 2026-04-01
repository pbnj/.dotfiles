local M = {}

-- ─── Default Config ──────────────────────────────────────────────────────────

M.config = {
  -- Each agent needs:
  --   name:  display name in the picker
  --   check: executable to verify it's installed
  --   cmd:   function(prompt) -> table of argv strings
  --
  -- GitHub Copilot CLI notes:
  --   Install: npm install -g @github/copilot
  --   The new standalone `copilot` CLI (released 2025) supersedes the
  --   deprecated `gh copilot` extension (EOL Oct 2025).
  --   -p / --prompt  → non-interactive single-shot mode (required for jobstart)
  --   --yolo         → auto-approve all tool permissions (no interactive prompts)
  --   --output-format json → optional JSON output (not used here; plain text is simpler)
  agents = {
    {
      name = "claude",
      check = "claude",
      cmd = function(p)
        return { "claude", "-p", p }
      end,
    },
    {
      name = "gemini",
      check = "gemini",
      cmd = function(p)
        return { "gemini", "-p", p }
      end,
    },
    {
      name = "codex",
      check = "codex",
      cmd = function(p)
        return { "codex", "-q", "--full-auto", p }
      end,
    },
    {
      name = "llm", -- Simon Willison's `llm` tool (any backend)
      check = "llm",
      cmd = function(p)
        return { "llm", p }
      end,
    },
    {
      name = "copilot",
      check = "copilot",
      cmd = function(p)
        return { "copilot", "-p", p, "--yolo" }
      end,
    },
    {
      name = "cursor",
      check = "cursor-agent",
      cmd = function(p)
        return { "cursor-agent", "-p", p, "--output-format", "text", "--yolo" }
      end,
    },
    {
      name = "ollama/llama3",
      check = "ollama",
      cmd = function(p)
        return { "ollama", "run", "llama3", p }
      end,
    },
  },

  -- Where to insert the response relative to cursor line:
  --   "below"   → insert after the current line  (default)
  --   "inline"  → replace the current line
  --   "above"   → insert before the current line
  insert_position = "below",

  -- Strip ANSI escape codes from output (strongly recommended — most CLIs
  -- emit colour codes; copilot CLI uses alt-screen in interactive mode but
  -- -p disables it, so plain text output is produced instead)
  strip_ansi = true,
}

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function strip_ansi(lines)
  local out = {}
  for _, line in ipairs(lines) do
    -- Remove ESC sequences: colours (\27[...m), cursor/mode (\27[?...h/l),
    -- OSC sequences (\27]...ST or \27]...\7), and lone carriage returns
    local clean = line
      :gsub("\27%[[%d;]*%a", "") -- CSI sequences  e.g. \27[1;32m
      :gsub("\27%[[%?%d;]*[hl]", "") -- private modes  e.g. \27[?1049h
      :gsub("\27%].-\7", "") -- OSC (BEL-terminated)
      :gsub("\27%].-\27\\", "") -- OSC (ST-terminated)
      :gsub("\r", "") -- bare carriage returns
    table.insert(out, clean)
  end
  return out
end

local function get_available_agents()
  local available = {}
  for _, agent in ipairs(M.config.agents) do
    if vim.fn.executable(agent.check) == 1 then
      table.insert(available, agent)
    end
  end
  return available
end

local function insert_lines(lines)
  local buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed

  local pos = M.config.insert_position
  if pos == "below" then
    vim.api.nvim_buf_set_lines(buf, row, row, false, lines)
    vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
  elseif pos == "above" then
    vim.api.nvim_buf_set_lines(buf, row - 1, row - 1, false, lines)
    vim.api.nvim_win_set_cursor(0, { row, 0 })
  elseif pos == "inline" then
    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, lines)
  end
end

-- ─── Core: Run agent and insert response ─────────────────────────────────────

local function run_agent(agent, prompt)
  local output = {}
  local errors = {}

  vim.notify(("[ai] ⏳ %s thinking…"):format(agent.name), vim.log.levels.INFO)

  vim.fn.jobstart(agent.cmd(prompt), {
    stdout_buffered = true,
    stderr_buffered = true,

    on_stdout = function(_, data)
      if not data then
        return
      end
      if data[#data] == "" then
        data[#data] = nil
      end
      vim.list_extend(output, data)
    end,

    on_stderr = function(_, data)
      if not data then
        return
      end
      if data[#data] == "" then
        data[#data] = nil
      end
      vim.list_extend(errors, data)
    end,

    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 then
          local msg = table.concat(errors, "\n")
          vim.notify(("[ai] ❌ %s exited %d:\n%s"):format(agent.name, code, msg), vim.log.levels.ERROR)
          return
        end

        if #output == 0 then
          vim.notify("[ai] ⚠️  Empty response.", vim.log.levels.WARN)
          return
        end

        local lines = M.config.strip_ansi and strip_ansi(output) or output
        insert_lines(lines)
        vim.notify(("[ai] ✅ %d lines inserted from %s"):format(#lines, agent.name), vim.log.levels.INFO)
      end)
    end,
  })
end

-- ─── Public API ──────────────────────────────────────────────────────────────

--- Prompt user to pick an agent, then interactively enter a prompt.
function M.prompt()
  local agents = get_available_agents()
  if #agents == 0 then
    vim.notify("[ai] No agents found. Install claude, gemini, codex, llm, copilot, or ollama.", vim.log.levels.ERROR)
    return
  end

  vim.ui.select(agents, {
    prompt = "Select agent:",
    format_item = function(a)
      return a.name
    end,
  }, function(agent)
    if not agent then
      return
    end

    vim.ui.input({ prompt = ("Prompt [%s]: "):format(agent.name) }, function(input)
      if not input or input == "" then
        return
      end
      run_agent(agent, input)
    end)
  end)
end

--- Pick an agent, then use the current line (or visual selection) as the prompt.
--- @param opts? { visual: boolean }
function M.prompt_from_buffer(opts)
  opts = opts or {}
  local agents = get_available_agents()
  if #agents == 0 then
    vim.notify("[ai] No agents found.", vim.log.levels.ERROR)
    return
  end

  local prompt
  if opts.visual then
    vim.cmd('noau normal! "vy')
    prompt = vim.fn.getreg("v")
  else
    prompt = vim.api.nvim_get_current_line()
  end

  if not prompt or prompt:match("^%s*$") then
    vim.notify("[ai] ⚠️  Nothing to send (empty line/selection).", vim.log.levels.WARN)
    return
  end

  vim.ui.select(agents, {
    prompt = "Select agent:",
    format_item = function(a)
      return a.name
    end,
  }, function(agent)
    if not agent then
      return
    end
    run_agent(agent, prompt)
  end)
end

-- ─── Setup ───────────────────────────────────────────────────────────────────

--- @param user_config? table
function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})

  vim.api.nvim_create_user_command("AiInsert", function()
    M.prompt()
  end, { desc = "ai: pick agent → enter prompt → insert response" })

  vim.api.nvim_create_user_command("AiInsertLine", function()
    M.prompt_from_buffer({ visual = false })
  end, { desc = "ai: pick agent → use current line as prompt → insert response" })

  vim.api.nvim_create_user_command("AiInsertVisual", function()
    M.prompt_from_buffer({ visual = true })
  end, { range = true, desc = "ai: pick agent → use visual selection as prompt → insert response" })
end

return M
