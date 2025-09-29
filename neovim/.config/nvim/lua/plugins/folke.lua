return {
  {
    "https://github.com/folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      image = {},
      bigfile = { enabled = true },
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      notify = { enabled = true },
      picker = {
        ui_select = true,
        matcher = {
          frecency = true,
        },
        sources = {
          files = {
            actions = {
              ---@class snacks.picker.actions
              delete_file = function(picker, _)
                for _, item in ipairs(picker:selected({ fallback = true })) do
                  vim.system({ "rm", "-rf", item._path })
                  Snacks.notify.info("Deleted " .. item._path)
                end
                picker:find()
              end,
            },
            win = {
              input = {
                keys = {
                  ["dd"] = { "delete_file", mode = { "n" } },
                },
              },
            },
          },
        },
        win = {
          input = {
            keys = {
              ["<c-j>"] = { "preview_scroll_down", mode = { "i", "n" } },
              ["<c-k>"] = { "preview_scroll_up", mode = { "i", "n" } },
            },
          },
        },
      },
      scope = { enabled = true },
      scroll = { enabled = true },
    },
    keys = {
      {
        "<leader><space>",
        function()
          Snacks.picker()
        end,
        desc = "All Pickers",
      },
      {
        "<leader>/",
        function()
          Snacks.picker.grep({ hidden = true, live = true })
        end,
        desc = "Grep",
      },
      {
        "<leader>/",
        function()
          Snacks.picker.grep_word({ live = true, hidden = true })
        end,
        desc = "Visual selection or word",
        mode = { "x" },
      },
      {
        "<leader>;",
        function()
          Snacks.picker.command_history()
        end,
        desc = "Command History",
      },
      {
        "<leader>:",
        function()
          Snacks.picker.commands()
        end,
        desc = "Commands",
      },
      {
        "<leader>fb",
        function()
          Snacks.picker.buffers()
        end,
        desc = "[F]ind [B]uffers",
      },
      {
        "<leader>fc",
        function()
          Snacks.picker.files({ cwd = vim.fn.stdpath("config") })
        end,
        desc = "[F]ind [C]onfig File",
      },
      {
        "<leader>ff",
        function()
          Snacks.picker.files({ hidden = true, formatters = { file = { truncate = 100 } } })
        end,
        desc = "[F]ind [F]iles",
      },
      {
        "<leader>fg",
        function()
          Snacks.picker.git_files()
        end,
        desc = "[F]ind [G]it Files",
      },
      {
        "<leader>fh",
        function()
          Snacks.picker.help()
        end,
        desc = "[F]ind [H]elp Pages",
      },
      {
        "<leader>fr",
        function()
          Snacks.picker.recent()
        end,
        desc = "[F]ind [R]ecent",
      },
      {
        "<leader>fd",
        function()
          Snacks.picker.diagnostics_buffer()
        end,
        desc = "[F]ind Buffer [D]iagnostics",
      },
      {
        "<leader>fD",
        function()
          Snacks.picker.diagnostics()
        end,
        desc = "[F]ind Global [D]iagnostics",
      },
      {
        "<leader>gb",
        function()
          Snacks.picker.git_branches()
        end,
        desc = "Find [G]it [B]ranches",
      },
      {
        "<leader>gl",
        function()
          Snacks.picker.git_log_file()
        end,
        desc = "Find Buffer [G]it [L]ogs",
      },
      {
        "<leader>gL",
        function()
          Snacks.picker.git_log()
        end,
        desc = "Find Global [G]it [L]ogs",
      },
      {
        "<leader>gs",
        function()
          Snacks.picker.git_status()
        end,
        desc = "Find [G]it [S]tatus",
      },
      {
        "<leader>gS",
        function()
          Snacks.picker.git_stash()
        end,
        desc = "Find [G]it [S]tash",
      },
      {
        "<leader>gd",
        function()
          Snacks.picker.git_diff()
        end,
        desc = "Find [G]it [D]iff",
      },
      {
        "<leader>sb",
        function()
          Snacks.picker.lines()
        end,
        desc = "[S]earch Buffer [L]ines",
      },
      {
        "<leader>sB",
        function()
          Snacks.picker.grep_buffers()
        end,
        desc = "[S]earch Open [B]uffers",
      },
      {
        '<leader>s"',
        function()
          Snacks.picker.registers()
        end,
        desc = "[S]earch [R]egisters",
      },
      {
        "<leader>s/",
        function()
          Snacks.picker.search_history()
        end,
        desc = "[S]earch [H]istory",
      },
      {
        "<leader>sa",
        function()
          Snacks.picker.autocmds()
        end,
        desc = "[S]earch [A]utocmds",
      },
      {
        "<leader>si",
        function()
          Snacks.picker.icons()
        end,
        desc = "[S]earch [I]cons",
      },
      {
        "<leader>sj",
        function()
          Snacks.picker.jumps()
        end,
        desc = "[S]earch [J]umps",
      },
      {
        "<leader>sk",
        function()
          Snacks.picker.keymaps()
        end,
        desc = "[S]earch [K]eymaps",
      },
      {
        "<leader>sl",
        function()
          Snacks.picker.loclist()
        end,
        desc = "[S]earch [L]ocation List",
      },
      {
        "<leader>sm",
        function()
          Snacks.picker.marks()
        end,
        desc = "[S]earch [M]arks",
      },
      {
        "<leader>sM",
        function()
          Snacks.picker.man()
        end,
        desc = "[S]earch [M]an Pages",
      },
      {
        "<leader>sp",
        function()
          Snacks.picker.lazy()
        end,
        desc = "[S]earch [P]lugin Spec",
      },
      {
        "<leader>sq",
        function()
          Snacks.picker.qflist()
        end,
        desc = "[S]earch [Q]uickfix List",
      },
      {
        "<leader>sR",
        function()
          Snacks.picker.resume()
        end,
        desc = "[S]earch [R]esume",
      },
      {
        "<leader>su",
        function()
          Snacks.picker.undo()
        end,
        desc = "[S]earch [U]ndo History",
      },
      {
        "gd",
        function()
          Snacks.picker.lsp_definitions()
        end,
        desc = "[G]oto [D]efinition",
      },
      {
        "gD",
        function()
          Snacks.picker.lsp_declarations()
        end,
        desc = "[G]oto [D]eclaration",
      },
      {
        "gr",
        function()
          Snacks.picker.lsp_references()
        end,
        nowait = true,
        desc = "[G]oto [R]eferences",
      },
      {
        "gI",
        function()
          Snacks.picker.lsp_implementations()
        end,
        desc = "[G]oto [I]mplementation",
      },
      {
        "gs",
        function()
          Snacks.picker.lsp_symbols()
        end,
        desc = "[G]oto Buffer [S]ymbols",
      },
      {
        "gS",
        function()
          Snacks.picker.lsp_workspace_symbols()
        end,
        desc = "[G]oto Workspace [S]ymbols",
      },
      {
        "gy",
        function()
          Snacks.picker.lsp_type_definitions()
        end,
        desc = "[G]oto T[y]pe Definition",
      },
      {
        "<leader>ss",
        function()
          Snacks.picker.lsp_symbols()
        end,
        desc = "[S]earch Global [S]ymbols",
      },
      {
        "<leader>sS",
        function()
          Snacks.picker.lsp_workspace_symbols()
        end,
        desc = "[S]earch Global [S]ymbols",
      },
      {
        "<leader>z",
        function()
          Snacks.zen()
        end,
        desc = "Toggle Zen Mode",
      },
      {
        "<leader>Z",
        function()
          Snacks.zen.zoom()
        end,
        desc = "Toggle Zoom",
      },
      {
        "<leader>n",
        function()
          Snacks.notifier.show_history()
        end,
        desc = "Notification History",
      },
      {
        "<leader>bd",
        function()
          Snacks.bufdelete()
        end,
        desc = "Delete Buffer",
      },
      {
        "<leader>cR",
        function()
          Snacks.rename.rename_file()
        end,
        desc = "Rename File",
      },
      {
        "<leader>un",
        function()
          Snacks.notifier.hide()
        end,
        desc = "Dismiss All Notifications",
      },
      {
        "<c-\\><c-\\>",
        function()
          Snacks.terminal()
        end,
        mode = { "t", "n", "i" },
        desc = "Toggle Terminal",
      },
      {
        "]]",
        function()
          Snacks.words.jump(vim.v.count1)
        end,
        desc = "Next Reference",
        mode = { "n" },
      },
      {
        "[[",
        function()
          Snacks.words.jump(-vim.v.count1)
        end,
        desc = "Prev Reference",
        mode = { "n" },
      },
      {
        "<leader>N",
        desc = "Neovim News",
        function()
          Snacks.win({
            file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
            width = 0.6,
            height = 0.6,
            wo = {
              spell = false,
              wrap = false,
              signcolumn = "yes",
              statuscolumn = " ",
              conceallevel = 3,
            },
          })
        end,
      },
      {
        "<leader>ta",
        function()
          Snacks.terminal({ "copilot" })
        end,
        desc = "Toggle Copilot CLI",
      },
    },
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          -- Setup some globals for debugging (lazy-loaded)
          _G.dd = function(...)
            Snacks.debug.inspect(...)
          end
          _G.bt = function()
            Snacks.debug.backtrace()
          end
          vim.print = _G.dd -- Override print to use snacks for `:=` command
          -- Create some toggle mappings
          Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>ts")
          Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>tw")
          Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>tL")
          Snacks.toggle.diagnostics():map("<leader>td")
          Snacks.toggle.line_number():map("<leader>tl")
          Snacks.toggle.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map("<leader>tc")
          Snacks.toggle.treesitter():map("<leader>tT")
          Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>tb")
          Snacks.toggle.inlay_hints():map("<leader>th")
          Snacks.toggle.indent():map("<leader>tg")
          Snacks.toggle.dim():map("<leader>tD")
        end,
      })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "snacks_picker_input",
        callback = function()
          vim.b.minicompletion_disable = true
        end,
      })
    end,
  },
  {
    "https://github.com/folke/trouble.nvim",
    opts = {},
    cmd = { "Trouble" },
    keys = {
      {
        "<leader>xx",
        "<cmd>Trouble diagnostics toggle<cr>",
        desc = "Diagnostics (Trouble)",
      },
      {
        "<leader>xX",
        "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
        desc = "Buffer Diagnostics (Trouble)",
      },
      {
        "<leader>cs",
        "<cmd>Trouble symbols toggle focus=false<cr>",
        desc = "Symbols (Trouble)",
      },
      {
        "<leader>cl",
        "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
        desc = "LSP Definitions / references / ... (Trouble)",
      },
      {
        "<leader>xL",
        "<cmd>Trouble loclist toggle<cr>",
        desc = "Location List (Trouble)",
      },
      {
        "<leader>xQ",
        "<cmd>Trouble qflist toggle<cr>",
        desc = "Quickfix List (Trouble)",
      },
    },
  },
  {
    "https://github.com/folke/todo-comments.nvim",
    event = "VeryLazy",
    dependencies = {
      "https://github.com/nvim-lua/plenary.nvim",
      "https://github.com/folke/snacks.nvim",
    },
    opts = {},
    keys = {
      {
        "]t",
        function()
          require("todo-comments").jump_next()
        end,
        desc = "Next todo comment",
      },
      {
        "[t",
        function()
          require("todo-comments").jump_prev()
        end,
        desc = "Previous todo comment",
      },
    },
  },
  {
    "https://github.com/folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        {
          path = "${3rd}/luv/library",
          words = { "vim%.uv" },
        },
        {
          path = "snacks.nvim",
          words = { "Snacks" },
        },
      },
    },
  },
}
