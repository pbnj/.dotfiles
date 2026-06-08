-- Just command wrapper
local just_recipes = function(arglead)
  local recipes = vim.fn.systemlist({ "just", "--summary" })
  if vim.v.shell_error ~= 0 then
    return {}
  end
  -- The summary is usually a single line of space-separated recipes
  local recipe_list = {}
  if #recipes > 0 then
    for word in string.gmatch(recipes[1], "%S+") do
      table.insert(recipe_list, word)
    end
  end
  return vim
    .iter(recipe_list)
    :filter(function(recipe)
      return string.match(recipe, "^" .. arglead)
    end)
    :totable()
end

vim.api.nvim_create_user_command("Just", function(opts)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  local cmd = { "just" }
  if opts.args ~= "" then
    table.insert(cmd, opts.args)
  end
  vim.fn.jobstart(cmd, { term = true })
end, {
  nargs = "*",
  complete = just_recipes,
})
