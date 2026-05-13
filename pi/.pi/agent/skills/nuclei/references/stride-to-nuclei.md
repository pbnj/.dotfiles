# STRIDE → Nuclei Template Mapping

This reference maps each STRIDE threat category to the nuclei template patterns
and test strategies most likely to validate that threat in a running
application.

Use this when generating templates from a STRIDE threat model report: find the
threat's category, pick the matching patterns, then customise them for the
component and attack vector named in the report.

---

## Quick-reference table

| STRIDE category            | What it tests                           | Nuclei approaches                                           |
| -------------------------- | --------------------------------------- | ----------------------------------------------------------- |
| S — Spoofing               | Identity, authentication, impersonation | Auth bypass, JWT attacks, credential stuffing, login check  |
| T — Tampering              | Data integrity, input validation        | SQLi, XSS, CSRF, parameter pollution, mass assignment       |
| R — Repudiation            | Audit trails, logging, accountability   | Log injection, log bypass, debug endpoint exposure          |
| I — Information Disclosure | Confidentiality, data leakage           | Sensitive file exposure, error messages, version disclosure |
| D — Denial of Service      | Availability, resource exhaustion       | Rate-limit bypass, large payload, ReDoS (file-based)        |
| E — Elevation of Privilege | Authorization, access control           | IDOR, SSRF, privilege escalation, BOLA, JWT role tampering  |

---

## S — Spoofing

**Threat**: An attacker impersonates a legitimate user or service.

### Spoofing: Common attack vectors and template strategies

| Attack vector                | Template strategy                                                    |
| ---------------------------- | -------------------------------------------------------------------- |
| Authentication bypass        | Send requests with empty/invalid creds and check for 200 responses   |
| JWT `alg=none` attack        | Send JWT with `alg: none` and empty signature, check for 200         |
| JWT weak secret              | Send JWT signed with `secret`, `password`, `123456`, check for 200   |
| Password reset poisoning     | Inject Host header in password reset request, check for OOB callback |
| Session fixation             | Set a known session ID before auth, check if server accepts it       |
| Default credentials          | Try admin/admin, root/root, etc. against login endpoint              |
| OAuth token theft / redirect | Inject crafted `redirect_uri`, check for token in redirect location  |

### Template example — JWT `alg:none` bypass

```yaml
id: jwt-alg-none-bypass
info:
  name: JWT Algorithm None - Authentication Bypass
  author: security-team
  severity: critical
  description: |
    Tests whether the application accepts JWTs with alg=none (no signature),
    which would allow an attacker to forge tokens for any user.
  classification:
    cwe-id: CWE-347
  tags: jwt,auth,bypass,spoofing

http:
  - raw:
      - |
        GET /api/me HTTP/1.1
        Host: {{Hostname}}
        Authorization: Bearer {{jwt}}

    payloads:
      jwt:
        # {"alg":"none","typ":"JWT"}.{"sub":"1","role":"admin"}.
        - "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiIxIiwicm9sZSI6ImFkbWluIn0." # betterleaks:allow
        - "eyJhbGciOiJOT05FIiwidHlwIjoiSldUIn0.eyJzdWIiOiIxIiwicm9sZSI6ImFkbWluIn0." # betterleaks:allow

    matchers-condition: and
    matchers:
      - type: status
        status:
          - 200
      - type: word
        part: body
        words:
          - "Unauthorized"
          - "Invalid token"
          - "signature"
        negative: true
```

### Template example — Host header injection (password reset)

```yaml
id: host-header-injection-password-reset
info:
  name: Host Header Injection - Password Reset Poisoning
  author: security-team
  severity: high
  description: |
    Tests for Host header injection in password reset flows, which can lead to
    token theft via a poisoned reset link delivered to the victim.
  classification:
    cwe-id: CWE-20
  tags: host-header,password-reset,spoofing,oast

http:
  - raw:
      - |
        POST /forgot-password HTTP/1.1
        Host: {{interactsh-url}}
        Content-Type: application/x-www-form-urlencoded

        email=victim@example.com

    matchers:
      - type: word
        part: interactsh_protocol
        words:
          - "http"
          - "dns"
        condition: or
```

---

## T — Tampering

**Threat**: An attacker modifies data in transit or at rest.

### Tampering: Common attack vectors and template strategies

