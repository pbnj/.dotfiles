return {
  {
    "https://github.com/neovim/nvim-lspconfig",
    event = "VeryLazy",
    dependencies = {
      "https://github.com/folke/snacks.nvim",
      "https://github.com/saghen/blink.cmp",
      { "https://github.com/williamboman/mason.nvim", opts = {} },
      "https://github.com/williamboman/mason-lspconfig.nvim",
      "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim",
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
          map("<leader>gD", require("fzf-lua").lsp_declarations, "Goto Declaration")
          map("<leader>gO", require("fzf-lua").lsp_document_symbols, "Open Document Symbols")
          map("<leader>gW", require("fzf-lua").lsp_live_workspace_symbols, "Open Workspace Symbols")
          map("<leader>gt", require("fzf-lua").lsp_typedefs, "Goto Type Definition")
        end,
      })
      vim.api.nvim_create_autocmd("LspProgress", {
        ---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
        callback = function(ev)
          local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
          vim.notify(vim.lsp.status(), "info", {
            id = "lsp_progress",
            title = "LSP Progress",
            opts = function(notif)
              notif.icon = ev.data.params.value.kind == "end" and " " or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
            end,
          })
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
        gopls = {},
        jsonls = {},
        lua_ls = {},
        pyright = {},
        regal = {},
        rust_analyzer = {},
        snyk_ls = {
          filetypes = { "go", "gomod", "gowork", "helm", "javascript", "json", "python", "requirements", "terraform", "terraform-vars", "toml", "typescript", "yaml" },
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
