-- :help fzf-lua.txt
return {
  "https://github.com/ibhagwan/fzf-lua",
  dependencies = {
    { "https://github.com/nvim-mini/mini.nvim" },
  },
  init = function()
    require("fzf-lua").register_ui_select()
  end,
  opts = {
    grep = { hidden = true },
    keymap = {
      builtin = {
        -- neovim `:tmap` mappings for the fzf win
        ["<M-Esc>"] = "hide",
        ["<F1>"] = "toggle-help",
        ["<F2>"] = "toggle-fullscreen",
        ["<F3>"] = "toggle-preview-wrap",
        ["<F4>"] = "toggle-preview",
        ["<F5>"] = "toggle-preview-cw",
        ["<F6>"] = "toggle-preview-behavior",
        ["<C-u>"] = "preview-page-up",
        ["<C-d>"] = "preview-page-down",
        ["<C-j>"] = "preview-half-page-down",
        ["<C-k>"] = "preview-half-page-up",
      },
      fzf = {
        -- fzf '--bind=' options
        ["alt-a"] = "toggle-all",
        ["alt-g"] = "first",
        ["alt-G"] = "last",
        ["f3"] = "toggle-preview-wrap",
        ["f4"] = "toggle-preview",
        ["shift-down"] = "preview-page-down",
        ["shift-up"] = "preview-page-up",
        ["ctrl-u"] = "preview-page-up",
        ["ctrl-d"] = "preview-page-down",
        ["ctrl-j"] = "preview-half-page-down",
        ["ctrl-k"] = "preview-half-page-up",
      },
    },
  },
  keys = {
    {
      "<leader><space>",
      function()
        require("fzf-lua").builtin()
      end,
      desc = "All Pickers",
    },
    {
      "<leader>/",
      function()
        require("fzf-lua").live_grep()
      end,
      desc = "Fuzzy Live Grep",
    },
    {
      "<leader>/",
      function()
        require("fzf-lua").grep_visual()
      end,
      desc = "Visual selection or word",
      mode = { "x" },
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
      "<leader>fb",
      function()
        require("fzf-lua").buffers()
      end,
      desc = "[F]ind [B]uffers",
    },
    {
      "<leader>fc",
      function()
        require("fzf-lua").files({ cwd = "~/.config/nvim", hidden = true })
      end,
      desc = "[F]ind Neovim [C]onfig Files",
    },
    {
      "<leader>fC",
      function()
        require("fzf-lua").files({ cwd = "~/.dotfiles", hidden = true })
      end,
      desc = "[F]ind [C]onfig Dotfiles",
    },
    {
      "<leader>ff",
      function()
        require("fzf-lua").files()
      end,
      desc = "[F]ind [F]iles",
    },
    {
      "<leader>fF",
      function()
        require("fzf-lua").files({ cwd = vim.fn.expand("%:p:h") })
      end,
      desc = "[F]ind [F]iles (local buffer)",
    },
    {
      "<leader>fg",
      function()
        require("fzf-lua").git_files()
      end,
      desc = "[F]ind [G]it Files",
    },
    {
      "<leader>fh",
      function()
        require("fzf-lua").help_tags()
      end,
      desc = "[F]ind [H]elp Pages",
    },
    {
      "<leader>fo",
      function()
        require("fzf-lua").oldfiles()
      end,
      desc = "[F]ind [O]ldfiles",
    },
    {
      "<leader>fd",
      function()
        require("fzf-lua").diagnostics_document()
      end,
      desc = "[F]ind [D]iagnostics (buffer)",
    },
    {
      "<leader>fD",
      function()
        require("fzf-lua").diagnostics_workspace()
      end,
      desc = "[F]ind [D]iagnostics (workspace)",
    },
    -- {
    --   "<leader>fn",
    --   function()
    --     require("notify.integrations").pick()
    --   end,
    --   desc = "[F]ind [N]otifications",
    -- },
    {
      "<leader>gb",
      function()
        require("fzf-lua").git_branches()
      end,
      desc = "[G]it [B]ranches",
    },
    {
      "<leader>gl",
      function()
        require("fzf-lua").git_commits()
      end,
      desc = "[G]it Commit [L]ogs",
    },
    {
      "<leader>gL",
      function()
        require("fzf-lua").git_bcommits()
      end,
      desc = "[G]it Commit [L]ogs (buffer)",
    },
    {
      "<leader>gs",
      function()
        require("fzf-lua").git_status()
      end,
      desc = "[G]it [S]tatus",
    },
    {
      "<leader>gS",
      function()
        require("fzf-lua").git_stash()
      end,
      desc = "[G]it [S]tash",
    },
    {
      "<leader>gd",
      function()
        require("fzf-lua").git_diff()
      end,
      desc = "[G]it [D]iff (Hunks)",
    },
    {
      "gf",
      function()
        local fzf = require("fzf-lua")
        local found = vim.fn.findfile(vim.fn.expand("<cfile>"), "**")
        if #found ~= 0 then
          vim.cmd.edit(found)
        else
          fzf.files({ query = vim.fn.expand("<cfile>") })
          return
        end
      end,
      desc = "[G]oto [F]ile (FzfLua)",
    },
    {
      "<leader>fR",
      function()
        require("fzf-lua").registers()
      end,
      desc = "[F]ind [R]egisters",
    },
    {
      "<leader>fs",
      function()
        require("fzf-lua").search_history()
      end,
      desc = "[F]ind [S]earch History",
    },
    {
      "<leader>fa",
      function()
        require("fzf-lua").autocmds()
      end,
      desc = "[F]ind [A]utocmds",
    },
    {
      "<leader>fk",
      function()
        require("fzf-lua").keymaps()
      end,
      desc = "[F]ind [K]eymaps",
    },
    {
      "<leader>fl",
      function()
        require("fzf-lua").loclist()
      end,
      desc = "[F]ind [L]ocation List",
    },
    {
      "<leader>fL",
      function()
        require("fzf-lua").loclist_stack()
      end,
      desc = "[F]ind [L]ocation List (Stack)",
    },
    {
      "<leader>fm",
      function()
        require("fzf-lua").man_pages()
      end,
      desc = "[F]ind [M]anpages",
    },
    {
      "<leader>fq",
      function()
        require("fzf-lua").quickfix()
      end,
      desc = "[F]ind [Q]uickfix List",
    },
    {
      "<leader>fQ",
      function()
        require("fzf-lua").quickfix_stack()
      end,
      desc = "[F]ind [Q]uickfix List (Stack)",
    },
    {
      "<leader>fr",
      function()
        require("fzf-lua").resume()
      end,
      desc = "[F]ind [R]esume",
    },
    {
      "gd",
      function()
        require("fzf-lua").lsp_definitions()
      end,
      desc = "[G]oto [D]efinition",
    },
    {
      "gD",
      function()
        require("fzf-lua").lsp_declarations()
      end,
      desc = "[G]oto [D]eclaration",
    },
    {
      "gr",
      function()
        require("fzf-lua").lsp_references()
      end,
      nowait = true,
      desc = "[G]oto [R]eferences",
    },
    {
      "gI",
      function()
        require("fzf-lua").lsp_implementations()
      end,
      desc = "[G]oto [I]mplementation",
    },
    {
      "gs",
      function()
        require("fzf-lua").lsp_document_symbols()
      end,
      desc = "[G]oto LSP [S]ymbols (buffer)",
    },
    {
      "gS",
      function()
        require("fzf-lua").lsp_workspace_symbols()
      end,
      desc = "[G]oto LSP [S]ymbols (workspace)",
    },
    {
      "gy",
      function()
        require("fzf-lua").lsp_typedefs()
      end,
      desc = "[G]oto T[y]pe Definition",
    },
    {
      "<leader>fp",
      function()
        require("fzf-lua").files({ cwd = "~/Projects", hidden = true })
        -- local fzf = require("fzf-lua")
        -- local actions = fzf.actions
        -- fzf.fzf_exec(
        --   vim.fn.systemlist({
        --     "fd",
        --     ".",
        --     "--type",
        --     "directory",
        --     "--max-depth",
        --     "3",
        --     vim.env.HOME .. "/Projects",
        --   }),
        --   {
        --     prompt = "Projects> ",
        --     actions = {
        --       ["enter"] = actions.file_edit_or_qf,
        --       ["ctrl-s"] = actions.file_split,
        --       ["ctrl-v"] = actions.file_vsplit,
        --       ["ctrl-t"] = actions.file_tabedit,
        --       ["alt-q"] = actions.file_sel_to_qf,
        --       ["alt-Q"] = actions.file_sel_to_ll,
        --       ["alt-i"] = actions.toggle_ignore,
        --       ["alt-h"] = actions.toggle_hidden,
        --       ["alt-f"] = actions.toggle_follow,
        --     },
        --   }
        -- )
      end,
      desc = "[F]ind [P]rojects",
    },
    {
      "<leader>fu",
      function()
        local url_pattern = "[a-zA-Z]+://[%w-_%.%?%.:/%+=&]+"
        -- local url_pattern = "https?://[%w%-%._~:/%?#%[%]@!$&'()*+,;=%%]+"
        require("fzf-lua").fzf_exec(
          vim
            .iter(vim.api.nvim_buf_get_lines(0, 0, -1, false))
            :filter(function(line)
              return string.match(line, url_pattern)
            end)
            :map(function(url)
              url = vim.trim(url:match(url_pattern) or "")
              return url
            end)
            :totable(),
          {
            prompt = "URLs> ",
            header = "<enter> to open URL / <c-y> to copy to clipboard",
            actions = {
              ["enter"] = function(selected)
                local url = selected[1]
                if url then
                  vim.ui.open(url)
                end
              end,
              ["ctrl-y"] = function(selected)
                local url = selected[1]
                if url then
                  vim.fn.setreg("+", url)
                  vim.notify("Copied to clipboard: " .. url, vim.log.levels.INFO)
                end
              end,
            },
          }
        )
      end,
      desc = "[F]ind [U]RLs",
    },
  },
}
