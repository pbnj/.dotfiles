vim.pack.add({
	"https://github.com/tpope/vim-fugitive",
	"https://github.com/tpope/vim-rhubarb",
})
vim.keymap.set({ "n" }, "<leader>gg", function()
	vim.cmd.Git()
end, { desc = "[G]it Status (fugitive)" })
