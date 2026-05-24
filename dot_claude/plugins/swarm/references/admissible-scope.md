# Admissible Scope Block Contract

Zoom-level-scoped feedback filtering for design, plan, and implement skills. All three skill files reference this document when composing scope blocks for triad agent prompts.

## Zoom-to-Phase Mapping

| Zoom Level | Phase | Skill File |
|---|---|---|
| Boundary | Design: Requirements (Phase 1) + Architecture (Phase 2) | `swarm/skills/design/SKILL.md` |
| Structural | Design: Code Design (Phase 3) + Plan Synthesis (Phase 4) | `swarm/skills/design/SKILL.md`, `swarm/skills/plan/SKILL.md` |
| Granular | Implementation (Phase 5) | `swarm/skills/implement/SKILL.md` |

All agents zoom at the same level simultaneously, progressing with the phase. Code Design (Phase 3) uses Structural zoom because module decomposition and interfaces are code-arch's primary output — deferred from Boundary.

## Block Structure Contract

### Boundary and Structural Zoom Levels

```markdown
## Admissible Scope
Current zoom: [Boundary | Structural]

**In-scope** (raise these concerns):
[bullet list — role-specific, from per-role tables below]

**Deferred** (these become in-scope at [next zoom level]):
[bullet list — role-specific, from per-role tables below]

Concerns outside the in-scope list: note them if critical to your domain,
but do not elaborate or argue for them. They will be addressed at the
appropriate zoom level.
```

### Granular Zoom Level

```markdown
## Admissible Scope
Current zoom: Granular

All concerns are in-scope. No filtering at this zoom level.
```

## Block Placement Rule

Insert the scope block **after** role-specific instructions and **before** output directory instructions in every triad prompt composition point.

## Leader vs. Reactor Distinction

| Role | What the Block Constrains |
|---|---|
| Leader | **Editorial judgment** — topics addressed and output produced |
| Reactor | **Feedback scope** — domain of concerns raised in reaction |

## Per-Role Admissible/Deferred Tables

### Boundary Zoom (Design Phase)

**requirements:**
- In-scope: Success criteria themes, scope boundaries, ambiguity in domain ownership
- Deferred (Structural): Detailed Given/When/Then, specific test assertions

**sys-arch:**
- In-scope: Service boundaries, protocol choices, failure domains, data ownership, structural feasibility
- Deferred (Structural): Specific error codes, retry policies, circuit breaker details

**code-arch:**
- In-scope: Feasibility validation — coupling that blocks independent deployment, scope that implies shared dependencies blocking parallel work, boundaries untestable without a major harness, dependency risks, deployment blockers
- Deferred (Structural): Module decomposition, file lists, build sequencing, workstream design, naming conventions, type signatures, interface shapes, module internals

### Structural Zoom (Planning Phase)

**requirements:**
- In-scope: Detailed acceptance criteria per phase, Given/When/Then test cases, phase-level "done" definitions
- Deferred (Granular): Specific assertion syntax, mock strategy details

**sys-arch:**
- In-scope: Component decomposition, interface contract shapes, integration test boundaries, failure mode handling per phase
- Deferred (Granular): Specific error message strings, retry timing values

**code-arch:**
- In-scope: Full module decomposition, workstream design, build sequence, dependency graph, file lists (absolute paths), test architecture, module ergonomics, interface shapes. Primary constructive phase — module design deferred from Boundary.
- Deferred (Granular): Variable names, function signatures, code style, implementation details

### Granular Zoom (Implementation Phase)

All concerns are in-scope. No per-role filtering.

## Who Gets Scope Blocks

Triad members only: `requirements`, `sys-arch`, `code-arch`. Not injected for: `ts-implementer`, `infra-implementer`, replacement teams.

## Invariants

Scope blocks are **advisory** — they shape agent focus, not hard enforcement. They affect none of:
- Manifest format
- Convergence evaluation
- Orchestration flow
- Coordination loop leadership rotation or fresh-agent-per-round pattern
