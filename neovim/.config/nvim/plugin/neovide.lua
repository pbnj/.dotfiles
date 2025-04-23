if vim.g.neovide then
  -- map cmd+c/v to copy/paste & cmd+s to write/save file
  vim.keymap.set("n", "<D-s>", "<cmd>write<CR>") -- Save
  vim.keymap.set("i", "<D-s>", "<esc><cmd>write<CR>") -- Save
  vim.keymap.set("v", "<D-c>", '"+y') -- Copy
  vim.keymap.set("n", "<D-v>", '"+P') -- Paste normal mode
  vim.keymap.set("v", "<D-v>", '"+P') -- Paste visual mode
  vim.keymap.set("c", "<D-v>", "<C-R>+") -- Paste command mode
  vim.keymap.set("i", "<D-v>", "<C-R>+") -- Paste insert mode

  -- transparency
  vim.g.neovide_opacity = 0.9
  vim.g.neovide_window_blurred = true

  -- zoom font
  vim.g.neovide_scale_factor = 1.0
  local change_scale_factor = function(delta)
    vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * delta
  end
  vim.keymap.set("n", "<C-=>", function()
    change_scale_factor(1.25)
  end)
  vim.keymap.set("n", "<C-->", function()
    change_scale_factor(1 / 1.25)
  end)
end
