vim.api.nvim_create_user_command("Top", function()
  local Terminal = require("toggleterm.terminal").Terminal
  local cmd = vim.fn.executable("btm") and "btm" or vim.fn.executable("htop") and "htop" or "top"
  Terminal:new({ cmd = cmd, direction = "float" }):toggle()
end, { desc = "Toggle process viewer (e.g. btm, htop, top)" })
