local function aws_profile_completion(arglead)
  return vim
    .iter(vim.fn.systemlist("aws configure list-profiles"))
    :filter(function(profile)
      return string.match(profile, arglead)
    end)
    :totable()
end

-- local function aws_profile_and_command_completion(arglead, cmdline)
--   local args = vim.split(cmdline, " ", { trimempty = true })
--   local last_arg = args[#args]
--   if last_arg == "--profile" then
--     -- profile completion
--     return aws_profile_completion(arglead)
--   else
--     -- command completion
--     return vim
--       .iter(vim.fn.systemlist("cat ~/.aws/commands"))
--       :filter(function(aws_cmd)
--         return string.match(aws_cmd, arglead)
--       end)
--       :totable()
--   end
-- end

vim.api.nvim_create_user_command("AWSConsole", function(opts)
  local aws_sso_start_url = vim.trim(vim.fn.system("grep 'sso_start_url' ~/.aws/config | uniq | awk -F'=' '{printf $2}'"))
  local aws_profiles = vim
    .iter(vim.fn.systemlist("aws configure list-profiles | grep -E '^\\d{12}'"))
    :map(function(val)
      return { text = val }
    end)
    :totable()
  if opts.args == "" then
    require("snacks").picker({
      source = "aws_console",
      layout = "vscode",
      format = "text",
      items = aws_profiles,
      matcher = { fuzzy = true, frecency = true },
      confirm = function(picker, item)
        picker:close()
        local selection = vim.split(item.text, "/")
        local account_id = selection[1]
        local role_name = selection[3]
        local url = string.format("%s/console?account_id=%s&role_name=%s", aws_sso_start_url, account_id, role_name)
        vim.system({ "open", url })
      end,
    })
  else
    local selection = vim.split(opts.args, "/")
    local account_id = selection[1]
    local role_name = selection[3]
    local url = string.format("%s/console?account_id=%s&role_name=%s", aws_sso_start_url, account_id, role_name)
    vim.system({ "open", url })
  end
end, {
  nargs = "?",
  complete = aws_profile_completion,
})
vim.keymap.set({ "n" }, "<leader>ac", vim.cmd.AWSConsole, { desc = "[A]WS [C]onsole" })

vim.api.nvim_create_user_command("AWS", function(opts)
  local cmd = string.format("awe --no-cli-pager --cli-auto-prompt %s", opts.args)
  require("snacks").terminal(cmd, { auto_close = false })
end, {
  nargs = "*",
  complete = aws_profile_completion,
})

-- Register the AWSProfile command
vim.api.nvim_create_user_command("AWSProfile", function(opts)
  local Terminal = require("toggleterm.terminal").Terminal
  local cmd = string.format("awe --no-cli-pager --cli-auto-prompt --profile=%s", opts.args)
  Terminal:new({ cmd = cmd, close_on_exit = false }):toggle()
end, {
  nargs = "*",
  complete = aws_profile_completion,
})
