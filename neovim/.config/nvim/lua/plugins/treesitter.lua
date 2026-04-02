return {
  {
    "https://github.com/nvim-treesitter/nvim-treesitter",
    enabled = true,
    lazy = false,
    build = ":TSUpdate",
    dependencies = { "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },
    opts = {},
    config = function()
      require("nvim-treesitter").install({
        "awk",
        "bash",
        "c",
        "css",
        "csv",
        "diff",
        "dockerfile",
        "editorconfig",
        "git_config",
        "git_rebase",
        "gitattributes",
        "gitcommit",
        "gitignore",
        "go",
        "gomod",
        "gosum",
        "gotmpl",
        "graphql",
        "hcl",
        "http",
        "ini",
        "jq",
        "json",
        "json5",
        "lua",
        "make",
        "markdown",
        "markdown_inline",
        "mermaid",
        "python",
        "query",
        "regex",
        "requirements",
        "rust",
        "scss",
        "svelte",
        "terraform",
        "toml",
        "tsv",
        "tsx",
        "typst",
        "vim",
        "vimdoc",
        "vue",
        "yaml",
      })

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local ft = vim.bo[args.buf].filetype
          if ft:match("^snacks_") then
            return
          end -- skip snacks UI buffers
          if ft:match("^sidekick_terminal") then
            return
          end -- skip sidekick terminal buffers
          if ft:match("^text") then
            return
          end -- skip plaintext buffers
          if ft:match("^conf") then
            return
          end -- skip plaintext buffers
          if ft:match("^config") then
            return
          end -- skip plaintext buffers
          if ft:match("^fugitive") then
            return
          end -- skip fugitive buffers
          vim.treesitter.start(args.buf)
        end,
      })
    end,
  },
}
