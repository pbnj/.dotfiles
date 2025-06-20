vim.api.nvim_create_user_command("Projects", function(opts)
  Snacks.picker.files({ hidden = true, cwd = "~/Projects", exclude = { ".env" }, layout = { fullscreen = opts.bang } })
end, { nargs = "*", bang = true, desc = "Projects Snacks Picker" })

vim.keymap.set({ "n" }, "<leader>fp", vim.cmd.Projects, { desc = "[F]uzzy [P]rojects" })
