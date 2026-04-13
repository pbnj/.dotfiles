-- Keymaps

-- Movements
vim.keymap.set("c", "<C-n>", "<Down>", { noremap = true })
vim.keymap.set("c", "<C-p>", "<Up>", { noremap = true })
vim.keymap.set("n", "j", "gj", { noremap = true, silent = true })
vim.keymap.set("n", "k", "gk", { noremap = true, silent = true })

-- Search
vim.keymap.set({ "n", "v" }, "n", function() return (vim.v.searchforward == 1 and "n" or "N") end, { expr = true, silent = true, desc = "Search forward" })
vim.keymap.set({ "n", "v" }, "N", function() return (vim.v.searchforward == 1 and "N" or "n") end, { expr = true, silent = true, desc = "Search backward" })

-- Plugin Manager
vim.keymap.set("n", "<leader>pp", function() vim.pack.update() end, { noremap = true, silent = true, desc = "[P]ack: Update [P]lugins" })

-- Format
vim.keymap.set("n", "Q", function()
  if vim.bo.formatexpr ~= "" then
    return "gggqG"
  else
    return ""
  end
end, { noremap = true, silent = true, desc = "Format buffer" })