| Attack vector       | Template strategy                                              |
| ------------------- | -------------------------------------------------------------- |
| SQL injection       | Inject `'`, `1'1`, SLEEP payloads; match DB error strings      |
| NoSQL injection     | Inject `$ne`, `$gt` operators; check for unexpected data       |
| XSS (reflected)     | Inject `<script>alert(1)</script>` in params; match reflection |
| XSS (stored)        | Store payload, then fetch page and check for reflected payload |
| CSRF                | Submit state-changing request without CSRF token; check 200    |
| Mass assignment     | Send extra JSON fields (`isAdmin:true`); check for privilege   |
| Parameter pollution | Duplicate params; check for unexpected behaviour               |
| XML/XXE injection   | Inject `DOCTYPE` entity referencing `/etc/passwd`              |
| Template injection  | Inject `{{7*7}}`, `${7*7}`; check for `49` in response         |

### Template example — Reflected XSS probe

```yaml
id: reflected-xss-probe
info:
  name: Reflected XSS - Parameter Injection Probe
  author: security-team
  severity: medium
  description: |
    Tests for reflected XSS by injecting a unique payload into query parameters
    and checking whether it appears unescaped in the response.
  classification:
    cwe-id: CWE-79
  tags: xss,reflected,tampering

variables:
  marker: "{{rand_text_alpha(8)}}"

http:
  - method: GET
    path:
      - "{{BaseURL}}/?q=<script>{{marker}}</script>"
      - "{{BaseURL}}/?search=<img src=x onerror={{marker}}>"
      - '{{BaseURL}}/?name="><svg onload={{marker}}>'

    matchers-condition: and
    matchers:
      - type: word
        part: body
        words:
          - "{{marker}}"
      - type: dsl
        dsl:
          - "!contains(tolower(body), '&lt;script&gt;')"
          - "!contains(tolower(body), '&amp;lt;')"
        condition: or
```

### Template example — Server-Side Template Injection

```yaml
id: ssti-generic-probe
info:
  name: Server-Side Template Injection - Generic Probe
  author: security-team
  severity: high
  description: |
    Tests for SSTI by injecting arithmetic expressions that popular template
    engines evaluate. A match means user input is executed in template context.
  classification:
    cwe-id: CWE-94
  tags: ssti,rce,tampering

http:
  - method: GET
    path:
      - "{{BaseURL}}/?name={{7*7}}"
      - "{{BaseURL}}/?name=${7*7}"
      - "{{BaseURL}}/?name=<%= 7*7 %>"
      - "{{BaseURL}}/?name=#{7*7}"

    matchers-condition: and
    matchers:
      - type: word
        part: body
        words:
          - "49"
      - type: status
        status:
          - 200
```

---

## R — Repudiation

**Threat**: An attacker performs actions that cannot be attributed to them.

### Repudiation: Common attack vectors and template strategies

| Attack vector          | Template strategy                                            |
| ---------------------- | ------------------------------------------------------------ |
| Log injection          | Inject newlines/ANSI codes into logged fields; check echoed  |
| Debug/trace endpoints  | Probe `/trace`, `/actuator/httptrace`, `/debug`; check 200   |
| Exposed audit log APIs | Probe `/api/audit`, `/admin/logs`; check for sensitive data  |
| HTTP TRACE method      | Send TRACE request; check for response with original headers |
| Verbose error messages | Trigger errors; check for stack traces, internal paths       |

### Template example — HTTP TRACE method

```yaml
id: http-trace-method-enabled
info:
  name: HTTP TRACE Method Enabled
  author: security-team
  severity: medium
  description: |
    The HTTP TRACE method is enabled. This can be used to reflect HTTP headers
    (including cookies and auth tokens) back to the client, aiding XSS attacks.
  classification:
    cwe-id: CWE-16
  tags: trace,misconfig,repudiation

http:
  - method: TRACE
    path:
      - "{{BaseURL}}/"
    matchers-condition: and
    matchers:
      - type: word
        part: body
        words:
          - "TRACE / HTTP"
      - type: status
        status:
          - 200
```

### Template example — Spring Boot actuator exposure

