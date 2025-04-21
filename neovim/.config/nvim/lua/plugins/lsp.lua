return {
  {
    "https://github.com/neovim/nvim-lspconfig",
    event = "VeryLazy",
    dependencies = {
      "https://github.com/saghen/blink.cmp",
      { "https://github.com/williamboman/mason.nvim", opts = {} },
      "https://github.com/williamboman/mason-lspconfig.nvim",
      "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim",
      { "https://github.com/j-hui/fidget.nvim", enabled = false, opts = {} },
      {
        "https://github.com/folke/lazydev.nvim",
        ft = "lua",
        opts = {
          library = {
            { path = "${3rd}/luv/library", words = { "vim%.uv" } },
          },
        },
      },
    },
    config = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
          end

          map("<leader>rn", vim.lsp.buf.rename, "Rename")
          map("<leader>ca", vim.lsp.buf.code_action, "Code Action", { "n", "x" })
          map("<leader>gr", require("fzf-lua").lsp_references, "Goto References")
          map("<leader>gi", require("fzf-lua").lsp_implementations, "Goto Implementation")
          map("<leader>gd", require("fzf-lua").lsp_definitions, "Goto Definition")
          map("<leader>gD", vim.lsp.buf.declaration, "Goto Declaration")
          map("<leader>gO", require("fzf-lua").lsp_document_symbols, "Open Document Symbols")
          map("<leader>gW", require("fzf-lua").lsp_live_workspace_symbols, "Open Workspace Symbols")
          map("<leader>gt", require("fzf-lua").lsp_typedefs, "Goto Type Definition")

          local function client_supports_method(client, method, bufnr)
            if vim.fn.has("nvim-0.11") == 1 then
              return client:supports_method(method, bufnr)
            else
              return client.supports_method(method, { bufnr = bufnr })
            end
          end

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_completion, event.buf) then
            vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
          end

          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })
            vim.api.nvim_create_autocmd("LspDetach", {
              group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
              end,
            })
          end

          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map("<leader>th", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
            end, "[T]oggle Inlay [H]ints")
          end
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
        bashls = {},
        docker_compose_language_service = {},
        dockerls = {},
        gopls = {},
        jsonls = {},
        lua_ls = {},
        pyright = {},
        rust_analyzer = {},
        snyk_ls = {
          settings = {},
          init_options = {
            organization = vim.env.SNYK_ORG,
            token = vim.env.SNYK_TOKEN,
            enableTrustedFoldersFeature = "false",
          },
        },
        terraformls = {},
        tflint = {},
        yamlls = {},
      }
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        "doctoc",
        "editorconfig-checker",
        "gh",
        "gitleaks",
        "goimports",
        "jq",
        "markdownlint",
        "prettier",
        "prettierd",
        "ruff",
        "shellcheck",
        "shfmt",
        "snyk",
        "stylua",
        "tflint",
        "trivy",
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
