return {
  "https://github.com/stevearc/oil.nvim",
  enable = false,
  lazy = false,
  opts = {
    view_options = {
      show_hidden = true,
    },
  },
  keys = {
    { "-", vim.cmd.Oil, desc = "Open parent directory" },
  },
}
