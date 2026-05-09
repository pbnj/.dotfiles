vim.pack.add({ "https://github.com/folke/sidekick.nvim" })

require("sidekick").setup({
	nes = { enabled = false },
})

vim.keymap.set({ "i", "n" }, "<tab>", function()
	if require("sidekick").nes_jump_or_apply() then
		return
	end
	if vim.lsp.inline_completion.get() then
		return
	end
	return "<tab>"
end, { expr = true, desc = "Goto/Apply Next Edit Suggestion" })

vim.keymap.set({ "n", "t", "i", "x" }, "<c-.>", function()
	require("sidekick.cli").toggle()
end, { desc = "Sidekick Toggle" })

vim.keymap.set("n", "<leader>aa", function()
	require("sidekick.cli").toggle()
end, { desc = "Sidekick Toggle CLI" })

vim.keymap.set({ "n", "v" }, "<leader>ap", function()
	require("sidekick.cli").prompt()
end, { desc = "Sidekick Ask Prompt" })

vim.keymap.set("n", "<leader>as", function()
	require("sidekick.cli").select()
end, { desc = "Select CLI" })

vim.keymap.set({ "x", "n" }, "<leader>at", function()
	require("sidekick.cli").send({ msg = "{this}" })
end, { desc = "Send This" })

vim.keymap.set("x", "<leader>av", function()
	require("sidekick.cli").send({ msg = "{selection}" })
end, { desc = "Send Visual Selection" })
