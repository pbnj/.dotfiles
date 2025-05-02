vim.api.nvim_create_user_command("Precommit", function(opts)
  vim.notify(vim.system({ "pre-commit", opts.args }):wait().stdout, vim.log.levels.INFO)
end, {
  nargs = "*",
  desc = "pre-commit",
  complete = function(arg_lead)
    return vim
      .iter({
        "autoupdate",
        "clean",
        "gc",
        "help",
        "init-templatedir",
        "install",
        "install-hooks",
        "migrate-config",
        "run",
        "sample-config",
        "try-repo",
        "uninstall",
        "validate-config",
        "validate-manifest",
      })
      :filter(function(cmd)
        return string.match(cmd, arg_lead)
      end)
      :totable()
  end,
})

-- command! -nargs=1 -complete=file_in_path PrecommitRun
--       \ <mods> terminal pre-commit run --files <args>
