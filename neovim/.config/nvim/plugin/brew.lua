vim.keymap.set({ "t", "n", "i" }, "<c-\\><c-u>", function()
  vim.cmd("botright new")
  vim.fn.jobstart({ "pkg_up" }, { term = true })
end, { desc = "Terminal: Update system packages" })
