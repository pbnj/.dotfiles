return {
  "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {},
  keys = {
    {"<leader>ff", function() require('fzf-lua').files() end, desc="Fuzzy Files"},
    {"<leader>fg", function() require('fzf-lua').live_grep() end, desc="Fuzzy Grep"},
    {"<leader>fb", function() require('fzf-lua').buffers() end, desc="Fuzzy Buffers"},
    {"<leader>fp", function() require('fzf-lua').files({cwd='~/Projects'}) end, desc="Fuzzy Projects"},
  },
}
