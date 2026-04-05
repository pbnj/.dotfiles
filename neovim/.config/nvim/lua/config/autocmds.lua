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
    vim.opt.autocomplete = vim.bo.buftype == ""
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

-- Auto-toggle neovim background based on system theme
local function get_system_theme()
  if vim.loop.os_uname().sysname:match("Darwin") then
    if vim.fn.systemlist({ "osascript", "-e", [[tell application "System Events" to tell appearance preferences to return dark mode]] })[1] == "true" then
      return "dark"
    else
      return "light"
    end
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("colorscheme_change", { clear = true }),
  pattern = "*",
  callback = function()
    -- vim.api.nvim_set_hl(0, "Normal", { bg = nil })
    -- vim.api.nvim_set_hl(0, "Visual", { link = "CursorLine" })
    vim.schedule(function()
      vim.o.background = get_system_theme()
    end)
  end,
})
