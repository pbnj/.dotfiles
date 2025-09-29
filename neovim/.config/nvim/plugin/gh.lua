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