```yaml
id: spring-actuator-exposure
info:
  name: Spring Boot Actuator - Sensitive Endpoint Exposed
  author: security-team
  severity: high
  description: |
    Spring Boot actuator endpoints expose internal application state.
    Exposed endpoints can leak configuration, environment variables, and traces.
  classification:
    cwe-id: CWE-200
  tags: spring,actuator,exposure,repudiation

http:
  - method: GET
    path:
      - "{{BaseURL}}/actuator"
      - "{{BaseURL}}/actuator/env"
      - "{{BaseURL}}/actuator/httptrace"
      - "{{BaseURL}}/actuator/mappings"

    matchers-condition: and
    matchers:
      - type: word
        part: body
        words:
          - '"_links":'
          - '"activeProfiles":'
          - '"traces":'
        condition: or
      - type: status
        status:
          - 200
```

---

## I — Information Disclosure

**Threat**: An attacker gains access to sensitive data.

### Information Disclosure: Common attack vectors and template strategies

| Attack vector               | Template strategy                                      |
| --------------------------- | ------------------------------------------------------ |
| Sensitive file exposure     | Probe `.env`, `.git/config`, `config.yaml`, `*.bak`    |
| Directory traversal / LFI   | Inject `../etc/passwd`; match `root:x:`                |
| Verbose error messages      | Trigger 500 errors; match stack traces, DSN strings    |
| API key / secret leakage    | Regex-scan responses for key patterns                  |
| Version disclosure          | Check `Server:`, `X-Powered-By:` headers               |
| GraphQL introspection       | Send `{__schema{types{name}}}` and check for type list |
| Swagger/OpenAPI UI exposure | Probe `/swagger-ui.html`, `/api-docs`, `/openapi.json` |

### Template example — Sensitive file exposure

```yaml
id: sensitive-file-exposure
info:
  name: Sensitive Files - Exposure Detection
  author: security-team
  severity: high
  description: |
    Checks for commonly exposed sensitive files that may leak credentials,
    configuration details, or application internals.
  classification:
    cwe-id: CWE-200
  tags: exposure,config,disclosure,information-disclosure

http:
  - method: GET
    path:
      - "{{BaseURL}}/.env"
      - "{{BaseURL}}/.env.local"
      - "{{BaseURL}}/.env.production"
      - "{{BaseURL}}/config.yaml"
      - "{{BaseURL}}/config.yml"
      - "{{BaseURL}}/secrets.yaml"
      - "{{BaseURL}}/application.properties"
      - "{{BaseURL}}/application.yml"
      - "{{BaseURL}}/.git/config"

    matchers-condition: and
    matchers:
      - type: word
        part: body
        words:
          - "DB_PASSWORD"
          - "DATABASE_URL"
          - "SECRET_KEY"
          - "API_KEY"
          - "AWS_ACCESS_KEY"
          - "[core]"
          - "password="
        condition: or
      - type: status
        status:
          - 200
```

### Template example — GraphQL introspection

```yaml
id: graphql-introspection-enabled
info:
  name: GraphQL Introspection - Enabled
  author: security-team
  severity: medium
  description: |
    GraphQL introspection is enabled, allowing any user to enumerate the full
    API schema including all queries, mutations, and types.
  classification:
    cwe-id: CWE-200
  tags: graphql,introspection,disclosure

http:
  - method: POST
    path:
      - "{{BaseURL}}/graphql"
      - "{{BaseURL}}/api/graphql"
      - "{{BaseURL}}/query"
    headers:
      Content-Type: application/json
    body: '{"query":"{__schema{queryType{name}}}"}'

    matchers-condition: and
    matchers:
      - type: word
        part: body
        words:
          - "__schema"
          - "queryType"
        condition: and
      - type: status
        status:
          - 200
```

---

## D — Denial of Service

**Threat**: An attacker degrades or disrupts service availability.

### Denial of Service: Common attack vectors and template strategies

| Attack vector             | Template strategy                                              |
| ------------------------- | -------------------------------------------------------------- |
| Missing rate limiting     | Send rapid repeated requests; check for 429 or lack thereof    |
| Large payload acceptance  | Send oversized bodies; check for 200 (server should reject)    |
| ReDoS (static analysis)   | File template scanning for catastrophic regex patterns in code |
| Unauthenticated heavy ops | Invoke expensive endpoints without auth; measure response time |
| Billion laughs (XML)      | Send XML entity expansion payload; check for timeout or OOM    |

### Template example — Rate limiting absent

