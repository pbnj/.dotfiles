return {
  "stevearc/oil.nvim",
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {
    view_options = { show_hidden = true },
  },
  dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
  lazy = false,
  keys = {
    { "-", "<cmd>Oil --float<cr>", { desc = "Open parent directory in Oil" } },
  },
}
