vim.api.nvim_create_user_command("Slides", function(opts)
  require("snacks").terminal({ "slides", opts.args }, { auto_close = false })
end, { desc = "Slides Presentation", nargs = "?", complete = "file_in_path" })
