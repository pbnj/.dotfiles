vim.pack.add({ "https://github.com/goropikari/sarif.nvim" })

require("sarif").setup({
  patterns = { "**/*.sarif", "**/*.sarif.json" },
})
