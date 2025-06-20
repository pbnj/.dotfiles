vim.api.nvim_create_user_command("BTM", function()
  require("snacks").terminal("btm")
end, { nargs = 0, desc = "Bottom CLI" })
