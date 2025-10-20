return {
  {
    "https://github.com/folke/snacks.nvim",
    init = function()
      vim.api.nvim_create_user_command("Projects", function(opts)
        Snacks.picker.files({
          title = "Project Files",
          cwd = "~/Projects/",
          hidden = true,
          exclude = { "output", ".env" },
          matcher = { frecency = true },
          layout = { fullscreen = true },
        })
      end, { bang = true, desc = "Find Project Files" })
      vim.api.nvim_create_user_command("ProjectsGrep", function(opts)
        Snacks.picker.grep({
          title = "Grep (all projects)",
          dirs = { "~/Projects/" },
          layout = { fullscreen = true },
        })
      end, { bang = true, desc = "Grep Project Files" })
      vim.api.nvim_create_user_command("AWSConsole", function(opts)
        require("snacks").picker({
          source = "aws_console",
          title = "AWS Console",
          finder = function()
            return vim
              .iter(vim.fn.systemlist({ "rg", "\\[profile (.*)\\]", "-or", "$1", vim.fn.expand("~/.aws/config") }))
              :filter(function(profile)
                return string.match(profile, "^%d+/.*/.*")
              end)
              :map(function(profile)
                local profile_elems = vim.split(profile, "/")
                local account_id = profile_elems[1]
                local account_alias = profile_elems[2]
                return {
                  profile = profile,
                  text = profile,
                  account_id = account_id,
                  account_alias = account_alias,
                }
              end)
              :totable()
          end,
          format = function(item, _)
            local ret = {}
            ret[#ret + 1] = { item.account_id }
            ret[#ret + 1] = { "  " }
            ret[#ret + 1] = { item.account_alias }
            return ret
          end,
          matcher = { fuzzy = true, frecency = true },
          actions = {
            yank_alias = { action = "yank", field = "account_alias", desc = "Yank Alias" },
            yank_id = { action = "yank", field = "account_id", desc = "Yank ID" },
            yank_profile = { action = "yank", field = "profile", desc = "Yank Profile" },
            open = function(picker, item)
              local sso_account_url = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_account_url", "--profile", item.profile }))
              vim.ui.open(sso_account_url)
              picker:close()
              if opts.bang then
                vim.cmd.quitall()
              end
            end,
            open_sso_account = function(picker, item)
              local default_account_url = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_account_url" }))
              local default_instance = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_instance" }))
              local sso_account_id = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_account_id", "--profile", item.profile }))
              local base_url = default_account_url .. "&destination="
              local destination_url = "https://us-west-2.console.aws.amazon.com/singlesignon/organization/home?region=us-west-2#/instances/" .. default_instance .. "/accounts/details/" .. sso_account_id .. "?section=users"
              local destination_url_encoded = vim.fn.substitute(vim.fn.iconv(destination_url, "latin1", "utf-8"), "[^A-Za-z0-9_.~-]", '\\="%".printf("%02X",char2nr(submatch(0)))', "g")
              local url = base_url .. destination_url_encoded
              vim.notify(url)
              vim.ui.open(url)
              picker:close()
              if opts.bang then
                vim.cmd.quitall()
              end
            end,
          },
          win = {
            input = {
              keys = {
                ["<m-n>"] = { "yank_alias", mode = { "n", "i" } },
                ["<m-i>"] = { "yank_id", mode = { "n", "i" } },
                ["<m-p>"] = { "yank_profile", mode = { "n", "i" } },
                ["<cr>"] = { "open", mode = { "n", "i" } },
                ["<m-o>"] = { "open_sso_account", mode = { "n", "i" } },
              },
            },
          },
          layout = { preset = "vscode", fullscreen = opts.bang },
        })
      end, {
        nargs = "?",
        bang = true,
        complete = function(arglead)
          return vim
            .iter(vim.fn.systemlist({ "rg", "\\[profile (.*)\\]", "-or", "$1", vim.fn.expand("~/.aws/config") }))
            :filter(function(profile)
              return string.match(profile, "^%d+/.*/.*")
            end)
            :filter(function(profile)
              return string.match(profile, arglead)
            end)
            :totable()
        end,
      })
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
    lazy = false,
    priority = 1000,
    opts = {
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
        formatters = {
          file = {
            filename_first = true,
            truncate = false,
          },
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
          Snacks.picker.grep({ title = "Grep (local project)", hidden = true, live = true })
        end,
        desc = "Grep",
      },
      {
        "<leader>\\",
        vim.cmd.ProjectsGrep,
        desc = "Grep Project Files",
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
          Snacks.picker.files({ hidden = true })
        end,
        desc = "[F]ind [F]iles",
      },
      {
        "<leader>fp",
        vim.cmd.Projects,
        desc = "[F]ind [P]roject Files",
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
        "<leader>fR",
        function()
          Snacks.picker.resume()
        end,
        desc = "[F]ind [R]esume",
      },
      {
        "<leader>fd",
        function()
          Snacks.picker.diagnostics_buffer()
        end,
        desc = "[F]ind [D]iagnostics (Buffer)",
      },
      {
        "<leader>fD",
        function()
          Snacks.picker.diagnostics()
        end,
        desc = "[F]ind [D]iagnostics (Global)",
      },
      {
        "<leader>gb",
        function()
          Snacks.picker.git_branches()
        end,
        desc = "[G]it [B]ranches",
      },
      {
        "<leader>gl",
        function()
          Snacks.picker.git_log_file()
        end,
        desc = "[G]it [L]ogs (Buffer)",
      },
      {
        "<leader>gL",
        function()
          Snacks.picker.git_log()
        end,
        desc = "[G]it [L]ogs (Global)",
      },
      {
        "<leader>gs",
        function()
          Snacks.picker.git_status()
        end,
        desc = "[G]it [S]tatus",
      },
      {
        "<leader>gS",
        function()
          Snacks.picker.git_stash()
        end,
        desc = "[G]it [S]tash",
      },
      {
        "<leader>gd",
        function()
          Snacks.picker.git_diff()
        end,
        desc = "[G]it [D]iff",
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
        "<leader>ud",
        function()
          Snacks.picker({
            source = "ddgr",
            title = "DuckDuckGo",
            layout = "vscode",
            finder = function(opts, ctx)
              return vim
                .iter({ "!duckduckgo", "!ai", "!amaps", "!archiveis", "!archiveweb", "!aws", "!azure", "!bangs", "!chat", "!chtsh", "!cloudformation", "!crates", "!d", "!devdocs", "!devto", "!dhdocs", "!dictionary", "!dmw", "!dockerhub", "!docs.rs", "!g", "!gcp", "!gdefine", "!gdocs", "!gh", "!ghcode", "!ghio", "!ghrepo", "!ght", "!ghtopic", "!ghuser", "!gist", "!gmail", "!gmaps", "!godoc", "!google", "!gopkg", "!gsheets", "!gslides", "!i", "!ker", "!kubernetes", "!man", "!mdn", "!mysql", "!n", "!node", "!npm", "!postgres", "!py3", "!python", "!rce", "!rclippy", "!reddit", "!rust", "!rustdoc", "!spotify", "!stackoverflow", "!tldr", "!tmg", "!translate", "!twitch", "!typescript", "!v", "!vimw", "!yt" })
                :map(function(bang)
                  return { bang = bang }
                end)
                :totable()
            end,
            format = function(item, _)
              local ret = {}
              ret[#ret + 1] = { item.bang }
              return ret
            end,
            matcher = { fuzzy = true, frecency = true },
            confirm = function(self, item, action)
              self:close()
              Snacks.input({ prompt = string.format("DDGR (%s)", item.bang) }, function(value)
                local cmd = { "ddgr", "--expand", "--noua" }
                local term_opts = { auto_close = false, interactive = true, start_insert = true }
                if item.bang ~= "!duckduckgo" then
                  vim.list_extend(cmd, { "--noprompt", "--gui-browser", item.bang })
                  term_opts = { auto_close = true, interactive = false }
                end
                vim.list_extend(cmd, { value })
                vim.notify(vim.inspect(cmd))
                Snacks.terminal(cmd, term_opts)
              end)
            end,
          })
        end,
        desc = "DuckDuckGo (DDGR)",
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
        "<leader>ac",
        vim.cmd.AWSConsole,
        desc = "[A]WS [C]onsole",
      },
    },
  },
  {
    "https://github.com/folke/sidekick.nvim",
    opts = {
      cli = {
        mux = { backend = "tmux" },
        enabled = true,
      },
    },
    keys = {
      {
        "<tab>",
        function()
          -- if there is a next edit, jump to it, otherwise apply it if any
          if not require("sidekick").nes_jump_or_apply() then
            return "<Tab>" -- fallback to normal tab
          end
        end,
        expr = true,
        desc = "Goto/Apply Next Edit Suggestion",
      },
      {
        "<c-.>",
        function()
          require("sidekick.cli").focus()
        end,
        mode = { "n", "x", "i", "t" },
        desc = "Sidekick Switch Focus",
      },
      {
        "<leader>aa",
        function()
          require("sidekick.cli").toggle()
        end,
        desc = "Sidekick Toggle CLI",
      },
      {
        "<leader>ap",
        function()
          require("sidekick.cli").prompt()
        end,
        desc = "Sidekick Ask Prompt",
        mode = { "n", "v" },
      },
      {
        "<leader>as",
        function()
          require("sidekick.cli").select()
        end,
        -- Or to select only installed tools:
        -- require("sidekick.cli").select({ filter = { installed = true } })
        desc = "Select CLI",
      },
      {
        "<leader>at",
        function()
          require("sidekick.cli").send({ msg = "{this}" })
        end,
        mode = { "x", "n" },
        desc = "Send This",
      },
      {
        "<leader>av",
        function()
          require("sidekick.cli").send({ msg = "{selection}" })
        end,
        mode = { "x" },
        desc = "Send Visual Selection",
      },
    },
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
        "]n",
        function()
          require("todo-comments").jump_next()
        end,
        desc = "Next todo comment",
      },
      {
        "[n",
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
  {
    "https://github.com/folke/tokyonight.nvim",
    init = function()
      -- Auto-toggle neovim background based on system theme
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("colorscheme_change", { clear = true }),
        pattern = "*",
        callback = function()
          -- vim.api.nvim_set_hl(0, "Normal", { bg = nil })
          -- vim.api.nvim_set_hl(0, "Visual", { link = "CursorLine" })
          if vim.loop.os_uname().sysname:match("Darwin") then
            vim.system({ "defaults", "read", "-g", "AppleInterfaceStyle", "2>/dev/null" }, nil, function(result)
              if result.stdout:match("Dark") then
                vim.schedule(function()
                  vim.o.background = "dark"
                end)
              else
                vim.schedule(function()
                  vim.o.background = "light"
                end)
              end
            end)
          end
        end,
      })
    end,
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({ transparent = true })
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },
}
