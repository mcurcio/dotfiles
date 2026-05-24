# Swarm Session Model

Every swarm run is keyed by a **swarm ID** and stored in its own session directory.
- **Resume:** New sessions discover in-progress swarms and continue
- **Audit trail:** Completed swarms remain on disk with full iteration history
- **Isolation:** Multiple swarms don't collide

## Directory Structure

```
.claude/swarm/
├── active.json                              # Points to the current swarm (if any)
└── sessions/
    ├── 2026-05-01-auth-middleware/           # swarm-id
    │   ├── meta.json                        # Swarm metadata and progress
    │   ├── iterations/
    │   │   ├── requirements/...
    │   │   ├── architecture/...
    │   │   ├── code-design/...
    │   │   ├── planning/...
    │   │   └── implementation/
    │   │       └── phase-N/
    │   │           ├── pre-flight/
    │   │           ├── replacement/
    │   │           └── post-review/
    │   ├── specs/                           # Final approved specs
    │   └── plans/                           # Final approved plans
    └── 2026-04-28-pipeline-redesign/        # Previous swarm (completed)
        └── ...
```

Nothing is written to `.claude/swarm/` except `active.json` and `.session-id`.

## Session Identity

`session_id` is only available inside hook callbacks — not as an environment variable. A `SessionStart` hook fires once, reads it from stdin, writes to `.claude/swarm/.session-id`. Both hooks are defined in `hooks/hooks.json`.

```bash
SESSION_ID=$(cat .claude/swarm/.session-id 2>/dev/null)
```

## Swarm ID

Format: `YYYY-MM-DD-<topic-slug-max-40>-<8-hex-random>`. Generated when `swarm:design` starts:

```bash
SWARM_ID="$(date +%Y-%m-%d)-$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 40)-$(head -c4 /dev/urandom | xxd -p)"
```

## active.json

Lives at `.claude/swarm/active.json`. Created when a swarm starts, removed on completion/cancellation. The guard hook reads this file.

```json
{
  "swarm_id": "2026-05-01-auth-middleware",
  "session_id": "<orchestrator-session-id>",
  "started_at": "2026-05-01T14:30:00Z",
  "topic": "auth middleware redesign",
  "phase": "design",
  "step": "architecture-round-2",
  "feedback": {
    "text": "The auth boundary should be split...",
    "target_stage": "architecture",
    "received_at": "2026-05-07T10:30:00Z"
  }
}
```

| Field | Purpose |
|-------|---------|
| `swarm_id` | Directory name under `sessions/` |
| `session_id` | Orchestrator's session_id — used by guard hook |
| `started_at` | When this session began working |
| `topic` | Human-readable description |
| `phase` | Current pipeline phase: `design`, `plan`, `implement` |
| `step` | Current step within phase (for resume) |
| `feedback` | Pending user feedback to incorporate on next invocation. `null` when none. |

The `feedback` field is written at approval gates. Next `/swarm` invocation reads it, incorporates into the target stage's leader prompt, clears after re-entry round begins.

### Step Vocabulary

Valid `step` values per phase. `N` = phase number, `M` = round/team number.

**Design phase:**
| Step | Meaning |
|------|---------|
| `starting` | Session created |
| `requirements-round-N` | Requirements coordination loop, round N |
| `requirements-approved` | User approved requirements (gate recorded) |
| `architecture-round-N` | Architecture coordination loop, round N |
| `code-design-round-N` | Code design coordination loop, round N |
| `design-approved` | User approved architecture + code design (gate recorded) |

**Plan phase:**
| Step | Meaning |
|------|---------|
| `starting` | Entered plan phase |
| `plan-round-N` | Plan synthesis coordination loop, round N |
| `plan-approved` | User approved plan (gate recorded) |

