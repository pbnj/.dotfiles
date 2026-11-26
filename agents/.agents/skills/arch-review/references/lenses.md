# Review lenses

Each lens is a brief for one read-only subagent (or a pass you make yourself in
a Lite review). Every agent receives: the target and where it lives, the drivers
/ utility tree / claims table from SKILL.md steps 1–3, its brief below, and the
finding format. Every agent must:

- Read the sources itself; cite doc section or file:line for every claim.
- Never modify files, commit, or post anything.
- Return findings in the finding format, plus a short list of **non-risks**
  (sound decisions worth recording) and **open questions** for the authors.
- Stay in its lane; mention cross-lens issues in one line for the consolidator.

The questions are prompts, not a form to fill. Skip the ones that do not apply;
do not report "N/A" rows.

---

## 1. Design coherence & completeness

Role: the subject-matter expert who has read every page of the design and its
sub-specs.

- Does the design state the problem, goals, **non-goals**, and the requirements
  (functional and non-functional) it must meet? Are NFRs measurable?
- Does it hold together end to end? Trace the main request/data path from entry
  to persistence and back. Where does it become hand-wavy?
- Internal consistency: contradictions between sections, sub-specs, diagrams and
  code; stale numbers, counts, names.
- Are components' responsibilities clear and non-overlapping? Any component with
  no owner?
- Data model: sources of truth, ownership of each entity, consistency model,
  schema evolution, retention.
- Phasing and dependencies: is the plan sequenced so value and risk retirement
  come early? Are external dependencies on other teams explicit with dates?
- Are the alternatives considered real, and the chosen option's consequences
  (good and bad) stated?
- What open questions does the doc leave that block building?

## 2. Systems fit

Role: an engineer who knows the organization's existing systems, platforms and
standards.

- Integration assumptions: do the APIs, schemas, auth flows and SLAs it relies
  on match the real systems? Check the sibling repos and their docs.
- Reuse: does it rebuild something the org already has (auth, RBAC, queues,
  workflow engine, observability, asset storage, deploy tooling)? Does it ignore
  a paved road?
- Standards: language, framework, build, deploy (Helm/Argo/Terraform/Scalr),
  secrets, logging conventions — aligned with recent comparable services or a
  deliberate, justified divergence?
- Naming and terminology consistent with the codebase and domain?
- Platform constraints it must respect: network topology, IAM/IRSA, accounts,
  regions, cluster layout, data residency.
- Ownership: who runs each new shared component? Is another team being signed up
  implicitly?

## 3. Reliability & operations (day 2)

Role: the on-call engineer paged at 2 a.m. six months after launch.

- For each component and dependency: how does it fail, how is that detected,
  what degrades, how does it recover, how long does it take? Single points of
  failure?
- Timeouts, retries (with backoff and jitter), idempotency, circuit breakers,
  back-pressure, bulkheads. Do timeout chains nest correctly (caller > callee)?
- State and data: backups, restore tested, RPO/RTO stated, migrations
  zero-downtime and reversible, what happens when a migration fails halfway?
- Deploy and rollback: progressive delivery, feature flags, version skew between
  components, config drift between environments.
- Observability: SLIs/SLOs, dashboards, alerts tied to user impact, structured
  logs, traces, correlation IDs end to end. Can someone other than the author
  diagnose a failure?
- Runbooks for the predictable incidents; on-call ownership; toil this design
  creates (rotations, cleanups, manual replays).
- Capacity: sizing, autoscaling signals, quotas and limits of managed services.
- What does the first week in production look like? What will break first?

## 4. Security & privacy (breadth)

Role: security engineer with compliance awareness. Breadth only — flag areas
that need a full STRIDE threat model (recommend the `threat-model` skill) rather
than doing one.

- Trust boundaries: what crosses them, what is authenticated and authorized at
  each crossing? Service-to-service identity? Tenant isolation?
- Sensitive data (PHI, PII, secrets, credentials): where it is stored, logged,
  cached, traced, returned in errors; encryption in transit and at rest;
  minimization and retention.
- AuthN/AuthZ model: least privilege, where authorization decisions are made,
  fail-closed vs fail-open, token handling and rotation.
- Exposure: public endpoints, ingress, egress, SSRF paths, admin/debug surfaces.
- Secrets management, supply chain (pinning, image provenance, CI permissions).
- Audit trail sufficient for incident response and compliance (who did what,
  when, to which data)?
- AI components (models, agents, MCP servers, tools, RAG): prompt injection
  paths, tool permissions, untrusted content reaching privileged actions.

## 5. Performance, scalability & cost

Role: performance engineer who also owns the cloud bill.

- Expected load (requests, data volume, fan-out) stated? Growth assumptions?
  Peak vs average?
- Hot paths: synchronous chains, N+1 calls, chatty cross-service traffic, large
  payloads, unbounded queries or result sets.
- What breaks at 10×, 100× today's load? Which component saturates first? Is the
  scaling model horizontal and stateless where it needs to be?
- Caching: what, where, invalidation, stampede protection, staleness tolerance.
- Data growth: tables/buckets/queues that grow without bound; partitioning,
  retention, archival.
- Latency budget: does the end-to-end target survive the sum of its hops?
- Cost: dominant cost drivers, cost per unit of work, idle cost, cost at 10×;
  managed vs self-run tradeoff; anything priced per request that is called in a
  loop.
- Load or performance testing planned before launch?

## 6. Consumer / API ergonomics

Role: a developer on a team that has to integrate with this system.

- Is the contract (API, events, SDK, schema) what a consumer would design? Clear
  resources, verbs, errors, pagination, idempotency keys, async patterns
  (polling, webhooks, events)?
- Versioning and compatibility: how do breaking changes ship? Deprecation
  policy?
- Integration burden: how much consumer code changes? Migration path from the
  old system?
- Failure UX: what does the consumer see when things fail, and can they act on
  it? Are error codes stable and documented?
- Debuggability from outside: request/run IDs returned, status endpoints,
  self-serve logs.
- Documentation and onboarding: could a new team integrate without the authors'
  help?
- Autonomy: can consumers configure what they need without filing a ticket?

## 7. Evolvability & simplicity

Role: the engineer who inherits this in two years.

- Coupling and cohesion: module and service boundaries aligned with domain
  boundaries and team ownership (Conway's law)? Shared databases? Distributed
  monolith risk?
- Is the complexity proportional to the problem? Abstractions, layers, ports or
  services that exist for hypothetical futures?
- Which decisions are **one-way doors** (data formats, public APIs, vendor
  lock-in, storage engines)? Are they made deliberately and recorded as ADRs?
- Testability: can components be tested in isolation? Contract tests at
  boundaries?
- Fitness functions: which architectural properties should be guarded
  automatically in CI (dependency rules, latency budgets, schema compatibility,
  bundle size)?
- Bus factor and knowledge concentration: can the team operate and change it
  without its author?

## 8. Devil's advocate

Role: adversarial reviewer. Assume the design is wrong and find out where.

- List the 5–10 load-bearing assumptions. For each, argue why it might be false
  and what happens if it is.
- Over-engineering: what can be cut, deferred or bought instead of built? What
  is the thinnest version that delivers the first real value?
- Under-engineering: what is conspicuously missing (rate limits, quotas,
  multi-tenancy, migration, rollback, deletion)?
- For each major locked decision, make the best case for the road not taken.
- Org and delivery risk: cross-team dependencies, single-person ownership, two
  systems running in parallel for too long, timeline realism.
- **The hard question**: argue that a fundamentally different approach (extend
  an existing system, buy, don't build, do nothing) is better. Concede honestly
  if it is not.
