return {
  enabled = true,
  "https://github.com/CopilotC-Nvim/CopilotChat.nvim",
  event = "VeryLazy",
  dependencies = {
    { "https://github.com/github/copilot.vim", cmd = { "Copilot" } },
    { "https://github.com/nvim-lua/plenary.nvim", branch = "master" },
    {
      "https://github.com/ravitemer/mcphub.nvim",
      build = "npm install -g mcp-hub@latest",
      opts = {
        extensions = {
          copilotchat = {
            enabled = true,
            convert_tools_to_functions = true,
            convert_resources_to_functions = true,
            add_mcp_prefix = false,
          },
        },
      },
    },
  },
  build = { "make tiktoken", "npm install @github/copilot-language-server" },
  opts = {
    window = { layout = "horizontal" },
  },
}
