return {
  "https://github.com/folke/tokyonight.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    light_style = "day",
    dim_inactive = true,
    transparent = true,
  },
  config = function()
    vim.cmd([[colorscheme tokyonight]])
  end,
}
