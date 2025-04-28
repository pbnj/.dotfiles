-- 1Password CLI brings 1Password to your terminal.
--
-- Turn on the 1Password app integration and sign in to get started. Run
-- 'op signin --help' to learn more.
--
-- For more help, read our documentation:
-- https://developer.1password.com/docs/cli
--
-- 1Password CLI is built using open-source software. View our credits and
-- licenses:
-- https://downloads.1password.com/op/credits/stable/credits.html
--
-- Usage:  op [command] [flags]
--
-- Management Commands:
--   account         Manage your locally configured 1Password accounts
--   connect         Manage Connect server instances and tokens in your 1Password account
--   document        Perform CRUD operations on Document items in your vaults
--   events-api      Manage Events API integrations in your 1Password account
--   group           Manage the groups in your 1Password account
--   item            Perform CRUD operations on the 1Password items in your vaults
--   plugin          Manage the shell plugins you use to authenticate third-party CLIs
--   service-account Manage service accounts
--   user            Manage users within this 1Password account
--   vault           Manage permissions and perform CRUD operations on your 1Password vaults
--
-- Commands:
--   completion      Generate shell completion information
--   inject          Inject secrets into a config file
--   read            Read a secret reference
--   run             Pass secrets as environment variables to a process
--   signin          Sign in to a 1Password account
--   signout         Sign out of a 1Password account
--   update          Check for and download updates.
--   whoami          Get information about a signed-in account
--
-- Global Flags:
--       --account account    Select the account to execute the command by account shorthand, sign-in address, account ID, or user ID. For a list of available accounts, run 'op account list'. Can be
--                            set as the OP_ACCOUNT environment variable.
--       --cache              Store and use cached information. Caching is enabled by default on UNIX-like systems. Caching is not available on Windows. Options: true, false. Can also be set with the
--                            OP_CACHE environment variable. (default true)
--       --config directory   Use this configuration directory.
--       --debug              Enable debug mode. Can also be enabled by setting the OP_DEBUG environment variable to true.
--       --encoding type      Use this character encoding type. Default: UTF-8. Supported: SHIFT_JIS, gbk.
--       --format string      Use this output format. Can be 'human-readable' or 'json'. Can be set as the OP_FORMAT environment variable. (default "human-readable")
--   -h, --help               Get help for op.
--       --iso-timestamps     Format timestamps according to ISO 8601 / RFC 3339. Can be set as the OP_ISO_TIMESTAMPS environment variable.
--       --no-color           Print output without color.
--       --session token      Authenticate with this session token. 1Password CLI outputs session tokens for successful 'op signin' commands when 1Password app integration is not enabled.
--   -v, --version            version for op

local function op_completion(a, l)
  local op_cmd = { "op", "--cache" }
  local arg_list = vim.split(l, " ", { trimempty = true })
  local last_arg = vim.iter(arg_list):last()
  if last_arg == "--account=" then
    local op_account_cmd = vim.iter({ op_cmd, "account", "list", "--format=json" }):flatten():totable()
    local op_account_json = vim.json.decode(vim.fn.system(op_account_cmd))
    local op_account_urls = vim.tbl_map(function(account)
      return string.format("--account=%s", account.url)
    end, op_account_json)
    return vim.tbl_filter(function(account)
      return string.match(account, a)
    end, op_account_urls)
  elseif last_arg == "--vault=" then
    local account_flag = vim
      .iter(arg_list)
      :filter(function(part)
        return string.match(part, "--account")
      end)
      :totable()
    local op_vault_cmd = vim.iter({ op_cmd, account_flag, "vault", "list", "--format=json" }):flatten():totable()
    local op_vault_json = vim.json.decode(vim.fn.system(op_vault_cmd))
    local op_vault_names = vim
      .iter(op_vault_json)
      :map(function(vault)
        return string.format("--vault=%s", vault.name)
      end)
      :totable()
    return vim
      .iter(op_vault_names)
      :filter(function(account)
        return string.match(account, a)
      end)
      :totable()
  end
  if l:find("item get") then
    local account_flag = vim.iter(arg_list):find("--account")
    local vault_flag = vim.iter(arg_list):find("--vault")
    local op_item_cmd = vim.iter({ op_cmd, account_flag, vault_flag, "item", "list", "--format=json" }):flatten():totable()
    local op_items_json = vim.json.decode(vim.fn.system(op_item_cmd))
    local op_item_names = vim
      .iter(op_items_json)
      :map(function(item)
        return item.name
      end)
      :totable()
    return vim
      .iter(op_item_names)
      :filter(function(item)
        return string.match(item, a)
      end)
      :totable()
  end
end

vim.api.nvim_create_user_command("OP", function(opts)
  local Terminal = require("toggleterm.terminal").Terminal
  Terminal:new({ cmd = string.format("op --cache %s", opts.args), direction = "float", close_on_exit = false }):toggle()
end, { nargs = "*", complete = op_completion })
