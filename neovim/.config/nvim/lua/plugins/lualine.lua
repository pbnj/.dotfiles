return {
  "https://github.com/nvim-lualine/lualine.nvim",
  dependencies = { "https://github.com/echasnovski/mini.nvim" },
  config = function()
    require("mini.icons").setup()
    require("mini.icons").mock_nvim_web_devicons()
    require("lualine").setup({})
  end,
}