```yaml
id: missing-rate-limiting
info:
  name: Login Endpoint - Missing Rate Limiting
  author: security-team
  severity: medium
  description: |
    The login endpoint does not enforce rate limiting, allowing an attacker to
    perform brute-force or credential stuffing attacks without restriction.
  classification:
    cwe-id: CWE-307
  tags: rate-limit,brute-force,dos,auth

http:
  - raw:
      - |
        POST /login HTTP/1.1
        Host: {{Hostname}}
        Content-Type: application/json

        {"username":"testuser","password":"wrongpassword1"}
      - |
        POST /login HTTP/1.1
        Host: {{Hostname}}
        Content-Type: application/json

        {"username":"testuser","password":"wrongpassword2"}
      - |
        POST /login HTTP/1.1
        Host: {{Hostname}}
        Content-Type: application/json

        {"username":"testuser","password":"wrongpassword3"}

    matchers:
      - type: dsl
        dsl:
          - "status_code_1 != 429"
          - "status_code_2 != 429"
          - "status_code_3 != 429"
        condition: and
```

---

## E — Elevation of Privilege

**Threat**: An attacker gains more access rights than intended.

### Elevation of Privilege: Common attack vectors and template strategies

| Attack vector            | Template strategy                                          |
| ------------------------ | ---------------------------------------------------------- |
| IDOR / BOLA              | Access another user's resource by changing an ID parameter |
| SSRF                     | Inject internal URLs into fetch/proxy/webhook params       |
| Privilege escalation     | Change role param in request; check for admin-level access |
| Path traversal to RCE    | Traverse to writable dirs; combine with file upload        |
| Exposed admin interfaces | Probe `/admin`, `/console`, `/manage`; check for 200       |
| JWT role tampering       | Modify JWT payload claims (role, isAdmin); check for 200   |
| Unprotected Kubernetes   | Probe `/metrics`, `/.well-known/`, `/healthz` without auth |

### Template example — SSRF via URL parameter

```yaml
id: ssrf-url-parameter
info:
  name: SSRF - URL Parameter Injection
  author: security-team
  severity: high
  description: |
    Tests for Server-Side Request Forgery by injecting an out-of-band
    interaction URL into parameters that may trigger server-side HTTP requests.
  classification:
    cwe-id: CWE-918
  tags: ssrf,oast,elevation-of-privilege

http:
  - method: GET
    path:
      - "{{BaseURL}}/fetch?url=http://{{interactsh-url}}"
      - "{{BaseURL}}/proxy?target=http://{{interactsh-url}}"
      - "{{BaseURL}}/redirect?to=http://{{interactsh-url}}"
      - "{{BaseURL}}/webhook?callback=http://{{interactsh-url}}"
      - "{{BaseURL}}/import?source=http://{{interactsh-url}}"

    matchers:
      - type: word
        part: interactsh_protocol
        words:
          - "http"
          - "dns"
        condition: or
```

### Template example — Exposed admin panel

```yaml
id: exposed-admin-panel
info:
  name: Admin Panel - Unauthenticated Access
  author: security-team
  severity: high
  description: |
    An admin panel is accessible without authentication, which could allow
    an attacker to gain administrative control over the application.
  classification:
    cwe-id: CWE-306
  tags: admin,exposure,privilege,elevation-of-privilege

http:
  - method: GET
    path:
      - "{{BaseURL}}/admin"
      - "{{BaseURL}}/admin/"
      - "{{BaseURL}}/administrator"
      - "{{BaseURL}}/admin/login"
      - "{{BaseURL}}/wp-admin"
      - "{{BaseURL}}/manage"
      - "{{BaseURL}}/console"
      - "{{BaseURL}}/dashboard"

    matchers-condition: and
    matchers:
      - type: word
        part: body
        words:
          - "admin"
          - "dashboard"
          - "control panel"
          - "management"
        condition: or
      - type: status
        status:
          - 200
      - type: dsl
        dsl:
          - "!contains(tolower(body), 'login')"
          - "!contains(tolower(body), 'sign in')"
        condition: and
```

---

## Combining STRIDE threats into one workflow

When generating templates for multiple STRIDE categories, create a workflow that
runs all of them together. The `workflow-authoring.md` reference shows how.

Key principle: **one template = one threat**. Keep templates focused so that a
match unambiguously indicates the specific vulnerability.
