---
description: STRIDE threat model — components, data flows, trust boundaries, SARIF + Linear
  issues
argument-hint: "[system name or path]"
---

# STRIDE Threat Model

Perform a STRIDE security threat model for **$ARGUMENTS**.

Reference files (read only when relevant):

- `~/.pi/agent/skills/threat-model/references/stride-guide.md` — Detailed STRIDE
  patterns, attack examples, and detection signals per category (read during
  Phase 2)

```plaintext
Workflow:
1. UNDERSTAND   → extract components, data flows, trust boundaries
2. ANALYZE      → apply STRIDE to each component and data flow
3. SCORE        → assign likelihood, impact, and severity
4. OUTPUT       → STRIDE matrix + Markdown report + SARIF JSON
5. LINEAR       → (optional) create issues for HIGH/CRITICAL threats
```

---

## Phase 1 — System Understanding

### 1a — Gather Context

| Input type           | How to handle                                                      |
| -------------------- | ------------------------------------------------------------------ |
| Source code path     | Run discovery commands to map components, APIs, data stores        |
| Architecture diagram | Extract components and flows from the text                         |
| Written description  | Extract entities, trust zones, and data flows from the prose       |
| Mix of all three     | Start with the description/diagram for structure; enrich from code |

Ask the user for anything that would significantly change the analysis:

- **Deployment context** (cloud, on-prem, serverless, containerized)
- **Authentication / authorization model** (OAuth2, API keys, mTLS, etc.)
- **Data sensitivity** (PII, PHI, financial, public)
- **External integrations** (third-party APIs, webhooks, message queues)

If only a description is given, synthesize the system model from the text and
state assumptions explicitly.

### 1b — Code Discovery (if source code is available)

```bash
# API entry points
grep -r --include="*.py" --include="*.ts" --include="*.js" --include="*.go" \
  --include="*.java" --include="*.rb" --include="*.rs" \
  -E "(route|@app\.(get|post|put|delete|patch)|router\.(get|post)|HandleFunc|http\.Handle)" \
  . 2>/dev/null | grep -v node_modules | grep -v ".git" | head -60

# Auth / authorization code
grep -r --include="*.py" --include="*.ts" --include="*.js" --include="*.go" \
  -lE "(auth|jwt|oauth|session|middleware|verify_token|require_auth|IsAuthenticated)" \
  . 2>/dev/null | grep -v node_modules | grep -v ".git"

# Data stores
grep -r --include="*.py" --include="*.ts" --include="*.js" --include="*.go" \
  --include="*.yaml" --include="*.yml" --include="*.env*" \
  -E "(postgres|mysql|mongodb|redis|dynamodb|s3|sqs|kafka|rabbitmq|sqlite)" \
  . 2>/dev/null | grep -v node_modules | grep -v ".git" | head -40

# Hardcoded secrets (immediate findings)
grep -r --include="*.py" --include="*.ts" --include="*.js" --include="*.go" \
  --include="*.env" \
  -E "(SECRET|PASSWORD|API_KEY|TOKEN|PRIVATE_KEY)\s*=\s*[\"'][A-Za-z0-9+/]{16,}" \
  . 2>/dev/null | grep -v node_modules | grep -v ".git"

# External HTTP calls (trust boundary crossings)
grep -r --include="*.py" --include="*.ts" --include="*.js" --include="*.go" \
  -E "(requests\.(get|post|put)|fetch\(|axios\.|http\.Get|http\.Post|curl)" \
  . 2>/dev/null | grep -v node_modules | grep -v ".git" | head -40
```

### 1c — Build the System Model

Document before running STRIDE:

**Components** — every distinct service, function, or process: name, purpose,
technology, trust level (internal / external / third-party).

**Data Flows** — source → destination, data type, protocol, whether encrypted,
whether authenticated.

**Trust Boundaries** — where trust level changes (e.g., internet → load
balancer, API → database, microservice A → microservice B with different IAM
permissions).

