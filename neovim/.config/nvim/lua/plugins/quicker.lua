return {
  "https://github.com/stevearc/quicker.nvim",
  ft = "qf",
  ---@module "quicker"
  ---@type quicker.SetupOptions
  opts = {},
  keys = {
    {
      ">",
      function()
        require("quicker").expand()
      end,
      desc = "Expand quickfix content",
    },
    {
      "<",
      function()
        require("quicker").collapse()
      end,
      desc = "Collapse quickfix content",
    },
  },
}
