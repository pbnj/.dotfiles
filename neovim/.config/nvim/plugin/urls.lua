-- command
vim.api.nvim_create_user_command("URLs", function(opts)
  require("snacks").picker({
    source = "urls",
    title = "URLs",
    layout = { preset = "vscode" },
    finder = function()
      local url_pattern = "[a-zA-Z]+://[%w-_%.%?%.:/%+=&]+"
      -- local url_pattern = "https?://[%w%-%._~:/%?#%[%]@!$&'()*+,;=%%]+"
      return vim
        .iter(vim.api.nvim_buf_get_lines(0, 0, -1, false))
        :filter(function(line)
          return string.match(line, url_pattern)
        end)
        :map(function(url)
          url = vim.trim(url:gsub("[%.%,%;%:%!%?%)%]%}%'%\"<>]+", ""))
          return { url = url, text = url }
        end)
        :totable()
    end,
    format = function(item, _)
      local ret = {}
      ret[#ret + 1] = { item.url }
      return ret
    end,
    matcher = { fuzzy = true, frecency = true },
    confirm = function(picker, item)
      picker:close()
      vim.ui.open(item.url)
    end,
  })
end, { nargs = "*", bang = true, desc = "Projects Snacks Picker" })

-- keymap
vim.keymap.set({ "n" }, "<leader>fu", vim.cmd.URLs, { desc = "[F]uzzy [U]RLs" })
