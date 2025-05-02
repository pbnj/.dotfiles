return {
  { "https://github.com/tpope/vim-vinegar" },
  { "https://github.com/tpope/vim-rsi", event = "VeryLazy" },
  { "https://github.com/tpope/vim-sleuth", event = "VeryLazy" },
  { "https://github.com/tpope/vim-surround", event = "VeryLazy" },
  { "https://github.com/tpope/vim-eunuch", event = "VeryLazy" },
  {
    "https://github.com/tpope/vim-fugitive",
    dependencies = { "https://github.com/tpope/vim-rhubarb" },
    cmd = { "G", "Git", "GB", "GBrowse", "Gw", "Gwrite", "Gread" },
    keys = {
      {
        "<leader>gg",
        function()
          vim.cmd("Git")
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
    },
  },
  {
    "https://github.com/kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "https://github.com/tpope/vim-dadbod", lazy = true },
      { "https://github.com/kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    cmd = {
      "DBUI",
      "DBUIToggle",
      "DBUIAddConnection",
      "DBUIFindBuffer",
    },
    init = function()
      vim.g.db_ui_use_nerd_fonts = 1
    end,
  },
}
