return {
  "https://github.com/stevearc/conform.nvim",
  event = "VeryLazy",
  opts = {
    format_on_save = {
      timeout_ms = 500,
      lsp_format = "fallback",
    },
    formatters_by_ft = {
      bash = { "shellcheck", "shfmt" },
      go = { "goimports", "golangci-lint" },
      json = { "prettierd", "jq", stop_after_first = true },
      lua = { "stylua" },
      markdown = { "markdownlint", "doctoc_update", "prettierd" },
      python = { "ruff_fix" },
      rust = { "rustfmt" },
      terraform = { "terraform_fmt" },
    },
    formatters = {
      doctoc_update = {
        command = "doctoc",
        args = { "--update-only", "$FILENAME" },
        stdin = false,
      },
    },
  },
}
