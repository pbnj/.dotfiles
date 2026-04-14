-- Build a gh CLI command prefixed with `op run --` so that 1Password secret
-- references in the environment are injected in one place.
local function gh(args)
  return vim.iter({ "op", "run", "--", "gh", args }):flatten():totable()
end

-- top level command for GH CLI, with autocompletion for subcommands
vim.api.nvim_create_user_command("GH", function(opts)
  -- intercept: GH repo clone with no URL → prompt then clone into ~/Projects/github.com/<org>/<repo>
  if opts.fargs[1] == "repo" and opts.fargs[2] == "clone" and not opts.fargs[3] then
    Snacks.input({ prompt = "GitHub repo (url or org/repo): " }, function(input)
      if not input or input == "" then
        return
      end
      local org, repo = input:match("github%.com[:/]([^/]+)/([^/%.]+)")
      if not org then
        org, repo = input:match("^([^/]+)/([^/%.]+)$")
      end
      if not org or not repo then
        vim.notify("Could not parse org/repo from: " .. input, vim.log.levels.ERROR)
        return
      end
      local target = vim.fn.expand("~/Projects/github.com/") .. org .. "/" .. repo
      local clone_url = "https://github.com/" .. org .. "/" .. repo
      require("snacks").terminal(gh({ "repo", "clone", clone_url, target }), { auto_close = false })
    end)
    return
  end

  require("snacks").terminal(gh(opts.fargs), { auto_close = false })
end, {
  desc = "GitHub CLI (GH)",
  nargs = "*",
  complete = function(arg_lead, cmd_line, _)
    if string.match(cmd_line, "GH pr") then
      return vim
        .iter({
          "create",
          "list",
          "status",
          "checkout",
          "checks",
          "close",
          "comment",
          "diff",
          "edit",
          "lock",
          "merge",
          "ready",
          "reopen",
          "review",
          "unlock",
          "update-branch",
          "view",
          "-R",
          "--repo",
        })
        :filter(function(cmd)
          return string.match(cmd, arg_lead)
        end)
        :totable()
    elseif string.match(cmd_line, "GH run") then
      return vim
        .iter({
          "cancel",
          "delete",
          "download",
          "list",
          "rerun",
          "view",
          "watch",
          "-R",
          "--repo",
        })
        :filter(function(cmd)
          return string.match(cmd, arg_lead)
        end)
        :totable()
    elseif string.match(cmd_line, "workflow") then
      return vim
        .iter({
          "disable",
          "enable",
          "list",
          "run",
          "view",
          "-R",
          "--repo",
        })
        :filter(function(cmd)
          return string.match(cmd, arg_lead)
        end)
        :totable()
    elseif string.match(cmd_line, "repo") then
      return vim
        .iter({
          "create",
          "list",
          "archive",
          "autolink",
          "clone",
          "delete",
          "deploy-key",
          "edit",
          "fork",
          "gitignore",
          "license",
          "rename",
          "set-default",
          "sync",
          "unarchive",
          "view",
        })
        :filter(function(cmd)
          return string.match(cmd, arg_lead)
        end)
        :totable()
    else
      return vim
        .iter({
          "alias",
          "api",
          "auth",
          "browse",
          "codespace",
          "config",
          "extension",
          "gist",
          "gpg-key",
          "issue",
          "label",
          "org",
          "pr",
          "project",
          "release",
          "repo",
          "run",
          "search",
          "secret",
          "ssh-key",
          "status",
          "variable",
          "workflow",
          "--help",
        })
        :filter(function(cmd)
          return string.match(cmd, arg_lead)
        end)
        :totable()
    end
  end,
})

-- gh workflow keymaps
-- <leader>gW  = list workflows
-- <leader>gWa = list all workflows (including disabled)
-- <leader>gWv = view a workflow (interactive)
-- <leader>gWr = run a workflow (interactive)
-- <leader>gWe = enable a workflow (interactive)
-- <leader>gWx = disable a workflow (interactive)
local function gh_workflow(args)
  require("snacks").terminal(gh({ "workflow", args }), { auto_close = false, interactive = true })
end

vim.keymap.set("n", "<leader>gW", function()
  gh_workflow("list")
end, { desc = "[G]H [W]orkflow List", noremap = true, silent = true })
vim.keymap.set("n", "<leader>gWa", function()
  gh_workflow({ "list", "--all" })
end, { desc = "[G]H [W]orkflow List [A]ll", noremap = true, silent = true })
vim.keymap.set("n", "<leader>gWv", function()
  gh_workflow("view")
end, { desc = "[G]H [W]orkflow [V]iew", noremap = true, silent = true })
vim.keymap.set("n", "<leader>gWr", function()
  gh_workflow("run")
end, { desc = "[G]H [W]orkflow [R]un", noremap = true, silent = true })
vim.keymap.set("n", "<leader>gWe", function()
  gh_workflow("enable")
end, { desc = "[G]H [W]orkflow [E]nable", noremap = true, silent = true })
vim.keymap.set("n", "<leader>gWx", function()
  gh_workflow("disable")
end, { desc = "[G]H [W]orkflow disable (x)", noremap = true, silent = true })

-- gh run keymaps
-- <leader>gR  = list runs
-- <leader>gRv = view a run (interactive)
-- <leader>gRw = watch a run (interactive)
-- <leader>gRr = rerun a run (interactive)
-- <leader>gRc = cancel a run (interactive)
-- <leader>gRd = delete a run (interactive)
-- <leader>gRD = download artifacts from a run (interactive)
local function gh_run(args)
  require("snacks").terminal(gh({ "run", args }), { auto_close = false, interactive = true })
end

vim.keymap.set("n", "<leader>gR", function()
  gh_run("list")
end, { desc = "[G]H [R]un List", noremap = true, silent = true })
vim.keymap.set("n", "<leader>gRv", function()
  gh_run("view")
end, { desc = "[G]H [R]un [V]iew", noremap = true, silent = true })
vim.keymap.set("n", "<leader>gRw", function()
  gh_run("watch")
end, { desc = "[G]H [R]un [W]atch", noremap = true, silent = true })
vim.keymap.set("n", "<leader>gRr", function()
  gh_run("rerun")
end, { desc = "[G]H [R]un [R]erun", noremap = true, silent = true })
vim.keymap.set("n", "<leader>gRc", function()
  gh_run("cancel")
end, { desc = "[G]H [R]un [C]ancel", noremap = true, silent = true })
vim.keymap.set("n", "<leader>gRd", function()
  gh_run("delete")
end, { desc = "[G]H [R]un [D]elete", noremap = true, silent = true })
vim.keymap.set("n", "<leader>gRD", function()
  gh_run("download")
end, { desc = "[G]H [R]un [D]ownload artifacts", noremap = true, silent = true })
