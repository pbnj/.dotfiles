vim.pack.add({ "https://github.com/folke/trouble.nvim" })

require("trouble").setup()

vim.keymap.set("n", "<leader>/t", function()
  vim.cmd.Trouble()
end, { desc = "Search [T]rouble" })

-- vim.pack.del({ "trouble.nvim" })
