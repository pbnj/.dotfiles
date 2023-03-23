vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- install neovim package manager
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  {
    'https://github.com/junegunn/fzf.vim',
    dependencies = {
      { 'https://github.com/junegunn/fzf', dir = '~/.fzf', build = '~/.fzf/install.sh --all' },
    }
  },
  -- let project_finder = executable('fd') ? 'fd . ~/Projects --type d' : 'find ~/Projects -type d -not \( -path *.git* -prune \) -not \( -path *.terraform* -prune \)'
  -- command! -bang Projects
  --       \ call fzf#run(fzf#wrap({'source': project_finder,'options': '--prompt=Projects\>\ '}))
  -- command! URLs
  --       \ call fzf#run(fzf#wrap({'source': map(filter(uniq(split(join(getline(1,'$'),' '),' ')), 'v:val =~ "http"'), {k,v->substitute(v,'\(''\|)\|"\|,\)','','g')}), 'sink': 'Open', 'options': '--multi --prompt=URLs\>\ '}))

  'https://github.com/lukas-reineke/indent-blankline.nvim',
  'https://github.com/numToStr/Comment.nvim',
  'https://github.com/editorconfig/editorconfig-vim',
  'https://github.com/ervandew/supertab',
  'https://github.com/godlygeek/tabular',
  'https://github.com/pbnj/terradoc.vim',
  'https://github.com/pbnj/vim-britive',
  'https://github.com/sheerun/vim-polyglot',
  'https://github.com/tpope/vim-abolish',
  'https://github.com/tpope/vim-commentary',
  'https://github.com/tpope/vim-endwise',
  'https://github.com/tpope/vim-eunuch',
  'https://github.com/tpope/vim-fugitive',
  'https://github.com/tpope/vim-rsi',
  'https://github.com/tpope/vim-surround',
  'https://github.com/tpope/vim-unimpaired',
  'https://github.com/tpope/vim-vinegar',
  'https://github.com/wellle/tmux-complete.vim',
  'https://github.com/ludovicchabant/vim-gutentags',

  {
    'https://github.com/akinsho/toggleterm.nvim',
    config = true,
  },

  {
    'https://github.com/catppuccin/nvim',
    name = 'catppuccin',
    opts = { no_italic = true },
  },

  {
    'https://github.com/neovim/nvim-lspconfig',
    dependencies = {
      'https://github.com/williamboman/mason.nvim',
      'https://github.com/williamboman/mason-lspconfig.nvim',
      'https://github.com/folke/neodev.nvim',
      {
        'https://github.com/j-hui/fidget.nvim',
        opts = {},
      },
    },
  },

  {
    'https://github.com/hrsh7th/nvim-cmp',
    dependencies = {
      'https://github.com/hrsh7th/cmp-nvim-lsp',
      'https://github.com/hrsh7th/cmp-buffer',
      'https://github.com/hrsh7th/cmp-path',
      'https://github.com/hrsh7th/cmp-cmdline',
      'https://github.com/L3MON4D3/LuaSnip',
      'https://github.com/saadparwaiz1/cmp_luasnip',
    },
  },

  { 'https://github.com/folke/which-key.nvim', opts = {} },
  {
    'https://github.com/lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
  },

}, {})

vim.o.autoindent     = 1
vim.o.autoread       = 1
vim.o.background     = 'dark'
vim.o.backspace      = 'indent,eol,start'
vim.o.breakindent    = 1
vim.o.clipboard      = 'unnamed,unnamedplus'
vim.o.completeopt    = 'menu,noselect'
vim.o.cursorline     = 1
vim.o.encoding       = 'utf-8'
vim.o.errorformat    = '%f:%l:%m,%f:%l:%c:%m'
vim.o.fillchars      = 'vert:│,fold:-,eob: '
vim.o.grepformat     = '%f:%l:%c:%m'
vim.o.hidden         = 1
vim.o.hlsearch       = 1
vim.o.ignorecase     = 1
vim.o.incsearch      = 1
vim.o.infercase      = 1
vim.o.laststatus     = 2
vim.o.lazyredraw     = 1
vim.o.linebreak      = 1
vim.o.list           = 1
vim.o.listchars      = 'tab:| ,trail:·'
vim.o.modeline       = 1
vim.o.mouse          = 'a'
vim.o.number         = 1
vim.o.secure         = 1
vim.o.shortmess      = 'filnxtToOc'
vim.o.showmode       = 1
vim.o.signcolumn     = 'yes'
vim.o.smartcase      = 1
vim.o.smarttab       = 1
vim.o.swapfile       = 0
vim.o.termguicolors  = 1
vim.o.timeout        = true
vim.o.timeoutlen     = 300
vim.o.ttimeout       = 1
vim.o.ttimeoutlen    = 50
vim.o.ttyfast        = 1
vim.o.undofile       = 1
vim.o.updatetime     = 250
vim.o.wildignorecase = 1
vim.o.wildmenu       = 1
vim.o.wildmode       = 'longest:full,full'
vim.o.wrap           = 0

