vim.pack.add({ "https://github.com/nvzone/showkeys" })

require("showkeys").setup({ maxkeys = 5 })

vim.keymap.set(
	"n",
	"<leader>tk",
	"<cmd>ShowkeysToggle<cr>",
	{ desc = "Toggle ShowKeys" }
)
