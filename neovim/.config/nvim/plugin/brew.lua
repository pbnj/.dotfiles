vim.keymap.set({ "t", "n", "i" }, "<c-\\><c-u>", function()
  vim.cmd("tabnew")
  vim.fn.jobstart({
    "bash",
    "-lc",
    [=[
echo "Checking brew..."
BREW="arch -arm64 brew"
${BREW} update
BREW_OUTDATED="$(${BREW} outdated)"
if [[ -n "${BREW_OUTDATED}" ]]; then
  ${BREW} upgrade --yes
  ${BREW} cleanup --prune=all
fi
]=],
  }, { term = true })
end, { desc = "Terminal: Update homebrew packages" })
