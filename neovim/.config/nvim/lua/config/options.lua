-- Options & settings
vim.opt.backspace = "indent,eol,start"
vim.opt.belloff = "all"
vim.opt.breakindent = true
vim.opt.clipboard = "unnamedplus"
vim.opt.cmdheight = 1
vim.opt.complete:append({ "o" })
vim.opt.completeopt = { "menu", "menuone", "popup", "fuzzy", "noselect" }
vim.opt.conceallevel = 0
vim.opt.cursorline = false
vim.opt.expandtab = true
vim.opt.foldenable = false
vim.opt.grepformat:append({ "%f:%l:%c:%m", "%f:%l:%m" })
vim.opt.guifont = "JetBrainsMono Nerd Font"
vim.opt.hidden = true
vim.opt.hlsearch = true
vim.opt.ignorecase = true
vim.opt.inccommand = "split"
vim.opt.incsearch = true
vim.opt.infercase = true
vim.opt.iskeyword = "@,48-57,_,192-255,-"
vim.opt.laststatus = 2
vim.opt.list = true
vim.opt.listchars = "tab:│⋅,trail:⋅,nbsp:␣"
vim.opt.modeline = true
vim.opt.modelines = 5
vim.opt.mouse = "a"
vim.opt.number = true
vim.opt.pumborder = "rounded"
vim.opt.ruler = true
vim.opt.scrolloff = 10
vim.opt.shortmess = "FCcWl"
vim.opt.showcmd = false
vim.opt.showmode = false
vim.opt.sidescrolloff = 10
vim.opt.signcolumn = "yes"
vim.opt.smartcase = true
vim.opt.smarttab = true
vim.opt.swapfile = false
vim.opt.termguicolors = true
vim.opt.title = true
vim.opt.titlestring = "%f %{%v:lua.StatuslineBranch()%}"
vim.opt.ttimeout = true
vim.opt.ttimeoutlen = 50
vim.opt.ttyfast = true
vim.opt.undofile = true
vim.opt.wildignorecase = true
vim.opt.wildmenu = true
vim.opt.winborder = "rounded"
vim.opt.wrap = false
vim.opt.wrapscan = true

-- Append git branch (from mini.git) to Neovim's default statusline.
_G.StatuslineBranch = function()
  local s = vim.b.minigit_summary
  return (s and s.head_name) and string.format("(%s)", s.head_name) or ""
end

local default_statusline_split = vim.fn.split(vim.opt.statusline._info.default, "%=")
default_statusline_split[1] = string.format("%s %s", default_statusline_split[1], "%{% v:lua.StatuslineBranch() %}")
-- default_statusline_split[2] = string.format("%s %s", default_statusline_split[2], "(%{ wordcount().bytes / 4 })")
vim.opt.statusline = table.concat(default_statusline_split, "%=")
