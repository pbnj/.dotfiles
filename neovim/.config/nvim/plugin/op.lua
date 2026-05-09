local function op_completion(a, l)
	local op_cmd = { "op", "--cache" }
	local arg_list = vim.split(l, " ", { trimempty = true })
	local last_arg = vim.iter(arg_list):last()
	if last_arg == "--account=" then
		local op_account_cmd =
			vim.iter({ op_cmd, "account", "list", "--format=json" })
				:flatten()
				:totable()
		local op_account_json = vim.json.decode(vim.fn.system(op_account_cmd))
		local op_account_urls = vim.tbl_map(function(account)
			return string.format("--account=%s", account.url)
		end, op_account_json)
		return vim.tbl_filter(function(account)
			return string.match(account, a)
		end, op_account_urls)
	elseif last_arg == "--vault=" then
		local account_flag = vim.iter(arg_list)
			:filter(function(part)
				return string.match(part, "--account")
			end)
			:totable()
		local op_vault_cmd =
			vim.iter({ op_cmd, account_flag, "vault", "list", "--format=json" })
				:flatten()
				:totable()
		local op_vault_json = vim.json.decode(vim.fn.system(op_vault_cmd))
		local op_vault_names = vim.iter(op_vault_json)
			:map(function(vault)
				return string.format("--vault=%s", vault.name)
			end)
			:totable()
		return vim.iter(op_vault_names)
			:filter(function(account)
				return string.match(account, a)
			end)
			:totable()
	end
	if l:find("item get") then
		local account_flag = vim.iter(arg_list):find("--account")
		local vault_flag = vim.iter(arg_list):find("--vault")
		local op_item_cmd = vim.iter({
			op_cmd,
			account_flag,
			vault_flag,
			"item",
			"list",
			"--format=json",
		})
			:flatten()
			:totable()
		local op_items_json = vim.json.decode(vim.fn.system(op_item_cmd))
		local op_item_names = vim.iter(op_items_json)
			:map(function(item)
				return item.name
			end)
			:totable()
		return vim.iter(op_item_names)
			:filter(function(item)
				return string.match(item, a)
			end)
			:totable()
	end
end

vim.api.nvim_create_user_command("OP", function(opts)
	local Terminal = require("toggleterm.terminal").Terminal
	Terminal:new({
		cmd = string.format("op --cache %s", opts.args),
		direction = "float",
		close_on_exit = false,
	}):toggle()
end, { nargs = "*", complete = op_completion })
