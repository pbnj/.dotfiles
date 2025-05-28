vim.api.nvim_create_user_command("C7nRun", function(opts)
  local custodian = { "uvx", "--from", "c7n", "custodian", "run", "--output-dir", "/tmp/c7n/", "--verbose", opts.args }
  local cmd = table.concat(custodian, " ")
  require("toggleterm.terminal").Terminal:new({ cmd = cmd, close_on_exit = false, direction = "float" }):toggle()
end, { nargs = "*", complete = "file_in_path" })

vim.api.nvim_create_user_command("C7nReport", function(opts)
  local custodian = { "uvx", "--from", "c7n", "custodian", "report", "--output-dir", "/tmp/c7n/", "--verbose", opts.args }
  local cmd = table.concat(custodian, " ")
  require("toggleterm.terminal").Terminal:new({ cmd = cmd, close_on_exit = false, direction = "float" }):toggle()
end, { nargs = "*", complete = "file_in_path" })
