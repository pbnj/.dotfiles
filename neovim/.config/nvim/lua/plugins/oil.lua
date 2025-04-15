return {
  "https://github.com/stevearc/oil.nvim",
  enabled = false,
  opts = {
    view_options = { show_hidden = true },
  },
  dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
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
