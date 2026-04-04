require("config")
require("plugins")

-- Diagnostics configuration
vim.diagnostic.config({
  severity_sort = true,
  float = { border = "rounded", source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "󰅚",
      [vim.diagnostic.severity.WARN] = "󰀪",
      [vim.diagnostic.severity.INFO] = "󰋽",
      [vim.diagnostic.severity.HINT] = "󰌶",
    },
  },
})

-- Filetypes
vim.filetype.add({
  extension = {
    tofu = "terraform",
    tf = "terraform",
  },
  filename = {
    [".snyk"] = "yaml",
    ["CODEOWNERS"] = "gitignore",
    ["config.ghostty"] = "config",
  },
  pattern = {
    --   [".*/%.github[%w/]+workflows[%w/]+.*%.ya?ml"] = "yaml.github",
    [".*"] = {
      function(_, bufnr)
        local contents = vim.api.nvim_buf_get_lines(bufnr, 0, 3, false) or {}
        for _, v in ipairs(contents) do
          if v:match("apiVersion:%s%S+") then
            return "yaml"
          end
        end
        -- if vim.regex([[^apiVersion:]]):match_str(content) ~= nil then
        --   return "yaml"
        -- end
      end,
      { priority = -math.huge },
    },
  },
})
