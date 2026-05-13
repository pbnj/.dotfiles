---
name: op-cli
description: >
  Expert guide for the 1Password CLI (`op`). Use this skill whenever the user
  asks about the `op` command, 1Password CLI, secret references (`op://`),
  injecting secrets into processes or config files, reading secrets from
  1Password vaults, managing vault items, or automating workflows that involve
  1Password. Also use this skill when the user has environment variables set to
  `op://` references and needs to run a CLI tool that depends on them — always
  wrap the command with `op run --`. Trigger on phrases like: "op command",
  "1password cli", "op run", "op read", "op inject", "secret reference", "inject
  my secrets", "read from 1password", "op://", "vault item", or anything
  involving secrets management with 1Password.
---

# 1Password CLI (`op`) Skill

You are an expert in the 1Password CLI (`op`). Help the user manage secrets,
vaults, and items — and integrate 1Password into their workflows and scripts.

---

## Secret Reference Syntax

Secret references are URIs that point to a specific field in 1Password:

```text
op://<vault>/<item>/<field>
op://<vault>/<item>/<section>/<field>
```

**Examples:**

```sh
op://Personal/Twitter/password
op://work/aws/access_key_id
op://app-prod/db/credentials/password
"op://app-prod/db/one-time password?attribute=otp"   # OTP field
"op://app-prod/ssh key/private key?ssh-format=openssh" # SSH key
```

Use item/vault names or UUIDs interchangeably. Names with spaces need quotes.

---

## Core Commands

### `op run` — Inject secrets into a process

The safest way to pass secrets to CLI tools. Resolves `op://` references in
environment variables and makes them available to the subprocess only.

```sh
# Wrap any command that needs secrets
op run -- <command>

# With an .env file containing op:// references
op run --env-file=.env -- <command>

# Example: run a script that needs DB credentials
export DB_PASSWORD="op://prod/db/password"
op run -- ./deploy.sh

# Example: pass secrets to docker
op run -- docker login -u "$DOCKER_USER" -p "$DOCKER_PASS"
```

**Key rule:** When an env var points to `op://`, always prefix with `op run --`.
Sub-shells inherit secrets from the parent `op run` — don't double-wrap:

```sh
# Good
op run -- jira issue view $(jira issue list)

# Bad — redundant inner op run
op run -- jira issue view $(op run -- jira issue list)
```

### `op read` — Read a single secret

Use when you need a single value inline:

```sh
op read op://vault/item/field

# Suppress trailing newline (useful in scripts)
op read -n op://prod/api/token

# Save to a file (e.g., a key)
op read --out-file ./key.pem op://prod/server/ssh/private_key

# Inline in a command
docker login -u $(op read op://prod/docker/username) \
             -p $(op read op://prod/docker/password)
```

### `op inject` — Template a config file

Replace `{{ op://... }}` placeholders in config templates:

```sh
# From stdin
echo "db_password: {{ op://prod/db/password }}" | op inject

# From file to file
op inject -i config.yml.tpl -o config.yml

# Multiple secrets in one template
# config.yml.tpl:
#   db_url: postgres://{{ op://prod/db/user }}:{{ op://prod/db/pass }}@{{ op://prod/db/host }}/mydb
op inject -i config.yml.tpl -o config.yml

# Parameterize with env vars
echo "db_password: op://$ENV/db/password" | env ENV=prod op inject
```

> Always delete resolved config files (`config.yml`) when done — they contain
> plaintext secrets.

---

## Item Management

### List and search items

```sh
op item list
op item list --vault MyVault
op item list --categories Login
op item list --tags production
op item list --tags production --format json | op item get -
```

### Get item details

```sh
op item get Netflix
op item get Netflix --fields label=username,label=password
op item get Netflix --fields label=username,label=password --format json
op item get <item-id>                     # by UUID
op item get Netflix --vault Personal
```

### Create an item

```sh
# Interactive (prompts for fields)
op item create --category login --title "My App" --vault Personal

# From a template
op item template get Login | op item create --stdin
```

### Edit an item

```sh
op item edit Netflix username=newuser@example.com
op item edit "AWS Production" access_key_id=AKIANEWKEY
```

### Delete / archive

```sh
op item delete Netflix             # archives by default
op item delete Netflix --archive   # explicitly archive
```

---

## Vault Management

```sh
op vault list
op vault get MyVault
op vault create "New Vault"
op vault delete "Old Vault"
```

---

## Authentication

```sh
# Sign in (if app integration is off)
op signin

# Check current session
op whoami

# Sign out
op signout

# Multi-account: specify account
op --account my.1password.com item list
```

### Service Accounts (for automation/CI)

Use service accounts in scripts, CI/CD, and cron jobs — they're scoped to
specific vaults and don't require interactive login:

```sh
export OP_SERVICE_ACCOUNT_TOKEN="ops_..."
op run -- ./my-script.sh
```

---

## `.env` File Integration

Create an `.env` file with `op://` references instead of plaintext secrets:

```sh
# .env
DATABASE_URL=op://prod/db/connection_string
API_KEY=op://prod/myservice/api_key
AWS_ACCESS_KEY_ID=op://prod/aws/access_key_id
AWS_SECRET_ACCESS_KEY=op://prod/aws/secret_access_key
```

Then run any tool with secrets injected:

```sh
op run --env-file=.env -- npm start
op run --env-file=.env -- python app.py
op run --env-file=.env -- terraform apply
```

Commit the `.env` file safely — it contains only references, not secrets.

---

## Output Formats

Most commands support `--format json` for scripting:

```sh
op item list --format json
op item get Netflix --format json
op vault list --format json
```

Use `--format json | jq` for complex queries:

```sh
op item list --format json | jq '.[].title'
op item get Netflix --format json | jq '.fields[] | select(.label=="password") | .value'
```

---

## Common Patterns

### Use secrets in a shell script

```sh
#!/usr/bin/env bash
# At the top of your script, ensure it runs via op run
# Call it as: op run -- ./my-script.sh
# Then access secrets as normal env vars:
echo "Connecting to $DB_HOST as $DB_USER..."
psql "$DATABASE_URL"
```

### Rotate a secret

```sh
NEW_KEY=$(generate-new-api-key)
op item edit "My Service" api_key="$NEW_KEY"
```

### Copy an item between vaults

```sh
op item move "My Login" --current-vault Personal --destination-vault Work
```

### Share an item

```sh
op item share Netflix --expiry 7d --emails colleague@example.com
```

---

## Flags Reference

| Flag                    | Description                                     |
| ----------------------- | ----------------------------------------------- |
| `--vault <name>`        | Scope to a specific vault                       |
| `--account <shorthand>` | Use a specific account                          |
| `--format json`         | Machine-readable JSON output                    |
| `--no-newline`          | Suppress trailing newline (useful in scripts)   |
| `--no-masking`          | Show secrets in `op run` stdout (use carefully) |
| `--env-file <file>`     | Load `.env` file for `op run`                   |
| `--out-file <path>`     | Write output to file instead of stdout          |

---

## Security Best Practices

- Never hardcode secrets — always use `op://` references or `op run`
- Use service accounts with minimal vault access for automation
- Prefer `op run --` over `op read` in scripts (secrets never touch disk/shell
  history)
- Delete resolved config files (`op inject` output) immediately after use
- Commit `.env` files with `op://` references — they're safe to version-control
- Don't store secrets in shell history; use `op run -- sh -c '...'` patterns
