return {
  "https://github.com/ibhagwan/fzf-lua",
  dependencies = { "https://github.com/echasnovski/mini.nvim" },
  opts = {
    actions = {
      files = {
        true,
        ["ctrl-a"] = {
          header = "create file",
          fn = function(_, opts)
            local utils = require("fzf-lua.utils")
            local file = opts.last_query
            if type(file) ~= "string" or #file == 0 then
              utils.warn("File name cannot be empty")
            else
              local fullpath = vim.fs.joinpath(opts._cwd, file)
              vim.cmd("edit " .. fullpath)
              utils.info(string.format("created file '%s'.", fullpath))
            end
          end,
        },
      },
    },
    keymap = {
      builtin = {
        ["<c-j>"] = "preview-down",
        ["<c-k>"] = "preview-up",
        ["<c-d>"] = "preview-half-page-down",
        ["<c-u>"] = "preview-half-page-up",
      },
    },
  },
  cmd = { "FzfLua" },
  keys = {
    {
      "<leader><space>",
      function()
        require("fzf-lua").builtin()
      end,
      desc = "FZF",
    },
    {
      "<leader>/",
      function()
        require("fzf-lua").live_grep()
      end,
      desc = "Fuzzy Grep",
    },
    {
      "<leader>;",
      function()
        require("fzf-lua").command_history()
      end,
      desc = "Fuzzy Command History",
    },
    {
      "<leader>:",
      function()
        require("fzf-lua").commands()
      end,
      desc = "Fuzzy Commands",
    },
    {
      "<leader>.",
      function()
        require("fzf-lua").files({ cwd = vim.fn.stdpath("config") })
      end,
      desc = "Fuzzy Dotfiles",
    },
    {
      "<leader>fb",
      function()
        require("fzf-lua").buffers()
      end,
      desc = "Fuzzy Buffers",
    },
    {
      "<leader>fdd",
      function()
        require("fzf-lua").diagnostics_document()
      end,
      desc = "Fuzzy Diagnostics (Document)",
    },
    {
      "<leader>fdw",
      function()
        require("fzf-lua").diagnostics_workspace()
      end,
      desc = "Fuzzy Diagnostics (Workspace)",
    },
    {
      "<leader>ff",
      function()
        require("fzf-lua").files()
      end,
      desc = "Fuzzy Files",
    },
    {
      "<leader>fgg",
      function()
        require("fzf-lua").git_files()
      end,
      desc = "Fuzzy Git Files",
    },
    {
      "<leader>fgb",
      function()
        require("fzf-lua").git_branches()
      end,
      desc = "Fuzzy Git Branches",
    },
    {
      "<leader>fgs",
      function()
        require("fzf-lua").git_status()
      end,
      desc = "Fuzzy Git Status",
    },
    {
      "<leader>fh",
      function()
        require("fzf-lua").help_tags()
      end,
      desc = "Fuzzy Help",
    },
    {
      "<leader>fo",
      function()
        require("fzf-lua").oldfiles()
      end,
      desc = "Fuzzy Old Files",
    },
    {
      "<leader>fp",
      function()
        require("fzf-lua").files({ cwd = "~/Projects" })
      end,
      desc = "Fuzzy Projects",
    },
    {
      "<leader>fr",
      function()
        require("fzf-lua").resume()
      end,
      desc = "Fuzzy Resume",
    },
    {
      "<leader>fw",
      function()
        require("fzf-lua").grep_cword()
      end,
      desc = "Fuzzy Grep Current Word",
    },
    {
      "<leader>fw",
      function()
        require("fzf-lua").grep_visual()
      end,
      mode = "v",
      desc = "Fuzzy Grep Visual Selection",
    },
    {
      "<leader>fh",
      function()
        require("fzf-lua").help_tags({ query = require("fzf-lua.utils").get_visual_selection() })
      end,
      mode = "v",
      desc = "Fuzzy Help Visual Selection",
    },
    {
      "<leader>fc",
      function()
        require("fzf-lua").lsp_code_actions()
      end,
      desc = "Fuzzy Code Actions",
    },
    {
      "<leader>flr",
      function()
        require("fzf-lua").lsp_references()
      end,
      desc = "Fuzzy LSP References",
    },
    {
      "<leader>fli",
      function()
        require("fzf-lua").lsp_implementations()
      end,
      desc = "Fuzzy LSP Implementations",
    },
    {
      "<leader>fld",
      function()
        require("fzf-lua").lsp_definitions()
      end,
      desc = "Fuzzy LSP Definitions",
    },
    {
      "<leader>flD",
      function()
        require("fzf-lua").lsp_declarations()
      end,
      desc = "Fuzzy LSP Declarations",
    },
    {
      "<leader>fls",
      function()
        require("fzf-lua").lsp_document_symbols()
      end,
      desc = "Fuzzy LSP Symbols (Document)",
    },
    {
      "<leader>flS",
      function()
        require("fzf-lua").lsp_live_workspace_symbols()
      end,
      desc = "Fuzzy Open Symbols (Workspace)",
    },
    {
      "<leader>flt",
      function()
        require("fzf-lua").lsp_typedefs()
      end,
      desc = "Fuzzy LSP Type Definition",
    },
  },
}
