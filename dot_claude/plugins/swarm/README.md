# swarm

Multi-agent team orchestration with an advisory triad, iterative design, and replacement-loop implementation. All swarm state is session-keyed and resumable.

## Skills

| Skill | Trigger | Mode |
|-------|---------|------|
| `/swarm:design` | "start design", "architect this with the team" | Collaborative — user in the loop |
| `/swarm:plan` | "plan the work", "break into phases" | Collaborative — user in the loop |
| `/swarm:implement` | "start building", "execute the plan" | Autonomous — fire and forget |
| `/swarm:status` | "where are we", "team status" | Read-only report |

## Workflow

```
design → plan → implement
                    ↑
                  status (check in anytime)
```

1. **Design** — requirements agent defines what to build (iterative loop), then architects (sys-arch + code-arch) design within those constraints (parallel iterative loops). Produces a spec with requirements traceability.
2. **Plan** — triad iteratively breaks the spec into phases with deliverables, workstreams, verification criteria, and requirements mapping. Produces a plan.
3. **Implement** — autonomous execution via replacement loop. For each phase: triad reviews, teams build, fresh teams verify convergence, requirements agent validates compliance.
4. **Status** — read session state, task list, and agent health. Report progress including iteration rounds and requirements compliance.

## Session Model

Every swarm run is keyed by a **swarm ID** (`YYYY-MM-DD-<topic-slug>`) and stored in its own session directory under `.claude/swarm/sessions/`. A new Claude Code session can discover and resume an in-progress swarm. Completed swarms remain on disk as an audit trail until manually cleaned up.

See `references/swarm-sessions.md` for the full lifecycle, resume protocol, and cleanup.

## Prerequisites

- **superpowers plugin** — `superpowers:brainstorming` is used by the design skill (graceful fallback if absent)
- **Agent definitions** in `~/.claude/agents/`:
  - `requirements` — user-centric requirements, acceptance criteria, test cases, compliance validation (goes first)
  - `system-architect` — system boundaries, protocols, failure modes
  - `code-architect` — module structure, types, dependency graphs
  - `ts-implementer` — TypeScript/Node.js production code
  - `infra-implementer` — Python, Bash, Docker, YAML

## Orchestrator Guard Hook

A `PreToolUse` hook prevents the orchestrator from writing files it shouldn't during an active swarm. It reads `.claude/swarm/active.json` and uses session_id matching to distinguish the orchestrator from subagents.

**Activation:** Skills write `active.json` (containing orchestrator session_id + swarm metadata) on startup.

**Orchestrator allowed writes:** `~/.claude/` only (memory, team config, settings)

**Orchestrator blocked writes:** Everything else — source code, project config, swarm session artifacts. The orchestrator must dispatch to subagents for all project writes.

**Subagents:** Unrestricted. Their session_id differs from the orchestrator's, so the hook passes them through.

**Deactivation:** `swarm:implement` removes `active.json` on completion.

## References

Shared reference files in `references/`:

- `swarm-sessions.md` — session model, lifecycle, resume protocol, cleanup
- `triad-lifecycle.md` — spawning, health checks, authority model, coordination protocol
- `iterative-design-loop.md` — iterative refinement protocol with directory-per-round model and manifests
- `replacement-loop.md` — full implementation loop protocol, convergence criteria, safety rails
- `plan-format.md` — canonical plan document structure
