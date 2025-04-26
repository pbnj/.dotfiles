return {
  "https://github.com/CopilotC-Nvim/CopilotChat.nvim",
  dependencies = {
    { "https://github.com/github/copilot.vim", cmd = { "Copilot" } },
    { "https://github.com/nvim-lua/plenary.nvim", branch = "master" },
  },
  build = "make tiktoken",
  opts = {},
  cmd = {
    "CopilotChat",
    "CopilotChatOpen",
    "CopilotChatToggle",
    "CopilotChatPrompts",
    "CopilotChatModels",
    "CopilotChatAgents",
  },
}
