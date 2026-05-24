---
name: implement
description: "This skill should be used when the user asks to \"start building\", \"begin implementation\", \"execute the plan\", \"implement the plan\", \"build this\", \"start coding\", \"run the replacement loop\", \"swarm implement\", or invokes /swarm:implement. Autonomously executes a phased implementation plan using the replacement loop with per-phase triad review. Swarm state is session-keyed and resumable."
argument-hint: "[path to plan file]"
allowed-tools: ["Agent", "SendMessage", "Read", "Bash", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "Write", "Edit"]
---

# Autonomous Implementation via Replacement Loop

Execute a phased implementation plan autonomously: spawn a fresh triad per phase, run pre-flight, replacement loop builds and verifies, triad post-reviews with divergence classification. State is session-keyed and resumable.

**Announce at start:** "Using swarm:implement to execute the plan via replacement loop."

## On Start: Session Check

Read `references/swarm-sessions.md` for the full session model.
Read `references/complexity-scaling.md` for the scaling rubric (tier determines per-phase triad model and pre-flight/post-review intensity).

1. `.claude/swarm/active.json` exists and `phase` is `implement` → **resume**. Check `meta.json` — if `gates.plan_approved` is null, re-present the plan before proceeding.
2. Exists and `phase` is `design` or `plan` → not ready. Inform the user.
3. Not exists → check for a provided plan file. Locate the producing swarm session, or start fresh.

**On entering implement phase from plan:** Read `.claude/swarm/active.json`, extract `swarm_id`. Set `SWARM_ROOT=".claude/swarm/sessions/<swarm_id>"`.

**`feedback` field present in `active.json`** → incorporate into the appropriate stage's leader prompt and clear after re-entry begins.

**On resume:** Read `meta.json` for last completed phase/round. Skip completed phases. If `active.json` step is ahead of directory state → trust directory state.

All paths below use `<swarm-root>` as shorthand.

## Checklist

After parsing the plan, create the full task structure via `TaskCreate` and `TaskUpdate`.

**Step 1 — Top-level phase tasks:**
```
For each phase in the plan:
  TaskCreate({ subject: "Phase N: [name]", description: "[deliverables]" })
TaskCreate({ subject: "Done: Present summary and close swarm", description: "..." })
```
Chain with `addBlockedBy` per the DAG. "Done" blocked by all phase tasks.

**Step 2 — Sub-tasks for the first unblocked phase:**
```
Phase N: Pre-flight (spawn triad, evaluate proposal)
Phase N: Implementation round M (replacement loop)
Phase N: Post-review (triad reviews code patch)
Phase N: Complete (triad destroyed, status written)
```
Chain sequentially with `addBlockedBy`.

**Step 3 — Dynamic extension:** Add implementation round sub-tasks as the loop iterates.

**Step 4 — Phase transition:** Mark phase task `completed`. Create sub-tasks for next unblocked phase.

Mark each task `in_progress` when starting, `completed` when done.

## Process

### Startup

1. Read the plan from `<swarm-root>/plans/`. Parse per `references/plan-format.md`.
2. Create the top-level task list from the phase list.
3. Begin with the first unblocked phase per the DAG.

### Per-Phase Protocol

Read `references/replacement-loop.md` for the full protocol.

#### Step 1: Spawn Per-Phase Triad

**Tier-based model selection:** Read the `tier` from `meta.json`. Per `references/complexity-scaling.md` § Model Selection:
- **Small:** Per-phase triad reactors spawn at Sonnet (upgrade to Opus if any reactor ITERATING during pre-flight or post-review)
- **Medium/Large:** All triad members spawn at Opus

Spawn a fresh triad for Phase N. All members receive:
- Phase N's plan spec (from `plans/` or pre-flight-corrected version)
- Downstream deltas targeting Phase N from completed upstream phases
- Phase 2 architecture doc path (`iterations/architecture/latest/`)
- Phase 3 code design path (`iterations/code-design/latest/`)
- Phase N's DAG position

Role-specific additions:

| Member | Additional context |
|---|---|
| requirements | Acceptance criteria mapped to this phase, behavioral test cases |
| sys-arch | Architecture boundaries, contracts this phase must satisfy |
| code-arch | Module assignments, file lists, dependency constraints, verification commands |

Triad persists across all replacement iterations within Phase N.

Update step: `phase-N-pre-flight`

#### Step 2: Pre-Flight

Triad evaluates: "Is this plan still correct given upstream deltas?"

**Tier-scaled intensity:** For small-tier projects where plan synthesis converged unanimously (signal: `unanimous`), pre-flight may use a streamlined fast-path check: code-arch alone confirms "proceed" without spawning the full coordination loop. Any hesitation → fall through to the standard slow path.

- **Fast path:** "Proceed" → use original proposal
- **Slow path:** 1-round coordination loop (code-arch leads, sys-arch + reqs react)
  - All converge → corrected proposal becomes canonical input
  - Any reactor ITERATING → step `phase-N-pre-flight-escalated`, escalate to human
- **Triad member dies** → restart pre-flight from scratch
- **Correction scope:** Bounded adjustments only. Fundamental restructuring → escalate.
- **DAG-invalidation:** Correction produced → check running parallel phases for impact. Pause affected.

Update step: `phase-N-pre-flight-correction` (if correcting) or proceed.

#### Step 3: Replacement Loop

**The proposal is FROZEN.**

1. Spawn implementation team per plan's team shape. `ts-implementer` for TypeScript; `infra-implementer` for Python/Bash/Docker/YAML. One agent per workstream. **Use `model: "sonnet"`** — implementers execute a frozen spec, not judgment calls.
2. Self-contained prompts with absolute paths, verification commands, scope boundaries. Include paths to design spec documents — implementers read the spec directly for interface contracts and type definitions (plan phase specs reference rather than restate these).
3. Team runs tests — all must pass before reporting done.
4. Shut down → spawn fresh replacement team (same proposal, zero prior context).
5. Replacement checks:
   - "No work to do" → CONVERGED
   - Work remains → do it, shut down, next replacement (back to step 4)

