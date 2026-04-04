-- return {
--   "https://github.com/folke/which-key.nvim",
--   event = "VeryLazy",
--   opts = { preset = "helix" },
-- }

vim.pack.add({ "https://github.com/folke/which-key.nvim" })

require("which-key").setup({ preset = "helix" })
