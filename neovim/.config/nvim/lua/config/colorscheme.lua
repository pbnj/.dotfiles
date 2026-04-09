-- Colorscheme

-- Autocmd to toggle neovim background based on system theme
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
    vim.api.nvim_set_hl(0, "Normal", { bg = nil })
    vim.api.nvim_set_hl(0, "Visual", { link = "CursorLine" })
    vim.schedule(function()
      vim.o.background = get_system_theme()
    end)
  end,
})

vim.cmd.colorscheme("default")
