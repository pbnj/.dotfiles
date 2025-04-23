return {
  "https://github.com/ibhagwan/fzf-lua",
  dependencies = { "https://github.com/echasnovski/mini.nvim" },
  opts = {
    keymap = {
      builtin = {
        ["<c-j>"] = "preview-down",
        ["<c-k>"] = "preview-up",
        ["<c-d>"] = "preview-half-page-down",
        ["<c-u>"] = "preview-half-page-up",
      },
    },
  },
  cmd = { "FzfLua" },
  keys = {
    {
      "<leader>/",
      function()
        require("fzf-lua").live_grep()
      end,
      desc = "Fuzzy Grep",
    },
    {
      "<leader>;",
      function()
        require("fzf-lua").command_history()
      end,
      desc = "Fuzzy Grep",
    },
    {
      "<leader>fb",
      function()
        require("fzf-lua").buffers()
      end,
      desc = "Fuzzy Buffers",
    },
    {
      "<leader>ff",
      function()
        require("fzf-lua").files()
      end,
      desc = "Fuzzy Files",
    },
    {
      "<leader>fh",
      function()
        require("fzf-lua").help_tags()
      end,
      desc = "Fuzzy Help",
    },
    {
      "<leader>fo",
      function()
        require("fzf-lua").oldfiles()
      end,
      desc = "Fuzzy Old Files",
    },
    {
      "<leader>fp",
      function()
        require("fzf-lua").files({ cwd = "~/Projects" })
      end,
      desc = "Fuzzy Projects",
    },
    {
      "<leader>fr",
      function()
        require("fzf-lua").resume()
      end,
      desc = "Fuzzy Resume",
    },
    {
      "<leader>fw",
      function()
        require("fzf-lua").grep_cword()
      end,
      desc = "Fuzzy Grep Current Word",
    },
    {
      "<leader>fw",
      function()
        require("fzf-lua").grep_visual()
      end,
      mode = "v",
      desc = "Fuzzy Grep Visual Selection",
    },
    {
      "<leader>fh",
      function()
        require("fzf-lua").help_tags({ query = require("fzf-lua.utils").get_visual_selection() })
      end,
      mode = "v",
      desc = "Fuzzy Help Visual Selection",
    },
    {
      "<leader>fd",
      function()
        require("fzf-lua").files({ cwd = vim.fn.stdpath("config") })
      end,
      desc = "Fuzzy Dotfiles",
    },
  },
}
