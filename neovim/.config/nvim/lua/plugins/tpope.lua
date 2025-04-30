return {
  {
    "https://github.com/tpope/vim-fugitive",
    dependencies = { "https://github.com/tpope/vim-rhubarb" },
    cmd = { "G", "Git", "GB", "GBrowse" },
    keys = {
      {
        "<leader>gg",
        function()
          vim.cmd("Git")
        end,
      },
      {
        "<leader>gc",
        function()
          vim.cmd("Git commit")
        end,
      },
      {
        "<leader>gp",
        function()
          vim.cmd("Git push -u origin")
        end,
      },
      {
        "<leader>gP",
        function()
          vim.cmd("Git pull")
        end,
      },
    },
  },
  { "https://github.com/tpope/vim-rsi", event = "VeryLazy" },
  { "https://github.com/tpope/vim-sleuth", event = "VeryLazy" },
  { "https://github.com/tpope/vim-surround", event = "VeryLazy" },
  { "https://github.com/tpope/vim-eunuch", event = "VeryLazy" },
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
