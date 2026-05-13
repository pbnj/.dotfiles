---
description: Comprehensive security review — OWASP, CVEs, containers, IaC, AI-SPM
argument-hint: "[path]"
---

# Security Review

Perform a comprehensive security review of **${1:-.}**.

Reference files (read only when relevant):

- `~/.pi/agent/skills/security-review/references/owasp-top10-2025.md` — OWASP
  Top 10 (2025) categories with detection patterns
- `~/.pi/agent/skills/security-review/references/sarif-output.md` — SARIF 2.1.0
  schema, required fields, and output templates
- `~/.pi/agent/skills/security-review/references/tool-guide.md` — Tool commands,
  install hints, and manual fallback checklists

---

## Step 0: Discover the Project

```bash
cd ${1:-.}
PROJECT_ROOT=$(pwd)

find . -maxdepth 5 \( \
  -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" \
  -o -name "*.java" -o -name "*.rb" -o -name "*.rs" -o -name "*.php" \
  -o -name "*.tf" -o -name "*.tfvars" \
  -o -name "Dockerfile*" -o -name "docker-compose*.yml" \
  -o -name "Chart.yaml" -o -name "values*.yaml" \
  -o -name "*.yaml" -o -name "*.yml" \
  -o -name "requirements*.txt" -o -name "Pipfile*" \
  -o -name "package.json" -o -name "package-lock.json" \
  -o -name "go.mod" -o -name "go.sum" \
  -o -name "Gemfile*" -o -name "Cargo.toml" \
  -o -name "pom.xml" -o -name "build.gradle" \
  -o -name "*.skill" -o -name "SKILL.md" \
  -o -name "*mcp*.json" -o -name "prompts*" \
  -o -name "system_prompt*" -o -name "*.env*" \
  \) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/vendor/*" |
  sort

mkdir -p .security-review-tmp
```

Determine which phases to run:

- **code-analysis**: always, if source files exist
- **dependency-analysis**: if package manifests or lock files found
- **container-analysis**: if `Dockerfile*` or `docker-compose*` found
- **iac-analysis**: if `.tf`, `Chart.yaml`, or Kubernetes manifests found
- **ai-spm-analysis**: if AI artifacts (models, prompts, skills, MCP servers)
  found

---

## Step 1: Spawn Parallel Sub-Agents

**Launch all applicable sub-agents in the same response** using the `task` tool
— do not wait for one to finish before starting the next. Each sub-agent writes
its findings to `.security-review-tmp/<phase>.json`:

```json
{
  "phase": "<phase-name>",
  "findings": [
    {
      "ruleId": "OWASP-A05-Injection",
      "level": "error",
      "file": "src/app.py",
      "startLine": 42,
      "message": "SQL injection via string concatenation",
      "fix": "Use parameterized queries: cursor.execute('SELECT * FROM users WHERE id=?', (uid,))",
      "owasp": "A05",
      "severity": "CRITICAL",
      "cvssScore": 9.8
    }
  ],
  "components": []
}
```

The `components` array is only used by dependency-analysis (for SBOM):

```json
{
  "name": "flask",
  "version": "2.0.1",
  "license": "BSD-3-Clause",
  "ecosystem": "pypi",
  "purl": "pkg:pypi/flask@2.0.1",
  "declaredIn": "requirements.txt",
  "vulnerabilities": ["CVE-2023-30861"]
}
```

---

### Sub-Agent: Code Analysis

