-- function! Finder(arg, _) abort
--   let files = systemlist('rg --files --hidden --color=never')
--   if len(a:arg) == 0
--     return files
--   else
--     return matchfuzzy(files, a:arg)
--   endif
-- endfunction
-- set findfunc=Finder

function _G.Finder(arg, _)
  local files = vim.fn.systemlist({ "rg", "--files", "--hidden", "--color=never" })
  if #arg == 0 then
    return files
  else
    return vim.fn.matchfuzzy(files, arg)
  end
end
vim.opt.findfunc = "v:lua.Finder"
