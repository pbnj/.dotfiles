vim.pack.add({ "https://github.com/folke/tokyonight.nvim" })

-- Transparent: the terminal's background shows through the editor, and through
-- sidebars and floats too.
require("tokyonight").setup({
  transparent = true,
  styles = {
    sidebars = "transparent",
    floats = "transparent",
  },
})

vim.cmd.colorscheme("tokyonight")
