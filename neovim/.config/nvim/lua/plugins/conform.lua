return {
  "https://github.com/stevearc/conform.nvim",
  opts = {
    format_on_save = {
      timeout_ms = 500,
      lsp_format = "fallback",
    },
    formatters_by_ft = {
      bash = { "shellcheck", "shfmt" },
      gitcommit = { "commitmsgfmt" },
      go = { "goimports", "golangci-lint" },
      json = { "jq" },
      lua = { "stylua" },
      markdown = { "markdownlint", "doctoc", "prettierd" },
      python = { "ruff_fix" },
      rust = { "rustfmt", lsp_format = "fallback" },
      terraform = { "terraform_fmt" },
    },
  },
}
