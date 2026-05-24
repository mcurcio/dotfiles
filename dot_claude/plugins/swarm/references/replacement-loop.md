# Replacement Loop Protocol

The replacement loop drives implementation to convergence within each phase, combined with the per-phase triad lifecycle (pre-flight → replacement → post-review).

## Why It Works

Fresh teams catch drift, gaps, and accumulated assumptions. The team that wrote the code cannot see what it assumed — a fresh team with zero prior context can. One unnecessary rotation is cheap vs. shipping a drifted implementation.

## Per-Phase Lifecycle

```
┌──────────────────────────────────────────────────────────┐
│  Phase N                                                  │
│                                                           │
│  1. SPAWN: Fresh triad spawns for Phase N                │
│                                                           │
│  2. PRE-FLIGHT: Triad evaluates plan + upstream deltas   │
│     ├─ "Proceed" → use original proposal                 │
│     └─ Correction → 1-round coordination loop            │
│        └─ Disagreement → escalate to human               │
│                                                           │
│  3. REPLACEMENT LOOP:                                     │
│     ┌────────────────────────────────────────────────┐   │
│     │  a. Spawn implementation team                  │   │
│     │  b. Team builds against canonical proposal     │   │
│     │  c. Team reports done → shut down              │   │
│     │  d. Spawn fresh replacement team               │   │
│     │  e. Replacement checks:                        │   │
│     │     ├─ "No work to do" → CONVERGED             │   │
│     │     └─ Work remaining → do it, go to (d)       │   │
│     └────────────────────────────────────────────────┘   │
│                                                           │
│  4. POST-REVIEW: Triad reviews code patch                │
│     ├─ "Proceed" → phase complete                        │
│     ├─ "Adjust downstream" → write delta, complete       │
│     └─ "Escalate" → architecture divergence              │
│                                                           │
│  5. DESTROY: Triad destroyed at phase completion         │
└──────────────────────────────────────────────────────────┘
```

## Pre-Flight

- **Trigger:** Orchestrator about to begin Phase N
- **Reads:** Phase N plan proposal + downstream deltas from upstream phases
- **Question:** "Is this plan still correct given upstream deltas?"
- **Fast path:** "Proceed, no changes needed" → zero-cost pass-through
- **Slow path:** 1-round coordination loop (code-arch leads, sys-arch + reqs react) → corrected proposal
- **Failure:** Any reactor ITERATING on correction → escalate to human
- **Correction scope:** Bounded adjustments only (file reassignments, interface tweaks, added test cases). Fundamental restructuring → escalate.
- **DAG-invalidation check:** Correction produced → orchestrator checks running parallel phases for impact. Affected → pause.

## Replacement Loop

### Proposal Stability

Canonical proposal (original or pre-flight-corrected) is FROZEN during the replacement loop. If teams can't converge after 5 rounds, escalate.

### The Loop

1. Spawn implementation team per plan's team shape
2. Feed canonical proposal (self-contained prompts)
3. Team runs all tests — must pass before reporting done
4. Team reports done → shut down
5. Spawn fresh replacement team (same proposal, zero prior context)
6. Replacement verifies: implementation matches proposal, tests pass, build clean
   - "No work to do" → CONVERGED
   - Work remaining → do it, shut down, go to step 5

### Convergence

Team N done + fresh team N+1 confirms "no work to do" = two-adjacent met.

### Oscillation Detection

Replacement team undoes prior team's work (visible in reports or git diffs) → escalate immediately. Proposal is ambiguous.

### Escalation Sequence

1. Per-phase triad gets one clarification attempt (alive with context)
2. Triad converges on correction (1 round max) → restart replacement loop with new proposal, counter resets
3. Triad can't clarify or oscillation recurs → escalate to human

### Safety Rails

- Max 5 replacement teams per phase
- No cross-phase bleed — each phase operates only on its files/scope
- Conflict detection → escalate as spec ambiguity

## Post-Review

Single-round coordination loop after phase converges. Code-arch leads; sys-arch and requirements react.

### Inputs (orchestrator provides)

- Full code patch (git diff of all phase changes)
- Phase 2 output (architecture doc — `iterations/architecture/latest/`)
- Phase 3 output (code design — `iterations/code-design/latest/`)
- Phase N's plan spec
- Test suite results (orchestrator runs tests, provides output)

### Member Focus

| Member | Focus | Tolerance |
|---|---|---|
| requirements | Acceptance criteria mapped to this phase are satisfied | Strict |
| sys-arch | Boundary integrity, contract shapes, service responsibilities vs architecture doc | Strict |
| code-arch | Module structure, dependency graph, interfaces vs code design | Forgiving — adaptations preserving module contract are expected |

### Divergence Classification

| Type | Example | Action |
|---|---|---|
| Within module boundaries (additive) | Interface gained a field; helper added; error type expanded | Normal. Downstream delta if affects later phases. |
| Architecture divergence (breaking) | Module boundary moved; service contract changed shape; responsibility shifted | Escalate. |

**Threshold:** Would Phase 2 or Phase 3 output need updating to remain accurate? Yes → architecture divergence.

**Tiebreaker:** sys-arch wins. If sys-arch says "escalate," it escalates.

### Outputs

- **"Proceed"** → phase complete. Destroy triad.
- **"Adjust downstream"** → produce downstream delta targeting dependency-downstream phases only. Destroy triad.
- **"Escalate"** → orchestrator presents divergence to user, recommends design stage re-entry.

### Downstream Delta

Self-contained document with per-target-phase sections. Each section:
- What changed (concrete)
- Literal type/interface changes
- What downstream phase should do differently
- Which plan artifacts are stale

Deltas target only dependency-downstream phases (per DAG), never parallel phases.

## Implementation Team Composition

- `ts-implementer` for TypeScript/Node.js
- `infra-implementer` for Python, Bash, Docker, YAML, Makefile
- 1-3 implementers per team, matched to workstreams in proposal
- `model: "sonnet"` — implementers execute a frozen spec with explicit paths and verification; opus reserved for triad judgment work

## Subteam Prompts

Every prompt includes:
- Canonical phase proposal (full text if <4000 words, else summary + file path)
- Files to read and modify (absolute paths)
- Verification commands (specific test/build)
- Scope boundary (no modifications outside phase scope)
- Communication protocol (report via SendMessage to orchestrator)

## File Conventions

**`replacement/status.json`:**
```json
{
  "converged_at_team": 2,
  "total_teams": 2,
  "produced_at": "2026-05-07T14:30:00Z"
}
```

**`post-review/status.json`:**
```json
{
  "signal": "proceed",
  "classification": "within-boundaries",
  "produced_at": "2026-05-07T14:30:00Z"
}
```

## Per-Phase Triad Briefing

At spawn, all members receive:
- Phase N's plan spec (or pre-flight-corrected version)
- All downstream deltas targeting Phase N
- Path to Phase 2 output (architecture)
- Path to Phase 3 output (code design)
- Phase N's DAG position

| Role | Additional Context |
|---|---|
| requirements | Acceptance criteria mapped to this phase, behavioral test cases |
| sys-arch | Architecture boundaries relevant to this phase, contracts to satisfy |
| code-arch | Module assignments, file lists, dependency constraints, verification commands |