Update step: `phase-N-implementation-round-M`

**Oscillation** (replacement undoes prior team's work) → escalate immediately.

**Escalation sequence:**
1. Present oscillation pattern to per-phase triad.
2. Triad gets one clarification attempt (1 round, code-arch leads). Converges → restart with corrected proposal, counter resets.
3. Can't clarify or recurs → escalate to human.

**Safety cap:** 5 replacement teams max. Not converged → escalate.

Update step on convergence: `phase-N-convergence-check`

#### Step 4: Post-Review

Single-round coordination loop. Code-arch leads; sys-arch + requirements react.

**Orchestrator provides:**
- Full code patch (`git diff` of all phase changes)
- Phase 2 architecture doc path
- Phase 3 code design path
- Phase N's plan spec
- Test suite results (orchestrator runs tests, provides output)

Triad does NOT read implementation team reports.

**Member focus:**

| Member | Focus |
|---|---|
| requirements | Acceptance criteria for this phase are satisfied |
| sys-arch | Boundary integrity, contract shapes, service responsibilities vs architecture doc |
| code-arch | Module structure, dependency graph, interfaces vs code design. Most forgiving — adaptations preserving module contract are expected. |

**Divergence classification:**

| Deviation Type | Example | Action |
|---|---|---|
| Within module boundaries (additive) | Interface gained a field; helper added; error type expanded | Normal. Downstream delta if affects later phases. |
| Architecture-breaking | Boundary moved; contract changed shape; responsibility shifted | Escalate. |

Threshold: requires updating Phase 2 or Phase 3 output → architecture divergence. Only affects per-phase spec → tactical correction.

**Tiebreaker:** sys-arch wins on classification.

**Outputs:**
- "Proceed" → phase complete
- "Adjust downstream" → write downstream delta (dependency-downstream phases only). Phase complete.
- "Escalate" → step `phase-N-post-review-escalated`, present to user with recommended re-entry stage.

**Downstream delta format** (self-contained; read cold by a fresh triad):
```markdown
---
source_phase: N
affected_phases: [list]
produced_at: <ISO timestamp>
---

## Phase M: [name]

### What Changed
[Concrete description]

### Literal Changes
[Type definitions, interface shapes, or path mappings]

### What Phase M Should Do Differently
[Specific instructions]

### Stale Plan Artifacts
[Which lines/sections of Phase M's plan spec are now inaccurate]
```

Write `post-review/status.json`:
```json
{
  "signal": "proceed | adjust | escalate",
  "classification": "within-boundaries | architecture-divergence",
  "produced_at": "<ISO timestamp>"
}
```

Update step: `phase-N-post-review` (or `phase-N-post-review-escalated`)

#### Step 5: Phase Completion

- Destroy the per-phase triad.
- Write `replacement/status.json`:
  ```json
  { "converged_at_team": N, "total_teams": N, "produced_at": "<ISO timestamp>" }
  ```
- Update `active.json` and `meta.json`.
- Mark phase task `completed`.
- Notify user: "Phase N converged and reviewed. Starting Phase N+1."

Update step: `phase-N-complete`

### Phase Execution Order (DAG)

Per `references/dag-execution.md`:
1. Compute initial ready set — phases with no unresolved dependencies.
2. Dispatch all ready phases simultaneously.
3. On completion, recompute ready set, dispatch newly unblocked phases.
4. File isolation between parallel phases is mandatory. Plan doesn't guarantee it → execute sequentially, flag to user.

- **DAG-invalidation:** Pre-flight correction → check all running parallel phases. Pause affected.
- **Conflicting upstream deltas:** Incompatible expansions of the same interface → pre-flight escalates.

### Completion (Done Phase)

Update `active.json`: `phase: "done"`, `step: "presenting-summary"`.

> **Swarm complete.** Here's what was delivered:
>
> **Phases completed:** [Phase N: name — key deliverables]
>
> **Implementation stats:** [replacement teams per phase, any escalations]
>
> **Session artifacts:** `<swarm-root>/`
>
> *Approve to close the swarm, or request changes.*

Swarm remains active until user explicitly approves.

**After user approves:**
1. Update `meta.json`: `status: "completed"`.
2. Remove `active.json`.
3. Mark all remaining tasks `completed`.
4. Final message: "Swarm closed. All artifacts preserved at `<swarm-root>/`."

## Management Discipline

- Orchestrator does NOT write code. Dispatch only.
- No inline subagents. Named, spawned team members only.
- Absolute paths only. `~` and `$HOME` are not expanded.
- Self-contained prompts: what to do, which files (absolute paths), how to verify, scope boundaries, who to notify.

## When Things Go Wrong

- **Agent stuck:** Shut down, respawn with improved instructions. After 2 failures → escalate.
- **Triad disagreement:** Collect positions via SendMessage. Summarize for user with trade-offs. Wait for decision.
- **Convergence not reached (5 rounds):** Pause phase, `meta.json` status → `"paused"`, escalate.
- **Never take over for a struggling agent.** Rewrite the prompt or escalate.

## Additional Resources

- `references/swarm-sessions.md` — session model, resume protocol
- `references/triad-lifecycle.md` — spawning, authority model, per-phase vs. fresh-per-round modes
- `references/replacement-loop.md` — full loop protocol, convergence criteria, oscillation detection
- `references/dag-execution.md` — parallel dispatch, DAG-invalidation check
- `references/plan-format.md` — plan document structure
