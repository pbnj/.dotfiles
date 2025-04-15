return {
  "https://github.com/ibhagwan/fzf-lua",
  dependencies = { "https://github.com/nvim-tree/nvim-web-devicons" },
  opts = {
    keymap = {
      builtin = {
        ["ctrl-j"] = "preview-down",
        ["ctrl-k"] = "preview-up",
        ["ctrl-d"] = "preview-half-page-down",
        ["ctrl-u"] = "preview-half-page-up",
      },
      fzf = {
        ["ctrl-j"] = "preview-down",
        ["ctrl-k"] = "preview-up",
        ["ctrl-d"] = "preview-half-page-down",
        ["ctrl-u"] = "preview-half-page-up",
      },
      files = {
        ["ctrl-j"] = "preview-down",
        ["ctrl-k"] = "preview-up",
        ["ctrl-d"] = "preview-half-page-down",
        ["ctrl-u"] = "preview-half-page-up",
      },
      oldfiles = {
        ["ctrl-j"] = "preview-down",
        ["ctrl-k"] = "preview-up",
        ["ctrl-d"] = "preview-half-page-down",
        ["ctrl-u"] = "preview-half-page-up",
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
      "<leader>:",
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
      "v",
      desc = "Fuzzy Grep Visual Selection",
    },
  },
}
