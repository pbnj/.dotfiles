-- " brew install ankitpokhrel/jira-cli/jira-cli
vim.api.nvim_create_user_command("Jira", function(opts)
  Snacks.terminal(vim.iter({ "jira", opts.fargs }):flatten():totable())
end, {
  nargs = "*",
  complete = function(arg_lead, line)
    local jira_cmds = {
      "board",
      "completion",
      "epic",
      "help",
      "init",
      "issue",
      "man",
      "me",
      "open",
      "project",
      "serverinfo",
      "sprint",
      "version",
    }
    local jira_issue_cmds = {
      "assign",
      "clone",
      "comment",
      "create",
      "delete",
      "edit",
      "link",
      "list",
      "move",
      "unlink",
      "view",
      "watch",
      "worklog",
    }
    local args = vim.split(line, " ", { trimempty = true })
    local last_arg = args[#args]
    if last_arg == "Jira" then
      return vim.tbl_filter(function(val)
        return string.match(val, arg_lead)
      end, jira_cmds)
    elseif last_arg == "issue" then
      return vim.tbl_filter(function(val)
        return string.match(val, arg_lead)
      end, jira_issue_cmds)
    else
      return {}
    end
  end,
})

-- " Open Jira issues in the browser
-- " If no Jira Key provided, then use current WORD under cursor
-- function! s:jira_open(jira_key) abort
--   if empty(a:jira_key)
--     call system(printf('jira open %s', expand('<cword>')))
--     return
--   endif
--   call system(printf('jira open %s', a:jira_key))
--   return
-- endfunction
-- command! -nargs=? -complete=customlist,s:jira_issue_completion JiraOpen
--       \ call s:jira_open(<q-args>)
