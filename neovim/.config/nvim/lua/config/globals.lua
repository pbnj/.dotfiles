-- Global Variables
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.g.editorconfig = true
vim.g.netrw_keepdir = 0

-- disable built-in plugins
local disabled_built_ins = {
	"2html_plugin",
	"getscript",
	"getscriptPlugin",
	"gzip",
	"logipat",
	"netrw",
	"netrwFileHandlers",
	"netrwPlugin",
	"netrwSettings",
	"rplugin",
	"shada_plugin",
	"tar",
	"tarPlugin",
	"tohtml",
	"tutor",
	"zip",
	"zipPlugin",
	"shada",
}

for _, plugin in pairs(disabled_built_ins) do
	vim.g["loaded_" .. plugin] = 1
end
