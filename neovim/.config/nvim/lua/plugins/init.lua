-- Built-in plugins
require("vim._core.ui2").enable({}) -- experimental UI features
vim.cmd.packadd("nohlsearch") -- auto-toggle hlsearch

-- high priority plugins
require("plugins.mini")
require("plugins.snacks")

-- general plugins
require("plugins.cloak")
require("plugins.treesitter")
require("plugins.conform")
require("plugins.diffview")
require("plugins.faster")
require("plugins.lint")
require("plugins.quicker")
require("plugins.lsp")
require("plugins.showkeys")
require("plugins.vim-startuptime")

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
require("plugins.vim-fugitive")
require("plugins.vim-dadbod")
