vim.api.nvim_create_user_command("Kubectl", function(opts)
	local cmd = vim.iter({ "kubectl", opts.fargs }):flatten():totable()
	require("snacks").terminal(cmd, {
		auto_close = false,
		interactive = false,
		win = { position = "bottom" },
	})
end, {
	nargs = "*",
	desc = "Kubectl",
	bang = true,
	complete = function(arg_lead, _, _)
		return vim.iter({
			"--kubeconfig=",
			"--context=",
			"--namespace=",
			"annotate",
			"api",
			"apply",
			"attach",
			"auth",
			"autoscale",
			"certificate",
			"cluster",
			"completion",
			"config",
			"cordon",
			"cp",
			"create",
			"debug",
			"delete",
			"describe",
			"diff",
			"drain",
			"edit",
			"events",
			"exec",
			"explain",
			"expose",
			"get",
			"kustomize",
			"label",
			"logs",
			"patch",
			"plugin",
			"port",
			"proxy",
			"replace",
			"rollout",
			"run",
			"scale",
			"set",
			"taint",
			"top",
			"uncordon",
			"version",
			"wait",
		})
			:filter(function(kcmd)
				return string.match(kcmd, arg_lead)
			end)
			:totable()
	end,
})
vim.keymap.set(
	{ "n" },
	"<leader>k",
	vim.cmd.Kubectl,
	{ desc = "Kubectl", noremap = true, silent = true }
)
