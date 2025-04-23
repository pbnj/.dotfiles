return {
  "https://github.com/saghen/blink.cmp",
  version = "1.*",
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
  event = "InsertEnter",
  opts = {
    keymap = { preset = "default" },
    signature = { enabled = true },
    fuzzy = { implementation = "prefer_rust_with_warning" },
    cmdline = {
      completion = {
        menu = { auto_show = false },
        list = { selection = { preselect = false, auto_insert = true } },
      },
    },
    sources = {
      default = { "lsp", "path", "buffer", "lazydev" },
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
