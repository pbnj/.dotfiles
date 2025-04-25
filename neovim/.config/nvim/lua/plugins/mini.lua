return {
  {
    "https://github.com/echasnovski/mini.nvim",
    event = "VeryLazy",
    version = false,
    config = function()
      require("mini.statusline").setup()
      require("mini.icons").setup()
    end,
  },
}
