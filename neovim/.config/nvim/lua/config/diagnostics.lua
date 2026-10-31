-- Diagnostics configuration
vim.diagnostic.config({
  severity_sort = true,
  float = { border = "rounded", source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "󰅚",
      [vim.diagnostic.severity.WARN] = "󰀪",
      [vim.diagnostic.severity.INFO] = "󰋽",
      [vim.diagnostic.severity.HINT] = "󰌶",
    },
  },
})

vim.keymap.set("n", "<leader>dq", function()
  vim.diagnostic.setqflist({ open = false })
end, { desc = "Diagnostics: all → quickfix" })

vim.keymap.set("n", "<leader>ds", function()
  vim.diagnostic.setqflist({
    namespace = require("sarif").namespace,
    open = false,
  })
end, { desc = "Diagnostics: SARIF → quickfix" })

vim.keymap.set("n", "<leader>dt", function()
  vim.cmd("Trouble diagnostics toggle")
end, { desc = "Diagnostics: toggle Trouble" })
