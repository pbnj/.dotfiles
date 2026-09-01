vim.pack.add({ "https://github.com/laytan/cloak.nvim" })
require("cloak").setup()

vim.keymap.set(
  "n",
  "<leader>tc",
  "<cmd>CloakToggle<cr>",
  { desc = "[T]oggle [C]loak" }
)
vim.keymap.set(
  "n",
  "<leader>tC",
  "<cmd>CloakPreviewLine<cr>",
  { desc = "[T]oggle [C]loak (current line)" }
)
