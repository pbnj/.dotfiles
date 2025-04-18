local completion_fzf_scalr_workspace = function() end

vim.api.nvim_create_user_command("FzfScalr", function(opts)
  local args = opts.args or ""
  local cmd = "fzf-scalr " .. args
  local Terminal = require("toggleterm.terminal").Terminal
  Terminal:new({ cmd = cmd, hidden = true, close_on_exit = true }):toggle()
end, {
  desc = "FZF Scalr",
  nargs = "?",
  complete = completion_fzf_scalr_workspace,
})
