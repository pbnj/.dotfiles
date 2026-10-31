vim.pack.add({ "https://github.com/folke/which-key.nvim" })

require("which-key").setup({ preset = "helix" })

require("which-key").add({
  { "<leader>/", group = "Search" },
  { "<leader>d", group = "Diagnostics" },
})