vim.o.wildignore     =
'*.o,*.obj,*.bin,*.dll,*.exe,*.DS_Store,*.pdf,*/.ssh/*,*.pub,*.crt,*.key,*/cache/*,*/dist/*,*/node_modules/*,*/vendor/*,*/__pycache__/*,*/build/*,*/.git/*,*/.terraform/*'

if vim.fn.executable('rg') then
  vim.o.grepprg = 'rg --vimgrep --line-number --column $*'
elseif vim.fn.executable('git') then
  vim.o.grepprg = 'git grep --line-number --column $*'
else
  vim.o.grepprg = 'grep -HIn --line-buffered $*'
end

vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('t', '<esc>', '<c-\\><c-n>', { silent = true, desc = "Go to normal mode in terminal buffer" })
vim.keymap.set('n', '<leader>tt', '<cmd>ToggleTerm size=30<cr>', { silent = true, desc = "Toggle split terminal" })

vim.keymap.set('n', '<leader>dl', vim.diagnostic.setloclist, { desc = "Open diagnostics list" })
vim.keymap.set('n', '<leader>do', vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic message" })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = "Go to next diagnostic message" })

local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = '*',
})

local on_attach = function(_, bufnr)
  local nmap = function(keys, func, desc)
    if desc then
      desc = 'LSP: ' .. desc
    end
    vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
  end

  nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
  nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
  nmap('gd', vim.lsp.buf.definition, '[G]oto [D]efinition')
  nmap('gr', vim.lsp.buf.references, '[G]oto [R]eferences')
  nmap('gI', vim.lsp.buf.implementation, '[G]oto [I]mplementation')
  nmap('gt', vim.lsp.buf.type_definition, '[G]oto [T]ype Definition')
  nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
  nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
  nmap('<C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')

  vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
    vim.lsp.buf.format()
  end, { desc = 'Format current buffer with LSP' })
end

local servers = {
  bashls = {},
  docker_compose_language_service = {},
  dockerls = {},
  golangci_lint_ls = {},
  gopls = {},
  jsonls = {},
  lua_ls = { Lua = { workspace = { checkThirdParty = false }, telemetry = { enable = false }, }, },
  marksman = {},
  rust_analyzer = {},
  terraformls = {},
  tflint = {},
  yamlls = {},
}

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

require('mason').setup()
local mason_lspconfig = require 'mason-lspconfig'
mason_lspconfig.setup {
  ensure_installed = vim.tbl_keys(servers),
}
mason_lspconfig.setup_handlers {
  function(server_name)
    require('lspconfig')[server_name].setup {
      capabilities = capabilities,
      on_attach = on_attach,
      settings = servers[server_name],
    }
  end,
}

local cmp = require 'cmp'
local luasnip = require 'luasnip'
luasnip.config.setup {}
cmp.setup {
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert {
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete {},
    ['<CR>'] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    },
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { 'i', 's' }),
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'buffer' },
  },
}
cmp.setup.cmdline({ '/', '?' }, {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = 'buffer' }
  }
})
cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = 'path' }
  }, {
    { name = 'cmdline' }
  })
})

vim.cmd [[ colorscheme catppuccin ]]

-- vim:ts=2:sts=2:sw=2:et:
