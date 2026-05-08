-- Snyk CLI wrapper — runs snyk commands in the built-in terminal.
-- Usage: :Snyk <command> [subcommand] [flags...]
-- Example: :Snyk test
--          :Snyk container test alpine:latest
--          :Snyk iac test --report
--          :Snyk code test

-- Build a snyk command prefixed with `op run --` so that 1Password secret
-- references in the environment are injected in one place.
local function snyk(args)
  return vim.iter({ "snyk", args }):flatten():totable()
end

-- Subcommand completion tables
local top_level = {
  "auth",
  "test",
  "monitor",
  "container",
  "iac",
  "code",
  "sbom",
  "aibom",
  "redteam",
  "log4shell",
  "config",
  "policy",
  "ignore",
  "--help",
  "--version",
  "-d",
}

local subcommands = {
  container = { "test", "monitor", "sbom", "--help" },
  iac = { "test", "describe", "update-exclude-policy", "--help" },
  code = { "test", "--help" },
  sbom = { "--format", "--org", "--file", "--all-projects", "--json-file-output", "--help" },
  aibom = { "test", "--help" },
  config = { "get", "set", "unset", "clear", "--help" },
  redteam = { "--help" },
}

local function complete(arg_lead, cmd_line)
  -- tokenise what has been typed so far (strip the leading :Snyk)
  local tokens = {}
  for token in cmd_line:gmatch("%S+") do
    table.insert(tokens, token)
  end
  -- tokens[1] == "Snyk", tokens[2..] == arguments

  -- determine position: how many complete arguments are before the cursor word
  -- if cmd_line ends with whitespace the user is starting a new token
  local completing_new = cmd_line:sub(-1) == " "
  local arg_count = #tokens - 1 -- number of args after "Snyk"
  if completing_new then
    arg_count = arg_count + 1
  end

  local first_arg = tokens[2]

  -- completing the first argument → top-level commands
  if arg_count <= 1 then
    return vim
      .iter(top_level)
      :filter(function(c)
        return c:find(arg_lead, 1, true) == 1
      end)
      :totable()
  end

  -- completing a subcommand for commands that have them
  if arg_count == 2 and first_arg and subcommands[first_arg] then
    return vim
      .iter(subcommands[first_arg])
      :filter(function(c)
        return c:find(arg_lead, 1, true) == 1
      end)
      :totable()
  end

  return {}
end

vim.api.nvim_create_user_command("Snyk", function(opts)
  vim.cmd("botright new")
  vim.fn.jobstart(snyk(opts.fargs), { term = true })
end, {
  desc = "Snyk CLI",
  nargs = "*",
  complete = complete,
})
