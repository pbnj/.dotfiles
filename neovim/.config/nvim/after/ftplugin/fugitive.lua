vim.keymap.set({ "n" }, "q", function()
  vim.cmd("bdelete")
end, {
  desc = "Delete Buffer (Fugitive)",
  buffer = true,
})
