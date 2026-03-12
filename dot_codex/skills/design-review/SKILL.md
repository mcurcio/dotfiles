---
name: design-review
description: Review design docs, proposals, ADRs/RFCs, and architecture changes with a design-first lens focused on clean architecture (SOLID/DRY), correctness assumptions, tradeoffs, boundaries/layering, risk/rollout, documentation quality, tests-as-contract, error handling, performance, dependencies, security/privacy, and operability. Use when the user asks to review a design, proposal, ADR, RFC, architecture, or to validate a solution approach before implementation or before opening a PR. Produce evidence-backed, question-first notes and a final Verdict (APPROVE, REQUEST_CHANGES, or COMMENT_ONLY). Prefix purely stylistic feedback with "Nit: ".
---

# Design review

## Voice & tone
- Prefer curious questions over negative assertions.
- When something is unclear, ask: "Why did you choose to do it like this?" / "How is this better than <alternative>?" / "What invariant makes this safe?"
- If feedback is purely stylistic/pedantic, prefix with `Nit: `.

## Evidence requirement
Every note must cite evidence. Prefer one of:
- **Section evidence**: `<doc> — <section heading>` + a short quote.
- **Decision evidence**: a quoted statement of the decision or assumption you are reacting to.
- If the doc lacks enough detail to cite, ask for the missing detail instead of speculating.

## What to review (priority order)
1. **Correctness assumptions**: invariants, inputs/outputs, failure modes, data integrity, ordering/timezones, idempotency, concurrency (if relevant).
2. **Architecture**: clear boundaries/layering, responsibilities in the right place, coupling/cohesion, avoiding duplication, elegant/clean design.
3. **Tradeoffs**: alternatives considered, why this option, what is explicitly out of scope.
4. **API & contracts**: public surface area, compatibility/breaking changes, versioning, migration plan.
5. **Rollout & safety**: feature flags, backwards compatibility, deploy order, rollback story, migrations/backfills.
6. **Tests as contract**: how behavior will be validated; what tests will prove the design in practice.
7. **Error handling & reliability**: timeouts, retries/backoff, graceful degradation, actionable errors.
8. **Security & privacy**: auth boundaries, input validation, secrets handling, PII logging.
9. **Operability**: logs/metrics/tracing, debuggability, on-call friendliness, SLO impact.
10. **Performance**: only when the design plausibly changes a hotspot; call out expected cost drivers.
11. **Dependencies**: new deps justified; avoid introducing one-off patterns that fragment the codebase.

## Output format (use exactly this shape)
### 1) Executive summary
- 3–6 bullets: intent, key decisions, biggest risks, and the top recommendations.

### 2) Verdict
- `Verdict: APPROVE | REQUEST_CHANGES | COMMENT_ONLY`
- 1–2 sentences on why.

### 3) Notes (grouped & numbered)
Use these groups in order. Number each item with its category prefix:

| Group | Prefix |
|:--|:--|
| Questions | Q1, Q2, … |
| Fix before merge | F1, F2, … |
| Suggestions | S1, S2, … |
| Nits | N1, N2, … |
| What's good | G1, G2, … |

Each note must use this template:
- **<Prefix>. <Short title>**
  - **Evidence**: `<doc> — <section>` — "<quote>"
  - **Why it matters**: <impact on correctness / design clarity / safety / ops>
  - **Comment**: <question-first phrasing; propose a concrete alternative or next step when helpful>

Rules:
- Omit empty groups.

## "Stay quiet" guidance
- Don't ask for perfection: focus on decision-quality gaps and high-leverage improvements.
- Don't bikeshed formatting unless it materially affects comprehension.
- Don't recommend a large rewrite unless you can justify the risk reduction vs a smaller step.
