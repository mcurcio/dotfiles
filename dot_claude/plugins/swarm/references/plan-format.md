# Canonical Plan Document Format

This is the required structure for plan documents produced by `swarm:plan` and consumed by `swarm:implement`. Both skills reference this format — changes here affect the entire pipeline.

## Scaling Principle

Plan detail scales with project tier (see `references/complexity-scaling.md`). The structure below is the **maximum** — small-tier projects use the compact variant, medium-tier uses the standard structure, large-tier uses full detail.

**The implementer already has the design spec.** Phase specs should reference upstream documents for interface contracts and type definitions rather than restating them. The plan's job is to specify: what to build (file list), in what order (dependencies), how to verify (commands), and what's off-limits (scope boundaries). Not to re-derive the architecture.

## Required Structure

```markdown
# [Feature Name] Implementation Plan

**Goal:** [One sentence describing what this builds]
**Spec:** [Path to the design spec this plan implements]
**Requirements:** [Path to the approved requirements document]
**Date:** [YYYY-MM-DD]

---

## Flow Model

Phase dependencies listed here. Determines execution order for `swarm:implement`.

- Phase 1: [name] — no dependencies
- Phase 2: [name] — blocked by Phase 1
- Phase 3: [name] — no dependencies (parallel with Phase 2)
- Phase 4: [name] — blocked by Phase 2, Phase 3

---

## Phase 1: [Phase Name]

### Deliverables

What exists when this phase is done. Concrete artifacts, not vague goals.

- [Deliverable 1]
- [Deliverable 2]

### Requirements Traceability

Which acceptance criteria from the requirements document this phase satisfies. Use the `REQ-N` / `AC-N.M` identifiers assigned by the requirements agent.

- REQ-1: [requirement name] — AC-1.1, AC-1.2
- REQ-2: [requirement name] — AC-2.1

### Workstreams

Independent threads of work within this phase. Each workstream becomes one implementer agent.

#### Workstream 1: [Name]

**Agent type:** ts-implementer | infra-implementer
**Files:**
- Create: `/absolute/path/to/new-file.ts`
- Modify: `/absolute/path/to/existing-file.ts`
- Test: `/absolute/path/to/test-file.test.ts`

**Tasks:**
1. [Specific task with enough detail for an agent with zero context]
2. [Next task]
3. [...]

#### Workstream 2: [Name]

(Same structure as Workstream 1)

### Verification Criteria

Specific commands and expected outputs that confirm this phase is done.

```bash
# Build check
npm run build
# Expected: exits 0, no errors

# Test check
npm run test -- --filter="phase-1-related"
# Expected: all tests pass

# Behavioral check
[specific checks for correct state transitions, error codes, event shapes]
```

### Scope Boundaries

Files and concerns explicitly OUT of scope for this phase. Implementation agents must not modify these.

- `/absolute/path/to/out-of-scope-file.ts` — belongs to Phase 3
- [concern] — deferred to Phase N

---

## Phase 2: [Phase Name]

(Same structure as Phase 1)

---

## Phase N: [Phase Name]

(Same structure as Phase 1)
```

## Compact Variant (Small Tier)

Same file structure as standard (manifest, dag, phase specs, team-shapes, traceability) — each triad member still produces their own output. What changes is the **content density** of each file.

**Phase spec target:** ~40-80 lines, not 200-350. Achieve this by:
- Tasks describe WHAT to build, not HOW (no method signatures, no constructor args — those are in the design spec)
- Write `"Implement AuthProvider interface per spec §3.2"` not 50 lines of method signatures
- Traceability is a concise table, not a per-AC narrative
- Team-shapes is a simple table without ASCII art or isolation narratives

**Key rule:** Don't restate interface contracts from the code-design spec. The implementer reads the spec directly.

## Standard Variant (Medium Tier)

Full structure as documented below, with separate files for DAG, phase specs, team-shapes, and traceability. Phase specs include file tables, task lists with enough context for zero-context agents, and verification gates.

## Full Variant (Large Tier)

Standard structure plus:
- Integration notes between phases (what downstream phases depend on from this phase's output)
- Cross-team coordination notes (if multiple teams)
- Detailed workstream isolation rules (read/write access per agent)

---

## Rules

1. **All file paths must be absolute.** No `~`, no `$HOME`, no relative paths.
2. **Each workstream must be self-contained.** An agent reading only that workstream section should know what to build and how to verify it.
3. **Verification criteria must be runnable commands.** No "ensure it works" — specify the exact command and expected output.
4. **Scope boundaries must list specific files.** Not "don't touch other phases" — list the actual paths that are off-limits.
5. **The flow model must be parseable.** Each line follows the pattern: `Phase N: [name] — [dependency clause]`. Dependency clauses are one of: `no dependencies`, `blocked by Phase N`, `blocked by Phase N, Phase M`.
6. **Every phase must have a Requirements Traceability section.** Each acceptance criterion must appear in at least one phase. No orphaned criteria.
7. **Don't restate upstream design.** Reference the spec by section for interface contracts, type definitions, and implementation notes. The plan adds: build order, file assignment, verification commands, scope boundaries.

## Parsing Notes for swarm:implement

To parse a plan document:
1. Find the `## Flow Model` section. Each `- Phase N:` line defines a phase and its dependencies.
2. For each phase, find `## Phase N: [Name]`. The content between this heading and the next `## Phase` heading (or end of file) is the phase specification.
3. Within each phase, find `#### Workstream N: [Name]` to identify individual agent assignments.
4. The `### Verification Criteria` section contains the convergence checks for the replacement loop.
