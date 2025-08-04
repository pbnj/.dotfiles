vim.api.nvim_create_user_command("Projects", function(opts)
  Snacks.picker.files({
    title = "Projects",
    hidden = true,
    cwd = "~/Projects",
    dirs = { "~/Projects" },
    exclude = { ".env" },
    layout = { preset = "vertical", fullscreen = true },
    formatters = { file = { truncate = 100 } },
  })
end, { nargs = "*", bang = true, desc = "Projects Snacks Picker" })

vim.keymap.set({ "n" }, "<leader>fp", vim.cmd.Projects, { desc = "[F]uzzy [P]rojects" })
