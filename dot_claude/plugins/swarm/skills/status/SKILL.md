---
name: status
description: "This skill should be used when the user asks \"where are we\", \"team status\", \"what's the progress\", \"how's the build going\", \"progress report\", \"what phase are we on\", \"check on the agents\", \"swarm status\", or invokes /swarm:status. Reads the current task list, swarm session state, and agent health, then produces a concise summary."
allowed-tools: ["Read", "Bash"]
---

# Swarm Status Report

Read swarm session state and iteration directories, produce a concise pipeline-position summary.

**Announce at start:** "Checking swarm status."

## Process

1. **Check for active swarm.** Read `.claude/swarm/active.json`. If absent, check `.claude/swarm/sessions/`.

2. **Read session metadata** from `meta.json`: swarm ID, topic, current phase/step, gate states (requirements_approved, design_approved, plan_approved), session history.

3. **Check pending feedback.** If `active.json` has a `feedback` field, report it prominently.

4. **Scan iteration directories.** For each stage (`requirements/`, `architecture/`, `code-design/`, `planning/`, `implementation/phase-N/`): count round-N dirs, check latest symlink, read manifest status. Implementation phases also have `pre-flight/`, `replacement/`, `post-review/` subdirs.

5. **Read convergence metadata.** For completed stages, read the `convergence` block from the final manifest: `coordination_rounds` + `signal`.

6. **Read implementation status files** for in-progress phases:
   - `replacement/status.json` — `converged_at_team`, `total_teams`
   - `post-review/status.json` — `signal`, `classification`

7. **Stall detection.** Flag:
   - Coordination loop at round 4+ (cap: 5)
   - Replacement loop at team 4+ (cap: 5)
   - Step vocabulary contains "escalated"
   - Pre-flight correction (not pass-through)

8. **Present summary** using the pipeline format:

### Design/Plan Phase Format

```
Swarm: <id> | Phase: design/architecture | Round 2/5

Pipeline:
  ✓ Requirements (2 rounds, unanimous) — approved 2026-05-07
  → Architecture (round 2, sys-arch leads)
  · Code Design
  · Plan Synthesis
  · Implementation (0/N phases)

Current: Architecture round 2
  Leader: sys-arch (ITERATING)
  Reactors: requirements (CONVERGED), code-arch (ITERATING — flagged coupling concern)

Gates: requirements ✓ | design · | plan ·
```

### Implementation Phase Format

```
Swarm: <id> | Phase: implement | Phase 3 of 4

Pipeline:
  ✓ Requirements — approved
  ✓ Architecture — approved
  ✓ Code Design — approved
  ✓ Plan — approved
  → Implementation (2/4 phases complete)

Implementation:
  ✓ Phase 1: Auth service (3 teams, negotiated)
  ✓ Phase 2: Storage layer (2 teams, unanimous)
  → Phase 3: API gateway (team 2 working)
    Pre-flight: passed (no correction)
    Replacement: team 2 in progress
  · Phase 4: Frontend (blocked by Phase 3)

Alerts:
  None.
```

### Feedback Pending Format

```
⚠ Pending feedback (target: architecture):
  "The auth boundary should be split..."
  Received: 2026-05-07T10:30:00Z
  Action: Next /swarm invocation will route to architecture stage.
```

Adapt to actual state. Omit sections with nothing to report.

## When There Is No Active Swarm

No `active.json` → list sessions under `.claude/swarm/sessions/` with status and dates. No sessions → `"No active swarm. Use /swarm to start a new design session."`

## Listing Past Swarms

List all dirs under `.claude/swarm/sessions/` with `meta.json` status and topic.
