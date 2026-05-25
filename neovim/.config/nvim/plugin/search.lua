-- search.lua
-- Interactive web search.
--
-- :Search [-n <num>] [-w <site>] [query]
--
-- SearXNG is tried first; falls back to DuckDuckGo via an inline ddgs script
-- when SearXNG is unreachable.
-- Page content is fetched with playwright via `uv run` and opened in a split.

local SEARXNG_URL = (vim.env.SEARXNG_URL or "http://localhost:8888"):gsub(
  "/$",
  ""
)

-- Passed verbatim to `uv run --with ddgs python -c`.
-- Query parameters are injected via environment variables.
local DDGS_SCRIPT = [[
import json, os, sys
from ddgs import DDGS

results = list(DDGS().text(
    os.environ["DDGS_QUERY"],
    region=os.environ.get("DDGS_REGION", "wt-wt"),
    safesearch="moderate",
    max_results=int(os.environ.get("DDGS_NUM", "10")),
))
sys.stdout.write(json.dumps([
    {"title": r.get("title", ""), "href": r.get("href", ""), "body": r.get("body", "")}
    for r in results
]))
]]

-- Passed verbatim to `uv run --with playwright --with html2text python -c`.
-- The target URL is injected through CRAWL_URL to avoid shell-quoting issues.
-- Uses a headless Chromium browser so JS-rendered pages are fully evaluated.
local CRAWL_SCRIPT = [[
import asyncio, os, sys
from playwright.async_api import async_playwright
import html2text

async def main():
    url = os.environ["CRAWL_URL"]
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        page = await browser.new_page()
        await page.goto(url, wait_until="load", timeout=30000)
        await page.wait_for_timeout(2000)
        html = await page.content()
        await browser.close()
    h = html2text.HTML2Text()
    h.ignore_links = False
    h.body_width = 0
    sys.stdout.write(h.handle(html))

asyncio.run(main())
]]

local function url_encode(s)
  return (
    s:gsub("([^%w%-_%.~])", function(c)
      return ("%%%02X"):format(c:byte())
    end)
  )
end

local function build_searxng_url(query, opts)
  return ("%s/search?q=%s&format=json&language=%s&safesearch=1&pageno=%d"):format(
    SEARXNG_URL,
    url_encode(query),
    opts.region or "wt-wt",
    opts.page or 1
  )
end

-- Async search. cb(err, results) is always invoked via vim.schedule.
local function search(query, opts, cb)
  vim.net.request(build_searxng_url(query, opts), {}, function(err, res)
    if err then
      -- SearXNG unreachable: fall back to DuckDuckGo via inline ddgs script.
      -- Results are written as a JSON array to stdout.
      vim.schedule(function()
        vim.notify(
          "SearXNG unavailable, falling back to DuckDuckGo…",
          vim.log.levels.WARN
        )
        local out = {}
        vim.fn.jobstart(
          { "uv", "run", "--with", "ddgs", "python", "-c", DDGS_SCRIPT },
          {
            env = vim.tbl_extend("force", vim.fn.environ(), {
              DDGS_QUERY = query,
              DDGS_NUM = tostring(opts.num or 10),
              DDGS_REGION = opts.region or "wt-wt",
            }),
            stdout_buffered = true,
            on_stdout = function(_, data)
              vim.list_extend(out, data)
            end,
            on_exit = function(_, code)
              vim.schedule(function()
                if code ~= 0 then
                  cb("DDG fallback failed (exit " .. code .. ")", nil)
                  return
                end
                local ok, parsed =
                  pcall(vim.json.decode, table.concat(out, "\n"))
                if ok and type(parsed) == "table" then
                  cb(nil, parsed)
                else
                  cb("Failed to parse DDG output", nil)
                end
              end)
            end,
          }
        )
      end)
      return
    end

    local ok, data = pcall(vim.json.decode, res.body)
    if not ok then
      vim.schedule(function()
        cb("JSON parse error: " .. tostring(data), nil)
      end)
      return
    end

    local num = opts.num or 10
    local results = {}
    for i, r in ipairs(data.results or {}) do
      if i > num then
        break
      end
      table.insert(results, {
        title = r.title or "",
        href = r.url or "",
        body = r.content or "",
      })
    end
    vim.schedule(function()
      cb(nil, results)
    end)
  end)
