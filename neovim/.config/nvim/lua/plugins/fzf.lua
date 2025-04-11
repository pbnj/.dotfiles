return {
  "https://github.com/ibhagwan/fzf-lua",
  dependencies = { "https://github.com/nvim-tree/nvim-web-devicons" },
  opts = {},
  cmd = { "FzfLua" },
  keys = {
    {
      "<leader>ff",
      function()
        require("fzf-lua").files()
      end,
      desc = "Fuzzy Files",
    },
    {
      "<leader>fg",
      function()
        require("fzf-lua").live_grep()
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
      "<leader>fp",
      function()
        require("fzf-lua").files({ cwd = "~/Projects" })
      end,
      desc = "Fuzzy Projects",
    },
  },
}