```markdown
You are a security analyst performing OWASP Top 10 (2025) code analysis.

Working directory: <PROJECT_ROOT> Files to analyze: <FILE_LIST — source files
only: .py, .js, .ts, .go, .java, .rb, .rs, .php>

## Tool priority (use first available):

1. semgrep:
   `semgrep --config=p/owasp-top-ten --config=p/security-audit --config=p/secrets --json --output .security-review-tmp/semgrep.json . 2>/dev/null`
2. bandit (Python):
   `bandit -r . -f json -o .security-review-tmp/bandit.json 2>/dev/null`
3. gosec (Go):
   `gosec -fmt json -out .security-review-tmp/gosec.json ./... 2>/dev/null`
4. Manual analysis if no tools available

## OWASP Top 10 (2025) — what to look for:

**A01 — Broken Access Control** (OWASP-A01): Route handlers without permission
checks, IDOR via user-supplied IDs, path traversal, SSRF (user input in URLs
without allowlist), `Access-Control-Allow-Origin: *` on authenticated endpoints.

**A02 — Security Misconfiguration** (OWASP-A02): `DEBUG=True` in production,
default/placeholder credentials, missing security headers, stack traces exposed.

**A03 — Software Supply Chain Failures** (OWASP-A03): Dependencies pinned to
broad ranges (`^1.0.0`, `>=2.0`), missing lock files, `curl | bash` in build
scripts, CI/CD with excessive permissions.

**A04 — Cryptographic Failures** (OWASP-A04): MD5/SHA1 for passwords, hardcoded
secrets/API keys, HTTP for sensitive data, weak ciphers (DES, RC4, 3DES),
passwords without salt, `Math.random()` for security tokens.

**A05 — Injection** (OWASP-A05): SQL string concat
(`f"SELECT * FROM users WHERE name = '{name}'"`), OS command injection, template
injection (`render_template_string(user_input)`, `eval()`), XSS
(`innerHTML = user_input`, `dangerouslySetInnerHTML`).

**A06 — Insecure Design** (OWASP-A06): No rate limiting on auth/registration,
business logic allowing price manipulation, missing CSRF tokens, sensitive
operations without re-authentication.

**A07 — Authentication Failures** (OWASP-A07): Plaintext/base64 passwords, no
account lockout, non-expiring session tokens, session IDs in URLs,
weak/hardcoded JWT secrets.

**A08 — Software and Data Integrity Failures** (OWASP-A08):
`pickle.loads(user_data)`, `yaml.load()` without SafeLoader, `eval()` on
external input, auto-update without signature verification, missing SRI hashes.

**A09 — Security Logging Failures** (OWASP-A09): Auth failures not logged,
sensitive data in log statements, `except: pass` / `catch(e) {}` swallowing
errors, no structured logging on security operations.

**A10 — Mishandling of Exceptional Conditions** (OWASP-A10): Fail-open on
errors, stack traces in error responses, missing null checks, type coercion in
security checks (`null == 0`).

## Output

Write `.security-review-tmp/code-analysis.json` with the schema above. Use level
`error` for CRITICAL/HIGH, `warning` for MEDIUM, `note` for LOW/INFO. Merge tool
output with manual findings — don't duplicate; add what tools missed.
```

---

### Sub-Agent: Dependency Analysis

```markdown
You are a security analyst performing dependency vulnerability analysis and SBOM
generation.

Working directory: <PROJECT_ROOT> Manifest files: <FILE_LIST — requirements.txt,
package.json, go.mod, Gemfile, Cargo.toml, pom.xml, build.gradle, etc.>

## Tool priority (use first available):

1. trivy:
   `trivy fs --format json --output .security-review-tmp/trivy-deps.json . 2>/dev/null`
2. grype:
   `grype dir:. -o json > .security-review-tmp/grype-deps.json 2>/dev/null`
3. Language-specific fallbacks:
   - Node.js:
     `npm audit --json > .security-review-tmp/npm-audit.json 2>/dev/null`
   - Python:
     `pip-audit --format json -o .security-review-tmp/pip-audit.json 2>/dev/null`
   - Ruby:
     `bundle-audit check --format json > .security-review-tmp/bundle-audit.json 2>/dev/null`
   - Go: `govulncheck ./... 2>/dev/null`
4. Manual: parse lock files; flag packages >2 major versions behind or
   known-vulnerable (e.g., log4j < 2.17.1, lodash < 4.17.21, requests < 2.31.0)

## purl format by ecosystem:

- PyPI: `pkg:pypi/<name>@<version>`
- npm: `pkg:npm/<name>@<version>`
- Go: `pkg:golang/<module>@<version>`
- Maven: `pkg:maven/<group>/<artifact>@<version>`
- Cargo: `pkg:cargo/<name>@<version>`
- RubyGems: `pkg:gem/<name>@<version>`
- Docker: `pkg:docker/<image>@<digest>`

## Output

Write `.security-review-tmp/dependency-analysis.json` with `findings` (CVEs) and
`components` (SBOM entries) using the schema above.
```

---

### Sub-Agent: Container Analysis

(Only spawn if Dockerfile or docker-compose files were found)

