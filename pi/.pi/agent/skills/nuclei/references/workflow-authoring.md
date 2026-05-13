# Nuclei Workflow Authoring Guide

Workflows orchestrate multiple nuclei templates with optional conditions. They
are ideal for scanning a target methodically: detect technology first, then run
specific exploits only if the technology is confirmed.

---

## Workflow anatomy

```yaml
id: <workflow-id> # unique ID, kebab-case

info:
  name: "<Workflow name>"
  author: <handle>
  severity: info
  description: |
    What this workflow does.
  tags: <comma,separated,tags>

workflows:
  - template: <path-or-url> # template to run first
    subtemplates: # (optional) run these if above matches
      - template: <path>
    matchers: # (optional) conditional on matcher name
      - name: <matcher-name>
        subtemplates:
          - template: <path>
```

---

## Type 1 — Generic workflow (run all)

Use when you want to run a set of templates against every target regardless of
conditions. Order matters — templates run in sequence.

```yaml
id: webapp-generic-scan

info:
  name: Web Application Generic Security Scan
  author: security-team
  severity: info
  description: |
    Generic security scan covering common web vulnerabilities.
  tags: generic,web,security

workflows:
  - template: templates/s-spoofing-jwt-alg-none.yaml
  - template: templates/s-host-header-injection.yaml
  - template: templates/t-reflected-xss.yaml
  - template: templates/t-ssti-probe.yaml
  - template: templates/i-sensitive-file-exposure.yaml
  - template: templates/i-graphql-introspection.yaml
  - template: templates/e-ssrf-url-parameter.yaml
  - template: templates/e-exposed-admin-panel.yaml
  - tags: sqli,lfi,rce
```

---

## Type 2 — Conditional workflow (tech-based)

Run expensive or targeted templates only after confirming a technology. This
cuts scan time dramatically and reduces false positives.

```yaml
id: django-app-scan

info:
  name: Django Application Security Scan
  author: security-team
  severity: info
  description: |
    Detects Django and runs Django-specific security checks.
  tags: django,python,web

workflows:
  # Step 1: detect Django
  - template: http/technologies/django-detect.yaml
    subtemplates:
      # Step 2a: run Django-specific checks
      - template: templates/django-debug-toolbar.yaml
      - template: templates/django-admin-exposed.yaml
      - template: templates/django-secret-key-leak.yaml
      # Step 2b: also run generic checks
      - tags: sqli,xss,ssrf
```

---

## Type 3 — Matcher-based conditional (multi-technology)

Branch on which technology the detection template matched.

```yaml
id: multi-tech-api-scan

info:
  name: Multi-Technology API Security Scan
  author: security-team
  severity: info
  description: |
    Detects the API technology stack and runs tailored security checks.
  tags: api,web,multi-tech

workflows:
  - template: http/technologies/tech-detect.yaml
    matchers:
      - name: graphql
        subtemplates:
          - template: templates/i-graphql-introspection.yaml
          - template: templates/graphql-field-suggestion.yaml
          - template: templates/graphql-batch-query-dos.yaml

      - name: swagger
        subtemplates:
          - template: templates/swagger-ui-exposed.yaml
          - template: templates/swagger-file-exposure.yaml

      - name: spring
        subtemplates:
          - template: templates/spring-actuator-exposure.yaml
          - template: templates/spring-h2-console.yaml

      - name: express
        subtemplates:
          - template: templates/t-ssti-probe.yaml
          - template: templates/node-debug-port.yaml
```

---

## Type 4 — STRIDE-organised workflow

When generating from a STRIDE report, organise the workflow by category. This
makes remediation easier since all templates for a STRIDE category run as a
block.

```yaml
id: stride-threat-model-scan

info:
  name: STRIDE Threat Model - Security Validation Scan
  author: security-team
  severity: info
  description: |
    Generated from STRIDE threat model report. Tests each identified threat
    with a targeted nuclei template. Run after any significant code change
    to validate threat mitigations remain effective.
  tags: stride,threat-model,custom,security

workflows:
  # ── S: Spoofing ──────────────────────────────────────────────────────────
  - template: templates/s-jwt-alg-none-bypass.yaml
  - template: templates/s-host-header-injection-password-reset.yaml
  - template: templates/s-default-credentials.yaml

  # ── T: Tampering ─────────────────────────────────────────────────────────
  - template: templates/t-sql-injection-login.yaml
  - template: templates/t-reflected-xss-search.yaml
  - template: templates/t-csrf-profile-update.yaml
  - template: templates/t-ssti-name-param.yaml

  # ── R: Repudiation ───────────────────────────────────────────────────────
  - template: templates/r-http-trace-method.yaml
  - template: templates/r-spring-actuator-exposure.yaml

  # ── I: Information Disclosure ────────────────────────────────────────────
  - template: templates/i-sensitive-file-exposure.yaml
  - template: templates/i-graphql-introspection.yaml
  - template: templates/i-verbose-error-messages.yaml

  # ── D: Denial of Service ─────────────────────────────────────────────────
  - template: templates/d-missing-rate-limiting-login.yaml

  # ── E: Elevation of Privilege ────────────────────────────────────────────
  - template: templates/e-ssrf-url-parameter.yaml
  - template: templates/e-exposed-admin-panel.yaml
  - template: templates/e-idor-user-profile.yaml
```

---

## Shared execution context (passing values between templates)

Workflows share a cookie jar and a key-value store. Named extractors from one
template are available in subsequent templates.

```yaml
# template 1: extract CSRF token
http:
  - raw:
      - GET /login HTTP/1.1
    extractors:
      - type: regex
        name: csrf_token      # ← this name is shared across the workflow
        internal: true
        regex:
          - 'name="_token" value="([^"]+)"'

# template 2: use the extracted token
http:
  - raw:
      - |
        POST /api/action HTTP/1.1
        X-CSRF-Token: {{csrf_token}}   # ← references the extracted value
```

---

## Naming conventions

Adopt a consistent naming pattern for generated templates and workflows:

```text
templates/
  <stride-category>-<component>-<attack>.yaml
  # Examples:
  s-api-jwt-alg-none.yaml
  t-search-reflected-xss.yaml
  i-graphql-introspection.yaml
  e-admin-panel-unauth.yaml

workflows/
  <project>-stride-scan.yaml
  <project>-<technology>-scan.yaml
```

---

## Running a workflow

```bash
# Single target
nuclei -u https://target.com -w ./.nuclei/workflows/my-project-stride-scan.yaml

# Multiple targets
nuclei -l targets.txt -w ./.nuclei/workflows/my-project-stride-scan.yaml

# With SARIF output
nuclei -u https://target.com \
  -w ./.nuclei/workflows/my-project-stride-scan.yaml \
  -se .nuclei/reports/results.sarif \
  -je .nuclei/reports/results.json

# Dry-run: list templates the workflow would execute
nuclei -u https://target.com -w ./.nuclei/workflows/my-project-stride-scan.yaml -tl
```

---

## Validation

Workflows themselves do not pass `-validate` (only templates do), but you can
validate the referenced templates:

```bash
nuclei -t ./.nuclei/templates/ -validate
```

If all templates validate cleanly, the workflow will run without errors.
