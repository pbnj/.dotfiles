vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
  callback = function(event)
    local client = assert(vim.lsp.get_client_by_id(event.data.client_id))
    if
      client:supports_method(vim.lsp.protocol.Methods.textDocument_completion)
    then
      vim.lsp.completion.enable(
        true,
        client.id,
        event.buf,
        { autotrigger = false }
      ) -- :help lsp-completion
    end
    if client.name == "rust-analyzer" then
      vim.lsp.on_type_formatting.enable(true, { client_id = client.id })
    end
    local map = function(keys, func, desc, mode)
      mode = mode or "n"
      vim.keymap.set(
        mode,
        keys,
        func,
        { buffer = event.buf, desc = "LSP: " .. desc }
      )
    end
    map("<c-s>", vim.lsp.buf.signature_help, "Signature Help", "i")
    map(
      "<c-space>",
      vim.lsp.completion.get,
      "Trigger completion suggestion",
      "i"
    )
    if
      client:supports_method(vim.lsp.protocol.Methods.textDocument_definition)
    then
      map("gd", vim.lsp.buf.definition, "Go to definition")
    end
    if
      client:supports_method(vim.lsp.protocol.Methods.textDocument_declaration)
    then
      map("gD", vim.lsp.buf.declaration, "Go to declaration")
    end
    if
      client:supports_method(
        vim.lsp.protocol.Methods.textDocument_implementation
      )
    then
      map("gi", vim.lsp.buf.implementation, "Go to implementation")
    end
    if
      client:supports_method(vim.lsp.protocol.Methods.textDocument_formatting)
    then
      map("grf", vim.lsp.buf.format, "Format buffer")
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = event.buf,
        group = vim.api.nvim_create_augroup(
          "lsp-format-" .. event.buf,
          { clear = true }
        ),
        callback = function()
          vim.lsp.buf.format({ bufnr = event.buf, id = client.id })
        end,
      })
    end
  end,
})

vim.api.nvim_create_autocmd("LspProgress", {
  buffer = buf,
  callback = function(ev)
    local value = ev.data.params.value
    vim.api.nvim_echo({ { value.message or "done" } }, false, {
      id = "lsp." .. ev.data.client_id,
      kind = "progress",
      source = "vim.lsp",
      title = value.title,
      status = value.kind ~= "end" and "running" or "success",
      percent = value.percentage,
    })
  end,
})

vim.pack.add({
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/b0o/SchemaStore.nvim",
})

vim.lsp.log.set_level("OFF")

local servers = {
  golangci_lint_ls = {},
  gopls = {},
  lua_ls = {},
  oxfmt = {},
  oxlint = {},
  ruff = {},
  rust_analyzer = {},
  stylua = {},
  tofu_ls = {},
  tflint = {},
  -- custom lsp config
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
        schemaStore = { enable = false, url = "" },
        schemas = require("schemastore").yaml.schemas({ extra = {} }),
      },
    },
  },
}

for server_name, server_config in pairs(servers) do
  server_config.capabilities = vim.tbl_deep_extend(
    "force",
    vim.lsp.protocol.make_client_capabilities(),
    server_config.capabilities or {}
  )
  vim.lsp.config(server_name, server_config)
  vim.lsp.enable(server_name)
end

vim.keymap.set("n", "<leader>li", function()
  vim.cmd.checkhealth("vim.lsp")
end, { desc = "[L]SP [I]nfo" })
