vim.api.nvim_create_user_command("DDGR", function(opts)
  local ddgr_bang_list = {
    { bang = "!ai", text = "Duck.ai" },
    { bang = "!amaps", text = "Apple Maps" },
    { bang = "!archiveis", text = "Archive.is" },
    { bang = "!archiveweb", text = "Archive.org" },
    { bang = "!aws", text = "AWS" },
    { bang = "!azure", text = "Azure" },
    { bang = "!bangs", text = "DuckDuckGo Bangs" },
    { bang = "!chat", text = "Duck.ai" },
    { bang = "!chtsh", text = "Cheatsheet" },
    { bang = "!cloudformation", text = "AWS CloudFormation" },
    { bang = "!crates", text = "Rust Crates" },
    { bang = "!d", text = "The Free Dictionary" },
    { bang = "!devdocs", text = "DevDocs" },
    { bang = "!devto", text = "DevTo" },
    { bang = "!dhdocs", text = "Dockerhub Docs" },
    { bang = "!dictionary", text = "The Free Dictionary" },
    { bang = "!dmw", text = "Meriam-Webster Dictionary" },
    { bang = "!dockerhub", text = "DockerHub" },
    { bang = "!docs.rs", text = "Rust Docs.rs" },
    { bang = "!g", text = "Google" },
    { bang = "!gcp", text = "Google Cloud" },
    { bang = "!gdefine", text = "Google Define" },
    { bang = "!gdocs", text = "Google Docs" },
    { bang = "!gh", text = "GitHub" },
    { bang = "!ghcode", text = "GitHub (code search)" },
    { bang = "!ghio", text = "GitHub User Pages" },
    { bang = "!ghrepo", text = "GitHub Repo" },
    { bang = "!ght", text = "GitHub Trending" },
    { bang = "!ghtopic", text = "GitHub Topics" },
    { bang = "!ghuser", text = "GitHub Users" },
    { bang = "!gist", text = "GitHub Gists" },
    { bang = "!gmail", text = "Google Mail" },
    { bang = "!gmaps", text = "Google Maps" },
    { bang = "!godoc", text = "Golang Docs" },
    { bang = "!google", text = "Google" },
    { bang = "!gopkg", text = "Golang Packages" },
    { bang = "!gsheets", text = "Google Sheets" },
    { bang = "!gslides", text = "Google Slides" },
    { bang = "!i", text = "DuckDuckGo Images" },
    { bang = "!ker", text = "Linux Kernel Archives" },
    { bang = "!kubernetes", text = "Kubernetes" },
    { bang = "!man", text = "Man Pages" },
    { bang = "!mdn", text = "Mozilla Developer Network Docs" },
    { bang = "!mysql", text = "MySQL" },
    { bang = "!n", text = "DuckDuckGo News" },
    { bang = "!node", text = "Node.js" },
    { bang = "!npm", text = "Node Package Manager" },
    { bang = "!postgres", text = "Postgres" },
    { bang = "!py3", text = "Python3 Docs" },
    { bang = "!python", text = "Python" },
    { bang = "!rce", text = "Rust Compiler Error" },
    { bang = "!rclippy", text = "Rust Clippy" },
    { bang = "!reddit", text = "Reddit" },
    { bang = "!rust", text = "Rust" },
    { bang = "!rustdoc", text = "Rust Docs" },
    { bang = "!spotify", text = "Spotify" },
    { bang = "!stackoverflow", text = "StackOverflow" },
    { bang = "!tldr", text = "TLDR (friendlier man-pages)" },
    { bang = "!tmg", text = "Terraform Registry" },
    { bang = "!translate", text = "Google Translate" },
    { bang = "!twitch", text = "Twitch" },
    { bang = "!typescript", text = "TypeScript Docs" },
    { bang = "!v", text = "DuckDuckGo Videos" },
    { bang = "!vimw", text = "Vim Docs" },
    { bang = "!yt", text = "YouTube" },
  }
  require("snacks").picker({
    source = "ddgr",
    title = "DDGR",
    layout = "vscode",
    finder = function()
      return vim
        .iter(ddgr_bang_list)
        :map(function(bang)
          return { text = bang.text, bang = bang.bang }
        end)
        :totable()
    end,
    format = function(item, _)
      local ret = {}
      ret[#ret + 1] = { item.bang }
      ret[#ret + 1] = { "  " }
      ret[#ret + 1] = { item.text }
      return ret
    end,
    matcher = { fuzzy = true, frecency = true },
    confirm = function(picker, item)
      picker:close()
      vim.ui.input({ prompt = string.format("Search (%s): ", item.text), default = opts.args }, function(input)
        local cmd = string.format("ddgr --noprompt --gui-browser --expand --num=5 '%s %s'", item.bang, input)
        require("snacks").terminal(cmd)
      end)
    end,
  })
end, { nargs = "*" })
