---@brief
---
--- https://docs.snyk.io/developer-tools/snyk-ide-plugins-and-extensions/snyk-language-server
---
--- LSP for Snyk Open Source, Snyk Infrastructure as Code, and Snyk Code.
return {
  cmd = { "snyk", "language-server" },
  root_markers = { ".snyk", ".git" },
  filetypes = {
    "go",
    "gomod",
    "javascript",
    "typescript",
    "json",
    "python",
    "requirements",
    "helm",
    "yaml",
    "terraform",
    "terraform-vars",
  },
  settings = {},
  -- https://docs.snyk.io/developer-tools/snyk-ide-plugins-and-extensions/snyk-language-server#lsp-initialization-options
  init_options = {
    activateSnykOpenSource = "true", -- Enables Snyk Open Source - defaults to true
    activateSnykCode = "true", -- Enables Snyk Code, if enabled for your organization - defaults to false
    activateSnykIac = "true", -- Enables Infrastructure as Code - defaults to true
    additionalParams = "--all-projects", -- Any extra params for the Snyk CLI, separated by spaces
    organization = vim.env.SNYK_ORG, -- The name of your organization, e.g. the output of: curl -H "Authorization: token $(snyk config get api)"  https://api.snyk.io/v1/cli-config/settings/sast | jq .org
    token = vim.env.SNYK_TOKEN, -- The Snyk token, e.g.: snyk config get api
    automaticAuthentication = "true", -- Whether or not LS will automatically authenticate on scan start (default: true)
    authenticationMethod = "token", -- the authentication method (token, oauth, pat)
    enableTrustedFoldersFeature = "false", -- Whether or not LS will prompt to trust a folder (default: true)
    -- trustedFolders= ["/a/trusted/path", "/another/trusted/path"], -- An array of folder that should be trusted
  },
  reuse_client = function(client, config)
    config.cmd_cwd = config.root_dir
    return client.config.cmd_cwd == config.cmd_cwd
  end,
}
