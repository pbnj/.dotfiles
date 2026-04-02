return {
  {
    "https://github.com/nvim-treesitter/nvim-treesitter",
    enabled = true,
    lazy = false,
    build = ":TSUpdate",
    dependencies = { "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },
    opts = {},
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "*" },
        callback = function(args)
          local ft = vim.bo[args.buf].filetype
          local lang = vim.treesitter.language.get_lang(ft) or ""

          local installed = require("nvim-treesitter").get_installed()
          if vim.tbl_contains(installed, lang) then
            if vim.treesitter.language.add(lang) then
              vim.treesitter.start(args.buf, lang)
              vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
              vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
              vim.wo[0][0].foldmethod = "expr"
            end
          else
            local available = vim.g.ts_available or require("nvim-treesitter").get_available()
            if not vim.g.ts_available then
              vim.g.ts_available = available
            end
            if vim.tbl_contains(available, lang) then
              require("nvim-treesitter").install(lang)
            end
          end
        end,
      })
    end,
  },
}
