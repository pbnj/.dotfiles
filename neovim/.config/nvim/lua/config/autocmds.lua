vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("Terminal", { clear = true }),
  pattern = "*",
  command = "startinsert",
})

vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("Resize", { clear = true }),
  pattern = "*",
  command = "wincmd =",
})
