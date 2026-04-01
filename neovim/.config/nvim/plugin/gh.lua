-- gh workflow keymaps
-- <leader>gW  = list workflows
-- <leader>gWa = list all workflows (including disabled)
-- <leader>gWv = view a workflow (interactive)
-- <leader>gWr = run a workflow (interactive)
-- <leader>gWe = enable a workflow (interactive)
-- <leader>gWx = disable a workflow (interactive)
local function gh_workflow(args)
  require("snacks").terminal(vim.iter({ "gh", "workflow", args }):flatten():totable(), { auto_close = false, interactive = true })
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
  require("snacks").terminal(vim.iter({ "gh", "run", args }):flatten():totable(), { auto_close = false, interactive = true })
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

vim.api.nvim_create_user_command("GH", function(opts)
  local cmd = { "gh", unpack(opts.fargs) }
  require("snacks").terminal(cmd, { auto_close = false })
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
