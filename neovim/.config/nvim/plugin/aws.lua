local function aws_profile_and_command_completion(a, l, _)
  local args = vim.split(l, " ", { trimempty = true })
  local last_arg = args[#args]
  if last_arg == "--profile" then
    -- profile completion
    local profiles = vim.fn.systemlist("aws configure list-profiles")
    return vim.tbl_filter(function(profile)
      return string.match(profile, a)
    end, profiles)
  else
    -- command completion
    local aws_cmds = vim.fn.systemlist("cat ~/.aws/commands")
    return vim.tbl_filter(function(aws_cmd)
      return string.match(aws_cmd, a)
    end, aws_cmds)
  end
end

vim.api.nvim_create_user_command("AWS", function(opts)
  local Terminal = require("toggleterm.terminal").Terminal
  local cmd = string.format("awe --no-cli-pager --cli-auto-prompt %s", opts.args)
  Terminal:new({ cmd = cmd, close_on_exit = false, direction = "float" }):toggle()
end, {
  nargs = "*",
  complete = aws_profile_and_command_completion,
})

-- Register the AWSProfile command
vim.api.nvim_create_user_command("AWSProfile", function(opts)
  local Terminal = require("toggleterm.terminal").Terminal
  local cmd = string.format("awe --no-cli-pager --cli-auto-prompt --profile=%s", opts.args)
  Terminal:new({ cmd = cmd, close_on_exit = false }):toggle()
end, {
  nargs = "*",
  complete = aws_profile_and_command_completion,
})
