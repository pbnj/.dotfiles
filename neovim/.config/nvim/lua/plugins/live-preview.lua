return {
  {
    "https://github.com/brianhuster/live-preview.nvim",
    dependencies = { "https://github.com/folke/snacks.nvim" },
    opts = {},
    ft = { "markdown" },
    cmd = { "LivePreview" },
  },
  {
    "https://github.com/selimacerbas/mermaid-playground.nvim",
    dependencies = { "https://github.com/selimacerbas/live-server.nvim" },
    opts = {
      -- all optional; sane defaults shown
      workspace_dir = ".mermaid-live", -- defaults to: $XDG_CONFIG_HOME/mermaid-playground
      index_name = "index.html",
      diagram_name = "diagram.mmd",
      overwrite_index_on_start = false, -- don't clobber your customized index.html
      auto_refresh = true,
      auto_refresh_events = { "InsertLeave", "TextChanged", "TextChangedI", "BufWritePost" },
      debounce_ms = 450,
      notify_on_refresh = false,
    },
    ft = { "markdown", "mermaid" },
    cmd = { "MermaidPreviewStart" },
  },
}
