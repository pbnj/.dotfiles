return {
  "https://github.com/CopilotC-Nvim/CopilotChat.nvim",
  dependencies = {
    { "https://github.com/github/copilot.vim", cmd = { "Copilot" } },
    { "https://github.com/nvim-lua/plenary.nvim", branch = "master" },
    { "https://github.com/ravitemer/mcphub.nvim", build = "npm install -g mcp-hub@latest", opts = {} },
  },
  build = "make tiktoken",
  opts = {
    window = { layout = "horizontal" },
  },
  cmd = {
    "CopilotChat",
    "CopilotChatOpen",
    "CopilotChatToggle",
    "CopilotChatPrompts",
    "CopilotChatModels",
    "CopilotChatAgents",
  },
  keys = {
    {
      "<leader>ta",
      function()
        vim.cmd.CopilotChatToggle()
      end,
      desc = "Copilot Chat Toggle",
    },
  },
}
