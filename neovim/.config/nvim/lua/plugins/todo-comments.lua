-- {
--   "https://github.com/folke/todo-comments.nvim",
--   event = "VeryLazy",
--   dependencies = {
--     "https://github.com/nvim-lua/plenary.nvim",
--     "https://github.com/folke/snacks.nvim",
--   },
--   opts = {},
--   keys = {
--     {
--       "]n",
--       function()
--         require("todo-comments").jump_next()
--       end,
--       desc = "Next todo comment",
--     },
--     {
--       "[n",
--       function()
--         require("todo-comments").jump_prev()
--       end,
--       desc = "Previous todo comment",
--     },
--   },
-- }

vim.pack.add({
  "https://github.com/folke/todo-comments.nvim",
  "https://github.com/nvim-lua/plenary.nvim",
})

require("todo-comments").setup()

vim.keymap.set("n", "]n", function()
  require("todo-comments").jump_next()
end, { desc = "Next todo comment" })

vim.keymap.set("n", "[n", function()
  require("todo-comments").jump_prev()
end, { desc = "Previous todo comment" })
