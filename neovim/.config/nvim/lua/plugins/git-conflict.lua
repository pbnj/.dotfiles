return {
  "https://github.com/akinsho/git-conflict.nvim",
  cmd = {
    "GitConflictChooseOurs",
    "GitConflictChooseTheirs",
    "GitConflictChooseBoth",
    "GitConflictChooseNone",
    "GitConflictNextConflict",
    "GitConflictPrevConflict",
    "GitConflictListQf",
  },
  keys = {
    {"]x", function() vim.cmd[[GitConflictNextConflict]] end, desc = "GitConflictNextConflict"},
    {"[x", function() vim.cmd[[GitConflictPrevConflict]] end, desc = "GitConflictPrevConflict"},
  },
  version = "*",
  opts = {},
}
