local terminal = function(args, auto_close)
  if pcall(require, "snacks") then
    require("snacks").terminal(args, { auto_close = auto_close, win = { wo = { winbar = table.concat(args, " ") } } })
    return
  elseif pcall(require, "toggleterm") then
    require("toggleterm.terminal").Terminal:new({ cmd = table.concat(args, " "), direction = "float", close_on_exit = auto_close }):toggle()
    return
  else
    vim.cmd("terminal " .. table.concat(args, " "))
  end
end

local ddgr_bang_list = {
  "!ai",
  "!amaps",
  "!archiveis",
  "!archiveweb",
  "!aws",
  "!azure",
  "!bangs",
  "!chat",
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
  "!duckduckgo",
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
  "!i",
  "!ker",
  "!kubernetes",
  "!man",
  "!mdn",
  "!mysql",
  "!n",
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
  "!v",
  "!vimw",
  "!yt",
}

local ddgr_bang_completion = function(arg_lead, _, _)
  return vim
    .iter(ddgr_bang_list)
    :filter(function(cmd)
      return string.match(cmd, arg_lead)
    end)
    :totable()
end

vim.api.nvim_create_user_command("DDGR", function(opts)
  local cmd = { "ddgr", "--expand" }
  if #opts.fargs == 0 then
    terminal(cmd, false)
  else
    vim.ui.select(ddgr_bang_list, { prompt = "DDGR> " }, function(bang)
      cmd = vim.tbl_extend("force", cmd, { "ddgr", "--noprompt", "--gui-browser", bang, unpack(opts.fargs) })
      terminal(cmd, true)
    end)
  end
end, {
  nargs = "*",
  bang = true,
  desc = "DuckDuckGo (DDGR)",
  complete = ddgr_bang_completion,
})

vim.keymap.set({ "n" }, "<leader>dd", vim.cmd.DDGR, { desc = "DuckDuckGo (DDGR)", silent = true, noremap = true })
