local terminal = function(args)
  if pcall(require, "snacks") then
    require("snacks").terminal(args, { auto_close = false, win = { wo = { winbar = table.concat(args, " ") } } })
    return
  elseif pcall(require, "toggleterm") then
    require("toggleterm.terminal").Terminal:new({ cmd = table.concat(args, " "), direction = "float", close_on_exit = false }):toggle()
    return
  else
    vim.cmd("terminal " .. table.concat(args, " "))
  end
end

local aws_profile = function(arglead)
  return vim
    .iter(vim.fn.systemlist({ "aws", "configure", "list-profiles" }))
    :filter(function(profile)
      return string.match(profile, arglead)
    end)
    :totable()
end

vim.api.nvim_create_user_command("AWSConsole", function(opts)
  require("fzf-lua").fzf_exec(function(fzf_cb)
    vim
      .iter(vim.fn.systemlist({ "aws", "configure", "list-profiles" }))
      :map(function(profile)
        fzf_cb(profile)
      end)
      :totable()
    fzf_cb()
  end, {
    prompt = "AWS Console> ",
    actions = {
      ["ctrl-a"] = function(selected)
        local parts = vim.split(selected[1], "/")
        local account_alias = parts[2]
        vim.fn.setreg("+", string.format("%s", account_alias))
        vim.notify(string.format("Yanked AWS Account Alias: %s", account_alias), vim.log.levels.INFO)
      end,
      ["ctrl-i"] = function(selected)
        local parts = vim.split(selected[1], "/")
        local account_id = parts[1]
        vim.fn.setreg("+", string.format("%s", account_id))
        vim.notify(string.format("Yanked AWS Account ID: %s", account_id), vim.log.levels.INFO)
      end,
      ["enter"] = function(selected)
        local profile = selected[1]
        local sso_account_url = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_account_url", "--profile", profile }))
        vim.ui.open(sso_account_url)
        vim.notify(string.format("Opening AWS Console for profile: %s", profile), vim.log.levels.INFO)
      end,
    },
    fzf_opts = {
      ["--info"] = "inline",
      ["--header"] = "<ctrl-a> yank alias, <ctrl-i> yank id, <enter> open console",
    },
  })
  -- require("snacks").picker({
  --   source = "aws_console",
  --   title = "AWS Console",
  --   layout = { preset = "vscode" },
  --   finder = function()
  --     return vim
  --       .iter(vim.fn.systemlist({ "aws", "configure", "list-profiles" }))
  --       :filter(function(profile)
  --         return string.match(profile, "^%d+/.*/.*")
  --       end)
  --       :map(function(profile)
  --         local profile_elems = vim.split(profile, "/")
  --         local account_id = profile_elems[1]
  --         local account_alias = profile_elems[2]
  --         return {
  --           profile = profile,
  --           text = profile,
  --           account_id = account_id,
  --           account_alias = account_alias,
  --         }
  --       end)
  --       :totable()
  --   end,
  --   format = function(item, _)
  --     local ret = {}
  --     ret[#ret + 1] = { item.account_id }
  --     ret[#ret + 1] = { "  " }
  --     ret[#ret + 1] = { item.account_alias }
  --     return ret
  --   end,
  --   matcher = { fuzzy = true, frecency = true },
  --   actions = {
  --     yank_alias = { action = "yank", field = "account_alias", desc = "Yank Alias" },
  --     yank_id = { action = "yank", field = "account_id", desc = "Yank ID" },
  --     yank_url = { action = "yank", field = "url", desc = "Yank URL" },
  --     yank_profile = { action = "yank", field = "profile", desc = "Yank Profile" },
  --   },
  --   win = {
  --     input = {
  --       keys = {
  --         ["<m-n>"] = { "yank_alias", mode = { "n", "i" } },
  --         ["<m-i>"] = { "yank_id", mode = { "n", "i" } },
  --         ["<m-u>"] = { "yank_url", mode = { "n", "i" } },
  --         ["<m-p>"] = { "yank_profile", mode = { "n", "i" } },
  --       },
  --     },
  --   },
  --   confirm = function(picker, item)
  --     picker:close()
  --     if opts.bang then
  --       vim.fn.setreg("+", string.format("%s (%s)", item.account_id, item.account_alias))
  --     else
  --       local sso_account_url = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_account_url", "--profile", item.profile }))
  --       vim.ui.open(sso_account_url)
  --     end
  --   end,
  -- })
end, {
  nargs = "?",
  bang = true,
  complete = aws_profile,
})
vim.keymap.set({ "n" }, "<leader>ac", vim.cmd.AWSConsole, { desc = "[A]WS [C]onsole" })

-- IAM User Picker
vim.api.nvim_create_user_command("AWSIAMUsers", function(opts)
  local profile = opts.args
  local sso_account_id = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_account_id", "--profile", profile }))
  require("snacks").picker({
    source = "aws_iam_users",
    title = string.format("AWS IAM Users (%s)", sso_account_id),
    layout = { preset = "vscode" },
    finder = function()
      local cmd = { "aws", "iam", "list-users", "--output", "json", "--profile", profile }
      local users = vim.json.decode(vim.fn.system(cmd))
      return vim
        .iter(users.Users)
        :map(function(user)
          return {
            text = user.UserName,
          }
        end)
        :totable()
    end,
    format = function(item, _)
      local ret = {}
      ret[#ret + 1] = { item.text }
      return ret
    end,
    matcher = { fuzzy = true, frecency = true },
    actions = {
      yank_name = { action = "yank", field = "text", desc = "Yank Name" },
    },
    win = {
      input = {
        keys = {
          ["<m-n>"] = { "yank_name", mode = { "n", "i" } },
        },
      },
    },
    preview = function(ctx)
      ctx.preview:reset()
      local cmd_get_user = { "aws", "iam", "get-user", "--user-name", ctx.item.text, "--profile", profile }
      local lines = vim.fn.systemlist(cmd_get_user)
      ctx.preview:set_lines(lines)
      ctx.preview:highlight({ ft = "json" })
    end,
    confirm = function(picker, item)
      -- picker:close()
      -- vim.api.nvim_set_current_line(item.arn)
    end,
  })
end, {
  nargs = "?",
  complete = aws_profile,
})

-- IAM Policy Picker
vim.api.nvim_create_user_command("AWSIAMPolicies", function(opts)
  local profile = opts.args
  local sso_account_id = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_account_id", "--profile", profile }))
  require("snacks").picker({
    source = "aws_iam_policies",
    title = string.format("AWS IAM Policies (%s)", sso_account_id),
    layout = { preset = "vscode" },
    finder = function()
      local cmd = { "aws", "iam", "list-policies", "--output", "json", "--profile", profile }
      local policies = vim.json.decode(vim.fn.system(cmd))
      return vim
        .iter(policies.Policies)
        :map(function(policy)
          return {
            text = policy.PolicyName,
            arn = policy.Arn,
          }
        end)
        :totable()
    end,
    format = function(item, _)
      local ret = {}
      ret[#ret + 1] = { item.arn }
      return ret
    end,
    matcher = { fuzzy = true, frecency = true },
    actions = {
      yank_name = { action = "yank", field = "text", desc = "Yank Name" },
      yank_arn = { action = "yank", field = "arn", desc = "Yank ARN" },
    },
    win = {
      input = {
        keys = {
          ["<m-n>"] = { "yank_name", mode = { "n", "i" } },
          ["<m-a>"] = { "yank_arn", mode = { "n", "i" } },
          ["<m-u>"] = { "yank_url", mode = { "n", "i" } },
        },
      },
    },
    preview = function(ctx)
      ctx.preview:reset()
      local cmd_policy = { "aws", "iam", "get-policy", "--policy-arn", ctx.item.arn }
      local json = vim.fn.system(cmd_policy)
      local decoded = vim.json.decode(json)
      local cmd_policy_version = { "aws", "iam", "get-policy-version", "--policy-arn", ctx.item.arn, "--version-id", decoded.Policy.DefaultVersionId }
      local lines = vim.fn.systemlist(cmd_policy_version)
      ctx.preview:set_lines(lines)
      ctx.preview:highlight({ ft = "json" })
    end,
    confirm = function(picker, item)
      -- picker:close()
      -- vim.api.nvim_set_current_line(item.arn)
    end,
  })
end, {
  nargs = "?",
  complete = aws_profile,
})

-- IAM Role Picker
vim.api.nvim_create_user_command("AWSIAMRoles", function(opts)
  local profile = opts.args
  local sso_account_id = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_account_id", "--profile", profile }))
  require("snacks").picker({
    source = "aws_iam_policies",
    title = string.format("AWS IAM Roles (%s)", sso_account_id),
    layout = { preset = "vscode" },
    finder = function()
      local cmd = { "aws", "iam", "list-roles", "--output", "json", "--profile", profile }
      local roles = vim.json.decode(vim.fn.system(cmd))
      return vim
        .iter(roles.Roles)
        :map(function(role)
          return {
            text = role.RoleName,
            arn = role.Arn,
          }
        end)
        :totable()
    end,
    format = function(item, _)
      local ret = {}
      ret[#ret + 1] = { item.arn }
      return ret
    end,
    matcher = { fuzzy = true, frecency = true },
    actions = {
      yank_name = { action = "yank", field = "text", desc = "Yank Name" },
      yank_arn = { action = "yank", field = "arn", desc = "Yank ARN" },
    },
    win = {
      input = {
        keys = {
          ["<m-n>"] = { "yank_name", mode = { "n", "i" } },
          ["<m-a>"] = { "yank_arn", mode = { "n", "i" } },
        },
      },
    },
    preview = function(ctx)
      ctx.preview:reset()
      local cmd_get_role = { "aws", "iam", "get-role", "--role-name", ctx.item.text }
      local lines = vim.fn.systemlist(cmd_get_role)
      ctx.preview:set_lines(lines)
      ctx.preview:highlight({ ft = "json" })
    end,
    confirm = function(picker, item)
      -- picker:close()
      -- vim.api.nvim_set_current_line(item.arn)
    end,
  })
end, {
  nargs = "?",
  complete = aws_profile,
})

vim.api.nvim_create_user_command("AWS", function(opts)
  local cmd = vim.iter({ "awe", "--no-cli-pager", "--cli-auto-prompt", opts.fargs }):flatten():totable()
  terminal(cmd)
end, {
  nargs = "*",
})

-- Register the AWSProfile command
vim.api.nvim_create_user_command("AWSProfile", function(opts)
  local Terminal = require("toggleterm.terminal").Terminal
  local cmd = string.format("awe --no-cli-pager --cli-auto-prompt --profile=%s", opts.args)
  Terminal:new({ cmd = cmd, close_on_exit = false }):toggle()
end, {
  nargs = "*",
})
