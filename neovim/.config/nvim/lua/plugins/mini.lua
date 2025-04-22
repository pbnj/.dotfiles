return {
  {
    "https://github.com/echasnovski/mini.nvim",
    event = "VeryLazy",
    version = false,
    config = function()
      require("mini.statusline").setup()
      require("mini.icons").setup()
    end,
  },
  {
    "https://github.com/nvim-lualine/lualine.nvim",
    enabled = false,
    event = "VeryLazy",
    dependencies = { "https://github.com/nvim-tree/nvim-web-devicons" },
    opts = {
      sections = {
        lualine_c = {
          { "filename", path = 1 },
        },
      },
    },
  },
}
