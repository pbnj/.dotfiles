return {
  {
    "https://github.com/folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      bigfile = { enabled = true },
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      notify = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = true },
      explorer = { enabled = true },
      gh = {},
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
          grep = { hidden = true, live = true },
          grep_word = { hidden = true, live = true },
          explorer = { layout = { layout = { position = "right" } } },
          files = {
            hidden = true,
            actions = {
              ---@class snacks.picker.actions
              delete_file = function(picker, _)
                for _, item in ipairs(picker:selected({ fallback = true })) do
                  vim.system({ "trash", item._path })
                  Snacks.notify.info("Trashed " .. item._path)
                end
                picker:find()
              end,
            },
            win = {
              input = {
                keys = {
                  ["dd"] = { "delete_file", mode = { "n" }, desc = "delete file" },
                },
              },
            },
          },
          projects = {
            format = "text",
            finder = function()
              return vim
                .iter(vim.fn.systemlist({ "fd", ".", vim.fn.expand("~/Projects"), "--type", "d", "--max-depth", "3" }))
                :map(function(dir)
                  local dir_split = vim.split(dir, "/")
                  local name = dir_split[#dir_split - 1]
                  return {
                    text = name,
                    file = dir,
                  }
                end)
                :totable()
            end,
            win = {
              input = {
                keys = {
                  ["<C-w>"] = { "<c-s-w>", mode = { "i" }, expr = true, desc = "delete word" },
                },
              },
            },
          },
          okta_apps = {
            name = "Okta Apps",
            format = "text",
            layout = "vscode",
            finder = function()
              return vim
                .iter(vim.json.decode(vim.fn.join(vim.fn.readfile(vim.fn.expand("~/.okta/apps.json"))))[1]._embedded.items)
                :map(function(app)
                  return {
                    text = app._embedded.resource.label,
                    label = app._embedded.resource.label,
                    url = app._embedded.resource.linkUrl,
                  }
                end)
                :totable()
            end,
            confirm = function(picker, item)
              picker:close()
              vim.ui.open(item.url)
            end,
          },
          gh_repos = {
            name = "GitHub Repositories",
            format = "text",
            layout = { preset = "vscode" },
            finder = function(opts, ctx)
              return vim
                .iter(vim.json.decode(vim.fn.system({ "gh", "search", "repos", "--owner", vim.fn.systemlist({ "gh", "org", "list" })[1], "--json", "fullName,url", ctx.filter.pattern })))
                :map(function(result)
                  return {
                    text = result.fullName,
                    url = result.url,
                    fullname = result.fullName,
                  }
                end)
                :totable()
            end,
            preview = function(ctx)
              ctx.preview:reset()
              if not ctx.item then
                return true
              end
              local cmd = { "gh", "api", "-H", "Accept: application/vnd.github+json", "-H", "X-GitHub-Api-Version: 2022-11-28", "--jq", ".[]", string.format("/repos/%s/properties/values", ctx.item.fullname) }
              local json = vim.fn.systemlist(cmd)
              ctx.preview:highlight({ ft = "json" })
              ctx.preview:set_title(ctx.item.fullname)
              ctx.preview:set_lines(json)
            end,
            actions = {
              clone_or_sync = function(picker, item)
                picker:close()
                local clone_path = vim.fn.expand("~/Projects/github.com/" .. item.fullname)
                if vim.fn.isdirectory(string.format("%s/.git", clone_path)) == 1 then
                  local cmd = { "gh", "repo", "sync" }
                  Snacks.terminal(cmd, { cwd = clone_path, win = { wo = { winbar = vim.fn.join(cmd, " ") } } })
                else
                  local cmd = { "gh", "repo", "clone", item.url, clone_path }
                  Snacks.terminal(cmd, { win = { wo = { winbar = vim.fn.join(cmd, " ") } } })
                end
              end,
              refresh = function(picker, _)
                picker:find({ refresh = true })
              end,
              open = function(picker, item)
                picker:close()
                vim.ui.open(item.url)
              end,
            },
            win = {
              input = {
                keys = {
                  ["<c-r>"] = { "refresh", mode = { "n", "i" } },
                  ["<m-o>"] = { "open", mode = { "n", "i" } },
                  ["<cr>"] = { "clone_or_sync", mode = { "n", "i" } },
                },
              },
            },
          },
          filetypes = {
            name = "filetypes",
            format = "text",
            layout = { preset = "vscode" },
            finder = function()
              return vim
                .iter(vim.fn.getcompletion("", "filetype"))
                :map(function(filetype)
                  return {
                    text = filetype,
                  }
                end)
                :totable()
            end,
            confirm = function(picker, item)
              picker:close()
              if item then
                vim.schedule(function()
                  vim.cmd("setfiletype " .. item.text)
                end)
              end
            end,
          },
          aws_console = {
            source = "aws_console",
            title = "AWS Console",
            layout = { preset = "vscode" },
            format = "text",
            finder = function()
              local aws_config = vim.json.decode(vim.system({ vim.o.shell, vim.o.shellcmdflag, string.format("cat %s | jc --ini", vim.fn.expand("~/.aws/config")) }, { text = true }):wait().stdout)
              return vim
                .iter(aws_config)
                :filter(function(profile)
                  return string.match(profile, "%d/.*/.*")
                end)
                :map(function(profile)
                  local sso_account_id = aws_config[profile].sso_account_id
                  local sso_account_alias = aws_config[profile].sso_account_alias
                  local sso_role_name = aws_config[profile].sso_role_name
                  local sso_account_url = aws_config[profile].sso_account_url
                  local profile_name = string.format("%s/%s/%s", sso_account_id, sso_account_alias, sso_role_name)
                  return {
                    profile = profile_name,
                    text = string.format("%s  %s", sso_account_id, sso_account_alias),
                    account_id = sso_account_id,
                    account_alias = sso_account_alias,
                    account_url = sso_account_url,
                    default = aws_config.default,
                  }
                end)
                :totable()
            end,
            matcher = { fuzzy = true, frecency = true },
            actions = {
              yank_alias = { action = "yank", field = "account_alias", desc = "Yank Alias" },
              yank_id = { action = "yank", field = "account_id", desc = "Yank ID" },
              yank_profile = { action = "yank", field = "profile", desc = "Yank Profile" },
              open = function(picker, item)
                picker:close()
                vim.ui.open(item.account_url)
              end,
              open_sso_account = function(picker, item)
                local default_account_url = item.default.sso_account_url
                local default_sso_instance = item.default.sso_instance
                local sso_account_id = item.account_id
                local base_url = default_account_url .. "&destination="
                local destination_url = "https://us-west-2.console.aws.amazon.com/singlesignon/organization/home?region=us-west-2#/instances/" .. default_sso_instance .. "/accounts/details/" .. sso_account_id .. "?section=users"
                local destination_url_encoded = vim.fn.substitute(vim.fn.iconv(destination_url, "latin1", "utf-8"), "[^A-Za-z0-9_.~-]", '\\="%".printf("%02X",char2nr(submatch(0)))', "g")
                local url = base_url .. destination_url_encoded
                picker:close()
                vim.ui.open(url)
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
    },
    keys = {
      -- stylua: ignore start
      { "<leader><space>", function() Snacks.picker() end, desc = "All Pickers" },
      { "<leader>/", function() Snacks.picker.grep({ title = "Grep (local project)" }) end, desc = "Grep" },
      { "<leader>/", function() Snacks.picker.grep_word() end, desc = "Visual selection or word", mode = { "x" } },
      { "<leader>;", function() Snacks.picker.command_history() end, desc = "Command History" },
      { "<leader>:", function() Snacks.picker.commands() end, desc = "Commands" },
      { "<leader>n", function() Snacks.notifier.show_history() end, desc = "[N]otification History" },
      { "<leader>e", function() Snacks.picker.explorer({focus = false, hidden = true}) end, desc = "File [E]xplorer" },
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
      -- fuzzy finders
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "[F]ind [B]uffers" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "[F]ind [C]onfig File" },
      { "<leader>ff", function() Snacks.picker.files() end, desc = "[F]ind [F]iles" },
      { "<leader>fp", function() Snacks.picker.projects({ dev = { "~/Projects" }, max_depth = 4 }) end, desc = "[F]ind [P]roject Files" },
      { "<leader>fg", function() Snacks.picker.git_files() end, desc = "[F]ind [G]it Files" },
      { "<leader>fh", function() Snacks.picker.help() end, desc = "[F]ind [H]elp Pages" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "[F]ind [R]ecent" },
      { "<leader>fR", function() Snacks.picker.resume() end, desc = "[F]ind [R]esume" },
      { "<leader>fd", function() Snacks.picker.diagnostics_buffer() end, desc = "[F]ind [D]iagnostics (Buffer)" },
      { "<leader>fD", function() Snacks.picker.diagnostics() end, desc = "[F]ind [D]iagnostics (Global)" },
      { "<leader>fs", function() Snacks.picker.lsp_symbols() end, desc = "[F]ind [S]ymbols (Buffer)" },
      { "<leader>fS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "[F]ind [S]ymbols (Global)" },
      -- git
      { "<leader>gi", function() Snacks.picker.gh_issue() end, desc = "GitHub Issues (open)" },
      { "<leader>gI", function() Snacks.picker.gh_issue({ state = "all" }) end, desc = "GitHub Issues (all)" },
      { "<leader>gp", function() Snacks.picker.gh_pr() end, desc = "GitHub Pull Requests (open)" },
      { "<leader>gP", function() Snacks.picker.gh_pr({ state = "all" }) end, desc = "GitHub Pull Requests (all)" },
      { "<leader>gb", function() Snacks.picker.git_branches() end, desc = "[G]it [B]ranches" },
      { "<leader>gl", function() Snacks.picker.git_log_file() end, desc = "[G]it [L]ogs (Buffer)" },
      { "<leader>gL", function() Snacks.picker.git_log() end, desc = "[G]it [L]ogs (Global)" },
      { "<leader>gs", function() Snacks.picker.git_status() end, desc = "[G]it [S]tatus" },
      { "<leader>gS", function() Snacks.picker.git_stash() end, desc = "[G]it [S]tash" },
      { "<leader>gd", function() Snacks.picker.git_diff() end, desc = "[G]it [D]iff" },
      { "<leader>sb", function() Snacks.picker.lines() end, desc = "[S]earch Buffer [L]ines" },
      { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "[S]earch Open [B]uffers" },
      { '<leader>s"', function() Snacks.picker.registers() end, desc = "[S]earch [R]egisters" },
      { "<leader>s/", function() Snacks.picker.search_history() end, desc = "[S]earch [H]istory" },
      { "<leader>sa", function() Snacks.picker.autocmds() end, desc = "[S]earch [A]utocmds" },
      { "<leader>si", function() Snacks.picker.icons() end, desc = "[S]earch [I]cons" },
      { "<leader>sj", function() Snacks.picker.jumps() end, desc = "[S]earch [J]umps" },
      { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "[S]earch [K]eymaps" },
      { "<leader>sl", function() Snacks.picker.loclist() end, desc = "[S]earch [L]ocation List" },
      { "<leader>sm", function() Snacks.picker.marks() end, desc = "[S]earch [M]arks" },
      { "<leader>sM", function() Snacks.picker.man() end, desc = "[S]earch [M]an Pages" },
      { "<leader>sp", function() Snacks.picker.lazy() end, desc = "[S]earch [P]lugin Spec" },
      { "<leader>sq", function() Snacks.picker.qflist() end, desc = "[S]earch [Q]uickfix List" },
      { "<leader>su", function() Snacks.picker.undo() end, desc = "[S]earch [U]ndo History" },
      -- lsp
      { "gd", function() Snacks.picker.lsp_definitions() end, desc = "[G]oto [D]efinition" },
      { "gD", function() Snacks.picker.lsp_declarations() end, desc = "[G]oto [D]eclaration" },
      { "gr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "[G]oto [R]eferences" },
      { "gI", function() Snacks.picker.lsp_implementations() end, desc = "[G]oto [I]mplementation" },
      { "go", function() Snacks.picker.lsp_symbols() end, desc = "[G]oto Symb[o]ls (Buffer)" },
      { "gO", function() Snacks.picker.lsp_workspace_symbols() end, desc = "[G]oto Symb[o]ls (Global)" },
      { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "[G]oto T[y]pe Definition" },
      -- utilities
      { "<c-\\><c-\\>", function() Snacks.terminal() end, mode = { "t", "n", "i" }, desc = "Toggle Terminal" },
      { "<c-\\>u", function() Snacks.terminal({ "pkg_up" }) end, mode = { "t", "n", "i" }, desc = "Terminal: Update system packages" },
      { "<leader>bd", function() Snacks.bufdelete() end, desc = "Delete Buffer" },
      { "<leader>cR", function() Snacks.rename.rename_file() end, desc = "Rename File" },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss All Notifications" },
      {
        "<leader>ud",
        function()
          Snacks.picker({
            source = "ddgr",
            title = "DuckDuckGo",
            format = "text",
            layout = "vscode",
            finder = function()
              return vim
                .iter({ "!duckduckgo", "!ai", "!amaps", "!archiveis", "!archiveweb", "!aws", "!azure", "!bangs", "!chat", "!chtsh", "!cloudformation", "!crates", "!d", "!devdocs", "!devto", "!dhdocs", "!dictionary", "!dmw", "!dockerhub", "!docs.rs", "!g", "!gcp", "!gdefine", "!gdocs", "!gh", "!ghcode", "!ghio", "!ghrepo", "!ght", "!ghtopic", "!ghuser", "!gist", "!gmail", "!gmaps", "!godoc", "!google", "!gopkg", "!gsheets", "!gslides", "!i", "!ker", "!kubernetes", "!man", "!mdn", "!mysql", "!n", "!node", "!npm", "!postgres", "!py3", "!python", "!rce", "!rclippy", "!reddit", "!rust", "!rustdoc", "!spotify", "!stackoverflow", "!tldr", "!tmg", "!translate", "!twitch", "!typescript", "!v", "!vimw", "!yt" })
                :map(function(bang)
                  return { text = bang, bang = bang }
                end)
                :totable()
            end,
            matcher = { fuzzy = true, frecency = true },
            confirm = function(self, item, action)
              self:close()
              Snacks.input({ prompt = string.format("DDGR (%s)", item.bang), default = self:word() }, function(value)
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
        mode = { "n", "x" },
      },
      {
        "<leader>\\",
        function()
          Snacks.picker.grep({ title = "Grep (all projects)", dirs = { "~/Projects/" }, layout = { fullscreen = true } })
        end,
        desc = "Grep Project Files",
      },
      -- work
      { "<leader>wa", function() Snacks.picker.aws_console() end, desc = "[W]ork [A]WS Console" },
      { "<leader>wo", function() Snacks.picker.okta_apps() end, desc = "[W]ork [O]kta Apps" },
    },
    -- stylua: ignore end
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
        function()
          vim.cmd.Trouble("diagnostics toggle")
        end,
        desc = "Diagnostics (Trouble)",
      },
      {
        "<leader>xX",
        "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
        desc = "Buffer Diagnostics (Trouble)",
      },
      {
        "<leader>cs",
        function()
          vim.cmd.Trouble("symbols toggle")
        end,
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
            if vim.fn.systemlist({ "defaults", "read", "-g", "AppleInterfaceStyle", "2>/dev/null" })[1]:match("Dark") then
              vim.schedule(function()
                vim.o.background = "dark"
              end)
            else
              vim.schedule(function()
                vim.o.background = "light"
              end)
            end
          end
        end,
      })
    end,
    enabled = true,
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({ transparent = true })
      vim.cmd.colorscheme("tokyonight")
    end,
  },
}
