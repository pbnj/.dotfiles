-- Built-in plugins
vim.cmd.packadd("nohlsearch") -- auto-toggle hlsearch
vim.cmd.packadd("nvim.difftool")

-- high priority plugins
require("plugins.mini")
require("plugins.snacks")

-- general plugins
require("plugins.cloak")
require("plugins.treesitter")
require("plugins.conform")
require("plugins.faster")
require("plugins.lint")
require("plugins.quicker")
require("plugins.lsp")
require("plugins.showkeys")
require("plugins.vim-startuptime")
require("plugins.neogit")

-- folke plugins
require("plugins.sidekick")
require("plugins.trouble")
require("plugins.todo-comments")
require("plugins.which-key")

-- tpope plugins
require("plugins.vim-dispatch")
require("plugins.vim-dotenv")
require("plugins.vim-rsi")
require("plugins.vim-sleuth")
require("plugins.vim-eunuch")
require("plugins.vim-dadbod")
