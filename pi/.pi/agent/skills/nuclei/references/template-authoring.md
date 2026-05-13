# Nuclei Template Authoring Guide

Nuclei templates are YAML files that describe how to detect a vulnerability.
This reference covers the full structure you need to author correct, effective
templates.

---

## Canonical template anatomy

```yaml
id: <kebab-case-unique-id> # no spaces, used in output

info:
  name: "<Human readable name>"
  author: <your-handle>
  severity: info | low | medium | high | critical
  description: |
    One or two sentences describing what this template detects.
  impact: |
    What an attacker can do if this fires.
  remediation: |
    How to fix it.
  classification:
    cvss-metrics: "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H"
    cvss-score: 9.8
    cwe-id: CWE-89
  tags: <comma,separated,tags>
  metadata:
    max-request: 1

# Protocol block — choose ONE: http, dns, ssl, tcp, headless, file, code
http:
  - method: GET
    path:
      - "{{BaseURL}}/path"
    matchers-condition: and
    matchers:
      - type: status
        status:
          - 200
      - type: word
        part: body
        words:
          - "evidence string"
```

---

## Built-in variables

| Variable                 | Resolves to                                              |
| ------------------------ | -------------------------------------------------------- |
| `{{BaseURL}}`            | Full URL with path from input (e.g. `https://host/path`) |
| `{{RootURL}}`            | Scheme + host only (e.g. `https://host`)                 |
| `{{Hostname}}`           | Host only (e.g. `host.example.com`)                      |
| `{{Host}}`               | IP or hostname without port                              |
| `{{Port}}`               | Port number                                              |
| `{{Path}}`               | URL path                                                 |
| `{{interactsh-url}}`     | Out-of-band interaction server URL (for blind detection) |
| `{{rand_text_alpha(n)}}` | Random alphabetic string of length n                     |
| `{{rand_int(min,max)}}`  | Random integer in range                                  |
| `{{to_lower(x)}}`        | Lowercase a string                                       |

---

## Matcher types

### `word` — string contains check

```yaml
- type: word
  part: body # body | header | all | raw | interactsh_protocol
  words:
    - "error in SQL"
    - "mysql_fetch"
  condition: or # or | and (default: or)
  case-insensitive: true
```

### `regex` — regex match

```yaml
- type: regex
  part: body
  regex:
    - "SQL syntax.{0,200}?MySQL"
    - "ORA-[0-9]{5}"
```

### `status` — HTTP status code

```yaml
- type: status
  status:
    - 200
    - 302
```

### `dsl` — Go/nuclei expression language

```yaml
- type: dsl
  dsl:
    - "status_code == 200"
    - "contains(tolower(header), 'access-control-allow-origin: *')"
    - "contains(body, 'root:') && status_code == 200"
  condition: and
```

### `binary` — binary content match

```yaml
- type: binary
  binary:
    - "504B0304" # PK zip magic bytes
```

---

## Extractor types

Extractors capture values from responses. Mark `internal: true` to use them
within the same template (e.g. for CSRF token extraction in multi-step flows).

```yaml
extractors:
  - type: regex
    part: body
    group: 1
    regex:
      - "token=([a-zA-Z0-9]+)"

  - type: xpath
    part: body
    attribute: value
    internal: true
    xpath:
      - /html/body//input[@name='csrf']

  - type: kval
    part: header
    kval:
      - content-type
      - set-cookie
```

---

## Multi-step HTTP templates (raw mode)

Use `raw:` for multi-step interactions (login → action, CSRF, session fixation):

```yaml
http:
  - raw:
      - |
        GET /login HTTP/1.1
        Host: {{Hostname}}

      - |
        POST /login HTTP/1.1
        Host: {{Hostname}}
        Content-Type: application/x-www-form-urlencoded

        username={{username}}&password={{password}}&csrf={{csrf_token}}

    extractors:
      - type: regex
        name: csrf_token
        part: body
        internal: true
        regex:
          - 'name="_token" value="([^"]+)"'

    matchers:
      - type: dsl
        dsl:
          - "status_code == 302"
          - "contains(header, 'Location: /dashboard')"
        condition: and
```

---

## Fuzzing templates (DAST mode)

Use `fuzzing:` to inject payloads into query params, headers, or path segments.
Requires `-dast` or `-fuzz` flag.

```yaml
http:
  - method: GET
    path:
      - "{{BaseURL}}"
    fuzzing:
      - part: query # query | path | header | body | cookie
        type: replace # replace | prefix | postfix | infix
        mode: single # single | multiple
        fuzz:
          - "' OR '1'='1"
          - "1 AND SLEEP(5)--"
    matchers:
      - type: dsl
        dsl:
          - "duration >= 5"
```

