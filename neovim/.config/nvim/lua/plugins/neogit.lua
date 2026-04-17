vim.pack.add({"https://github.com/nvim-lua/plenary.nvim", "https://github.com/NeogitOrg/neogit"})
vim.keymap.set({"n"}, "<leader>gg" ,function() require("neogit").open() end, { desc = "Neogit" })
