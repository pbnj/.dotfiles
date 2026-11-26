---
name: arch-review
description:
  Architecture review of a design doc, RFC, ADR, repo, service or consequential
  PR. Pins the business drivers and quality-attribute scenarios first (ATAM
  utility tree), verifies the design's claims against the code, then reviews it
  through parallel read-only lenses — design coherence, fit with existing
  systems, reliability and day-2 operations, security and privacy, performance
  and cost, consumer/API ergonomics, evolvability, and a devil's advocate — and
  consolidates one report of risks, tradeoffs, missing decisions and author
  questions, ranked by severity. Also runs targeted reviews (scenario
  walkthrough, FMEA, ADR audit) and delta reviews. Triggers on 'architecture
  review', 'arch review', 'design review', 'review this design doc', 'review
  this RFC', 'is this architecture sound', 'production readiness review',
  'failure mode analysis', 'scenario walkthrough', 'ADR audit', 'review our
  ADRs', 'well-architected review'. For a security-only review use the
  threat-model skill; for line-level PR bugs use code-review.
---

# arch-review

An architecture review finds the **risks in the decisions** that are expensive
to reverse — not style, not line-level bugs. Every finding must trace back to a
quality attribute the business cares about, cite evidence, and say what to do.

Read-only throughout: never edit the reviewed code or doc, and never commit,
push, post or comment anywhere unless the user asks.

## 0. Pick the review type

From the request; if unclear and the target is a design doc or repo, default to
**Full**.

