-- {
--   "https://github.com/folke/lazydev.nvim",
--   ft = "lua",
--   opts = {
--     library = {
--       {
--         path = "${3rd}/luv/library",
--         words = { "vim%.uv" },
--       },
--       {
--         path = "snacks.nvim",
--         words = { "Snacks" },
--       },
--     },
--   },
-- }

vim.pack.add({ "https://github.com/folke/lazydev.nvim" })

require("lazydev").setup({
  library = {
    {
      path = "${3rd}/luv/library",
      words = { "vim%.uv" },
    },
    {
      path = "snacks.nvim",
      words = { "Snacks" },
    },
  },
})
