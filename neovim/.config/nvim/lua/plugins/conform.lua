return {
  "https://github.com/stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "Q",
      function()
        require("conform").format({ lsp_format = "fallback", async = true })
      end,
      mode = "n",
      desc = "Format Buffer",
    },
    {
      "<leader>cf",
      function()
        require("conform").format({ lsp_format = "fallback", async = true })
      end,
      mode = "n",
      desc = "[C]ode [F]ormat (Buffer)",
    },
  },
  opts = {
    format_on_save = {
      timeout_ms = 1500,
      lsp_format = "fallback",
    },
    formatters_by_ft = {
      bash = { "shellcheck", "shfmt" },
      go = { "goimports", "golangci-lint" },
      json = { "prettier" },
      lua = { "stylua" },
      markdown = { "injected", "markdownlint-cli2", "markdown-toc", "prettier", timeout_ms = 5000 },
      python = { "ruff_format" },
      rust = { "rustfmt" },
      sh = { "shellcheck", "shfmt" },
      terraform = { "terraform_fmt" },
      yaml = function()
        local bufname = vim.api.nvim_buf_get_name(0)
        if bufname:match("/.github/workflows/") then
          return { "pinact", "prettier" }
        end
        return { "prettier" }
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
      pinact = {
        command = "pinact",
        args = { "run", "$RELATIVE_FILEPATH" },
        stdin = false,
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
      markdown_toc = {
        command = "markdown-toc",
        args = function(_, ctx)
          local indent = vim.bo[ctx.buf].expandtab and (" "):rep(ctx.shiftwidth) or "\t"
          return { "--no-firsth1", "--bullets", "-", "--indent=" .. indent, "-i", "$FILENAME" }
        end,
        stdin = false,
      },
    },
  },
  init = function()
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
}
