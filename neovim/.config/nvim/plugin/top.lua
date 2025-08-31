vim.api.nvim_create_user_command("Top", function()
  local cmd = vim.fn.executable("btm") and { "btm", "--theme", vim.o.background == "dark" and "default" or "default-light" } or vim.fn.executable("htop") and { "htop" } or { "top" }
  require("snacks").terminal(cmd, { win = { wo = { winbar = cmd[1] } } })
end, { desc = "Toggle process viewer (e.g. btm, htop, top)" })
