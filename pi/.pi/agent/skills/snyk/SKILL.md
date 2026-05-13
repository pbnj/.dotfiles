---
name: snyk
description:
  "Interact with the Snyk REST API (v2025-11-05) for vulnerability management,
  security scanning, and developer security. Use for: listing
  orgs/projects/targets, querying issues (package vulnerabilities, licenses,
  cloud misconfigs, SAST), searching audit logs, managing service accounts,
  memberships, invitations, fetching SBOMs, and looking up package
  vulnerabilities by PURL. Requires SNYK_TOKEN injected via 1Password `op run`."
---

# Snyk REST API Skill

Interact with the [Snyk REST API](https://api.snyk.io/rest) (`v2025-11-05`) for
security automation tasks.

## Prerequisites

- `uv` installed (`brew install uv`)
- `op` (1Password CLI) installed and authenticated
  (`brew install 1password-cli`)
- `SNYK_TOKEN` & `SNYK_ORG` stored in 1Password; the `op run` prefix injects
  them automatically

## Authentication

All scripts use `SNYK_TOKEN` (injected by 1Password):

```bash
op run -- uv run scripts/ [args] <script >.py
```

**Base URL:** `https://api.snyk.io/rest` **Required header:**
`Authorization: token $SNYK_TOKEN` **Required query param:**
`version=2025-11-05` (already set in all scripts)

---

## Scripts

All scripts live in `scripts/` relative to this skill directory.

---

### whoami.py — Current user info

```bash
# Show current user details
op run -- uv run scripts/whoami.py

# Include personal access tokens
op run -- uv run scripts/whoami.py --tokens

# Raw JSON
op run -- uv run scripts/whoami.py --json
```

---

### list_orgs.py — List organizations

```bash
# All accessible orgs
op run -- uv run scripts/list_orgs.py

# Filter by group
op run -- uv run scripts/list_orgs.py --group-id GROUP_UUID

# Filter by name (substring)
op run -- uv run scripts/list_orgs.py --name "security"

# Filter by exact slug
op run -- uv run scripts/list_orgs.py --slug "my-org-slug"

# Raw JSON (pipe-friendly)
op run -- uv run scripts/list_orgs.py --json
```

---

### list_projects.py — List projects in an org

```bash
# All projects in an org
op run -- uv run scripts/list_projects.py --org-id ORG_UUID

# Filter by origin (github, cli, bitbucket-cloud, etc.)
op run -- uv run scripts/list_projects.py --org-id ORG_UUID --origin github

# Filter by type (npm, pip, maven, gradle, etc.)
op run -- uv run scripts/list_projects.py --org-id ORG_UUID --type npm

# Include latest issue counts in output
op run -- uv run scripts/list_projects.py --org-id ORG_UUID --with-counts

# Filter by tag
op run -- uv run scripts/list_projects.py --org-id ORG_UUID --tag "team=security"

# Filter by lifecycle
op run -- uv run scripts/list_projects.py --org-id ORG_UUID --lifecycle production
```

---

### list_issues.py — List vulnerability/security issues

Issues can be scoped to an org or a group. Supports full pagination and rich
filtering.

```bash
# All issues in an org
op run -- uv run scripts/list_issues.py --org-id ORG_UUID

# Critical and high package vulnerabilities only
op run -- uv run scripts/list_issues.py \
        --org-id ORG_UUID \
        --type package_vulnerability \
        --severity critical \
        --severity high

# Issues for a specific project
op run -- uv run scripts/list_issues.py \
        --org-id ORG_UUID \
        --scan-item-id PROJECT_UUID \
        --scan-item-type project

# Issues created after a date
op run -- uv run scripts/list_issues.py \
        --org-id ORG_UUID \
        --created-after 2024-01-01T00:00:00Z

# Only non-ignored issues
op run -- uv run scripts/list_issues.py --org-id ORG_UUID --not-ignored

# Group-scoped issues
op run -- uv run scripts/list_issues.py --group-id GROUP_UUID --severity critical

# Limit results
op run -- uv run scripts/list_issues.py --org-id ORG_UUID --max-results 50

# Issue types:
#   package_vulnerability, license, cloud, code, custom, config
```

---

### list_targets.py — List targets in an org

Targets are repositories/images/etc. that Snyk monitors.

```bash
# All targets
op run -- uv run scripts/list_targets.py --org-id ORG_UUID

# Only targets with projects
op run -- uv run scripts/list_targets.py --org-id ORG_UUID --exclude-empty

# Filter by URL
op run -- uv run scripts/list_targets.py --org-id ORG_UUID --url "https://github.com/myorg/myrepo"

# Filter by display name prefix
op run -- uv run scripts/list_targets.py --org-id ORG_UUID --display-name "my-service"

# Filter by source type
op run -- uv run scripts/list_targets.py --org-id ORG_UUID --source-type github
```

---

### audit_logs.py — Search audit logs

```bash
# Search org audit logs (defaults to yesterday)
op run -- uv run scripts/audit_logs.py --org-id ORG_UUID

# Date range
op run -- uv run scripts/audit_logs.py \
        --org-id ORG_UUID \
        --from 2024-01-01T00:00:00Z \
        --to 2024-02-01T00:00:00Z

# Filter by user
op run -- uv run scripts/audit_logs.py --org-id ORG_UUID --user-id USER_UUID

# Filter by event type
op run -- uv run scripts/audit_logs.py --org-id ORG_UUID --event "org.user.invite.sent"

# Exclude event types
op run -- uv run scripts/audit_logs.py --org-id ORG_UUID --exclude-event "api.access"

# Group-level audit logs
op run -- uv run scripts/audit_logs.py --group-id GROUP_UUID

# Limit results
op run -- uv run scripts/audit_logs.py --org-id ORG_UUID --max-results 200
```

---

### package_issues.py — Issues for a specific package (PURL)

Look up known vulnerabilities for a package version by
[Package URL (PURL)](https://github.com/package-url/purl-spec).

```bash
# npm package
op run -- uv run scripts/package_issues.py \
        --org-id ORG_UUID \
        --purl "pkg:npm/lodash@4.17.21"

# Python package
op run -- uv run scripts/package_issues.py \
        --org-id ORG_UUID \
        --purl "pkg:pypi/requests@2.31.0"

# Maven package
op run -- uv run scripts/package_issues.py \
        --org-id ORG_UUID \
        --purl "pkg:maven/org.apache.logging.log4j/log4j-core@2.14.1"

# Go module
op run -- uv run scripts/package_issues.py \
        --org-id ORG_UUID \
        --purl "pkg:golang/github.com/gin-gonic/gin@v1.9.0"
```

Supported ecosystems: `npm`, `pypi`, `maven`, `nuget`, `golang`

---

### get_sbom.py — Get project SBOM

```bash
# CycloneDX 1.6 JSON (default)
op run -- uv run scripts/get_sbom.py \
        --org-id ORG_UUID \
        --project-id PROJECT_UUID

# Save to file
op run -- uv run scripts/get_sbom.py \
        --org-id ORG_UUID \
        --project-id PROJECT_UUID \
        --output sbom.json

# SPDX 2.3 JSON
op run -- uv run scripts/get_sbom.py \
        --org-id ORG_UUID \
        --project-id PROJECT_UUID \
        --format spdx2.3+json \
        --output sbom-spdx.json
```

**Supported formats:**

- `cyclonedx1.6+json` _(default)_
- `cyclonedx1.6+xml`
- `cyclonedx1.5+json` / `cyclonedx1.5+xml`
- `cyclonedx1.4+json` / `cyclonedx1.4+xml`
- `spdx2.3+json`

---

### service_accounts.py — Manage service accounts

```bash
# List service accounts in an org
op run -- uv run scripts/service_accounts.py list --org-id ORG_UUID

# List service accounts in a group
op run -- uv run scripts/service_accounts.py list --group-id GROUP_UUID

# Get a specific service account
op run -- uv run scripts/service_accounts.py get \
        --org-id ORG_UUID --sa-id SA_UUID

# Create a new service account
op run -- uv run scripts/service_accounts.py create \
        --org-id ORG_UUID \
        --name "my-ci-bot" \
        --role-id ROLE_UUID

# Delete a service account
op run -- uv run scripts/service_accounts.py delete \
        --org-id ORG_UUID --sa-id SA_UUID

# Rotate a service account's client secret
op run -- uv run scripts/service_accounts.py rotate \
        --org-id ORG_UUID --sa-id SA_UUID
```

> ⚠ Client secrets are shown **once** on creation/rotation. Save them
> immediately.

---

### memberships.py — Manage org/group memberships and invitations

```bash
# List org memberships
op run -- uv run scripts/memberships.py list-org --org-id ORG_UUID

# List group memberships
op run -- uv run scripts/memberships.py list-group --group-id GROUP_UUID

# Invite a user to an org
op run -- uv run scripts/memberships.py invite \
        --org-id ORG_UUID \
        --email user@example.com \
        --role collaborator

# Cancel a pending invite
op run -- uv run scripts/memberships.py cancel-invite \
        --org-id ORG_UUID \
        --invite-id INVITE_UUID
```

---

## Direct curl / API calls

For endpoints not covered by scripts, call the API directly:

```bash
# List groups
op run -- sh -c 'curl -s -H "Authorization: token $SNYK_TOKEN" \
  "https://api.snyk.io/rest/groups?version=2025-11-05" | jq .'

# Get a single org
op run -- sh -c 'curl -s -H "Authorization: token $SNYK_TOKEN" \
  "https://api.snyk.io/rest/orgs/ORG_UUID?version=2025-11-05" | jq .'

# Get IaC settings for an org
op run -- sh -c 'curl -s -H "Authorization: token $SNYK_TOKEN" \
  "https://api.snyk.io/rest/orgs/ORG_UUID/settings/iac?version=2025-11-05" | jq .'

# Get SAST settings
op run -- sh -c 'curl -s -H "Authorization: token $SNYK_TOKEN" \
  "https://api.snyk.io/rest/orgs/ORG_UUID/settings/sast?version=2025-11-05" | jq .'
```

---

## API Reference

**Base URL:** `https://api.snyk.io/rest`  
**API Version:** `2025-11-05` (default; supports `experimental`, `beta`,
date-based versions)

### Pagination

All list endpoints use cursor-based pagination via `links.next` in the response.
The scripts handle this automatically. Manual pagination:

```python
params = {"version": "2025-11-05", "limit": 100}
# After first response: use links.next URL for next page
# Stop when links.next is absent
```

### Key Resource Hierarchy

```plaintext
Tenant
└── Group(s)
    └── Organization(s)
        ├── Projects        (monitored manifests/repos)
        ├── Targets         (source repos/images)
        ├── Issues          (vulnerabilities, licenses, cloud, SAST)
        ├── Service Accounts
        └── Members / Invites
```

### Common Path Parameters

| Parameter    | Description       |
| ------------ | ----------------- |
| `org_id`     | Organization UUID |
| `group_id`   | Group UUID        |
| `tenant_id`  | Tenant UUID       |
| `project_id` | Project UUID      |
| `target_id`  | Target UUID       |
| `issue_id`   | Issue UUID        |

### Issue Types

| Type                    | Description                     |
| ----------------------- | ------------------------------- |
| `package_vulnerability` | Known CVEs in open source deps  |
| `license`               | License policy violations       |
| `cloud`                 | Cloud misconfiguration findings |
| `code`                  | SAST (Snyk Code) findings       |
| `custom`                | Custom rules                    |
| `config`                | IaC misconfigurations           |

### Severity Levels

`critical` → `high` → `medium` → `low` → `info`

### Project Origins

`github`, `github-enterprise`, `gitlab`, `bitbucket-cloud`, `bitbucket-server`,
`azure-repos`, `cli`, `api`, `ecr`, `docker-hub`, `acr`, `gcr`,
`artifactory-cr`, `harbor-cr`, `quay-cr`