```markdown
You are a security analyst performing container security analysis.

Working directory: <PROJECT_ROOT> Container files: <FILE_LIST — Dockerfile*,
docker-compose*.yml>

## Tool priority (use first available):

1. hadolint:
   `find . -name "Dockerfile*" | xargs -I{} hadolint --format json {} 2>/dev/null > .security-review-tmp/hadolint.json`
2. trivy config:
   `trivy config --format json --output .security-review-tmp/trivy-container.json . 2>/dev/null`
3. Manual review (checklist below)

## Manual Dockerfile checklist:

| Check                    | Look for                                             | ruleId | Level   |
| ------------------------ | ---------------------------------------------------- | ------ | ------- |
| Non-root user            | Missing `USER` or `USER root`                        | DS002  | error   |
| Pinned base image        | `FROM image:latest` or mutable tag                   | DS001  | warning |
| No embedded secrets      | `ENV PASSWORD=`, `ARG API_KEY=` with real values     | DS003  | error   |
| COPY not ADD             | `ADD http://...` unnecessarily                       | DS004  | warning |
| --no-install-recommends  | `apt-get install` without flag                       | DS005  | note    |
| Multi-stage build        | Single-stage with dev tools in prod image            | DS006  | warning |
| HEALTHCHECK              | No `HEALTHCHECK` directive                           | DS007  | note    |
| Minimal base image       | Full OS image vs distroless/alpine/slim              | DS008  | note    |
| No secrets in build args | `ARG` used for secrets (visible in `docker history`) | DS009  | error   |
| Capability dropping      | No `--cap-drop ALL` in docs/compose                  | DS010  | warning |

For docker-compose: check `privileged: true`, `network_mode: host`, hardcoded
secrets in `environment:`, sensitive host volume mounts (`/etc`,
`/var/run/docker.sock`).

## Output

Write `.security-review-tmp/container-analysis.json` using the schema above.
```

---

### Sub-Agent: IaC Analysis

(Only spawn if Terraform, Helm, or Kubernetes manifests were found)

```markdown
You are a security analyst performing Infrastructure-as-Code security analysis.

Working directory: <PROJECT_ROOT> IaC files: <FILE_LIST — \*.tf, Chart.yaml,
values\*.yaml, Kubernetes \*.yaml/\*.yml>

## Tool priority (use first available):

1. checkov:
   `checkov -d . --output json > .security-review-tmp/checkov.json 2>/dev/null`
2. tfsec (Terraform):
   `tfsec . --format json --out .security-review-tmp/tfsec.json 2>/dev/null`
3. kubesec (K8s):
   `find . -name "*.yaml" | xargs -I{} kubesec scan {} 2>/dev/null > .security-review-tmp/kubesec.json`
4. Manual review (checklists below)

## Terraform manual checklist:

| Resource           | Check                                                                | ruleId | Level   |
| ------------------ | -------------------------------------------------------------------- | ------ | ------- |
| aws_security_group | No ingress `cidr_blocks = ["0.0.0.0/0"]` on ports 22, 3389, DB ports | TF001  | error   |
| aws_s3_bucket      | `block_public_acls = true`, `block_public_policy = true`             | TF002  | error   |
| aws_s3_bucket      | `server_side_encryption_configuration` present                       | TF003  | warning |
| aws_db_instance    | `storage_encrypted = true`                                           | TF004  | warning |
| aws_db_instance    | `publicly_accessible = false`                                        | TF005  | error   |
| aws*iam*\*         | No wildcard `*` actions in policies                                  | TF006  | error   |
| aws_cloudtrail     | `enable_logging = true`                                              | TF007  | warning |
| Any .tf file       | No hardcoded secrets or passwords                                    | TF008  | error   |

## Kubernetes manual checklist:

| Resource           | Check                                                    | ruleId | Level   |
| ------------------ | -------------------------------------------------------- | ------ | ------- |
| Pod/Deployment     | `securityContext.runAsNonRoot: true`                     | K8S001 | error   |
| Pod/Deployment     | `securityContext.privileged: false` (or absent)          | K8S002 | error   |
| Pod/Deployment     | `securityContext.allowPrivilegeEscalation: false`        | K8S003 | warning |
| Pod/Deployment     | `resources.requests` and `resources.limits` set          | K8S004 | warning |
| Pod/Deployment     | `readOnlyRootFilesystem: true`                           | K8S005 | warning |
| Pod                | `hostNetwork: false`, `hostPID: false`, `hostIPC: false` | K8S006 | error   |
| ServiceAccount     | `automountServiceAccountToken: false` if not needed      | K8S007 | warning |
| ClusterRoleBinding | No wildcard verbs/resources in cluster-admin bindings    | K8S008 | error   |
| NetworkPolicy      | Exists and restricts ingress/egress                      | K8S009 | warning |
| Secret             | Not hardcoded in `env` as plaintext                      | K8S010 | error   |
| All containers     | No `:latest` image tags                                  | K8S011 | warning |

## Helm checklist:

- `values.schema.json` exists for input validation
- Default `values.yaml` sets `securityContext.runAsNonRoot: true`
- No hardcoded secrets — uses `existingSecret` pattern
- Image tag pinned, not `latest`
- NetworkPolicy resources created by chart

## Output

Write `.security-review-tmp/iac-analysis.json` using the schema above.
```

---

### Sub-Agent: AI-SPM Analysis

_(Only spawn if AI artifacts found: `*.skill`, `SKILL.md`, `prompts/`,
`system_prompt`, `*mcp*`, `.env` files with API keys)_

```markdown
You are performing AI Security Posture Management (AI-SPM) and BOM analysis.

