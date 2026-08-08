-- Built-in plugins
vim.cmd.packadd("nohlsearch") -- auto-toggle hlsearch
vim.cmd.packadd("nvim.difftool")

-- high priority plugins
require("plugins.flatten")
require("plugins.mini")
require("plugins.snacks")

-- general plugins
require("plugins.cloak")
require("plugins.faster")
require("plugins.lsp")
require("plugins.showkeys")
require("plugins.treesitter")
require("plugins.vim-startuptime")
require("plugins.tmux-complete")

-- folke plugins
require("plugins.sidekick")
require("plugins.todo-comments")
require("plugins.trouble")
require("plugins.which-key")
require("plugins.tokyonight")

-- tpope plugins
require("plugins.vim-dotenv")
require("plugins.vim-rsi")
require("plugins.vim-sleuth")
require("plugins.vim-eunuch")
require("plugins.vim-dadbod")
require("plugins.vim-fugitive")

-- language plugins
require("plugins.helm")
