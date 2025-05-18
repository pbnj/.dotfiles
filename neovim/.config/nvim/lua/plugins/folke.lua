return {
  -- {
  --   "https://github.com/folke/noice.nvim",
  --   event = "VeryLazy",
  --   dependencies = { "https://github.com/MunifTanjim/nui.nvim" },
  --   opts = { presets = { command_palette = true } },
  -- },
  {
    "https://github.com/folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      bigfile = { enabled = true },
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      notify = { enabled = true },
      picker = { ui_select = true },
      scope = { enabled = true },
      scroll = { enabled = true },
    },
  },
  {
    "https://github.com/folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
    config = function()
      vim.cmd([[colorscheme tokyonight]])
    end,
  },
  {
    "https://github.com/folke/todo-comments.nvim",
    event = "VeryLazy",
    dependencies = { "https://github.com/nvim-lua/plenary.nvim" },
    opts = {},
  },
}
