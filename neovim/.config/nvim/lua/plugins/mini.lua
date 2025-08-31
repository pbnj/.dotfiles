return {
  {
    "https://github.com/nvim-mini/mini.nvim",
    event = "VeryLazy",
    version = false,
    config = function()
      require("mini.misc").setup_auto_root()
      require("mini.ai").setup()
      -- require("mini.completion").setup({ lsp_completion = { source_func = "omnifunc" } })
      require("mini.diff").setup()
      require("mini.git").setup()
      require("mini.icons").setup()
      require("mini.statusline").setup()
      require("mini.surround").setup()
      require("mini.splitjoin").setup()
      require("mini.bracketed").setup()
      require("mini.files").setup()
    end,
  },
}
