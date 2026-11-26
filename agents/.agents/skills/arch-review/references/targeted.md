# Targeted reviews

Single-agent reviews for one question. Run steps 1–3 of SKILL.md (target,
drivers, claims) at reduced depth, launch one read-only `general-purpose` agent
with the brief below (or do it yourself if the target is small), then re-verify
the High-severity rows and write the report. No lens consolidation. Filename
suffix: `scenario-walkthrough`, `fmea`, `adr-audit`.

## Scenario walkthrough

Traces concrete scenarios end to end to expose where the design breaks or goes
vague.

Pick 4–6 scenarios — from the utility tree when it exists, otherwise ask the
user or choose: the main happy path; a dependency failing mid-flow; a load
spike; a bad deploy and rollback; a security-relevant path (cross-tenant
request, expired token); an operator task (backfill, replay, data deletion
request).

For each scenario, one table:

| Step | Component | Action | Assumption | Risk / gap |
| ---- | --------- | ------ | ---------- | ---------- |

Then: where the scenario breaks or becomes unclear, and the findings (finding
format) it produced.

## FMEA

Systematic failure-mode and effects analysis over every component and external
dependency.

| Component | Failure mode | Detection | Severity 1–5 | Likelihood 1–5 | RPN | Impact | Current mitigation | Residual risk | Recommended action |
| --------- | ------------ | --------- | ------------ | -------------- | --- | ------ | ------------------ | ------------- | ------------------ |

- RPN = severity × likelihood (add detectability 1–5 as a third factor if the
  user wants the classic form); sort by RPN, descending.
- Failure modes to consider per component: unavailable, slow, wrong answer,
  partial write, duplicate delivery, data loss, resource exhaustion, expired
  credential/certificate, bad config or deploy, dependency version skew.
- Detection must name the actual signal (alert, metric, log), or "none" —
  undetected failure modes are findings on their own.
- Summarize: top 5 by RPN, and modes with no detection.

## ADR audit

Reviews the architecture decisions (ADR files, a decisions section of a design
doc, or decisions you extract from it).

For each decision:

1. Is the problem and context clear?
2. Are the alternatives real and fairly characterized?
3. Is the rationale convincing against the drivers?
4. Are consequences — including negative ones — stated?
5. Is it still valid given what is now known (check the code and later
   decisions)?
6. Was advice sought from the affected teams and experts, and recorded?

| ID  | Title | Status | Verdict | Notes |
| --- | ----- | ------ | ------- | ----- |

Verdict: **Sound**, **Needs revision**, **Missing context**, **Superseded in
practice** (the code no longer follows it).

Then list **missing decisions**: significant choices visible in the code or
design that have no ADR, each with a one-line suggested ADR title. Lightweight
ADR shape for stubs: Title, Status, Context, Decision, Options considered,
Consequences, Advice.
