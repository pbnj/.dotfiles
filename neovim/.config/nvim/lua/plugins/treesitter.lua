return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function ()
      local configs = require("nvim-treesitter.configs")

      configs.setup({
        ensure_installed = {
          "awk",
          "bash",
          "c",
          "csv",
          "diff",
          "dockerfile",
          "editorconfig",
          "git_config",
          "git_rebase",
          "gitattributes",
          "gitcommit",
          "gitignore",
          "go", "gomod", "gosum", "gotmpl",
          "graphql",
          "hcl",
          "http",
          "ini",
          "lua",
          "make",
          "markdown",
          "markdown_inline",
          "mermaid",
          "python",
          "query",
          "rust", "regex", "requirements",
          "terraform",
          "toml",
          "tsv",
          "vim",
          "vimdoc",
          "yaml",
        },
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end
  },
  {"https://github.com/nvim-treesitter/nvim-treesitter-textobjects"}
}