**Data Stores** — type, data sensitivity, access controls, encryption at rest.

**External Actors** — end users, admins, third-party APIs, CI/CD pipelines.

State assumptions explicitly.

---

## Phase 2 — STRIDE Analysis

For each **component**, **data flow**, and **trust boundary crossing**, work
through all six STRIDE categories. Read
`~/.pi/agent/skills/threat-model/references/stride-guide.md` for detailed
patterns, attack examples, and signal indicators.

| Category                       | Question to ask                                         | Where it hurts most            |
| ------------------------------ | ------------------------------------------------------- | ------------------------------ |
| **S — Spoofing**               | Can an attacker impersonate a user, service, or entity? | Auth, inter-service calls, IDs |
| **T — Tampering**              | Can data be modified in transit or at rest?             | Data flows, storage, logs      |
| **R — Repudiation**            | Can an attacker deny having performed an action?        | Audit logs, non-repudiation    |
| **I — Info Disclosure**        | Can sensitive data be exposed to unauthorized parties?  | APIs, error messages, storage  |
| **D — Denial of Service**      | Can availability be disrupted?                          | APIs, resources, rate limits   |
| **E — Elevation of Privilege** | Can an attacker gain more access than intended?         | AuthZ, role boundaries, SSRF   |

For each identified threat, capture:

```plaintext
Threat ID:       TM-001
Component:       User Authentication API
STRIDE Category: Spoofing
Description:     JWT tokens are not validated for algorithm confusion (alg:none
                 attack). An attacker could forge a token and authenticate as
                 any user.
Likelihood:      High (publicly documented attack; easy to exploit if present)
Impact:          Critical (full account takeover)
Severity:        Critical
Mitigation:      Explicitly whitelist accepted JWT algorithms server-side
                 (e.g., RS256 only). Reject tokens with alg:none or unexpected
                 algorithms.
Status:          Open
```

**Aim for completeness.** A large codebase or complex architecture should yield
many threats. Common gaps: input handling (injection, deserialization), IPC
trust assumptions (service A blindly trusting service B), secret handling
(hardcoded, logged, over-scoped), dependency risks. Do not stop enumerating
threats early.

---

## Phase 3 — Risk Scoring

**Compliance annotation:** If data includes PHI, PII, financial, or other
regulated data, annotate each **Information Disclosure** and **Tampering**
threat:

- HIPAA §164.312(e)(2)(ii) — Encryption in Transit (unencrypted PHI channels)
- HIPAA §164.312(a)(2)(iv) — Encryption at Rest (unencrypted PHI storage)
- PCI DSS Req 3.5 — Protection of stored cardholder data
- GDPR Art. 32 — Appropriate technical measures for personal data

**Severity calibration:**

| Severity     | Likelihood × Impact                                                  | Example                                           |
| ------------ | -------------------------------------------------------------------- | ------------------------------------------------- |
| **Critical** | High likelihood + Critical/High impact                               | Unauthenticated RCE, SQL injection on prod DB     |
| **High**     | High likelihood + Medium impact, or Low likelihood + Critical impact | Auth bypass, SSRF to internal services, data leak |
| **Medium**   | Moderate likelihood or moderate impact                               | Missing rate limiting, verbose error messages     |
| **Low**      | Low likelihood + Low impact                                          | Non-sensitive info in logs, weak but valid config |
| **Info**     | Best-practice gap, no exploitable path identified                    | Missing security headers on non-sensitive routes  |

**Likelihood factors** (raises): publicly known attack, no auth required, common
misconfiguration.

**Impact factors** (raises): affects auth/authz, exposes PII/PHI/secrets,
affects data integrity or availability of critical paths.

---

## Phase 4 — Output Generation

Save all outputs to `<project-root>/.stride/` (create if needed). Use today's
date in filenames (`YYYY-MM-DD`).

### 4a — STRIDE Threat Matrix

