# glean-chat

pi extension providing Glean AI access via `@gleanwork/api-client`.

## Setup

```bash
cd ~/.pi/agent/extensions/glean-chat
npm install
```

Set the backend URL (shell profile):

```bash
export GLEAN_BACKEND_URL="https://mycompany-be.glean.com"
```

Store the API token via pi (persisted as `glean.key` in
`~/.pi/agent/auth.json`):

```plaintext
/login
# select glean, paste your Glean Client API token
```

Alternatively export `GLEAN_API_TOKEN` (e.g. via 1Password: set it to an `op://`
reference and launch with `op run -- pi`).

## Tests

```bash
npm test
```

Unit tests (`index.test.ts`) run with the built-in Node test runner (Node >=
23.6 for native type stripping). They cover request building (most-recent-first
ordering, author mapping, merging, context stripping) and ND-JSON stream parsing
(fragment reassembly per messageId, thinking/text interleaving, citations,
errors, abort) against a mock Glean backend.

## Environment variables

| Variable                     | Required | Description                                                               |
| ---------------------------- | -------- | ------------------------------------------------------------------------- |
| `GLEAN_BACKEND_URL`          | one of   | Full backend URL, e.g. `https://mycompany-be.glean.com`                   |
| `GLEAN_INSTANCE`             | one of   | Instance name, e.g. `mycompany` — used when `GLEAN_BACKEND_URL` is absent |
| `GLEAN_API_TOKEN`            | no       | Glean Client API token — overrides the token stored in `auth.json`        |
| `GLEAN_ENABLE_MODEL_SURFACE` | no       | Set to `0` to disable the provider/model surface                          |

## Surfaces

### Tool: `glean_chat`

The LLM can call `glean_chat` to answer questions about internal knowledge.
Conversations are threaded — follow-up calls continue the same Glean chat
session via `chatId`. Pass `new_conversation: true` to start a fresh thread.

The tool's `promptGuidelines` instruct the model to use it for internal docs,
runbooks, policies, ADRs, Jira tickets, and Confluence pages.

### Command: `/glean <question>`

Direct query without an LLM round-trip. The answer is injected as a displayed
session message so subsequent LLM turns can reference it.

```plaintext
/glean what is our PTO policy?
/glean --new what does the incident runbook say about P0 escalation?
```

`--new` clears the current `chatId` and starts a fresh conversation thread.

### Model: `glean / Glean Assistant`

Selectable via `Ctrl+P` or `/model`. Routes the active conversation through
Glean Chat instead of a normal LLM. Registered only when `GLEAN_BACKEND_URL` or
`GLEAN_INSTANCE` is set at startup.

Streaming is real: the provider calls `/rest/api/v1/chat` with `stream: true`
and parses ND-JSON lines as they arrive. Glean `UPDATE`/`HEADING` progress
messages render as thinking blocks; `CONTENT` messages stream as text; citations
are appended as a Sources block.

**Limitations — read before using:**

- **No tool calling.** Glean returns prose + citations only. This model cannot
  run `bash`, `read`, `edit`, or any other tool. Do not use it for coding tasks.
- **Context is stripped.** pi's system prompt, tool schemas, and tool-result
  messages are dropped. Only user/assistant text turns reach Glean.
- **No token accounting.** Glean returns no usage data; cost tracking stays
  zero.

Disable with `GLEAN_ENABLE_MODEL_SURFACE=0` if you want only the tool/command
surfaces.

## Conversation threading

`chatId` is tracked in extension memory and persisted via `pi.appendEntry` so
the thread survives `/reload`. It is shared between the tool and the `/glean`
command. The provider (model) surface does not use `chatId` — it forwards the
full conversation history to Glean on every turn.

## Token source

The token is resolved from `~/.pi/agent/auth.json` (`glean.key`, managed by pi's
`/login`) or the `GLEAN_API_TOKEN` env var. For the tool and command, env takes
precedence over `auth.json`. For the model surface, pi's auth storage takes
precedence and passes the token via `options.apiKey`, with `$GLEAN_API_TOKEN` as
the declared fallback.
