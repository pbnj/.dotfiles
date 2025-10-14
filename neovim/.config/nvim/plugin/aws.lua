local aws_profile = function(arglead)
  return vim
    .iter(vim.fn.systemlist({ "rg", "\\[profile (.*)\\]", "-or", "$1", vim.fn.expand("~/.aws/config") }))
    :filter(function(profile)
      return string.match(profile, "^%d+/.*/.*")
    end)
    :filter(function(profile)
      return string.match(profile, arglead)
    end)
    :totable()
end

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
  local cmd = string.format("awe --no-cli-pager --cli-auto-prompt %s", opts.args)
  require("snacks").terminal(cmd, { auto_close = false })
end, {
  nargs = "*",
})

-- Register the AWSProfile command
vim.api.nvim_create_user_command("AWSProfile", function(opts)
  local cmd = { "awe", "--no-cli-pager", "--cli-auto-prompt", "--profile", unpack(opts.fargs) }
  require("snacks").terminal(cmd, { auto_close = false })
end, {
  nargs = "*",
})
