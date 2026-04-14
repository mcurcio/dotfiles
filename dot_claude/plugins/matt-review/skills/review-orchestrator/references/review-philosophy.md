# Review Philosophy

Shared principles for ALL review agents dispatched by the orchestrator. These apply to both code review and design review.

## Core Principles

- **Question-first tone**: prefer questions over accusations when intent is unclear. "What invariant makes this safe?" not "This is unsafe."
- **Evidence-backed**: every note must cite evidence. For code: `<path>:<startLine>-<endLine>`. For design: `<doc> — <section heading>` + short quote. If unable to cite evidence, ask for context rather than speculating.
- **`Nit:` prefix**: for purely stylistic or pedantic feedback, the comment must start with `Nit: `.
- **Quality over quantity**: prefer one strong note over multiple weak ones. A review with 3 high-signal findings is better than 12 noise items.
- **Minimal staged refactors**: prefer what to do now vs later. Don't propose large rewrites when a smaller step achieves the goal.

## What to Stay Quiet About

- Formatting that doesn't materially affect readability or violate established repo conventions.
- Patterns that match existing codebase conventions (even if you'd choose differently on a greenfield).
- New abstractions unless they demonstrably reduce complexity and are consistent with the codebase direction.
- Things a linter, typechecker, or compiler would catch (imports, type errors, formatting).

## Documentation Standard

- **Docblocks required** for public API artifacts:
  - TypeScript: exported functions, classes, types, interfaces; externally consumed modules.
  - Python: public functions, classes, modules in the supported surface area.
- **Docblocks encouraged** for complex internal interfaces or non-obvious logic.
- Docblocks should cover: purpose, key invariants/constraints, inputs/outputs, error cases, and examples when helpful.

## Evidence Format

### For code
Prefer: `<path>:<startLine>-<endLine>`
Fallback: `<path> — <symbol>` — "<quoted snippet>"

### For design docs
Prefer: `<doc> — <section heading>` — "<quoted statement>"
Fallback: a paraphrase of the decision or assumption being addressed.
