# Report template

Fill every section; write "None" rather than deleting one. Omit the Delta
section when there is no prior review. Keep per-lens detail out of the main body
— put it in the appendix.

```markdown
# Architecture review: <system / design name>

**Date**: YYYY-MM-DD · **Type**: Full | Lite | Delta | … · **Reviewer**: Claude
(arch-review) **Target**: <doc link / repo@commit / PR> · **Prior review**:
<path or "none"> **Lenses**: <run> · <dropped, and why>

## Verdict

**Approve | Approve with conditions | Revise and re-review**

<2–4 sentences: what the design is, whether it meets its drivers, the one or two
things that decide the verdict.>

Conditions (if any):

1. …

| Blocker | Major | Minor | Nit |
| ------- | ----- | ----- | --- |
| n       | n     | n     | n   |

## Drivers and quality-attribute scenarios

<business drivers, constraints>

| #   | Quality attribute | Scenario (stimulus → env → response → measure) | Importance | Difficulty |
| --- | ----------------- | ---------------------------------------------- | ---------- | ---------- |

## Claims checked

| Claim | Source   | Result       | Evidence  |
| ----- | -------- | ------------ | --------- |
| …     | doc §3.2 | ✅ / ❌ / ❓ | file:line |

## Risk themes

1. **<theme>** — <one paragraph; which findings roll up into it>

## Findings

<Blockers first, then Major, Minor, Nit. Finding format from SKILL.md.>

## Tradeoff and sensitivity points

| Decision / parameter | Helps | Hurts | Fits the drivers? |
| -------------------- | ----- | ----- | ----------------- |

## Key tensions

<where lenses disagreed; both arguments; your call and why>

## Non-risks

- <sound decisions worth recording, with the reason>

## Missing decisions (ADR candidates)

- <suggested ADR title> — <why it needs recording>

## Questions for the authors

1. …

## Delta from last review

| Prior finding | Status (resolved / persists / worsened) | Note |
| ------------- | --------------------------------------- | ---- |

New since last review: …

## Actions

- [ ] Before build: …
- [ ] Before launch: …
- [ ] Later: …

## Appendix: lens reports

<each lens's full output, lightly edited>
```
