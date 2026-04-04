-- return {
--   "https://github.com/stevearc/quicker.nvim",
--   ft = "qf",
--   ---@module "quicker"
--   ---@type quicker.SetupOptions
--   opts = {},
--   keys = {
--     {
--       "+",
--       function()
--         require("quicker").expand()
--       end,
--       desc = "Expand quickfix content",
--     },
--     {
--       "-",
--       function()
--         require("quicker").collapse()
--       end,
--       desc = "Collapse quickfix content",
--     },
--   },
-- }

vim.pack.add({ "https://github.com/stevearc/quicker.nvim" })

vim.keymap.set("n", "<leader>q", function()
  require("quicker").toggle()
end, {
  desc = "Toggle quickfix",
})
vim.keymap.set("n", "<leader>l", function()
  require("quicker").toggle({ loclist = true })
end, {
  desc = "Toggle loclist",
})

---@module "quicker"
---@type quicker.SetupOptions
require("quicker").setup({
  keys = {
    {
      ">",
      function()
        require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
      end,
      desc = "Expand quickfix context",
    },
    {
      "<",
      function()
        require("quicker").collapse()
      end,
      desc = "Collapse quickfix context",
    },
  },
})
