return {
  "https://github.com/stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  opts = {
    format_on_save = {
      timeout_ms = 500,
      lsp_format = "fallback",
    },
    formatters_by_ft = {
      bash = { "shellcheck", "shfmt" },
      go = { "goimports", "golangci-lint" },
      json = { "jq" },
      lua = { "stylua" },
      markdown = { "markdownlint", "doctoc_update", "prettierd" },
      python = { "ruff_fix" },
      rust = { "rustfmt" },
      terraform = { "terraform_fmt" },
      yaml = function(bufnr)
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        if bufname:match("/.github/workflows/") then
          return { "pin_github_action", "prettierd" }
        elseif bufname:match(".snyk") then
          return {}
        else
          return { "prettierd" }
        end
      end,
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
        args = { "$FILENAME" },
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
