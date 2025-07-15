local function aws_profile_completion(arglead)
  return vim
    .iter(vim.fn.systemlist({ "aws", "configure", "list-profiles" }))
    :filter(function(profile)
      return string.match(profile, arglead)
    end)
    :totable()
end

vim.api.nvim_create_user_command("AWSConsole", function(opts)
  if opts.args == "" then
    vim.ui.select(vim.fn.systemlist({ "aws", "configure", "list-profiles" }), {
      prompt = "AWS Profiles",
    }, function(profile)
      local account_id = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_account_id", "--profile", profile }))
      local role_name = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_role_name", "--profile", profile }))
      local sso_start_url = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_start_url", "--profile", profile }))
      local url = string.format("%s/console?account_id=%s&role_name=%s", sso_start_url, account_id, role_name)
      vim.ui.open(url)
      if opts.bang then
        vim.cmd.quitall()
      end
    end)
  else
    local profile = opts.args
    local account_id = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_account_id", "--profile", profile }))
    local role_name = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_role_name", "--profile", profile }))
    local sso_start_url = vim.trim(vim.fn.system({ "aws", "configure", "get", "sso_start_url", "--profile", profile }))
    local url = string.format("%s/console?account_id=%s&role_name=%s", sso_start_url, account_id, role_name)
    vim.ui.open(url)
  end
end, {
  nargs = "?",
  bang = true,
  complete = aws_profile_completion,
})
vim.keymap.set({ "n" }, "<leader>ac", vim.cmd.AWSConsole, { desc = "[A]WS [C]onsole" })

vim.api.nvim_create_user_command("AWSIAMPolicies", function(opts)
  local profile = opts.args
  local sso_start_url = vim.trim(vim.fn.system("aws configure get sso_start_url"))
  local sso_account_id = vim.trim(vim.fn.system("aws configure get sso_account_id"))
  local sso_account_role = vim.trim(vim.fn.system("aws configure get sso_role_name"))
  if profile ~= "" then
    sso_account_id = vim.split(profile, "/")[1]
    sso_account_role = vim.split(profile, "/")[3]
  end
  require("snacks").picker({
    source = "aws_iam_policies",
    title = profile and string.format("AWS IAM Policies (%s)", profile) or "AWS IAM Policies",
    layout = { preset = "default" },
    finder = function()
      local url = ""
      local cmd = { "aws", "iam", "list-policies", "--output", "json" }
      if profile ~= "" then
        url = string.format("%s/console?account_id=%s&role_name=%s", sso_start_url, sso_account_id, sso_account_role)
        vim.list_extend(cmd, { "--profile", profile })
      end
      local policies = vim.json.decode(vim.fn.system(cmd))
      return vim
        .iter(policies.Policies)
        :map(function(policy)
          return {
            text = policy.PolicyName,
            arn = policy.Arn,
            url = url,
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
      yank_url = { action = "yank", field = "url", desc = "Yank URL" },
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
      if profile ~= "" then
        vim.list_extend(cmd_policy, { "--profile", profile })
      end
      local json = vim.fn.system(cmd_policy)
      local decoded = vim.json.decode(json)
      local cmd_policy_version = { "aws", "iam", "get-policy-version", "--policy-arn", ctx.item.arn, "--version-id", decoded.Policy.DefaultVersionId }
      if profile ~= "" then
        vim.list_extend(cmd_policy_version, { "--profile", profile })
      end
      local lines = vim.fn.systemlist(cmd_policy_version)
      ctx.preview:set_lines(lines)
      ctx.preview:highlight({ ft = "json" })
    end,
    confirm = function(picker, item)
      picker:close()
      vim.api.nvim_set_current_line(item.arn)
      -- TODO: open selected policy in aws console
    end,
  })
end, {
  nargs = "?",
  complete = aws_profile_completion,
})

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