**Implement phase:**
| Step | Meaning |
|------|---------|
| `starting` | Entered implement phase |
| `phase-N-pre-flight` | Fresh triad spawned; evaluating Phase N's proposal |
| `phase-N-pre-flight-correction` | Triad producing corrected proposal for Phase N |
| `phase-N-pre-flight-escalated` | Pre-flight disagreement, waiting for human input |
| `phase-N-implementation-round-M` | Replacement loop: team M working |
| `phase-N-convergence-check` | Fresh team verifying implementation |
| `phase-N-post-review` | Triad reviewing converged Phase N output |
| `phase-N-post-review-escalated` | Post-review escalation (architecture divergence), waiting for human input |
| `phase-N-complete` | Phase N converged, reviewed, cleared. Triad destroyed. |

**Terminal:**
| Step | Meaning |
|------|---------|
| `done` | Swarm completed successfully |
| `cancelled` | Swarm cancelled by user |

Updated by skills at each step transition via the Write tool (which is pre-approved for `.claude/swarm/**` paths).

## meta.json

Lives at `.claude/swarm/sessions/<swarm-id>/meta.json`. Canonical record of the swarm's full lifecycle.

```json
{
  "swarm_id": "2026-05-01-auth-middleware",
  "topic": "auth middleware redesign",
  "tier": "medium",
  "created_at": "2026-05-01T14:30:00Z",
  "updated_at": "2026-05-01T15:45:00Z",
  "status": "active",
  "phase": "design",
  "step": "architecture-round-2",
  "gates": {
    "requirements_approved": "2026-05-01T14:55:00Z",
    "design_approved": null,
    "plan_approved": null
  },
  "sessions": [
    {
      "session_id": "abc-123",
      "started_at": "2026-05-01T14:30:00Z",
      "ended_at": "2026-05-01T15:00:00Z",
      "reason": "context compaction"
    },
    {
      "session_id": "def-456",
      "started_at": "2026-05-01T15:05:00Z",
      "ended_at": null
    }
  ]
}
```

| Field | Purpose |
|-------|---------|
| `status` | `active`, `paused`, `completed`, `cancelled` |
| `tier` | Complexity tier: `small`, `medium`, `large`. Set at session start per `references/complexity-scaling.md`. Updated on tier upgrade/downgrade. |
| `gates` | User approval timestamps — `null` = not yet approved. Convergence ≠ approval. |
| `sessions` | History of all sessions that worked on this swarm |

Gate names: `requirements_approved`, `design_approved`, `plan_approved`.

### Gate Nullification on Re-entry

| Re-entry target | Gates nullified |
|-----------------|-----------------|
| Requirements | `requirements_approved`, `design_approved`, `plan_approved` |
| Architecture | `design_approved`, `plan_approved` |
| Code design | `design_approved`, `plan_approved` |
| Plan | `plan_approved` |

Nullified gates must be re-earned through fresh user approval.

## Swarm Root

Skills define a **swarm root** variable on entry:

```
SWARM_ROOT=.claude/swarm/sessions/<swarm-id>
```

All paths within skills/references are relative to this root:
- `<swarm-root>/iterations/requirements/...`
- `<swarm-root>/iterations/architecture/...`
- `<swarm-root>/iterations/code-design/...`
- `<swarm-root>/iterations/planning/...`
- `<swarm-root>/iterations/implementation/phase-N/...`
- `<swarm-root>/specs/...`
- `<swarm-root>/plans/...`

## State Mutation Protocol

**All mutations to `active.json` and `meta.json` use the Read + Write tools — never `jq` shell pipelines.**

Pattern:
1. Read the JSON file with the Read tool
2. Modify the parsed JSON in memory (update fields, append to arrays, set timestamps)
3. Write the full modified JSON back with the Write tool

This avoids permission prompts (Write to `.claude/swarm/**` is pre-approved) and eliminates freestyle shell command variations that break allowlist patterns. The only Bash needed for state management is `rm -f .claude/swarm/active.json` on swarm completion/cancellation.

For initial file creation (new swarm), use Write directly — no need to Read first since the file doesn't exist yet.

## Lifecycle

### Starting a New Swarm (`swarm:design`)

1. Read session ID: `Bash(cat .claude/swarm/.session-id)`
2. Generate swarm ID: `Bash(echo "$(date +%Y-%m-%d)-$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 40)-$(head -c4 /dev/urandom | xxd -p)")`
3. Create directories: `Bash(mkdir -p .claude/swarm/sessions/$SWARM_ID/{iterations/{requirements,architecture,code-design,planning},specs,plans})`
4. Write `meta.json` and `active.json` using the **Write tool** (not Bash):

