return {
  {
    "https://github.com/nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "https://github.com/nvim-tree/nvim-web-devicons" },
    opts = {
      sections = {
        lualine_c = {
          { "filename", path = 1 },
        },
      },
    },
  },
}
