---
name: nuclei
description: >
  Security testing skill for Nuclei — a fast, template-driven vulnerability
  scanner by ProjectDiscovery. Use this skill to: scan URLs, APIs, or OpenAPI
  specs for vulnerabilities; run or write nuclei YAML templates and workflows;
  generate templates from a STRIDE threat model report; or run a full pipeline
  (threat model → templates → scan). Triggers on: "run nuclei", "scan this URL",
  "nuclei template", "nuclei workflow", "nuclei from threat model", "web app
  security scan", "pen test this API", "full security pipeline", "threat model
  and scan", SQLi, XSS, SSRF, IDOR, auth bypass, CORS misconfig. Use proactively
  when the user shares a URL, OpenAPI spec, source code, or STRIDE report and
  wants security testing — even if they haven't mentioned nuclei by name.
metadata:
  author: Peter Benjamin
  version: 1.0.0
  nuclei-version: ">=3.0.0"
allowed-tools: Bash
---

# Nuclei Security Testing Skill

Nuclei (v3+) is a fast, declarative vulnerability scanner driven by community
YAML templates. This skill covers three modes:

1. **Scan** — Run nuclei against URLs, URL lists, or OpenAPI/Swagger specs and
   produce actionable reports (SARIF, JSON, Markdown).
2. **Generate** — Create custom nuclei YAML templates and workflows from a
   STRIDE threat model report, then validate and run them.
3. **Full pipeline** — Invoke the `threat-model` skill to produce a STRIDE
   report from source code or an architecture description, then automatically
   generate templates (Mode 2) and scan (Mode 1) — all in one go.

---

## Quick-start decision tree

```text
User has a URL / API only?               → Mode 1: Scan
User has a STRIDE report + URL?          → Mode 2: Generate templates → Mode 1: Scan
User has source code / architecture?     → Mode 3: Full pipeline
  → threat-model skill  (generates STRIDE report)
  → Mode 2              (generates nuclei templates + workflow)
  → Mode 1              (runs nuclei, produces SARIF + JSON report)
```

---

## Mode 1 — Running Nuclei Scans

### 1a. Scan a single URL (default templates)

```bash
nuclei -u https://example.com -j -o results.jsonl
```

### 1b. Scan a list of URLs

```bash
nuclei -l targets.txt -j -o results.jsonl
```

### 1c. Scan an OpenAPI / Swagger spec

Nuclei natively understands OpenAPI 3.x and Swagger 2.x YAML/JSON. It
auto-generates requests for every endpoint + method defined in the spec.

```bash
nuclei -l openapi.yaml -im openapi -j -o results.jsonl
```

### 1d. Filter by severity and tags

Run only HIGH and CRITICAL, web-focused templates:

```bash
nuclei -u https://example.com \
  -severity high,critical \
  -tags xss,sqli,ssrf,idor,auth,lfi,rce \
  -j -o results.jsonl
```

### 1e. Run custom templates (generated or local)

```bash
nuclei -u https://example.com \
  -t ./.nuclei/templates/ \
  -validate     # always validate first
```

### 1f. Run a workflow

```bash
nuclei -u https://example.com -w ./.nuclei/workflows/my-workflow.yaml
```

### 1g. Output formats

| Flag                | Format         | Use case                            |
| ------------------- | -------------- | ----------------------------------- |
| `-j` / `-jsonl`     | JSONL          | Programmatic processing             |
| `-je results.json`  | JSON export    | Single-file report                  |
| `-se results.sarif` | SARIF          | GitHub Advanced Security / VS Code  |
| `-me reports/`      | Markdown (dir) | Human-readable per-template reports |
| (default stdout)    | Coloured CLI   | Interactive use                     |

For GitHub SARIF upload, use:

```bash
nuclei -u https://target.com -se nuclei.sarif -severity medium,high,critical
```

### 1h. Useful flag combinations

```bash
# Full scan with SARIF + JSONL + rate limiting + store req/resp
nuclei -l targets.txt \
  -severity medium,high,critical \
  -je report.json \
  -se report.sarif \
  -rl 100 \            # rate limit: 100 req/s
  -c 25 \              # 25 concurrent templates
  -stats               # live stats

# OpenAPI scan with custom templates + reporting
nuclei -l api.yaml -im openapi \
  -t ./.nuclei/templates/ \
  -se api-scan.sarif \
  -j -o api-results.jsonl
```

### 1i. Validating templates before running

Always validate custom templates to catch YAML errors:

```bash
nuclei -t ./.nuclei/templates/ -validate
```

A valid template produces no output; errors are printed with line numbers.

---

## Mode 2 — Generating Templates from a STRIDE Report

When a user provides a STRIDE threat model report (Markdown or JSON), translate
the identified threats into actionable nuclei templates and an orchestrating
workflow.

### Step-by-step process

1. **Parse the report** — extract the threat table rows: component, threat
   category (S/T/R/I/D/E), threat description, severity, and any identified
   attack vectors.

2. **Map to nuclei test strategies** — use the STRIDE→Nuclei mapping table in
   `references/stride-to-nuclei.md` to decide what kind of template to write for
   each threat.

3. **Write templates** — one YAML file per distinct threat or related threat
   group. Follow the authoring guidelines in `references/template-authoring.md`.

4. **Write a workflow** — a single YAML workflow orchestrating all the templates
   with appropriate conditions. See `references/workflow-authoring.md`.

5. **Validate** — run `nuclei -t ./.nuclei/templates/ -validate`.

6. **Scan** — run nuclei with the generated templates against the target.

### Output directory structure

Always organise generated files like this:

