---
name: code-review
description: Review pull requests, diffs, and code changes with an emphasis on clean architecture (SOLID/DRY), correctness, readability/organization, tests, and public API documentation (docblocks). Also evaluate error handling, performance (when relevant), dependency hygiene, security/privacy, and operability. Use when the user asks for a code review, PR review, review notes, or validation of code/design before opening a GitHub PR. Produce evidence-backed notes and a final Verdict (APPROVE, REQUEST_CHANGES, or COMMENT_ONLY) using a question-first tone; prefix purely stylistic feedback with "Nit: ".
---

# Code review

## Voice & tone
- Prefer questions over accusations when intent is unclear.
- Use examples: "What invariant makes this safe?" / "How does this compare to <alternative>?"
- For purely stylistic/pedantic feedback, prefix with `Nit: `.

## Evidence requirement
Every note must cite evidence. Prefer:
- `<path>:<startLine>-<endLine>`
Fallback when line numbers are unavailable:
- `<path> — <symbol>` — "<quoted snippet>"

If you cannot cite evidence, ask for context rather than speculating.

## What to review (priority order)
1. **Correctness**: logic, edge cases, data invariants, nullability, time/timezones, ordering, idempotency, concurrency/races (if relevant).
2. **Architecture**: boundaries/layering, responsibilities, coupling/cohesion, code smells, avoiding duplication, consistency with existing patterns.
3. **Readability**: clear naming, small do-one-thing functions, logical organization, files in the right places, coherent module structure.
4. **Tests**: tests exist, validate behavior (not implementation), cover edge cases/regressions, readable and intention-revealing.
5. **Documentation**: public API docblocks; docblocks for complex internal interfaces/logic where they add clarity.
6. **Error handling & reliability**: actionable errors, safe defaults, timeouts, retries/backoff where appropriate; no sensitive leakage.
7. **Security & privacy**: authz boundaries, input validation, injection surfaces, secrets handling, PII logging.
8. **Dependencies**: new deps justified, avoids duplication, aligns with stack conventions.
9. **Performance**: only when evidence suggests risk (N+1, extra round trips, large loops, heavy allocations).
10. **Operability**: logs/metrics/tracing, debuggability, rollout/migration safety, feature flags where needed.

## Documentation standard (TypeScript + Python)
- **Docblocks required** for public API artifacts:
  - TypeScript: exported functions/classes/types/interfaces; externally consumed modules.
  - Python: public functions/classes/modules in the supported surface area.
- For complex internal interfaces or non-obvious logic, docblocks/docstrings are strongly encouraged.
- Docblocks should cover: purpose, key invariants/constraints, inputs/outputs, error cases, and examples when helpful.

## Output format (use exactly this shape)
### 1) Executive summary
- 3–6 bullets: intent, risk areas, and the biggest findings.

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
  - **Evidence**: `<path>:<line>-<line>` OR `<path> — <symbol> — "<snippet>"`
  - **Why it matters**: <impact on correctness / design / readability / testability / safety / ops>
  - **Comment**: <question-first phrasing; propose a concrete alternative when appropriate>

Rules:
- If it's purely stylistic, the **Comment** line must start with `Nit: `.
- Prefer minimal, staged refactors (what to do now vs later) over large rewrites.
- Omit empty groups.

## "Stay quiet" guidance
- Don't bikeshed formatting unless it materially affects readability or violates established repo conventions.
- Don't propose new abstractions unless they reduce complexity and are consistent with the codebase direction.
