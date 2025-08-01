return {
  {
    "https://github.com/neovim/nvim-lspconfig",
    event = "VeryLazy",
    dependencies = {
      { "https://github.com/b0o/SchemaStore.nvim" },
      {
        "https://github.com/folke/lazydev.nvim",
        ft = "lua",
        opts = {
          library = {
            {
              path = "${3rd}/luv/library",
              words = { "vim%.uv" },
            },
            {
              path = "snacks.nvim",
              words = { "Snacks" },
            },
          },
        },
      },
    },
    config = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
        callback = function(event)
          local client = assert(vim.lsp.get_client_by_id(event.data.client_id))
          if client:supports_method("textDocument/completion") then
            vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = false }) -- :help lsp-completion
          end
          local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
          end
          map("<c-s>", vim.lsp.buf.signature_help, "Signature Help", "i")
          map("<c-space>", vim.lsp.completion.get, "Trigger completion suggestion", "i")
        end,
      })
      vim.diagnostic.config({
        severity_sort = true,
        float = { border = "rounded", source = true },
        underline = true,
        virtual_text = true,
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "󰅚",
            [vim.diagnostic.severity.WARN] = "󰀪",
            [vim.diagnostic.severity.INFO] = "󰋽",
            [vim.diagnostic.severity.HINT] = "󰌶",
          },
        },
      })
      local capabilities = vim.tbl_deep_extend("force", {}, vim.lsp.protocol.make_client_capabilities())
      local servers = {
        -- misc
        docker_language_server = {},
        gh_actions_ls = {},
        -- go
        gopls = {},
        golangci_lint_ls = {},
        -- lua
        lua_ls = {},
        -- python
        pyright = {},
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
  },
}
