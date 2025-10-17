return {
  "https://github.com/nvim-mini/mini.nvim",
  lazy = false,
  version = false,
  config = function()
    require("mini.ai").setup({ n_lines = 500 })
    require("mini.bracketed").setup()
    require("mini.diff").setup()
    require("mini.git").setup()
    require("mini.icons").setup()
    require("mini.misc").setup_auto_root()
    require("mini.move").setup()
    require("mini.splitjoin").setup()
    require("mini.statusline").setup()
    require("mini.surround").setup()
  end,
  keys = {
    {
      "<leader>gh",
      function()
        MiniDiff.toggle_overlay(0)
      end,
      desc = "[G]it [H]unks (Diff Hunks)",
    },
  },
}
