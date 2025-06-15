local function aws_profile_completion(arglead)
  return vim
    .iter(vim.fn.systemlist("aws configure list-profiles"))
    :filter(function(profile)
      return string.match(profile, arglead)
    end)
    :totable()
end

vim.api.nvim_create_user_command("AWSConsole", function(opts)
  local aws_sso_start_url = vim.trim(vim.fn.system("grep 'sso_start_url' ~/.aws/config | uniq | awk -F'=' '{printf $2}'"))
  if opts.args == "" then
    require("snacks").picker({
      source = "aws_console",
      layout = "vscode",
      finder = function()
        return vim
          .iter(vim.fn.systemlist("aws configure list-profiles | grep -E '^\\d{12}'"))
          :map(function(profile)
            local profile_split = vim.split(profile, "/")
            local account_id = profile_split[1]
            local account_alias = profile_split[2]
            local role_name = profile_split[3]
            local account_url = string.format("%s/console?account_id=%s&role_name=%s", aws_sso_start_url, account_id, role_name)
            return {
              text = profile,
              item = profile,
              account_id = account_id,
              account_alias = account_alias,
              account_url = account_url,
            }
          end)
          :totable()
      end,
      format = function(item, _)
        local a = Snacks.picker.util.align
        local ret = {}
        ret[#ret + 1] = { a(item.account_id, 12, { truncate = false }) }
        ret[#ret + 1] = { "  " }
        ret[#ret + 1] = { a(item.account_alias, 63, { truncate = true }) }
        return ret
      end,
      matcher = { fuzzy = true, frecency = true },
      actions = {
        yank_id = { action = "yank", field = "account_id", desc = "Yank ID" },
        yank_alias = { action = "yank", field = "account_alias", desc = "Yank Alias" },
        yank_profile = { action = "yank", desc = "Yank Profile" },
        yank_url = { action = "yank", field = "account_url", desc = "Yank URL" },
      },
      win = {
        input = {
          keys = {
            ["<m-i>"] = { "yank_id", mode = { "n", "i" } },
            ["<m-a>"] = { "yank_alias", mode = { "n", "i" } },
            ["<m-p>"] = { "yank_profile", mode = { "n", "i" } },
            ["<m-u>"] = { "yank_url", mode = { "n", "i" } },
          },
        },
      },
      confirm = function(picker, item)
        picker:close()
        local selection = vim.split(item.text, "/")
        local account_id = selection[1]
        local role_name = selection[3]
        local url = string.format("%s/console?account_id=%s&role_name=%s", aws_sso_start_url, account_id, role_name)
        vim.system({ "open", url })
      end,
    })
  else
    local selection = vim.split(opts.args, "/")
    local account_id = selection[1]
    local role_name = selection[3]
    local url = string.format("%s/console?account_id=%s&role_name=%s", aws_sso_start_url, account_id, role_name)
    vim.system({ "open", url })
  end
end, {
  nargs = "?",
  complete = aws_profile_completion,
})
vim.keymap.set({ "n" }, "<leader>ac", vim.cmd.AWSConsole, { desc = "[A]WS [C]onsole" })

vim.api.nvim_create_user_command("AWS", function(opts)
  local cmd = string.format("awe --no-cli-pager --cli-auto-prompt %s", opts.args)
  require("snacks").terminal(cmd, { auto_close = false })
end, {
  nargs = "*",
  complete = aws_profile_completion,
})

-- Register the AWSProfile command
vim.api.nvim_create_user_command("AWSProfile", function(opts)
  local Terminal = require("toggleterm.terminal").Terminal
  local cmd = string.format("awe --no-cli-pager --cli-auto-prompt --profile=%s", opts.args)
  Terminal:new({ cmd = cmd, close_on_exit = false }):toggle()
end, {
  nargs = "*",
  complete = aws_profile_completion,
})
