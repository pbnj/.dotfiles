return {
  "https://github.com/akinsho/toggleterm.nvim",
  event = "VeryLazy",
  config = function()
    vim.keymap.set("t", "<esc><esc>", "<C-\\><C-n>", { noremap = true, silent = true })
    require("toggleterm").setup({
      open_mapping = [[<c-\>]],
      size = function(term)
        if term.direction == "horizontal" then
          return vim.o.lines * 0.4
        elseif term.direction == "vertical" then
          return vim.o.columns * 0.4
        end
      end,
    })
  end,
  keys = {
    {
      "<leader>tr",
      vim.cmd.ToggleTermSendCurrentLine,
      mode = { "n" },
      desc = "[T]oggleterm [R]un Visual Selection",
    },
    {
      "<leader>tr",
      vim.cmd.ToggleTermSendVisualSelection,
      mode = { "v", "x" },
      desc = "[T]oggleterm [R]un Visual Selection",
    },
  },
}
