vim.pack.add({ "https://github.com/folke/trouble.nvim" })

require("trouble").setup()

vim.keymap.set("n", "<leader>ft", function()
	vim.cmd.Trouble()
end, { desc = "[F]ind [T]rouble" })

-- vim.pack.del({ "trouble.nvim" })