---

## Payload-based templates

Use `payloads:` for wordlist-style fuzzing over a fixed endpoint:

```yaml
http:
  - method: GET
    path:
      - "{{BaseURL}}/{{paths}}"
    payloads:
      paths:
        - "admin"
        - "administrator"
        - ".env"
        - "config.php.bak"
    attack: batteringram # batteringram | pitchfork | clusterbomb
    matchers:
      - type: status
        status:
          - 200
      - type: word
        part: body
        words:
          - "DB_PASSWORD"
          - "APP_SECRET"
        condition: or
```

---

## Headless (browser) templates

For JavaScript-heavy apps, DOM XSS, CSRF with SameSite, etc.:

```yaml
headless:
  - steps:
      - action: navigate
        args:
          url: "{{BaseURL}}"
      - action: waitload
      - action: script
        args:
          code: "document.title"
        name: title
    matchers:
      - type: word
        part: title
        words:
          - "Admin Panel"
```

---

## Common template patterns per vulnerability class

### SQL Injection (error-based)

```yaml
http:
  - method: GET
    path:
      - "{{BaseURL}}/?id=1'"
    matchers-condition: and
    matchers:
      - type: regex
        part: body
        regex:
          - "SQL syntax.{0,200}?MySQL"
          - "PostgreSQL.{0,200}?ERROR"
          - "ORA-[0-9]{5}"
      - type: status
        status:
          - 200
```

### Sensitive file exposure

```yaml
http:
  - method: GET
    path:
      - "{{BaseURL}}/.env"
      - "{{BaseURL}}/config.yaml"
      - "{{BaseURL}}/.git/config"
    matchers-condition: and
    matchers:
      - type: word
        part: body
        words:
          - "DB_PASSWORD"
          - "SECRET_KEY"
          - "[core]"
        condition: or
      - type: status
        status:
          - 200
```

### Missing security headers

```yaml
http:
  - method: GET
    path:
      - "{{BaseURL}}/"
    matchers:
      - type: dsl
        dsl:
          - "!contains(tolower(header), 'x-frame-options')"
          - "!contains(tolower(header), 'content-security-policy')"
          - "!contains(tolower(header), 'strict-transport-security')"
        condition: or
```

### CORS misconfiguration

```yaml
http:
  - raw:
      - |
        GET / HTTP/1.1
        Host: {{Hostname}}
        Origin: https://evil.example.com
    matchers:
      - type: dsl
        dsl:
          - "contains(tolower(header), 'access-control-allow-origin:
            https://evil.example.com')"
          - "contains(tolower(header), 'access-control-allow-credentials: true')"
        condition: and
```

### Out-of-band (blind) SSRF

```yaml
http:
  - method: GET
    path:
      - "{{BaseURL}}/fetch?url=http://{{interactsh-url}}"
    matchers:
      - type: word
        part: interactsh_protocol
        words:
          - "http"
          - "dns"
        condition: or
```

### JWT algorithm confusion (none)

```yaml
http:
  - raw:
      - |
        GET /api/protected HTTP/1.1
        Host: {{Hostname}}
        Authorization: Bearer {{jwt_none}}
    payloads:
      jwt_none:
        # alg=none base64url-encoded header.payload.empty-sig
        - "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiIxMjM0NTY3ODkwIiwicm9sZSI6ImFkbWluIn0." # betterleaks:allow
    matchers:
      - type: dsl
        dsl:
          - "status_code == 200"
          - "!contains(body, 'Unauthorized')"
          - "!contains(body, 'Invalid token')"
        condition: and
```

---

## Severity mapping guidelines

| Severity   | When to use                                                            |
| ---------- | ---------------------------------------------------------------------- |
| `critical` | RCE, auth bypass with full access, SQL injection with data exfil       |
| `high`     | SSRF, stored XSS, IDOR, privilege escalation, sensitive data exposure  |
| `medium`   | Reflected XSS, CSRF, open redirect, misconfigured CORS, path traversal |
| `low`      | Missing security headers, verbose error messages, directory listing    |
| `info`     | Technology fingerprinting, version disclosure, informational exposures |

---

## Validation

Always validate before running:

```bash
nuclei -t ./.nuclei/templates/my-template.yaml -validate
```

Common errors:

- Missing required field (`id`, `info.name`, `info.severity`)
- Invalid YAML indentation
- Wrong matcher `part` value
- Using `{{interactsh-url}}` without an interactsh matcher
