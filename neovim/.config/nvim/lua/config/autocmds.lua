-- Autocommands

-- automatically resize splits when the window is resized
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("resize_windows", { clear = true }),
  pattern = "*",
  command = "wincmd =",
})

-- diable autocomplete in non-file buffers (e.g., terminal, help, etc.)
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("disable_autocomplete", { clear = true }),
  pattern = "*",
  callback = function()
    vim.bo.autocomplete = vim.bo.buftype == ""
  end,
})

-- highlight yanked text for 300ms
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.hl.on_yank({ timeout = 300 })
  end,
})
