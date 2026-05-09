-- prek Git hook manager wrapper — runs prek commands in the built-in terminal.
-- Usage: :Prek <command> [subcommand] [flags...]
-- Example: :Prek run
--          :Prek run --all-files
--          :Prek run --stage pre-push
--          :Prek cache gc
--          :Prek util yaml-to-toml

local function prek(args)
	return vim.iter({ "prek", args }):flatten():totable()
end

local top_level = {
	"auto-update",
	"cache",
	"install",
	"list",
	"prepare-hooks",
	"run",
	"sample-config",
	"self",
	"try-repo",
	"uninstall",
	"util",
	"validate-config",
	"validate-manifest",
}

local subcommands = {
	cache = { "clean", "dir", "gc", "size", "--help" },
	self = { "update", "--help" },
	util = {
		"identify",
		"init-template-dir",
		"list-builtins",
		"yaml-to-toml",
		"--help",
	},
}

-- Flags accepted by `prek` and `prek run` (hook execution context).
local run_flags = {
	"-a",
	"--all-files",
	"-d",
	"--directory",
	"-o",
	"--to-ref",
	"-s",
	"--from-ref",
	"--dry-run",
	"--fail-fast",
	"--files",
	"--last-commit",
	"--show-diff-on-failure",
	"--skip",
	"--stage",
}

-- Flags accepted by every subcommand.
local global_flags = {
	"-C",
	"--cd",
	"-V",
	"--version",
	"-c",
	"--config",
	"-h",
	"--help",
	"-q",
	"--quiet",
	"-v",
	"--verbose",
	"--color",
	"--log-file",
	"--no-progress",
	"--refresh",
}

-- `prek` and `prek run` accept run_flags; all other subcommands do not.
local function flags_for(first_arg)
	if not first_arg or first_arg == "run" then
		return vim.list_extend(vim.deepcopy(global_flags), run_flags)
	end
	return global_flags
end

local function complete(arg_lead, cmd_line)
	local tokens = {}
	for token in cmd_line:gmatch("%S+") do
		table.insert(tokens, token)
	end
	-- tokens[1] == "Prek", tokens[2..] == arguments

	local completing_new = cmd_line:sub(-1) == " "
	local arg_count = #tokens - 1
	if completing_new then
		arg_count = arg_count + 1
	end

	local first_arg = tokens[2]
	local is_flag = arg_lead:sub(1, 1) == "-"

	local function filter_list(list)
		return vim.iter(list)
			:filter(function(c)
				return c:find(arg_lead, 1, true) == 1
			end)
			:totable()
	end

	-- position 1: subcommands or flags (no subcommand = run context)
	if arg_count <= 1 then
		if is_flag then
			return filter_list(flags_for(nil))
		end
		return filter_list(top_level)
	end

	-- position 2 under a parent with nested subcommands: offer children or flags
	if arg_count == 2 and first_arg and subcommands[first_arg] then
		if is_flag then
			return filter_list(global_flags)
		end
		return filter_list(subcommands[first_arg])
	end

	-- remaining positions: flags only
	if is_flag then
		return filter_list(flags_for(first_arg))
	end

	return {}
end

vim.api.nvim_create_user_command("Prek", function(opts)
	local args = vim.tbl_map(vim.fn.expand, opts.fargs)
	vim.cmd("botright new")
	vim.fn.jobstart(prek(args), { term = true })
end, {
	desc = "prek Git hook manager",
	nargs = "*",
	complete = complete,
})

vim.keymap.set("n", "<leader>rp", vim.cmd.Prek, { desc = "[R]un [P]rek" })
