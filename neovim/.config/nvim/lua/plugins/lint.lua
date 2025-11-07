return {
  "https://github.com/mfussenegger/nvim-lint",
  event = "BufWritePost",
  config = function()
    local lint = require("lint")
    lint.linters_by_ft = {
      dockerfile = { "hadolint" },
      go = { "golangcilint" },
      markdown = { "markdownlint-cli2" },
      python = { "ruff" },
      rego = { "opa_check" },
      rust = { "clippy" },
      sh = { "shellcheck" },
      terraform = { "tflint", "terraform_validate" },
    }
    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
      pattern = "*",
      callback = function()
        lint.try_lint()
      end,
    })
  end,
}
