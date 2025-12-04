return {
  "https://github.com/neovim/nvim-lspconfig",
  init = function()
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
      callback = function(event)
        local client = assert(vim.lsp.get_client_by_id(event.data.client_id))
        if client:supports_method(vim.lsp.protocol.Methods.textDocument_completion) then
          vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = false }) -- :help lsp-completion
        end
        if vim.fn.has("nvim-0.12") == 1 and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion) then
          vim.lsp.inline_completion.enable(true) -- :help lsp-completion
        end
        local map = function(keys, func, desc, mode)
          mode = mode or "n"
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
        end
        map("<c-s>", vim.lsp.buf.signature_help, "Signature Help", "i")
        map("<c-space>", vim.lsp.completion.get, "Trigger completion suggestion", "i")
      end,
    })
  end,
  event = "VeryLazy",
  dependencies = {
    { "https://github.com/b0o/SchemaStore.nvim" },
  },
  config = function()
    vim.lsp.log.set_level("OFF")
    local servers = {
      -- misc
      docker_language_server = {},
      bashls = {},
      copilot = {},
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
            schemas = require("schemastore").yaml.schemas({
              extra = {
                -- {
                --   description = "OpenTelemetry Collector Schema",
                --   fileMatch = { "**/otel-collector*.yaml" },
                --   name = "otel-collector",
                --   url = "https://raw.githubusercontent.com/srikanthccv/otelcol-jsonschema/main/schema.json",
                -- },
              },
            }),
            customTags = {
              "!And sequence",
              "!If sequence",
              "!Not sequence",
              "!Equals sequence",
              "!Or sequence",
              "!FindInMap sequence",
              "!Base64 scalar",
              "!Cidr sequence",
              "!Ref scalar",
              "!Ref sequence",
              "!Sub scalar",
              "!Sub sequence",
              "!GetAtt scalar",
              "!GetAtt sequence",
              "!GetAZs scalar",
              "!ImportValue scalar",
              "!ImportValue sequence",
              "!Join sequence",
              "!Select sequence",
              "!Split sequence",
              "!Transform mapping",
              "!Condition scalar",
            },
          },
        },
      },
    }
    for server_name, server_config in pairs(servers) do
      server_config.capabilities = vim.tbl_deep_extend("force", vim.lsp.protocol.make_client_capabilities(), server_config.capabilities or {})
      vim.lsp.config(server_name, server_config)
      vim.lsp.enable(server_name)
    end
  end,
  keys = {
    { "<leader>li", vim.cmd.LspInfo, desc = "[L]SP [I]nfo" },
  },
}