**Write** to `<swarm-root>/meta.json`:
```json
{
  "swarm_id": "<swarm-id>",
  "topic": "<topic>",
  "tier": "<small|medium|large>",
  "created_at": "<ISO timestamp>",
  "updated_at": "<ISO timestamp>",
  "status": "active",
  "phase": "design",
  "step": "starting",
  "gates": {
    "requirements_approved": null,
    "design_approved": null,
    "plan_approved": null
  },
  "sessions": [
    {
      "session_id": "<session-id>",
      "started_at": "<ISO timestamp>",
      "ended_at": null
    }
  ]
}
```

**Write** to `.claude/swarm/active.json`:
```json
{
  "swarm_id": "<swarm-id>",
  "session_id": "<session-id>",
  "started_at": "<ISO timestamp>",
  "topic": "<topic>",
  "phase": "design",
  "step": "starting",
  "feedback": null
}
```

### Resuming a Swarm (new session)

1. Read session ID: `Bash(cat .claude/swarm/.session-id)`
2. **Read** `.claude/swarm/active.json` — extract `swarm_id`, `phase`, `step`, `feedback`
3. **Read** `<swarm-root>/meta.json`
4. Modify in memory: close prior session (`ended_at` on any null entry), append new session entry, update `updated_at`
5. **Write** the modified `meta.json` back (full file via Write tool)
6. **Read** `active.json`, update `session_id` and `started_at`, **Write** it back
7. Check `gates` — if current phase requires a gate that is `null`, re-present relevant output for approval
8. Check `feedback` — if non-null, route to indicated re-entry stage
9. Scan iteration directories for last `latest` symlink
10. Resume from recorded `phase`/`step`

### Updating Progress

Write `meta.json` first (authoritative), then `active.json` (pointer). If interrupted, `meta.json` has correct state; resume reconciles `active.json` from it.

1. **Read** `<swarm-root>/meta.json`, update `phase`, `step`, `updated_at` fields
2. **Write** the full modified JSON back to `<swarm-root>/meta.json`
3. **Read** `.claude/swarm/active.json`, update `phase` and `step`
4. **Write** the full modified JSON back to `.claude/swarm/active.json`

### Completing a Swarm

1. **Read** `<swarm-root>/meta.json`, set `status: "completed"`, `phase: "done"`, `step: "done"`, `updated_at`, and `ended_at` on the last session entry
2. **Write** the full modified JSON back to `<swarm-root>/meta.json`
3. `Bash(rm -f .claude/swarm/active.json)`

### Cancelling a Swarm

Same as completion but `status: "cancelled"`. Session directory remains for audit.

## Resume Protocol

### Resume Granularity

| Context | Resume Point | Rationale |
|---------|-------------|-----------|
| Coordination loop | Last fully-completed round | Partial rounds have incomplete state |
| Replacement loop | Last team report written | Teams are atomic units |
| Pre-flight | Restart from beginning | Cheap; partial state unreliable |
| Post-review | Restart from beginning | Cheap; partial state unreliable |

"Fully-completed round" = leader output written + all reactor outputs written + `latest` symlink updated. Incomplete round → resume starts fresh with the same inputs.

### Resume Procedure

1. Read `active.json` for phase/step
2. Read `meta.json` for gate states
3. `feedback` field present → route to re-entry
4. Scan iteration directories for last `latest` symlink
5. `active.json` step ahead of directory state → trust directory state

## Cleanup

Session directories are never automatically deleted. Use `/swarm:cleanup` to list and remove old sessions. Completed/cancelled sessions are safe to remove; active sessions should not be deleted.

## Guard Hook Integration

The guard hook reads `.claude/swarm/active.json` to match session_id:

```bash
orchestrator_session=$(jq -r '.session_id' "$FLAG_FILE")
```

If the caller's session_id matches the orchestrator's, writes outside `~/.claude/` are blocked. Subagents (different session_id) pass through.