Working directory: <PROJECT_ROOT> AI artifacts: <FILE_LIST — \*.skill, SKILL.md,
prompts/, system_prompt, \*mcp\*, \*model\*, \*agent\*, \*dataset\*, .env files with
API keys>

## Discovery checklist:

- `*.skill` or `SKILL.md` files (Pi skills)
- Config files with `mcpServers` or `mcp_servers`
- `system_prompt` files or `prompts/` directories
- Hardcoded API keys: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc. (Critical)
- Large datasets or knowledge bases (`.jsonl`, vectorstore)
- Agent definitions and tool/function declarations

## AI-SPM Security Checkpoints:

| Check ID   | Framework    | Description                                   | Risk     |
| ---------- | ------------ | --------------------------------------------- | -------- |
| AI-SEC-001 | OWASP LLM01  | Prompt injection surface assessment           | High     |
| AI-SEC-003 | OWASP LLM03  | Training data poisoning risk                  | High     |
| AI-SEC-006 | OWASP LLM06  | Sensitive info disclosure (PII, secrets)      | Critical |
| AI-SEC-007 | OWASP LLM07  | Insecure plugin/tool design (unbounded perms) | Critical |
| AI-SEC-008 | OWASP LLM08  | Excessive agency/tool access                  | High     |
| AI-SEC-011 | CIS AI       | Hardcoded credentials in artifact config      | Critical |
| AI-SEC-012 | CIS AI       | Unauthenticated MCP transport                 | High     |
| AI-SEC-015 | Supply Chain | Unverified third-party artifacts              | High     |
| AI-SEC-020 | CIS AI       | Missing safety controls / guardrails          | High     |

## Output

Write `.security-review-tmp/ai-spm-analysis.json` with `findings` and
`components` (type: `model|mcp_server|skill|agent|system_prompt|tool|dataset`,
trust_level: `trusted|third_party|untrusted|unknown`).
```

---

## Step 2: Aggregate Results

Once all sub-agents complete:

```bash
ls .security-review-tmp/*.json 2>/dev/null
```

Read `~/.pi/agent/skills/security-review/references/sarif-output.md` for the
full SARIF 2.1.0 template, then produce:

### File 1: `security-review.sarif.json`

One `run` per phase (`security-review/code-analysis`,
`security-review/dependency-analysis`, `security-review/container-analysis`,
`security-review/iac-analysis`, `security-review/ai-spm-analysis`). For each
finding: set `ruleId`, `message.text` (message + `"\n\nFix: "` + fix),
`locations[]` with `file://` URI + `region.startLine`, `level`, and `properties`
(`{ severity, cvssScore, owasp, fix }`). Include runs with zero findings to
document coverage.

### File 2: `ai-security-report-<date>.md`

Generated only if `ai-spm-analysis.json` contains findings or components.
Includes AI artifact inventory (AI-BOM), findings grouped by severity, and
remediation guidance.

### File 3: `sbom.sarif.json`

One run named `security-review/sbom`. Each component from dependency-analysis
becomes a result: `ruleId` = `sbom/<ecosystem>-package`, `message.text` =
`"<name>@<version> — <license>"`, `properties` =
`{ name, version, license, ecosystem, purl, vulnerabilities }`.

### Cleanup

```bash
rm -rf .security-review-tmp
```

### Summary Report

```plaintext
╔══════════════════════════════════════════════╗
║          Security Review Summary             ║
╚══════════════════════════════════════════════╝

📋 Code Analysis (OWASP Top 10 2025)
   🔴 Critical: X  🟠 High: X  🟡 Medium: X  🔵 Low: X

📦 Dependency Analysis
   X vulnerable packages (X critical CVEs, X high)
   Top CVEs: [list up to 5 most severe]

🐳 Container Analysis
   X issues found across X Dockerfile(s)

🏗️  IaC Analysis
   X misconfigurations (Terraform: X, K8s: X, Helm: X)

🧠 AI Security Posture (AI-SPM)
   X artifacts inventoried, X findings
   Report → ai-security-report-<date>.md

📄 SBOM
   X components inventoried → sbom.sarif.json

📁 Full report → security-review.sarif.json
```

---

## Tips

- Pass the discovered file list to each sub-agent — don't make them re-discover.
- Merge tool output with manual findings; don't duplicate, add what tools
  missed.
- Avoid false positives — if unsure, use `note` level and explain why.
- Every `error`-level finding needs a concrete `fix`.
- Use `file://` URIs relative to project root so SARIF is portable.
- Include runs with zero results for phases that ran clean.
