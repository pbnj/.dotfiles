return {
  {
    "https://github.com/echasnovski/mini.nvim",
    event = "VeryLazy",
    version = false,
    config = function()
      require("mini.misc").setup_auto_root()
      require("mini.icons").setup()
      require("mini.diff").setup()
    end,
  },
}
