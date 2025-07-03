vim.api.nvim_create_user_command("GH", function(opts)
  local cmd = vim.iter({ "gh", opts.fargs }):flatten():totable()
  require("snacks").terminal(cmd, { auto_close = false, win = { wo = { winbar = "gh " .. opts.args } } })
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

vim.api.nvim_create_user_command("GHRepoClone", function(opts)
  local cmd = { "gh", "repo", "clone", opts.args }
  local gh_repo_url = vim.split(opts.args, "/") -- { "https:", "", "github.com", "komodohealth", "cloud-iam" }
  local gh_domain = gh_repo_url[3]
  local gh_repo_org = gh_repo_url[4]
  local gh_repo_name = gh_repo_url[5]
  local projects_dir = vim.fn.expand("~/Projects/")
  local cwd = string.format("%s/%s/%s/", projects_dir, gh_domain, gh_repo_org)
  vim.fn.mkdir(cwd, "p")
  vim
    .system(cmd, { cwd = cwd }, function(job)
      if job.code == 0 then
        require("snacks").notifier("GH Repo Clone Success", "info")
      else
        require("snacks").notifier(job.stderr, "error")
      end
    end)
    :wait()
  require("snacks").picker.files({ cwd = string.format("%s/%s/%s/%s", projects_dir, gh_domain, gh_repo_org, gh_repo_name), prompt = string.format("%s> ", gh_repo_name) })
end, {
  desc = "GitHub CLI (GH) - Clone Repo",
  nargs = 1,
  -- complete = function(arg_lead, cmd_line, _) end,
})

-- " REPO subcommand
-- function! s:gh_repo_completion(A,L,P) abort
--   let l:org_repo = split(a:A, '/')
--   let l:org = l:org_repo[0]
--   let l:repo = ""
--   if len(l:org_repo) == 2
--     let l:repo = l:org_repo[1]
--   endif
--   return filter(systemlist(printf('gh repo list --json=nameWithOwner --jq .[].nameWithOwner %s', l:org)) ,'v:val =~ l:repo' )
-- endfunction
--
-- " REPO VIEW
-- command! -nargs=1 -complete=customlist,s:gh_repo_completion GHRepoView
--       \ terminal gh repo view <args>
--
-- " REPO CLONE
-- command! -nargs=1 -complete=customlist,s:gh_repo_completion GHRepoClone
--       \ exe 'terminal gh repo clone <args> ' . expand('~/Projects/github.com/<args>')
--
-- " RUN subcommand
-- function! s:gh_run_completion(A,L,P) abort
--   return filter(
--         \ [
--         \   'cancel',
--         \   'delete',
--         \   'download',
--         \   'list',
--         \   'rerun',
--         \   'view',
--         \   'watch',
--         \   '-R', '--repo',
--         \   '--help',
--         \ ], 'v:val =~ a:A')
-- endfunction
--
-- command! -nargs=* -complete=customlist,s:gh_run_completion GHRun
--       \ terminal gh run <args>
--
-- function! s:gh_run_view_completion(A,L,P) abort
--   return filter(systemlist('gh run list --json=databaseId --jq .[].databaseId'), 'v:val =~ a:A')
-- endfunction
--
-- command! -nargs=* -complete=customlist,s:gh_run_view_completion GHRunView
--       \ terminal gh run view <args>
-- command! -nargs=* -complete=customlist,s:gh_run_view_completion GHRunLog
--       \ terminal gh run view --log <args>
-- command! -nargs=* GHRunWatch
--       \ terminal gh run watch <args>
--
-- " WORKFLOW
-- function! s:gh_workflow_completion(A,L,P) abort
--   return filter(systemlist('gh workflow list --json=name --jq .[].name'), 'v:val =~ a:A')
-- endfunction
-- command! -nargs=1 -complete=customlist,s:gh_workflow_completion GHWorkflowRun
--       \ exe 'terminal gh workflow run ' .. shellescape('<args>')
--
-- " SEARCH
-- function! s:gh_search_completion(A, L, P) abort
--   return [
--         \ '--extension=',
--         \ '--filename=',
--         \ '--jq=',
--         \ '--json=',
--         \ '--language=',
--         \ '--limit=30',
--         \ '--owner=',
--         \ '--repo=',
--         \ '--web',
--         \ ]->filter('v:val =~ a:A')
-- endfunction
-- command! -nargs=* -complete=customlist,s:gh_search_completion GHSearchCode
--       \ terminal gh search code <args>
