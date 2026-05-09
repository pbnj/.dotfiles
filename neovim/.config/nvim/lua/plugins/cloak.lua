-- return {
--   "https://github.com/laytan/cloak.nvim",
--   event = "VeryLazy",
--   opts = {},
--   cmd = { "CloakDisable", "CloakdEnable", "CloakToggle" },
-- }

vim.pack.add({ "https://github.com/laytan/cloak.nvim" })
require("cloak").setup()
