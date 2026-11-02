vim.pack.add({ "https://github.com/goropikari/sarif.nvim" })

local sarif = require("sarif")

-- sarif.nvim globs its patterns under cwd synchronously in setup(). A "**"
-- pattern walks the whole tree, which stalls startup for seconds in a parent
-- directory like ~/Projects. Give setup() top-level patterns only: it still
-- loads SARIF files in cwd, and its autocmds match any opened *.sarif file
-- by name. The recursive scan runs asynchronously below.
sarif.setup({
  patterns = { "*.sarif", "*.sarif.json" },
})

-- Rewrites relative artifact URIs to absolute paths against the SARIF file's
-- directory, so runs from several files can be merged into one document.
local function absolutize(doc, base_dir)
  for _, run in ipairs(doc.runs or {}) do
    for _, result in ipairs(run.results or {}) do
      for _, location in ipairs(result.locations or {}) do
        local artifact = location.physicalLocation
          and location.physicalLocation.artifactLocation
        local uri = artifact and artifact.uri
        if
          type(uri) == "string"
          and uri ~= ""
          and not uri:match("^%a[%w+.-]*://")
          and not uri:match("^/")
        then
          artifact.uri = vim.fs.joinpath(base_dir, uri)
        end
      end
    end
  end
end

-- Loads every SARIF file under cwd, recursively, without blocking startup.
-- sarif.load() replaces all SARIF diagnostics, so this includes the top-level
-- files setup() already loaded.
-- Only runs inside a git repository, so a parent directory of many repos
-- isn't scanned.
local function load_project_sarif()
  local cwd = vim.fn.getcwd()
  if not vim.fs.root(cwd, ".git") or vim.fn.executable("fd") == 0 then
    return
  end

  vim.system({
    "fd",
    "--type",
    "f",
    "--hidden",
    "--no-ignore",
    "--exclude",
    ".git",
    "--exclude",
    "node_modules",
    "--exclude",
    ".venv",
    "--absolute-path",
    [[\.sarif(\.json)?$]],
  }, { cwd = cwd, text = true }, function(out)
    if out.code ~= 0 or out.stdout == "" then
      return
    end

    local merged = { runs = {} }
    for _, path in ipairs(vim.split(out.stdout, "\n", { trimempty = true })) do
      local file = io.open(path, "r")
      if file then
        local ok, doc = pcall(vim.json.decode, file:read("*a"))
        file:close()
        if ok and type(doc) == "table" and type(doc.runs) == "table" then
          absolutize(doc, vim.fs.dirname(path))
          vim.list_extend(merged.runs, doc.runs)
        end
      end
    end

    if #merged.runs == 0 then
      return
    end

    vim.schedule(function()
      local tmp = vim.fn.tempname() .. ".sarif"
      vim.fn.writefile({ vim.json.encode(merged) }, tmp)
      sarif.load(tmp)
      os.remove(tmp)
    end)
  end)
end

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("SarifProjectScan", { clear = true }),
  once = true,
  callback = load_project_sarif,
})
