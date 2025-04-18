-- Function to handle Amazon Q command
local function amazon_q(args, line_start, line_end, count)
  local Terminal = require("toggleterm.terminal").Terminal
  local cmd = "q chat"
  local arg_list = {}

  -- Filter out empty arguments
  for arg in string.gmatch(args, "%S+") do
    table.insert(arg_list, arg)
  end

  local formatted_string = ""

  if #arg_list > 0 then
    -- If there's a range selection
    if count > -1 then
      -- Get the selected lines
      local lines = vim.api.nvim_buf_get_lines(0, line_start - 1, line_end, false)
      table.insert(arg_list, ":")
      table.insert(arg_list, table.concat(lines, "\n"))
    end

    -- Format the arguments
    formatted_string = table.concat(arg_list, " ")
    -- Escape special characters
    formatted_string = formatted_string:gsub('"', '\\"'):gsub("%%", "\\%%"):gsub("#", "\\#")
    cmd = string.format(cmd .. ' "%s"', formatted_string)
  end

  -- Execute the command with modifiers
  Terminal:new({ cmd = cmd }):toggle()
end

-- Register the command
vim.api.nvim_create_user_command("Q", function(opts)
  local args = opts.args
  local line_start = opts.line1
  local line_end = opts.line2
  local count = opts.range > 0 and opts.range or -1

  amazon_q(args, line_start, line_end, count)
end, {
  nargs = "?",
  range = true,
  complete = "file_in_path",
})
