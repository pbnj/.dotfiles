-- {
--   "https://github.com/tpope/vim-dadbod",
--   dependencies = {
--     { "https://github.com/kristijanhusak/vim-dadbod-ui", lazy = true },
--     { "https://github.com/kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
--   },
--   cmd = { "DB", "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
-- }

vim.pack.add({
  "https://github.com/tpope/vim-dadbod",
  "https://github.com/kristijanhusak/vim-dadbod-ui",
  "https://github.com/kristijanhusak/vim-dadbod-completion",
})
