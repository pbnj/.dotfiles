return {
  {
    "https://github.com/neovim/nvim-lspconfig",
    event = "VeryLazy",
    dependencies = {
      { "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
      { "https://github.com/b0o/SchemaStore.nvim" },
      { "https://github.com/folke/snacks.nvim" },
      { "https://github.com/saghen/blink.cmp" },
      { "https://github.com/williamboman/mason-lspconfig.nvim" },
      { "https://github.com/williamboman/mason.nvim", opts = {} },
    },
    config = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
          end
          map("gra", vim.lsp.buf.code_action, "Code Actions")
          map("grD", vim.lsp.buf.declaration, "Goto Declaration")
          map("grd", vim.lsp.buf.definition, "Goto Definition")
          map("grf", vim.lsp.buf.format, "Format")
          map("gri", vim.lsp.buf.implementation, "Goto Implemention")
          map("grn", vim.lsp.buf.rename, "Rename")
          map("grs", vim.lsp.buf.document_symbol, "Goto Document Symbol")
          map("grS", vim.lsp.buf.workspace_symbol, "Goto Workspace Symbol")
          map("grr", vim.lsp.buf.references, "Goto References")
          map("grt", vim.lsp.buf.type_definition, "Goto Type Definition")
          map("<c-s>", vim.lsp.buf.signature_help, "Goto Type Definition", "i")
        end,
      })
      vim.diagnostic.config({
        severity_sort = true,
        float = { border = "rounded", source = "if_many" },
        underline = true,
        virtual_lines = { current_line = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "󰅚",
            [vim.diagnostic.severity.WARN] = "󰀪",
            [vim.diagnostic.severity.INFO] = "󰋽",
            [vim.diagnostic.severity.HINT] = "󰌶",
          },
        },
        loclist = {
          open = false,
          severity = { min = vim.diagnostic.severity.INFO },
        },
      })

      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local servers = {
        docker_compose_language_service = {},
        dockerls = {},
        -- gh_actions_ls = {},
        gopls = {},
        golangci_lint_ls = {},
        jsonls = {
          settings = {
            json = {
              schemas = require("schemastore").json.schemas(),
              validate = { enable = true },
            },
          },
        },
        lua_ls = {},
        pyright = {},
        regal = {},
        rust_analyzer = {},
        snyk_ls = {
          filetypes = { "go", "gomod", "gowork", "helm", "javascript", "json", "python", "requirements", "terraform", "terraform-vars", "toml", "typescript", "yaml" },
          settings = {},
          init_options = {
            activateSnykCode = "true",
            activateSnykIac = "true",
            activateSnykOpenSource = "true",
            additionalParams = "--all-projects",
            enableTrustedFoldersFeature = "false",
            organization = vim.env.SNYK_ORG,
            token = vim.env.SNYK_TOKEN,
          },
        },
        terraformls = {},
        tflint = {},
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
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        "doctoc",
        "editorconfig-checker",
        "gh",
        "gitleaks",
        "goimports",
        "jq",
        "kube-linter",
        "markdownlint",
        "opa",
        "prettier",
        "prettierd",
        "ruff",
        "shellcheck",
        "shfmt",
        "snyk",
        "stylua",
        "tflint",
        "trivy",
        "yq",
      })
      require("mason-tool-installer").setup({
        ensure_installed = ensure_installed,
        run_on_start = true,
      })
      require("mason-lspconfig").setup({
        ensure_installed = {},
        automatic_installation = true,
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
            require("lspconfig")[server_name].setup(server)
          end,
        },
      })
    end,
  },
}
