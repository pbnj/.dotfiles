return {
  { "https://github.com/tpope/vim-dispatch", event = "VeryLazy" },
  { "https://github.com/tpope/vim-rsi", event = "VeryLazy" },
  { "https://github.com/tpope/vim-vinegar", event = "VeryLazy" },
  { "https://github.com/tpope/vim-sleuth", event = "VeryLazy" },
  { "https://github.com/tpope/vim-eunuch", event = "VeryLazy" },
  {
    "https://github.com/tpope/vim-fugitive",
    event = "VeryLazy",
    dependencies = { "https://github.com/tpope/vim-rhubarb" },
    keys = {
      {
        "<leader>gg",
        function()
          vim.cmd.G()
        end,
        desc = "[G]it (Fugitive)",
      },
      {
        "<leader>gS",
        function()
          vim.cmd("Git show")
        end,
        desc = "[G]it [S]how (Fugitive)",
      },
      {
        "<leader>gc",
        function()
          vim.cmd("Git commit")
        end,
        desc = "[G]it [C]ommit (Fugitive)",
      },
      {
        "<leader>gp",
        function()
          vim.cmd("Git push -u origin")
        end,
        desc = "[G]it [P]ush (Fugitive)",
      },
      {
        "<leader>gP",
        function()
          vim.cmd("Git pull")
        end,
        desc = "[G]it [P]ull (Fugitive)",
      },
      {
        "<leader>gw",
        function()
          vim.cmd("Gwrite")
        end,
        desc = "[Gw]rite (Fugitive)",
      },
      {
        "<leader>gB",
        function()
          vim.cmd("Git blame")
        end,
        desc = "[G]it [B]lame (Fugitive)",
      },
    },
  },
  {
    "https://github.com/tpope/vim-dadbod",
    dependencies = {
      { "https://github.com/kristijanhusak/vim-dadbod-ui", lazy = true },
      { "https://github.com/kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    cmd = {
      "DBUI",
      "DBUIToggle",
      "DBUIAddConnection",
      "DBUIFindBuffer",
    },
  },
}
