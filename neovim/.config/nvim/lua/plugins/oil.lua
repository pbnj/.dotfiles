return {
  "https://github.com/stevearc/oil.nvim",
  dependencies = { "https://github.com/echasnovski/mini.nvim" },
  opts = {
    view_options = { show_hidden = true },
  },
  lazy = false,
  keys = {
    {
      "-",
      function()
        require("oil").open()
      end,
      { desc = "Open parent directory in Oil" },
    },
  },
}
