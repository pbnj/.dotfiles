vim.api.nvim_create_user_command("Slides", function(opts)
  require("toggleterm.terminal").Terminal:new({ cmd = string.format("slides %s", opts.args), direction = "float" }):toggle()
end, { desc = "Slides Presentation", nargs = "?", complete = "file_in_path" })