```markdown
| ID     | Component | STRIDE | Description (brief)                       | Severity | Status |
| ------ | --------- | ------ | ----------------------------------------- | -------- | ------ |
| TM-001 | Auth API  | S      | JWT algorithm confusion / alg:none attack | Critical | Open   |
| TM-002 | User DB   | T      | No encryption at rest                     | High     | Open   |
```

### 4b — Markdown Report (`threat-model-<YYYY-MM-DD>.md`)

```markdown
# Threat Model: <System Name>

**Date:** <YYYY-MM-DD> **Methodology:** STRIDE **Overall Risk:** 🔴 Critical |
🟠 High | 🟡 Medium | 🟢 Low | ✅ Minimal

---

## Executive Summary

<2–4 sentences: what was analyzed, most significant findings, overall risk
posture>

## System Model

### Components

### Data Flows

### Trust Boundaries

### Assumptions

---

## Threat Findings

### 🔴 Critical (N)

### 🟠 High (N)

### 🟡 Medium (N)

### 🟢 Low (N)

### ℹ️ Info (N)

---

## Mitigation Roadmap

| Priority | Threat ID | Description | Effort | Owner    |
| -------- | --------- | ----------- | ------ | -------- |
| P1       | TM-001    | ...         | Low    | Security |

## Methodology Notes

STRIDE was applied to each component, data flow, and trust boundary. Threats
were scored by likelihood × impact.
```

### 4c — SARIF JSON (`threat-model-<YYYY-MM-DD>.sarif.json`)

```json
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "threat-model",
          "version": "0.1.0",
          "rules": [
            {
              "id": "STRIDE-S",
              "name": "Spoofing",
              "shortDescription": { "text": "Identity spoofing threat" }
            },
            {
              "id": "STRIDE-T",
              "name": "Tampering",
              "shortDescription": { "text": "Data tampering threat" }
            },
            {
              "id": "STRIDE-R",
              "name": "Repudiation",
              "shortDescription": { "text": "Repudiation / audit gap threat" }
            },
            {
              "id": "STRIDE-I",
              "name": "InformationDisclosure",
              "shortDescription": { "text": "Information disclosure threat" }
            },
            {
              "id": "STRIDE-D",
              "name": "DenialOfService",
              "shortDescription": { "text": "Denial of service threat" }
            },
            {
              "id": "STRIDE-E",
              "name": "ElevationOfPrivilege",
              "shortDescription": { "text": "Privilege escalation threat" }
            }
          ]
        }
      },
      "results": [
        {
          "ruleId": "STRIDE-S",
          "level": "error",
          "message": { "text": "<threat description>" },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": { "uri": "<file path or 'architecture'>" },
                "region": { "startLine": 1 }
              }
            }
          ],
          "properties": {
            "severity": "Critical",
            "threat_id": "TM-001",
            "component": "<component name>",
            "mitigation": "<mitigation text>"
          }
        }
      ]
    }
  ]
}
```

SARIF level mapping: `"error"` → Critical/High · `"warning"` → Medium · `"note"`
→ Low/Info

### 4d — Linear Issues (optional)

After generating outputs, ask the user:

> "I found **N Critical** and **M High** severity threats. Would you like me to
> create Linear issues for these in your project?"

If yes, ask for the Linear team key and project name. Use the `linear-cli` skill
to create one issue per HIGH/CRITICAL threat:

- **Title**: `[ThreatModel] TM-XXX: <brief description>`
- **Priority**: `1` (Urgent) for Critical, `2` (High) for High
- **Description**: Full threat detail — component, attack scenario, likelihood,
  impact, and mitigation
- **Labels**: `threat-model`, `security`, `stride-<category-letter>`

---

## Output Checklist

- [ ] STRIDE matrix covers all components, data flows, and trust boundary
      crossings
- [ ] Every threat has a mitigation (even "accept risk" or "needs further
      investigation")
- [ ] Severity ratings are calibrated — not everything is Critical
- [ ] All files saved to `.stride/`
- [ ] SARIF file is valid (balanced braces, all required fields present)
- [ ] User was asked about Linear issue creation
