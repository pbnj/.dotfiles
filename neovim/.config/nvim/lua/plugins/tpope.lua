return {
  { "https://github.com/tpope/vim-rsi", event = "VeryLazy" },
  { "https://github.com/tpope/vim-sleuth", event = "VeryLazy" },
  { "https://github.com/tpope/vim-eunuch", event = "VeryLazy" },
  {
    "https://github.com/tpope/vim-fugitive",
    dependencies = { "https://github.com/tpope/vim-rhubarb" },
    event = "VeryLazy",
    keys = {
      {
        "<leader>gg",
        function()
          vim.cmd.G()
        end,
        desc = "Git (Fugitive)",
      },
      {
        "<leader>gc",
        function()
          vim.cmd("Git commit")
        end,
        desc = "Git Commit (Fugitive)",
      },
      {
        "<leader>gp",
        function()
          vim.cmd("Git push -u origin")
        end,
        desc = "Git Push (Fugitive)",
      },
      {
        "<leader>gP",
        function()
          vim.cmd("Git pull")
        end,
        desc = "Git Pull (Fugitive)",
      },
      {
        "<leader>gw",
        function()
          vim.cmd("Gwrite")
        end,
        desc = "Gwrite (Fugitive)",
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
