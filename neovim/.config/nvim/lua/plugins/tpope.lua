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
  -- { "https://github.com/tpope/vim-unimpaired", event = "VeryLazy", enabled = false },
  { "https://github.com/tpope/vim-surround", event = "VeryLazy" },
  { "https://github.com/tpope/vim-eunuch", event = "VeryLazy" },
}
