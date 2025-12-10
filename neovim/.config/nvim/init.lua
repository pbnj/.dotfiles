-- initialize Lazy plugin manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Global Variables
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.g.editorconfig = true
vim.g.netrw_keepdir = 0

-- Options & settings
vim.opt.backspace = "indent,eol,start"
vim.opt.belloff = "all"
vim.opt.breakindent = true
vim.opt.clipboard = "unnamedplus"
vim.opt.cmdheight = 1
-- enable in nvim-0.12
-- vim.opt.autocomplete = true
-- vim.opt.complete:append({ "o" })
vim.opt.completeopt = { "menu", "menuone", "popup", "fuzzy", "noselect" }
vim.opt.conceallevel = 0
vim.opt.cursorline = false
vim.opt.expandtab = true
vim.opt.foldenable = false
vim.opt.grepformat:append({ "%f:%l:%c:%m", "%f:%l:%m" })
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
vim.opt.ruler = false
vim.opt.scrolloff = 10
vim.opt.shortmess = "FICcWl"
vim.opt.showcmd = false
vim.opt.showmode = false
vim.opt.sidescrolloff = 10
vim.opt.signcolumn = "yes"
vim.opt.smartcase = true
vim.opt.smarttab = true
vim.opt.swapfile = false
vim.opt.ttimeout = true
vim.opt.ttimeoutlen = 50
vim.opt.ttyfast = true
vim.opt.undofile = true
vim.opt.wildignorecase = true
vim.opt.wildmenu = true
vim.opt.winborder = "rounded"
vim.opt.wrap = false
vim.opt.wrapscan = true

-- Load plugins
require("lazy").setup({
  rocks = { enabled = false, hererocks = false },
  spec = {
    { import = "plugins" },
  },
  install = { colorscheme = { "tokyonight" } },
  ui = { border = "rounded" },
  checker = { enabled = true },
  change_detection = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
        "rplugin",
        "shada",
      },
    },
  },
})

-- Keymaps > General
vim.keymap.set("c", "<C-n>", "<Down>", { noremap = true })
vim.keymap.set("c", "<C-p>", "<Up>", { noremap = true })
vim.keymap.set("n", "j", "gj", { noremap = true, silent = true })
vim.keymap.set("n", "k", "gk", { noremap = true, silent = true })
vim.keymap.set("i", "<Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true })
vim.keymap.set("i", "<S-Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
end, { expr = true })
vim.keymap.set({ "n", "v" }, "n", function()
  return (vim.v.searchforward == 1 and "n" or "N")
end, { expr = true, silent = true, desc = "Search forward" })
vim.keymap.set({ "n", "v" }, "N", function()
  return (vim.v.searchforward == 1 and "N" or "n")
end, { expr = true, silent = true, desc = "Search backward" })

-- Keymaps > Lazy
vim.keymap.set("n", "<leader>ll", vim.cmd.Lazy, { desc = "[L]azy" })
vim.keymap.set("n", "<leader>lu", function()
  vim.cmd.Lazy("update")
end, { desc = "[L]azy [U]pdate" })
vim.keymap.set("n", "<leader>lp", function()
  vim.cmd.Lazy("profile")
end, { desc = "[L]azy [P]rofile" })

-- Autocommands
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("resize_windows", { clear = true }),
  pattern = "*",
  command = "wincmd =",
})

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.hl.on_yank({ higroup = "Visual", timeout = 300 })
  end,
})

-- Auto-toggle neovim background based on system theme
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("colorscheme_change", { clear = true }),
  pattern = "*",
  callback = function()
    vim.api.nvim_set_hl(0, "Normal", { bg = nil })
    vim.api.nvim_set_hl(0, "Visual", { link = "CursorLine" })
    if vim.loop.os_uname().sysname:match("Darwin") then
      if vim.fn.systemlist({ "defaults", "read", "-g", "AppleInterfaceStyle", "2>/dev/null" })[1]:match("Dark") then
        vim.schedule(function()
          vim.o.background = "dark"
        end)
      else
        vim.schedule(function()
          vim.o.background = "light"
        end)
      end
    end
  end,
})

-- Diagnostics configuration
vim.diagnostic.config({
  severity_sort = true,
  float = { border = "rounded", source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "󰅚",
      [vim.diagnostic.severity.WARN] = "󰀪",
      [vim.diagnostic.severity.INFO] = "󰋽",
      [vim.diagnostic.severity.HINT] = "󰌶",
    },
  },
})

-- Filetypes
vim.filetype.add({
  extension = {
    tofu = "terraform",
    tf = "terraform",
  },
  filename = {
    [".snyk"] = "yaml",
    -- [".aws/config"] = "dosini",
  },
  pattern = {
    --   [".*/%.github[%w/]+workflows[%w/]+.*%.ya?ml"] = "yaml.github",
    [".*"] = {
      function(path, bufnr)
        local contents = vim.api.nvim_buf_get_lines(bufnr, 0, 3, false) or {}
        for _, v in ipairs(contents) do
          if v:match("apiVersion:%s%S+") then
            return "yaml"
          end
        end
        -- if vim.regex([[^apiVersion:]]):match_str(content) ~= nil then
        --   return "yaml"
        -- end
      end,
      { priority = -math.huge },
    },
  },
})

-- Built-in packages
vim.cmd.packadd("nohlsearch") -- auto-toggle hlsearch

-- Colorscheme
vim.cmd.colorscheme("default")
