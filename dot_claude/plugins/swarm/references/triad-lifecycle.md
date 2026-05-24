# Triad Lifecycle Management

The advisory triad (requirements + system-architect + code-architect) operates in two modes depending on swarm phase.

## Two Modes

### Mode 1: Fresh-Per-Round (Phases 1-4: Design + Plan)

Every agent spawns fresh per round. Persisted files are the context.

- Leader: fresh each round, reads prior output + reactor feedback
- Reactors: fresh each round, read leader's current output
- All agents shut down after the round completes
- Applies to all four loops: requirements, architecture, code design, plan synthesis

### Mode 2: Per-Phase Persistent (Phase 5: Implementation)

Fresh triad spawns at Phase N start, persists across all replacement iterations, destroyed when the phase completes.

**Lifecycle:**
1. **Spawn** — orchestrator spawns fresh triad at Phase N start
2. **Pre-flight** — triad evaluates plan proposal + upstream deltas (1 round max)
3. **Passive during replacement** — alive but idle; available if clarification is triggered
4. **Clarification (if triggered)** — oscillation/cap hit → triad gets one attempt to correct the proposal
5. **Post-review** — triad reviews converged code patch (1-round loop, code-arch leads)
6. **Destroy** — after post-review completes

No cross-phase persistence. The triad that writes a downstream delta is not the triad that reads it.

## Spawning

Spawn all three agents in a single message (parallel):

```
Agent({
  name: "reqs",
  subagent_type: "requirements",
  mode: "bypassPermissions",
  model: "opus",
  run_in_background: true,
  prompt: "<self-contained prompt>"
})

Agent({
  name: "sys-arch",
  subagent_type: "system-architect",
  mode: "bypassPermissions",
  model: "opus",
  run_in_background: true,
  prompt: "<self-contained prompt>"
})

Agent({
  name: "code-arch",
  subagent_type: "code-architect",
  mode: "bypassPermissions",
  model: "opus",
  run_in_background: true,
  prompt: "<self-contained prompt>"
})
```

Required parameters:
- `model: "opus"` — leaders (always); reactors in medium/large tier or after any reactor declared ITERATING
- `model: "sonnet"` — small-tier default reactors (upgrade to Opus if any reactor ITERATING); rubber-stamp re-run reactors (small/medium tier); implementers (ts-implementer, infra-implementer) — they execute frozen specs, not judgment calls
- See `references/complexity-scaling.md` § Model Selection for the authoritative per-tier table
- `mode: "bypassPermissions"` — always
- `run_in_background: true` — always for team agents

## Per-Phase Triad Briefing (Mode 2)

**All members receive:**
- Phase N's plan spec (or pre-flight-corrected version)
- All downstream deltas targeting Phase N
- Path to Phase 2 output (architecture doc — `iterations/architecture/latest/`)
- Path to Phase 3 output (code design — `iterations/code-design/latest/`)
- Phase N's DAG position (what completed before it, what depends on it)

**Role-specific additions:**
- **requirements:** Acceptance criteria mapped to this phase, behavioral test cases
- **sys-arch:** Architecture boundaries relevant to this phase, contracts to satisfy
- **code-arch:** Module assignments, file lists, dependency constraints, verification commands

## Prompt Requirements

Every triad prompt must be self-contained:
- Agent's role
- Specific work: absolute file paths, what to read, what to produce
- How to verify its own work
- Scope boundaries (what not to do)
- Communication protocol: who to notify via SendMessage, what format

## Authority Model

- **requirements** wins on WHAT (scope, acceptance criteria, test cases, compliance)
- **sys-arch** wins on HOW it's shaped (system boundaries, protocols, failure modes)
- **code-arch** wins on HOW it's delivered (build strategy, testability, maintainability)
- Cross-domain conflicts → human decides
- Post-review: sys-arch wins on divergence classification (architecture-breaking vs additive)

## Testing Concerns Across the Triad

| Member | Testing responsibility |
|--------|----------------------|
| requirements | Defines test cases as first-class requirements (Given/When/Then behavioral specs) |
| sys-arch | System/integration test strategy, test boundaries, environment needs |
| code-arch | Automated test structure, mocking strategy, test utilities, coverage approach |

## Clarification Attempt Protocol (Mode 2)

If oscillation is detected or safety cap is hit during replacement:

1. Orchestrator presents the problem to the per-phase triad
2. Triad has one round to produce a corrected proposal (code-arch leads)
3. All members converge → replacement loop restarts with corrected proposal
4. Any member disagrees → escalate to human

Triad's only active role during replacement. Otherwise passive.

## Orchestrator Boundaries

**Allowed:** SendMessage, TaskCreate/Update, Read on plan/spec/config files, Write to session state, Agent spawning
**Not allowed:** Write/Edit on source code, reading implementation files to debug agent work, running build/test commands

If a triad member fails: shut down and respawn with better instructions.
