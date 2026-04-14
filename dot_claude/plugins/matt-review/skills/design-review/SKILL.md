---
name: design-review
description: This skill should be used when the user asks to "review a design", "review this proposal", "check this ADR", "review this RFC", "architecture review", "validate this approach", "review this design doc", "check this architecture", or when analyzing design documents, proposals, ADRs, RFCs, and architecture changes for quality, completeness, and risk.
---

# Design Review

Review design docs, proposals, ADRs/RFCs, and architecture changes with a design-first lens. Focus on decision quality, not implementation detail.

## Voice and Tone

- Prefer curious questions over negative assertions.
- When something is unclear: "Why this approach over X?" / "What invariant makes this safe?" / "How does this handle failure of Y?"
- Prefix purely stylistic feedback with `Nit: `.

## Evidence Requirement

Every note must cite evidence. Preferred forms:
- **Section evidence**: `<doc> — <section heading>` + a short quote
- **Decision evidence**: a quoted statement of the decision or assumption being addressed

If the doc lacks enough detail to cite, ask for the missing detail instead of speculating.

## Review Checklist (Priority Order)

1. **Correctness assumptions** — invariants, inputs/outputs, failure modes, data integrity, ordering/timezones, idempotency, concurrency.

2. **Architecture** — clear boundaries/layering, responsibilities in the right place, coupling/cohesion, avoiding duplication, elegant/clean design.

3. **Tradeoffs** — alternatives considered, why this option, what is explicitly out of scope.

4. **API and contracts** — public surface area, compatibility/breaking changes, versioning, migration plan.

5. **Rollout and safety** — feature flags, backwards compatibility, deploy order, rollback story, migrations/backfills.

6. **Tests as contract** — how behavior will be validated; what tests will prove the design in practice.

7. **Error handling and reliability** — timeouts, retries/backoff, graceful degradation, actionable errors.

8. **Security and privacy** — auth boundaries, input validation, secrets handling, PII logging.

9. **Operability** — logs/metrics/tracing, debuggability, on-call friendliness, SLO impact.

10. **Performance** — only when the design plausibly changes a hotspot; call out expected cost drivers.

11. **Dependencies** — new deps justified; avoid introducing one-off patterns that fragment the codebase.

## Output

Return findings as a structured list. Each finding includes:
- **Category**: Q (question), F (fix before merge), S (suggestion), N (nit), G (good)
- **Title**: short description
- **Evidence**: `<doc> — <section>` — "quote"
- **Comment**: question-first phrasing; propose a concrete alternative or next step when helpful

The review orchestrator handles final formatting and verdict. Return raw findings only.

## Stay Quiet

- Focus on decision-quality gaps and high-leverage improvements.
- Do not bikeshed formatting unless it materially affects comprehension.
- Do not recommend a large rewrite unless the risk reduction justifies it over a smaller step.
