return {
  "https://github.com/saghen/blink.cmp",
  dependencies = { "https://github.com/rafamadriz/friendly-snippets" },
  version = "1.*",
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    keymap = { preset = "default" },
    signature = { enabled = true },
    fuzzy = { implementation = "prefer_rust_with_warning" },
    completion = {
      documentation = { auto_show = true },
      list = { selection = { preselect = false, auto_insert = true } },
    },
    cmdline = {
      completion = {
        menu = { auto_show = true },
        list = { selection = { preselect = false, auto_insert = true } },
      },
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
  },
  opts_extend = { "sources.default" },
}
