---
name: subagent
description: >
  Spawn AI subagents (claude, pi, copilot) in a new tmux window. Trigger on
  requests containing 'subagent', 'spawn', 'spin up', or 'spin out'. Use weight
  keywords (heavy/medium/light) for preset agent/model/effort/yolo combos, or
  specify explicit agent + model + effort + yolo options.
metadata:
  author: Peter Benjamin
  version: 0.1.0
user-invocable: true
---

# Subagent Skill

Spawn an AI agent as a detached interactive session in a new tmux window.

## How to use

When the user asks for a subagent, parse the request into:

1. **Agent** — `claude`, `pi`, or `copilot` (`copilot` maps to `pi`).
2. **Model** — model name/alias to pass to `--model`.
3. **Effort** — optional `low`, `medium`, `high`, `xhigh`, `max` for `--effort`.
4. **Yolo mode** — if the user mentions `yolo` or
   `dangerously-skip-permissions`, add `--dangerously-skip-permissions`.
5. **CWD** — default `~/Projects/github.com/komodohealth/`, or the current
   working directory if another is not implied.
6. **Prompt** — the actual task, usually after `to`, `for`, or the main verb.

Then run:

```bash
./scripts/spawn.py \
  --agent <claude|pi|copilot> \
  --model <model> \
  [--effort <level>] \
  [--yolo] \
  --cwd <path> \
  --prompt "<task>"
```

## Preset weight tiers

Use these defaults when the user gives a weight keyword without explicit
agent/model/effort:

| Weight   | Agent    | Model                         | Effort   | Yolo |
| -------- | -------- | ----------------------------- | -------- | ---- |
| `heavy`  | `claude` | `opus`                        | `medium` | yes  |
| `medium` | `pi`     | `github-copilot/kimi-k2.7`    | —        | no   |
| `light`  | `pi`     | `github-copilot/gpt-5.4-mini` | —        | no   |

## Examples

### Weight-based

- **User:** `spin up a heavy subagent to do xyz`
  - **Command:**
    `./scripts/spawn.py --agent claude --model opus --effort medium --yolo --cwd ~/Projects/github.com/komodohealth/ --prompt "do xyz"`
  - **Result:** `tmux` window running
    `claude --model opus --effort medium --dangerously-skip-permissions "do xyz"`

- **User:** `spawn a light subagent to do foobar`
  - **Command:**
    `./scripts/spawn.py --agent pi --model github-copilot/gpt-5.4-mini --cwd ~/Projects/github.com/komodohealth/ --prompt "do foobar"`
  - **Result:** `tmux` window running
    `pi --model github-copilot/gpt-5.4-mini "do foobar"`

### Explicit agent/model/effort/yolo

- **User:**
  `spin up a claude subagent with sonnet 5 and high reasoning in yolo mode to develop a new feature`
  - **Command:**
    `./scripts/spawn.py --agent claude --model sonnet-5 --effort high --yolo --cwd ~/Projects/github.com/komodohealth/ --prompt "develop a new feature"`
  - **Result:** `tmux` window running
    `claude --model sonnet-5 --effort high --dangerously-skip-permissions "develop a new feature"`

## Notes

- Window name is derived from the first word of the prompt (sanitized).
- The script lives at `./scripts/spawn.py` relative to this skill directory.
- Always quote the prompt argument to avoid whitespace issues.
