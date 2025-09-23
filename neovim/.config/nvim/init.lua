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
vim.opt.complete = ".,w,b,u,t"
vim.opt.completeopt = { "menu", "menuone", "popup", "fuzzy" }
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
vim.opt.iskeyword = "@,48-57,_,192-255,-,#"
vim.opt.laststatus = 3
vim.opt.list = true
vim.opt.listchars = "tab:│⋅,trail:⋅,nbsp:␣"
vim.opt.modeline = true
vim.opt.modelines = 5
vim.opt.mouse = "a"
vim.opt.number = true
vim.opt.ruler = false
vim.opt.scrolloff = 10
vim.opt.shortmess = "FICcW"
vim.opt.showmode = false
vim.opt.sidescrolloff = 10
vim.opt.signcolumn = "yes"
vim.opt.smartcase = true
vim.opt.smarttab = true
vim.opt.splitkeep = "screen"
vim.opt.swapfile = false
vim.opt.ttimeout = true
vim.opt.ttimeoutlen = 50
vim.opt.ttyfast = true
vim.opt.undofile = true
vim.opt.wildignorecase = true
vim.opt.wildmenu = true
vim.opt.winborder = "rounded"
vim.opt.wrap = false
vim.opt.wrapscan = false

-- Load plugins
require("lazy").setup({
  rocks = { enabled = false, hererocks = false },
  spec = {
    { import = "plugins" },
  },
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

-- Keymaps
vim.keymap.set("n", "<leader>ll", vim.cmd.Lazy, { desc = "[L]azy" })
vim.keymap.set("n", "j", "gj")
vim.keymap.set("n", "k", "gk")
vim.keymap.set("c", "<c-p>", "<up>")
vim.keymap.set("c", "<c-n>", "<down>")

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

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
  callback = function(event)
    local client = assert(vim.lsp.get_client_by_id(event.data.client_id))
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = false }) -- :help lsp-completion
    end
    local map = function(keys, func, desc, mode)
      mode = mode or "n"
      vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
    end
    map("<c-s>", vim.lsp.buf.signature_help, "Signature Help", "i")
    map("<c-space>", vim.lsp.completion.get, "Trigger completion suggestion", "i")
  end,
})

-- Auto-toggle neovim background based on system theme
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("colorscheme_change", { clear = true }),
  pattern = "*",
  callback = function()
    vim.api.nvim_set_hl(0, "Normal", { bg = nil })
    -- vim.api.nvim_set_hl(0, "Visual", { link = "CursorLine" })
    if vim.system({ "uname" }):wait().stdout:match("Darwin") then
      vim.system({ "defaults", "read", "-g", "AppleInterfaceStyle", "2>/dev/null" }, nil, function(result)
        if result.stdout:match("Dark") then
          vim.schedule(function()
            vim.o.background = "dark"
          end)
        else
          vim.schedule(function()
            vim.o.background = "light"
          end)
        end
      end)
    end
  end,
})

-- Diagnostics configuration
vim.diagnostic.config({
  severity_sort = true,
  float = { border = "rounded", source = true },
  underline = true,
  virtual_text = {
    current_line = true,
    source = true,
  },
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
    json = "jsonc",
  },
  filename = {
    [".snyk"] = "yaml",
    [".aws/config"] = "dosini",
  },
  -- pattern = {
  --   [".*/%.github[%w/]+workflows[%w/]+.*%.ya?ml"] = "yaml.github",
  -- },
})

vim.cmd.colorscheme("default")
