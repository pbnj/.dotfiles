vim.api.nvim_create_user_command("Brew", function(opts)
  local cmd = vim.iter({ "brew", opts.fargs }):flatten():totable()
  require("snacks").terminal(cmd, { auto_close = false })
end, {
  nargs = "*",
  desc = "Brew",
  complete = function(arglead)
    return vim
      .iter({ "search", "info", "update", "upgrade", "cleanup", "uninstall", "list", "doctor", "unlink", "link" })
      :filter(function(val)
        return string.match(val, arglead)
      end)
      :totable()
  end,
})