| Type                     | When                                              | How                                                                   |
| ------------------------ | ------------------------------------------------- | --------------------------------------------------------------------- |
| **Full**                 | New design, major change, pre-build gate          | All steps below, lenses in parallel                                   |
| **Lite**                 | Small design, single service change, < ~10 pages  | Steps 1–3 and 5, lenses applied inline by you, no subagents           |
| **Delta**                | A prior review exists for the same target         | Full or Lite, scoped to what changed; adds a Delta section            |
| **Scenario walkthrough** | Before a phase transition / launch                | One agent, [targeted.md](references/targeted.md#scenario-walkthrough) |
| **FMEA**                 | Before a launch or a reliability-sensitive change | One agent, [targeted.md](references/targeted.md#fmea)                 |
| **ADR audit**            | After a batch of decisions                        | One agent, [targeted.md](references/targeted.md#adr-audit)            |

Use Lite instead of Full when the target is small: the full fan-out is
expensive. Say which type you picked and why in one line.

## 1. Gather the target and context

- **Target**: a file path, repo, PR (`gh pr view/diff`), Google Doc, Confluence
  page, Linear doc or URL. Fetch it with the matching tool. If the user named
  nothing, look for a design doc in the cwd (`docs/`, `rfcs/`, `adr/`,
  `ARCHITECTURE.md`, `design*.md`) and confirm the pick.
- **Code**: if the design describes a system that exists (fully or partly),
  locate the repo(s). Claims in the doc that the code can confirm or refute are
  the highest-value evidence.
- **Prior reviews**: look in `docs/architecture-reviews/`, `docs/adr/` and the
  doc's own history. If one exists for this target, run in **Delta** mode
  against the newest.
- **Org context** (when the Glean or Confluence tools are available): search for
  related designs, sibling services, standards and earlier decisions the design
  should reuse or align with.

If there is no design artifact at all — only code — reverse-engineer a short
architecture summary first (components, data stores, external dependencies,
trust boundaries, deploy target) and review that. Say so in the report.

## 2. Pin drivers and quality-attribute scenarios

This is the step most reviews skip, and the one that makes findings defensible.
Write down:

1. **Business drivers** — what the system is for, who uses it, what success
   looks like, hard deadlines, regulatory scope (PHI/PII, SOC 2, HIPAA).
2. **Constraints** — fixed tech, team size, budget, platform mandates.
3. **Utility tree** — the 5–10 most important quality-attribute scenarios, each
   as _stimulus → environment → response → measure_, ranked (H/M/L) by business
   importance and by architectural difficulty. Example: "Upstream Burrow export
   times out (stimulus) during normal load (env); the run fails fast with a
   retryable error (response) within 30 s, no partial write (measure)."

Take these from the doc where stated; infer and label `(inferred)` where not.
Missing or vague NFRs are themselves a finding. If the drivers are genuinely
unknowable and change the review, ask the user (one question, with your inferred
defaults as the recommended option).

## 3. Verify claims against evidence

List the design's load-bearing claims ("X is stateless", "Y retries
idempotently", "Z is internal-only", "uses the platform's auth", counts, SLAs).
For each, check the code, config, IaC or linked docs and mark it ✅ verified, ❌
contradicted (cite where), or ❓ unverifiable. A contradicted claim is usually a
finding. Do this before the lenses run and pass the table to them.

## 4. Review through the lenses (Full / Delta)

If your harness can run read-only subagents in parallel (in Claude Code: the
Agent tool, `general-purpose`, `run_in_background: true`, all in one message),
launch one **read-only** subagent per lens. Otherwise apply each lens yourself,
one at a time, with the same inputs, brief and finding format, and keep each
lens's findings separate until step 5. Each gets: the target and its location,
the step 1–3 outputs, its lens brief and question bank from
[lenses.md](references/lenses.md), the finding format below, and — in Delta mode
— the prior report path with the instruction to classify each prior finding as
resolved / persists / worsened. Tell each to read sources itself and cite
file:line or doc section for every claim.

Lenses (drop any that clearly do not apply, e.g. Consumer for a batch job with
no callers; say which you dropped):

1. Design coherence & completeness
2. Systems fit (existing org systems, standards, reuse)
3. Reliability & operations (day 2)
4. Security & privacy — breadth only; recommend the **threat-model** skill for a
   full STRIDE
5. Performance, scalability & cost
6. Consumer / API ergonomics
7. Evolvability & simplicity
8. Devil's advocate — attack the top assumptions and argue the road not taken

Wait for all to finish before consolidating.

## 5. Consolidate

You are the consolidator, not a stapler. For every finding the agents return:

- **Re-verify** anything rated Major or Blocker in the source yourself. Drop or
  downgrade what does not hold up; mark what you re-verified with ✅.
- **Deduplicate** across lenses; note which lenses raised it (agreement raises
  confidence).
- **Tie** each to a utility-tree scenario or driver. A finding with no driver
  behind it is a nit or gets cut.
- **Classify** (ATAM vocabulary): _risk_ (a decision that may prevent a quality
  goal), _non-risk_ (a decision that is sound — record the important ones),
  _sensitivity point_ (a parameter a quality attribute hinges on), _tradeoff
  point_ (a decision that helps one quality and hurts another).
- **Group** risks into 3–6 **risk themes** — the systemic patterns behind
  individual risks (e.g. "no back-pressure anywhere on the ingest path").
- **Name missing decisions**: choices the design makes implicitly that deserve
  an ADR.
- Where lenses disagree, keep the disagreement as a **Key tension**, with both
  arguments.

### Finding format

```text
### [SEV] Title — lens(es)
**Type**: risk | tradeoff | sensitivity point
**Scenario**: which utility-tree scenario / driver it threatens
**Evidence**: doc §, file:line, config — what was observed (✅ if re-verified)
**Impact**: what goes wrong, for whom, how likely
**Recommendation**: the smallest change that addresses it; alternatives if real
**Confidence**: high | medium | low
```

Severity: **Blocker** (must resolve before build/launch — a driver cannot be
met, data exposure, irreversible decision on a wrong assumption), **Major**
(resolve before launch or accept explicitly with an owner), **Minor** (should
fix, low impact), **Nit**. Cap Nits at five.

## 6. Report

Fill [report-template.md](references/report-template.md). Lead with the verdict:
**Approve**, **Approve with conditions** (list them), or **Revise and
re-review**. Keep it decision-oriented: a reader who stops after the summary
must know what to do.

Where to put it:

- If the target repo has `docs/architecture-reviews/`, write
  `YYYY-MM-DD-<slug>-<type>.md` there (don't commit).
- Otherwise print the report in chat and offer to save it (repo path, Confluence
  page or Google Doc). Don't publish anywhere without the user asking.

Then reply with: verdict, counts by severity, the top 3 risks in one line each,
and the report path. Offer, without doing it: Linear tickets for
Blockers/Majors, ADR stubs for missing decisions, the threat-model skill if
security risks are prominent.

## Principles

- Review **decisions and their consequences**, not people or prose. Name
  tradeoffs honestly — most "problems" are tradeoffs someone chose; say whether
  the choice fits the drivers.
- **Evidence over opinion.** No finding without a citation; mark inference as
  inference.
- **Proportionate**: a 2-page change does not need eight agents or forty
  findings.
- **Record the non-risks** too — knowing what is sound stops it being
  relitigated.
- Prefer the **smallest fix** and the **reversible** path; flag one-way doors
  explicitly.
- Ask _what would have to be true_ for the design to work, then check whether it
  is.
