# Pi-specific instructions

## Arbitrary Python: use codemode

- When writing and executing ad hoc Python (data processing, HTTP fetching,
  HTML-to-Markdown conversion, inspection, or other one-off automation), use
  Pi's `codemode` tool. Do not invoke the Bash tool directly to run that Python.
- Codemode runs JavaScript in QuickJS, not Python, and has no direct filesystem,
  network, Node APIs, or package imports. Execute Python through
  `await tools.bash(...)` inside codemode; do not try to run Python as the
  codemode script itself.
- This applies to Python heredocs, `python -c` / `python3 -c`, temporary
  scripts, and Python commands launched through `uv` or `uvx`. Use `python3` for
  standalone scripts, or the project's Python environment when needed.
- For persistent Python files, use `tools.write` for new files and `tools.edit`
  for targeted changes, then execute through `tools.bash`, all called from
  codemode. Do not use shell redirection to create source files.
- Check `exit_code` before treating a run as successful. Filter or summarize
  output in codemode before returning it to the model; do not expose secrets or
  sensitive data.
- Use existing open-source libraries where useful. For one-off dependencies,
  prefer an isolated `uv run --no-project --with <package> python ...`
  invocation rather than changing project dependencies.
- This is a tool-routing preference, not an execution sandbox or permission
  bypass: Python run through `tools.bash` has the same permissions and side
  effects as a direct Bash call. Preserve all safety and approval requirements.
  If codemode is unavailable, explain that before falling back.

Example codemode script:

```js
const result = await tools.bash({
  command: "python3 - <<'PY'\nimport json\nprint(json.dumps({'ok': True}))\nPY",
  timeout: 30,
});
if (result.exit_code !== 0) {
  throw new Error(`Python failed (${result.exit_code}): ${result.output}`);
}
text(JSON.parse(result.output));
```
