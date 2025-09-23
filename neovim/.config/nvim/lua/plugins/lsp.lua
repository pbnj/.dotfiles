return {
  "https://github.com/neovim/nvim-lspconfig",
  event = "VeryLazy",
  dependencies = {
    { "https://github.com/b0o/SchemaStore.nvim" },
  },
  config = function()
    vim.lsp.set_log_level("OFF")
    local capabilities = vim.tbl_deep_extend("force", {}, vim.lsp.protocol.make_client_capabilities())
    local servers = {
      -- misc
      docker_language_server = {},
      bashls = {},
      snyk_language_server = {},
      -- go
      gopls = {},
      golangci_lint_ls = {},
      -- python
      pyright = {},
      -- lua
      lua_ls = {},
      -- rust
      rust_analyzer = {},
      -- terraform
      terraformls = {},
      tflint = {},
      -- config languages
      regal = {},
      jsonls = {
        settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      },
      yamlls = {
        settings = {
          yaml = {
            schemaStore = {
              enable = false, -- disable built-in yamlls schemastore
              url = "", -- Avoid TypeError: Cannot read properties of undefined (reading 'length')
            },
            schemas = require("schemastore").yaml.schemas(),
          },
        },
      },
    }
    for server_name, server_config in pairs(servers) do
      server_config.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server_config.capabilities or {})
      vim.lsp.config(server_name, server_config)
      vim.lsp.enable(server_name)
    end
  end,
  keys = {
    { "<leader>li", vim.cmd.LspInfo, desc = "[L]SP [I]nfo" },
  },
}
