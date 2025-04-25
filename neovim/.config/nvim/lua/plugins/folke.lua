return {
  {
    "https://github.com/folke/trouble.nvim",
    opts = {},
    cmd = "Trouble",
    keys = {
      {
        "<leader>xx",
        function()
          require("trouble").toggle({ mode = "diagnostics" })
        end,
        desc = "Toggle Diagnostics (Trouble)",
      },
      {
        "]x",
        function()
          require("trouble").next({ mode = "diagnostics", jump = true })
        end,
        desc = "Next Diagnostics (Trouble)",
      },
      {
        "[x",
        function()
          require("trouble").prev({ mode = "diagnostics", jump = true })
        end,
        desc = "Previous Diagnostics (Trouble)",
      },
    },
  },
  {
    "https://github.com/folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      bigfile = { enabled = true },
      indent = { enabled = true },
      notifier = { enabled = true },
      notify = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = true },
      ui_select = { enabled = true },
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
