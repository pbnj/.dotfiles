vim.pack.add({
	"https://github.com/selimacerbas/markdown-preview.nvim",
	"https://github.com/selimacerbas/live-server.nvim",
})

if not vim.g.markdown_preview_setup then
	vim.g.markdown_preview_setup = true
	require("markdown_preview").setup()
end
