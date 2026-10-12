# Design & Architecture

> **When to read this:** When designing, building, or reviewing modules, services, APIs, or system architecture. This is not limited to formal reviews — it applies any time you are making structural decisions about code.

## When This Applies

- **Implementation**: designing new modules, services, or multi-file features
- **Architecture decisions**: choosing boundaries, interfaces, data flow, or service scope
- **Code review**: when a PR introduces new directories, service boundaries, or domain model changes
- **Design review**: evaluating design documents, proposals, ADRs, RFCs
- **Cross-cutting changes**: auth, infra, rollout, shared libraries
- User explicitly asks for "design review", "architecture review", "check this ADR/RFC"

## Design Review Checklist (Priority Order)

1. **Correctness assumptions** — invariants, inputs/outputs, failure modes, data integrity, ordering/timezones, idempotency, concurrency.
2. **Architecture** — clear boundaries/layering, responsibilities in the right place, coupling/cohesion, avoiding duplication, elegant/clean design.
3. **Tradeoffs** — alternatives considered, why this option, what is explicitly out of scope.
4. **API and contracts** — public surface area, compatibility/breaking changes, versioning, migration plan.
5. **Rollout and safety** — feature flags, backwards compatibility, deploy order, rollback story, migrations/backfills.
6. **Tests as contract** — how behavior will be validated; what tests prove the design in practice.
7. **Error handling and reliability** — timeouts, retries/backoff, graceful degradation, actionable errors.
8. **Security and privacy** — auth boundaries, input validation, secrets handling, PII logging.
9. **Operability** — logs/metrics/tracing, debuggability, on-call friendliness, SLO impact.
10. **Performance** — only when the design plausibly changes a hotspot; call out expected cost drivers.
11. **Dependencies** — new deps justified; avoid introducing one-off patterns that fragment the codebase.

## Voice and Tone

- Prefer curious questions over negative assertions: "Why this approach over X?" / "What invariant makes this safe?" / "How does this handle failure of Y?"
- `Nit:` prefix for purely stylistic feedback.

## Evidence Requirement

Every finding must cite evidence:
- Preferred: `<doc> — <section heading>` + a short quote
- Fallback: a paraphrase of the decision or assumption being addressed

If the doc lacks enough detail to cite, ask for the missing detail rather than speculating.

## Output

Return findings as a structured list. Each finding includes:
- **Category**: Q (question), F (fix before merge), S (suggestion), N (nit), G (good)
- **Title**: short description
- **Evidence**: `<doc> — <section>` — "quote"
- **Comment**: question-first phrasing; propose a concrete alternative or next step when helpful

## Stay Quiet

- Focus on decision-quality gaps and high-leverage improvements.
- Do not bikeshed formatting unless it affects comprehension.
- Do not recommend a large rewrite unless the risk reduction justifies it over a smaller step.
