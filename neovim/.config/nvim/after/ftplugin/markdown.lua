vim.pack.add({
  "https://github.com/selimacerbas/mdkite.nvim",
  "https://github.com/selimacerbas/kitehost.nvim",
})

if not vim.g.mdkite_setup then
  vim.g.mdkite_setup = true
  require("mdkite").setup()
end
