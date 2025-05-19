vim.filetype.add({
  extension = {
    json = "jsonc",
  },
  filename = {
    [".snyk"] = "yaml",
    [".aws/config"] = "dosini",
  },
  -- pattern = {
  --   [".*/%.github[%w/]+workflows[%w/]+.*%.ya?ml"] = "yaml.github",
  -- },
})
