return {
  "https://github.com/saghen/blink.cmp",
  dependencies = {
    {
      "https://github.com/folke/lazydev.nvim",
      ft = "lua",
      opts = {
        library = {
          { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        },
      },
    },
  },
  version = "1.*",
  event = "VeryLazy",
  opts = {
    keymap = { preset = "default" },
    signature = { enabled = true },
    fuzzy = {
      implementation = "prefer_rust_with_warning",
      sorts = {
        "exact",
        "score",
        "sort_text",
      },
    },
    completion = {
      documentation = { auto_show = false },
      list = { selection = { preselect = false, auto_insert = true } },
    },
    cmdline = {
      completion = {
        menu = { auto_show = true },
        list = { selection = { preselect = false, auto_insert = true } },
      },
    },
    sources = {
      default = { "lsp", "path", "buffer", "lazydev" },
      providers = {
        lsp = { fallbacks = { "buffer" } },
        buffer = { opts = { get_bufnrs = vim.api.nvim_list_bufs } },
        lazydev = { module = "lazydev.integrations.blink", score_offset = 100 },
      },
    },
  },
  opts_extend = { "sources.default" },
}
