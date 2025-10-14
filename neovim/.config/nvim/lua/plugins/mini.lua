return {
  "https://github.com/nvim-mini/mini.nvim",
  lazy = false,
  version = false,
  config = function()
    require("mini.misc").setup_auto_root()
    require("mini.ai").setup({ n_lines = 500 })
    require("mini.diff").setup()
    require("mini.git").setup()
    require("mini.icons").setup()
    require("mini.statusline").setup()
    require("mini.surround").setup()
    require("mini.splitjoin").setup()
    require("mini.bracketed").setup()
  end,
}
