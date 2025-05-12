return {
  "https://github.com/stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  opts = {
    log_level = vim.log.levels.DEBUG,
    format_on_save = function()
      if vim.g.disable_conform or vim.b[0].disable_conform then
        return {}
      end
      return { lsp_format = "fallback" }
    end,
    formatters_by_ft = {
      bash = { "shellcheck", "shfmt" },
      go = { "goimports", "golangci-lint" },
      json = { "jq" },
      lua = { "stylua" },
      markdown = { "markdownlint", "doctoc_update", "prettierd", timeout_ms = 1500 },
      python = { "ruff_fix" },
      rust = { "rustfmt" },
      terraform = { "terraform_fmt" },
      yaml = { "prettierd" },
    },
    formatters = {
      injected = {
        options = {
          ignore_errors = true,
          lang_to_ft = {
            bash = "sh",
          },
          lang_to_ext = {
            bash = "sh",
            javascript = "js",
            markdown = "md",
            python = "py",
            ruby = "rb",
            rust = "rs",
            shell = "sh",
            terraform = "tf",
            typescript = "ts",
          },
        },
      },
      pin_github_action = {
        command = "pin-github-action",
        args = { "$RELATIVE_FILEPATH" },
        stdin = false,
      },
      doctoc_update = {
        command = "doctoc",
        args = { "--update-only", "$FILENAME" },
        stdin = false,
      },
    },
  },
}
