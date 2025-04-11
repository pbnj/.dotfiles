vim.api.nvim_create_user_command("BufOnly", "silent! execute '%bd | e# | bd#'", {})
