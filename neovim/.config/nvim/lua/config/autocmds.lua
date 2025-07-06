vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("resize_windows", { clear = true }),
  pattern = "*",
  command = "wincmd =",
})

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.hl.on_yank({ higroup = "Visual", timeout = 300 })
  end,
})