end

-- Fetch URL with playwright and open the resulting markdown in a new split.
local function fetch_and_view(href, title)
  local label = title ~= "" and title or href
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_name(buf, "search://" .. href)
  vim.api.nvim_buf_set_lines(
    buf,
    0,
    -1,
    false,
    { "# " .. label, "", href, "", "Fetching…" }
  )
  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, buf)

  local lines = {}
  vim.fn.jobstart({
    "uv",
    "run",
    "--with",
    "playwright",
    "--with",
    "html2text",
    "python",
    "-c",
    CRAWL_SCRIPT,
  }, {
    env = vim.tbl_extend("force", vim.fn.environ(), { CRAWL_URL = href }),
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      vim.list_extend(lines, data)
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        local content = { "# " .. label, "", href, "" }
        if code == 0 and #lines > 0 then
          while lines[#lines] == "" do
            lines[#lines] = nil
          end
          vim.list_extend(content, lines)
        else
          table.insert(content, "*(fetch failed — exit code " .. code .. ")*")
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
      end)
    end,
  })
end

-- Main interactive loop.
local function interactive(query, opts)
  opts = vim.tbl_extend("keep", opts or {}, { num = 10, region = "wt-wt" })

  local function run(page)
    opts.page = page
    vim.notify(
      ('Searching "%s" [page %d]…'):format(query, page),
      vim.log.levels.INFO
    )

    search(query, opts, function(err, results)
      if err then
        vim.notify("Search error: " .. err, vim.log.levels.ERROR)
        return
      end
      if not results or #results == 0 then
        vim.notify("No results for: " .. query, vim.log.levels.WARN)
        return
      end

      local items = vim.list_extend(vim.list_slice(results), {
        { title = "» Next page", _nav = "next" },
        { title = "« Prev page", _nav = "prev" },
      })

      vim.ui.select(items, {
        prompt = ('Search: "%s"  [page %d]'):format(query, page),
        format_item = function(item)
          return item.title ~= "" and item.title or "(no title)"
        end,
      }, function(item)
        if not item then
          return
        end
        if item._nav == "next" then
          run(page + 1)
        elseif item._nav == "prev" then
          run(math.max(1, page - 1))
        else
          vim.ui.select(
            { "View content in buffer", "Open in browser", "Back to results" },
            { prompt = item.title .. "  —  " .. item.href },
            function(action)
              if not action then
                return
              end
              if action == "View content in buffer" then
                fetch_and_view(item.href, item.title)
              elseif action == "Open in browser" then
                vim.ui.open(item.href)
              elseif action == "Back to results" then
                run(page)
              end
            end
          )
        end
      end)
    end)
  end

  run(1)
end

vim.api.nvim_create_user_command("Search", function(cmd_opts)
  local args = table.concat(cmd_opts.fargs, " ")
  local opts = {}

  -- Strip inline flags: -n <num>, -w <site>
  args = args
    :gsub("%-n%s+(%d+)", function(n)
      opts.num = tonumber(n)
      return ""
    end)
    :gsub("%-w%s+(%S+)", function(w)
      opts.site = w
      return ""
    end)
    :gsub("^%s+", "")
    :gsub("%s+$", "")

  local function start(query)
    if not query or query == "" then
      return
    end
    if opts.site then
      query = "site:" .. opts.site .. " " .. query
    end
    interactive(query, opts)
  end

  if args ~= "" then
    start(args)
  else
    vim.ui.input({ prompt = "Search: " }, start)
  end
end, {
  desc = "Interactive web search  :Search [-n num] [-w site] [query]",
  nargs = "*",
})
