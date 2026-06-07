vim.keymap.set({ "t", "n", "i" }, "<c-\\><c-u>", function()
  vim.cmd("tabnew")
  vim.fn.jobstart({ "pkg_up" }, { term = true })
end, { desc = "Terminal: Update system packages" })
