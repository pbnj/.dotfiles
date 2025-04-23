return {
  "https://github.com/mfussenegger/nvim-lint",
  config = function()
    local lint = require("lint")
    lint.linters_by_ft = {
      dockerfile = { "hadolint" },
      go = { "golangcilint" },
      json = { "jsonlint" },
      markdown = { "markdownlint" },
      python = { "ruff", "mypy" },
      rego = { "opa_check" },
      rust = { "clippy" },
      shell = { "shellcheck" },
      terraform = { "snyk_iac", "tflint" },
      yaml = { "yamllint" },
    }
    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
      pattern = "*",
      callback = function()
        lint.try_lint()
      end,
    })
  end,
}
