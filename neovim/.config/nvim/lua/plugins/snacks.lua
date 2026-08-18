vim.pack.add({ "https://github.com/folke/snacks.nvim" })

require("snacks").setup({
  bigfile = { enabled = true },
  explorer = { enabled = true },
  gh = {},
  indent = { enabled = true },
  input = { enabled = true },
  notifier = { enabled = true },
  notify = { enabled = true },
  scope = { enabled = true },
  scroll = { enabled = false },
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
      explorer = {
        layout = { layout = { position = "right" } },
        hidden = true,
        ignored = true,
        follow_file = true,
      },
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
              ["dd"] = {
                "delete_file",
                mode = { "n" },
                desc = "delete file",
              },
            },
          },
        },
      },
      gh_repos = {
        name = "GitHub Repositories",
        format = "text",
        layout = { preset = "vscode" },
        finder = function(_, ctx)
          return vim
            .iter(vim.json.decode(vim.fn.system({
              "gh",
              "search",
              "repos",
              "--owner",
              vim.fn.systemlist({ "gh", "org", "list" })[1],
              "--json",
              "fullName,url",
              ctx.filter.pattern,
            })))
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
          local cmd = {
            "gh",
            "api",
            "-H",
            "Accept: application/vnd.github+json",
            "-H",
            "X-GitHub-Api-Version: 2022-11-28",
            "--jq",
            ".[]",
            string.format("/repos/%s/properties/values", ctx.item.fullname),
          }
          local json = vim.fn.systemlist(cmd)
          ctx.preview:highlight({ ft = "json" })
          ctx.preview:set_title(ctx.item.fullname)
          ctx.preview:set_lines(json)
        end,
        actions = {
          clone_or_sync = function(picker, item)
            picker:close()
            local clone_path =
              vim.fn.expand("~/Projects/github.com/" .. item.fullname)
            if
              vim.fn.isdirectory(string.format("%s/.git", clone_path)) == 1
            then
              local cmd = { "gh", "repo", "sync" }
              Snacks.terminal(cmd, {
                cwd = clone_path,
                win = {
                  wo = { winbar = vim.fn.join(cmd, " ") },
                },
              })
            else
              local cmd = { "gh", "repo", "clone", item.url, clone_path }
              Snacks.terminal(cmd, {
                win = {
                  wo = { winbar = vim.fn.join(cmd, " ") },
                },
              })
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
      treesitter_languages = {
        name = "Treesitter Languages",
        format = "text",
        layout = { preset = "vscode" },
        finder = function()
          local ok, ts = pcall(require, "nvim-treesitter")
          if not ok then
            return {}
          end
          local installed = {}
          for _, lang in ipairs(ts.get_installed()) do
            installed[lang] = true
          end
          return vim
            .iter(ts.get_available())
            :map(function(lang)
              local is_installed = installed[lang] == true
              return {
                text = lang .. (is_installed and " (installed)" or ""),
                language = lang,
                installed = is_installed,
              }
            end)
            :totable()
        end,
        confirm = function(picker, item)
          picker:close()
          if item then
            vim.schedule(function()
              if item.installed then
                vim.cmd("TSUninstall " .. item.language)
              else
                vim.cmd("TSInstall " .. item.language)
              end
            end)
          end
        end,
      },
      scalr_runs = {
        name = "Scalr Runs",
        format = "text",
        preview_window = "bottom",
        finder = function(opts)
          if not opts or not opts.workspace_id then
            return {}
          end
          local result = vim
            .system({
              "scalr",
              "get-runs",
              string.format("-filter-workspace=%s", opts.workspace_id),
            }, { text = true })
            :wait()
          local ok, runs = pcall(vim.json.decode, result.stdout)
          if not ok or not runs then
            return {}
          end
          return vim
            .iter(runs)
            :map(function(run)
              return {
                text = run.id,
                id = run.id,
                apply = run.apply,
                plan = run.plan,
                workspace_id = opts.workspace_id,
                workspace_name = opts.workspace_name,
                environment_id = opts.environment_id,
              }
            end)
            :totable()
        end,
        preview = function(ctx)
          if not ctx.item then
            return true
          end
          local item = ctx.item
          local lines = {}
          if item.apply and item.apply.id then
            local result = vim
              .system({
                "scalr",
                "get-apply-log",
                string.format("-apply=%s", item.apply.id),
                "-clean=true",
              }, { text = true })
              :wait()
            if result.stdout and result.stdout ~= "" then
              vim.list_extend(lines, vim.split(result.stdout, "\n"))
            end
          end
          if item.plan and item.plan.id then
            local result = vim
              .system({
                "scalr",
                "get-plan-log",
                string.format("-plan=%s", item.plan.id),
                "-clean=true",
              }, { text = true })
              :wait()
            if result.stdout and result.stdout ~= "" then
              vim.list_extend(lines, vim.split(result.stdout, "\n"))
            end
          end
          ctx.preview:set_lines(
            #lines > 0 and lines or { "(no logs available)" }
          )
        end,
        confirm = function(picker, item)
          picker:close()
          local lines = {}
          if item.apply and item.apply.id then
            local result = vim
              .system({
                "scalr",
                "get-apply-log",
                string.format("-apply=%s", item.apply.id),
              }, { text = true })
              :wait()
            if result.stdout then
              vim.list_extend(lines, vim.split(result.stdout, "\n"))
            end
          end
          if item.plan and item.plan.id then
            local result = vim
              .system({
                "scalr",
                "get-plan-log",
                string.format("-plan=%s", item.plan.id),
              }, { text = true })
              :wait()
            if result.stdout then
              vim.list_extend(lines, vim.split(result.stdout, "\n"))
            end
          end
          local log_file = vim.fn.tempname()
          vim.fn.writefile(lines, log_file)
          vim.cmd("edit " .. log_file)
          vim.api.nvim_open_term(0, {})
        end,
        actions = {
          approve_run = function(_, item)
            vim.system({
              "scalr",
              "confirm-run",
              string.format("-run=%s", item.id),
            })
            Snacks.notify.info("Approved run: " .. item.id)
          end,
          cancel_run = function(_, item)
            vim.system({
              "scalr",
              "cancel-run",
              string.format("-run=%s", item.id),
            })
            Snacks.notify.info("Cancelled run: " .. item.id)
          end,
          browse_run = function(picker, item)
            picker:close()
            vim.ui.open(
              string.format(
                "https://%s/v2/e/%s/workspaces/%s/runs/%s",
                vim.env.SCALR_HOSTNAME,
                item.environment_id,
                item.workspace_id,
                item.id
              )
            )
          end,
          refresh = function(picker, _)
            picker:find({ refresh = true })
          end,
        },
        win = {
          input = {
            keys = {
              ["<a-a>"] = {
                "approve_run",
                mode = { "n", "i" },
                desc = "Approve run",
              },
              ["<a-c>"] = {
                "cancel_run",
                mode = { "n", "i" },
                desc = "Cancel run",
              },
              ["<c-o>"] = {
                "browse_run",
                mode = { "n", "i" },
                desc = "Open run in web browser",
              },
              ["<c-r>"] = {
                "refresh",
                mode = { "n", "i" },
                desc = "Refresh runs",
              },
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
})

vim.keymap.set("n", "<leader><space>", function()
  Snacks.picker()
end, { desc = "All Pickers" })
vim.keymap.set("n", "<leader>/", function()
  Snacks.picker.grep({ title = "Grep (local project)" })
end, { desc = "Grep" })
vim.keymap.set("x", "<leader>/", function()
  Snacks.picker.grep_word()
end, { desc = "Visual selection or word" })
vim.keymap.set("n", "<leader>;", function()
  Snacks.picker.command_history()
end, { desc = "Command History" })
vim.keymap.set("n", "<leader>:", function()
  Snacks.picker.commands()
end, { desc = "Commands" })
vim.keymap.set("n", "<leader>n", function()
  Snacks.notifier.show_history()
end, { desc = "[N]otification History" })
vim.keymap.set("n", "-", function()
  Snacks.picker.explorer()
end, { desc = "File Explorer" })
vim.keymap.set("n", "<leader>N", function()
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
end, { desc = "Neovim News" })
-- fuzzy finders
vim.keymap.set("n", "<leader>bb", function()
  Snacks.picker.buffers({ current = false })
end, { desc = "[F]ind [B]uffers" })
vim.keymap.set("n", "<leader>fc", function()
  Snacks.picker.files({ cwd = vim.fn.stdpath("config") })
end, { desc = "[F]ind [C]onfig File" })
vim.keymap.set("n", "<leader>ff", function()
  Snacks.picker.files()
end, { desc = "[F]ind [F]iles" })
vim.keymap.set("n", "<leader>fp", function()
  Snacks.picker.files({ cwd = "~/Projects" })
end, { desc = "[F]ind [P]roject Files" })
vim.keymap.set("n", "<leader>fg", function()
  Snacks.picker.git_files()
end, { desc = "[F]ind [G]it Files" })
vim.keymap.set("n", "<leader>fh", function()
  Snacks.picker.help()
end, { desc = "[F]ind [H]elp Pages" })
vim.keymap.set("n", "<leader>fr", function()
  Snacks.picker.recent()
end, { desc = "[F]ind [R]ecent" })
vim.keymap.set("n", "<leader>fR", function()
  Snacks.picker.resume()
end, { desc = "[F]ind [R]esume" })
vim.keymap.set("n", "<leader>fd", function()
  Snacks.picker.diagnostics_buffer()
end, { desc = "[F]ind [D]iagnostics (Buffer)" })
vim.keymap.set("n", "<leader>fD", function()
  Snacks.picker.diagnostics()
end, { desc = "[F]ind [D]iagnostics (Global)" })
vim.keymap.set("n", "<leader>fs", function()
  Snacks.picker.lsp_symbols()
end, { desc = "[F]ind [S]ymbols (Buffer)" })
vim.keymap.set("n", "<leader>fS", function()
  Snacks.picker.lsp_workspace_symbols()
end, { desc = "[F]ind [S]ymbols (Global)" })
-- git
vim.keymap.set("n", "<leader>gi", function()
  Snacks.picker.gh_issue()
end, { desc = "GitHub Issues (open)" })
vim.keymap.set("n", "<leader>gp", function()
  Snacks.picker.gh_pr()
end, { desc = "GitHub Pull Requests (open)" })
vim.keymap.set("n", "<leader>gb", function()
  Snacks.picker.git_branches()
end, { desc = "[G]it [B]ranches" })
vim.keymap.set("n", "<leader>gB", function()
  Snacks.gitbrowse()
end, { desc = "[G]it [B]rowse" })
vim.keymap.set("n", "<leader>gl", function()
  Snacks.picker.git_log_file()
end, { desc = "[G]it [L]ogs (Buffer)" })
vim.keymap.set("n", "<leader>gL", function()
  Snacks.picker.git_log()
end, { desc = "[G]it [L]ogs (Global)" })
vim.keymap.set("n", "<leader>gs", function()
  Snacks.picker.git_status()
end, { desc = "[G]it [S]tatus" })
vim.keymap.set("n", "<leader>gS", function()
  Snacks.picker.git_stash()
end, { desc = "[G]it [S]tash" })
vim.keymap.set("n", "<leader>gd", function()
  Snacks.picker.git_diff()
end, { desc = "[G]it [D]iff" })
vim.keymap.set("n", "<leader>sb", function()
  Snacks.picker.lines()
end, { desc = "[S]earch Buffer [L]ines" })
vim.keymap.set("n", "<leader>sB", function()
  Snacks.picker.grep_buffers()
end, { desc = "[S]earch Open [B]uffers" })
vim.keymap.set("n", '<leader>s"', function()
  Snacks.picker.registers()
end, { desc = "[S]earch [R]egisters" })
vim.keymap.set("n", "<leader>s/", function()
  Snacks.picker.search_history()
end, { desc = "[S]earch [H]istory" })
vim.keymap.set("n", "<leader>sa", function()
  Snacks.picker.autocmds()
end, { desc = "[S]earch [A]utocmds" })
vim.keymap.set("n", "<leader>si", function()
  Snacks.picker.icons()
end, { desc = "[S]earch [I]cons" })
vim.keymap.set("n", "<leader>sj", function()
  Snacks.picker.jumps()
end, { desc = "[S]earch [J]umps" })
vim.keymap.set("n", "<leader>sk", function()
  Snacks.picker.keymaps()
end, { desc = "[S]earch [K]eymaps" })
vim.keymap.set("n", "<leader>sl", function()
  Snacks.picker.loclist()
end, { desc = "[S]earch [L]ocation List" })
vim.keymap.set("n", "<leader>sm", function()
  Snacks.picker.marks()
end, { desc = "[S]earch [M]arks" })
vim.keymap.set("n", "<leader>sM", function()
  Snacks.picker.man()
end, { desc = "[S]earch [M]an Pages" })
vim.keymap.set("n", "<leader>sq", function()
  Snacks.picker.qflist()
end, { desc = "[S]earch [Q]uickfix List" })
vim.keymap.set("n", "<leader>su", function()
  Snacks.picker.undo()
end, { desc = "[S]earch [U]ndo History" })
-- lsp
vim.keymap.set("n", "<leader>lgd", function()
  Snacks.picker.lsp_definitions()
end, { desc = "[L]SP [G]oto [D]efinition" })
vim.keymap.set("n", "<leader>lgD", function()
  Snacks.picker.lsp_declarations()
end, { desc = "[L]SP [G]oto [D]eclaration" })
vim.keymap.set("n", "<leader>lgr", function()
  Snacks.picker.lsp_references()
end, { nowait = true, desc = "[L]SP [G]oto [R]eferences" })
vim.keymap.set("n", "<leader>lgI", function()
  Snacks.picker.lsp_implementations()
end, { desc = "[L]SP [G]oto [I]mplementation" })
vim.keymap.set("n", "<leader>lgo", function()
  Snacks.picker.lsp_symbols()
end, { desc = "[L]SP [G]oto Symb[o]ls (Buffer)" })
vim.keymap.set("n", "<leader>lgO", function()
  Snacks.picker.lsp_workspace_symbols()
end, { desc = "[L]SP [G]oto Symb[o]ls (Global)" })
vim.keymap.set("n", "<leader>lgy", function()
  Snacks.picker.lsp_type_definitions()
end, { desc = "[L]SP [G]oto T[y]pe Definition" })
-- utilities
vim.keymap.set({ "t", "n", "i" }, "<c-\\><c-\\>", function()
  Snacks.terminal()
end, { desc = "Toggle Terminal" })
vim.keymap.set("n", "<leader>st", function()
  Snacks.picker.treesitter_languages()
end, { desc = "[S]earch [T]reesitter Languages" })
vim.keymap.set("n", "<leader>bd", function()
  Snacks.bufdelete()
end, { desc = "Delete Buffer" })
vim.keymap.set("n", "<leader>cR", function()
  Snacks.rename.rename_file()
end, { desc = "Rename File" })
vim.keymap.set("n", "<leader>un", function()
  Snacks.notifier.hide()
end, { desc = "Dismiss All Notifications" })
vim.keymap.set("n", "<leader>\\", function()
  Snacks.picker.grep({
    title = "Grep (all projects)",
    dirs = { "~/Projects/" },
    layout = { fullscreen = true },
  })
end, { desc = "Grep Project Files" })
