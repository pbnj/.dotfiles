vim.pack.add({ "https://github.com/folke/sidekick.nvim" })

require("sidekick").setup({
  nes = { enabled = false },
  cli = {
    tools = {
      antigravity = {
        cmd = { "agy" },
      },
    },
  },
})

vim.keymap.set({ "n", "t", "i", "x" }, "<c-.>", function()
  require("sidekick.cli").toggle()
end, { desc = "Sidekick Toggle" })

vim.keymap.set("n", "<leader>aa", function()
  require("sidekick.cli").toggle()
end, { desc = "Sidekick Toggle CLI" })

vim.keymap.set({ "n", "v" }, "<leader>ap", function()
  require("sidekick.cli").prompt()
end, { desc = "Sidekick Ask Prompt" })

vim.keymap.set("n", "<leader>as", function()
  require("sidekick.cli").select()
end, { desc = "Select CLI" })

vim.keymap.set({ "x", "n" }, "<leader>at", function()
  require("sidekick.cli").send({ msg = "{this}" })
end, { desc = "Send This" })

vim.keymap.set("x", "<leader>av", function()
  require("sidekick.cli").send({ msg = "{selection}" })
end, { desc = "Send Visual Selection" })