```text
.nuclei/
├── templates/
│   ├── <threat-id>-<short-description>.yaml   # one per threat
│   └── ...
├── workflows/
│   └── <project-name>-workflow.yaml
└── reports/
    ├── results.jsonl
    └── results.sarif
```

### Presenting generated templates

After generating templates:

1. Show the user the list of template files created and what each detects.
2. Validate them with `nuclei -validate`.
3. Ask the user for a target URL or OpenAPI spec to run them against, OR show
   the commands they need to run themselves.

---

## Mode 3 — Full Pipeline: Threat Model → Generate → Scan

Mode 3 orchestrates all three stages in sequence. Use it when the user has
source code, an architecture description, or an OpenAPI spec but no existing
threat model or nuclei templates yet — you produce everything from scratch.

### Prerequisites

- Source code path, architecture description, or OpenAPI/Swagger spec
- A target URL (or OpenAPI file) to scan against
- The `threat-model` skill is available

### Stage 1 — Generate the STRIDE report

Invoke the `threat-model` skill on the provided codebase or description. That
skill handles all discovery, STRIDE analysis, scoring, and output.

Expected outputs (saved to `threat-model/`):

- `threat-model-<YYYY-MM-DD>.md` — Markdown report with STRIDE matrix + full
  threat details
- `threat-model-<YYYY-MM-DD>.sarif.json` — SARIF file

Once the threat model report is written, **pause and summarise** for the user:

- How many threats were found per severity
- The top 3 highest-severity threats
- Ask: _"Ready to generate nuclei templates for these threats and run a scan?"_

### Stage 2 — Generate nuclei templates (Mode 2)

Parse the threat model Markdown report. The STRIDE matrix table looks like:

```text
| ID     | Component | STRIDE | Description (brief)          | Severity | Status |
| ------ | --------- | ------ | ---------------------------- | -------- | ------ |
| TM-001 | Auth API  | S      | JWT alg:none bypass          | Critical | Open   |
| TM-002 | User DB   | I      | DB error messages leaked     | High     | Open   |
```

For each `Open` threat row:

1. Extract: `ID`, `Component`, `STRIDE category`, `Description`, `Severity`
2. Read the full threat detail section in the report for `Mitigation` and
   `Attack vector` context
3. Apply the STRIDE→Nuclei mapping from `references/stride-to-nuclei.md`
4. Write one template file named `<id>-<stride>-<slug>.yaml` e.g.
   `tm-001-s-jwt-alg-none.yaml`
5. Set the template `severity` field to match the threat severity
6. Add `tags` that include the STRIDE category letter, e.g. `spoofing,jwt,auth`

Then write one orchestrating workflow (see `references/workflow-authoring.md`
Type 4 — STRIDE-organised workflow) that runs all generated templates.

Save to:

```text
.nuclei/
├── templates/
│   ├── tm-001-s-jwt-alg-none.yaml
│   ├── tm-002-i-db-error-disclosure.yaml
│   └── ...
└── workflows/
    └── <project>-stride-scan.yaml
```

Validate before proceeding:

```bash
nuclei -t ./.nuclei/templates/ -validate
```

If any templates fail validation, fix them before Stage 3.

### Stage 3 — Run the scan (Mode 1)

Use the target URL or OpenAPI spec provided by the user. Always produce at least
SARIF + JSONL output so results can be reviewed programmatically.

```bash
# URL target
nuclei -u https://target.com \
  -w ./.nuclei/workflows/<project>-stride-scan.yaml \
  -se ./.nuclei/reports/results.sarif \
  -je ./.nuclei/reports/results.json \
  -stats

# OpenAPI spec target
nuclei -l openapi.yaml -im openapi \
  -w ./.nuclei/workflows/<project>-stride-scan.yaml \
  -se ./.nuclei/reports/results.sarif \
  -je ./.nuclei/reports/results.json \
  -stats
```

After the scan completes, present the consolidated results using the
**Interpreting scan results** format below. Cross-reference nuclei findings back
to threat IDs (e.g. "TM-001 confirmed by template `tm-001-s-jwt-alg-none`").

### Full pipeline output layout

```text
<project-root>/
├── threat-model/
│   ├── threat-model-<YYYY-MM-DD>.md         ← Stage 1 output
│   └── threat-model-<YYYY-MM-DD>.sarif.json ← Stage 1 output
└── .nuclei/
    ├── templates/                            ← Stage 2 output
    │   └── tm-NNN-<stride>-<slug>.yaml
    ├── workflows/                            ← Stage 2 output
    │   └── <project>-stride-scan.yaml
    └── reports/                              ← Stage 3 output
        ├── results.sarif
        └── results.json
```

---

## Interpreting scan results

After a scan, summarise findings clearly:

```markdown
## Nuclei Scan Summary — <target>

| Severity | Count | Key Findings                         |
| -------- | ----- | ------------------------------------ |
| Critical | 2     | SQL injection, exposed .env file     |
| High     | 5     | CORS misconfiguration, open redirect |
| Medium   | 3     | Missing security headers             |
| Low/Info | 11    | Tech fingerprinting                  |

→ Top priority: [list top 3 actionable items with template IDs]
```

For each critical/high finding, include:

- **Template ID** and name
- **Matched URL** / endpoint
- **What it means** (1-2 sentences)
- **Recommended fix** (1-2 sentences)

---

## Reference files

Load these when you need detailed guidance:

| File                               | When to load                                       |
| ---------------------------------- | -------------------------------------------------- |
| `references/template-authoring.md` | Writing or reviewing nuclei YAML templates         |
| `references/stride-to-nuclei.md`   | Mapping STRIDE threats to nuclei template patterns |
| `references/workflow-authoring.md` | Writing nuclei workflow YAML files                 |
