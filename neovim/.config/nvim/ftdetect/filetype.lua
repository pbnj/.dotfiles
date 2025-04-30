vim.filetype.add({
  extension = {
    json = "jsonc",
  },
  filename = {
    [".snyk"] = "yaml",
    [".aws/config"] = "dosini",
  },
})
