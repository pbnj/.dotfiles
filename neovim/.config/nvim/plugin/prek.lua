local function split_shell_args(args)
  local result = {}
  local current = ""
  local in_quotes = false
  local quote_char = ""

  for i = 1, #args do
    local char = args:sub(i, i)
    if not in_quotes and (char == '"' or char == "'") then
      in_quotes = true
      quote_char = char
    elseif in_quotes and char == quote_char then
      in_quotes = false
    elseif not in_quotes and char == " " then
      if current ~= "" then
        table.insert(result, current)
        current = ""
      end
    else
      current = current .. char
    end
  end
  if current ~= "" then
    table.insert(result, current)
  end
  return result
end

vim.api.nvim_create_user_command("Prek", function(opts)
  local Snacks = require("snacks")
  local cmd = { "prek" }

  if opts.args ~= "" then
    local split_args = split_shell_args(opts.args)
    for _, arg in ipairs(split_args) do
      table.insert(cmd, arg)
    end

    Snacks.terminal(cmd, {
      auto_close = false,
      win = {
        wo = {
          winbar = " prek " .. opts.args,
        },
      },
    })
  else
    Snacks.terminal(cmd, {
      auto_close = false,
      win = {
        wo = {
          winbar = " prek",
        },
      },
    })
  end
end, {
  nargs = "*",
  desc = "Run prek hooks",
  complete = function(arg_lead)
    local commands = {
      "install",
      "prepare-hooks",
      "run",
      "list",
      "uninstall",
      "validate-config",
      "validate-manifest",
      "sample-config",
      "auto-update",
      "cache",
      "try-repo",
      "util",
      "self",
    }
    local options = {
      "--skip",
      "-a",
      "--all-files",
      "--files",
      "-d",
      "--directory",
      "-s",
      "--from-ref",
      "-o",
      "--to-ref",
      "--last-commit",
      "--stage",
      "--show-diff-on-failure",
      "--fail-fast",
      "--dry-run",
      "-c",
      "--config",
      "-C",
      "--cd",
      "--color",
      "--refresh",
      "-h",
      "--help",
      "--no-progress",
      "-q",
      "--quiet",
      "-v",
      "--verbose",
      "--log-file",
      "-V",
      "--version",
    }

    local all = {}
    for _, v in ipairs(commands) do
      table.insert(all, v)
    end
    for _, v in ipairs(options) do
      table.insert(all, v)
    end

    return vim.iter(all)
      :filter(function(cmd)
        return string.match(cmd, "^" .. arg_lead)
      end)
      :totable()
  end,
})
