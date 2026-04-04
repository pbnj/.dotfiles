vim.pack.add({
  "https://github.com/selimacerbas/markdown-preview.nvim",
  "https://github.com/selimacerbas/live-server.nvim",
})

if not vim.g.loaded_markdown_preview then
  vim.g.loaded_markdown_preview = true
  require("markdown_preview").setup()
end
