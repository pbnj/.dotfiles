local function ddgr_bang_completion(a)
  local ddgr_bang_list = {
    "!amaps",
    "!archiveis",
    "!archiveweb",
    "!aws",
    "!azure",
    "!bangs",
    "!chtsh",
    "!cloudformation",
    "!crates",
    "!d",
    "!devdocs",
    "!devto",
    "!dhdocs",
    "!dictionary",
    "!dmw",
    "!dockerhub",
    "!docs.rs",
    "!g",
    "!gcp",
    "!gdefine",
    "!gdocs",
    "!gh",
    "!ghcode",
    "!ghio",
    "!ghrepo",
    "!ght",
    "!ghtopic",
    "!ghuser",
    "!gist",
    "!gmail",
    "!gmaps",
    "!godoc",
    "!google",
    "!gopkg",
    "!gsheets",
    "!gslides",
    "!ker",
    "!kubernetes",
    "!man",
    "!mdn",
    "!mw",
    "!mwd",
    "!mysql",
    "!node",
    "!npm",
    "!postgres",
    "!py3",
    "!python",
    "!rce",
    "!rclippy",
    "!reddit",
    "!rust",
    "!rustdoc",
    "!spotify",
    "!stackoverflow",
    "!tldr",
    "!tmg",
    "!translate",
    "!twitch",
    "!typescript",
    "!vimw",
    "!yt",
  }
  local arg_list = vim.split(a, " ", { trimempty = true })
  local last_arg = arg_list[#arg_list]
  if last_arg == "!" then
    return vim.tbl_filter(function(ddgr_bang)
      return string.match(ddgr_bang, a)
    end, ddgr_bang_list)
  end
end

vim.api.nvim_create_user_command("DDGR", function(opts)
  local cmd_list = { "ddgr" }
  if opts.args:find("!") or opts.bang then
    table.insert(cmd_list, "--gui-browser")
    table.insert(cmd_list, "--noprompt")
    table.insert(cmd_list, "--ducky")
    table.insert(cmd_list, opts.args)
    vim.system(cmd_list)
  else
    table.insert(cmd_list, "--expand")
    table.insert(cmd_list, "--num=5")
    table.insert(cmd_list, opts.args)
    require("toggleterm.terminal").Terminal:new({ cmd = table.concat(cmd_list, " "), close_on_exit = false, direction = "float" }):toggle()
  end
end, { nargs = "*", complete = ddgr_bang_completion, bang = true })
