return {
  "https://github.com/mfussenegger/nvim-lint",
  config = function()
    local lint = require("lint")
    lint.linters_by_ft = {
      dockerfile = { "hadolint" },
      go = { "golangcilint" },
      markdown = { "markdownlint" },
      python = { "ruff" },
      rego = { "opa_check" },
      rust = { "clippy" },
      shell = { "shellcheck" },
      terraform = { "tflint" },
    }
    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
      pattern = "*",
      callback = function()
        lint.try_lint()
      end,
    })
  end,
}
