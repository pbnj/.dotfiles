local terminal = function(args)
  if pcall(require, "snacks") then
    require("snacks").terminal(args, { auto_close = false, win = { wo = { winbar = table.concat(args, " ") } } })
    return
  elseif pcall(require, "toggleterm") then
    require("toggleterm.terminal").Terminal:new({ cmd = table.concat(args, " "), direction = "float", close_on_exit = false }):toggle()
    return
  else
    vim.cmd("terminal " .. table.concat(args, " "))
  end
end

vim.api.nvim_create_user_command("Top", function()
  local cmd = vim.fn.executable("btm") and { "btm", "--theme", vim.o.background == "dark" and "default" or "default-light" } or vim.fn.executable("htop") and { "htop" } or { "top" }
  terminal(cmd)
end, { desc = "Toggle process viewer (e.g. btm, htop, top)" })
