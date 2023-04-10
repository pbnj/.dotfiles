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
	{ 'https://github.com/junegunn/fzf.vim', dependencies = { { 'https://github.com/junegunn/fzf', dir = '~/.fzf', build = '~/.fzf/install --all' } } },
	{ 'https://github.com/ludovicchabant/vim-gutentags' },
	{ 'https://github.com/lukas-reineke/indent-blankline.nvim' },
	{ 'https://github.com/pbnj/pbnj.vim' },
	{ 'https://github.com/chriskempson/base16-vim' },
	{ 'https://github.com/pbnj/terradoc.vim' },
	{ 'https://github.com/pbnj/vim-britive' },
	{ 'https://github.com/tpope/vim-abolish' },
	{ 'https://github.com/tpope/vim-commentary' },
	{ 'https://github.com/tpope/vim-dispatch' },
	{ 'https://github.com/tpope/vim-endwise' },
	{ 'https://github.com/tpope/vim-eunuch' },
	{ 'https://github.com/tpope/vim-fugitive' },
	{ 'https://github.com/tpope/vim-rsi' },
	{ 'https://github.com/tpope/vim-surround' },
	{ 'https://github.com/tpope/vim-unimpaired' },
	{ 'https://github.com/tpope/vim-vinegar' },
	{ 'https://github.com/lewis6991/gitsigns.nvim',
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

-- lsp plugins
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

-- completion plugins
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

}, {})
