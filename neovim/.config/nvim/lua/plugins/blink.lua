return {
  "https://github.com/saghen/blink.cmp",
  version = "1.*",
  dependencies = {
    "https://github.com/folke/lazydev.nvim",
  },
  event = "VeryLazy",
  opts = {
    keymap = { preset = "default" },
    signature = { enabled = true },
    fuzzy = {
      implementation = "prefer_rust_with_warning",
      sorts = {
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
        menu = { auto_show = false },
        list = { selection = { preselect = false, auto_insert = true } },
      },
    },
    sources = {
      default = { "lazydev", "lsp", "path", "buffer" },
      providers = {
        lazydev = {
          name = "LazyDev",
          module = "lazydev.integrations.blink",
          score_offset = 100,
        },
        lsp = { fallbacks = { "buffer" } },
        buffer = { opts = { get_bufnrs = vim.api.nvim_list_bufs } },
      },
    },
  },
  opts_extend = { "sources.default" },
}
