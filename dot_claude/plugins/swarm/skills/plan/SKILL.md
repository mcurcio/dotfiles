---
name: plan
description: "This skill should be used when the user asks to \"plan the work\", \"break into phases\", \"break this down into phases\", \"phase the implementation\", \"create the implementation plan\", \"plan the build\", \"swarm plan\", or invokes /swarm:plan. Code-arch leads a single coordination loop to produce an implementation DAG with per-phase specs, team shapes, and requirements traceability. Swarm state is session-keyed and resumable."
argument-hint: "[path to spec file]"
allowed-tools: ["Agent", "SendMessage", "Read", "Bash", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "Write", "Edit"]
---

# Plan Synthesis

Code-arch leads a single coordination loop with sys-arch and requirements reacting. Produces an implementation DAG, per-phase specs, team shapes, and requirements traceability. Expected to converge in 1-2 rounds; 5-round cap is a safety net.

**Announce at start:** "Using swarm:plan to produce the implementation plan."

## On Start: Session Check

Read `references/swarm-sessions.md` for the full session model.
Read `references/complexity-scaling.md` for the scaling rubric (tier determines plan detail level and reactor policy).

1. `.claude/swarm/active.json` exists and `phase` is `plan` → **resume**. Check `meta.json` — if `gates.design_approved` is null, design was never approved; inform user.
2. Exists and `phase` is `design` → not finished. Inform user.
3. Exists and `phase` is `implement` → planning done. Inform user.
4. Not exists → check if a spec path was provided.

**On entering plan phase from design:** Read `.claude/swarm/active.json`, extract `swarm_id`. Set `SWARM_ROOT=".claude/swarm/sessions/<swarm_id>"`. Create directories: `Bash(mkdir -p .claude/swarm/sessions/<swarm_id>/iterations/planning .claude/swarm/sessions/<swarm_id>/plans)`

All paths below use `<swarm-root>` as shorthand.

## Checklist

Create all tasks via `TaskCreate`, chain with `addBlockedBy`:

```
TaskCreate({ subject: "Session check", description: "Verify swarm session, update phase to plan, create planning directory" })
TaskCreate({ subject: "Plan synthesis coordination loop", description: "code-arch leads, sys-arch + requirements react until convergence" })
TaskCreate({ subject: "User validates plan (Gate 3)", description: "Present DAG, per-phase specs, team shapes, traceability matrix" })
TaskCreate({ subject: "Iterate with user", description: "Incorporate feedback if provided" })
TaskCreate({ subject: "Persist canonical plan", description: "Save to plan location; commit if in git repo" })
TaskCreate({ subject: "Transition to implement", description: "Hand off to swarm:implement" })
```

Mark `in_progress` when starting, `completed` when done. On resume, skip tasks with existing `latest` symlink + CONVERGED manifest.

## Plan Synthesis Coordination Loop

Read `references/iterative-design-loop.md` for the general protocol.

**Leader:** code-arch. **Reactors:** sys-arch, requirements.

### Inputs (provided to code-arch leader prompt)

Upstream outputs with attention-directing preamble:
- Converged requirements with priority ordering — `<swarm-root>/iterations/requirements/latest/`
- Converged architecture with dependency sequencing — `<swarm-root>/iterations/architecture/latest/`
- Converged code design with module decomposition — `<swarm-root>/iterations/code-design/latest/`
- Approved design documentation paths (the specs implementers will read directly)

Preamble directs attention to: priority ordering, dependency constraints, module assignments.

**Critical instruction in leader prompt:** "Phase specs reference the design spec — they do not restate it. Your job is build order, file assignment, verification commands, and scope boundaries. Interface contracts, type definitions, and implementation notes live in the spec. Write `'Implement X per spec §N'` not 50 lines of method signatures. See `references/complexity-scaling.md` § Redundancy Elimination and `references/plan-format.md` § Compact/Standard/Full variants for your tier."

### Leader Output

- **Implementation DAG** — phase ordering with dependency edges
- **Per-phase specifications** — interfaces, modules, files, tests, verification criteria
- **Per-phase team shapes** — implementers, language specialties, testers
- **Requirements traceability** — acceptance criteria → phase mapping

Does NOT specify lines of code.

Include **Structural** zoom Admissible Scope block for **code-arch** / **leader** framing per `references/admissible-scope.md`.

**Tier-scaled output:** Include the project tier in the leader prompt. Per `references/complexity-scaling.md`:
- **Small:** Compact phase specs (deliverables + files + verification). Max 3–4 phases. Aim for concise, implementer-ready specs — not enterprise documentation.
- **Medium:** Standard plan-format.md structure. 4–6 phases.
- **Large:** Full detail with integration notes. 6–10 phases.

### Reactor Verification

| Reactor | Verifies |
|---|---|
| sys-arch | Ordering respects dependencies; each phase independently implementable; team shapes appropriate |
| requirements | High-priority requirements in early phases; every criterion has a home; each phase independently verifiable |

Include Admissible Scope block per role, **reactor** framing.

Reactors provide constructive alternatives when flagging problems.

### Convergence

Per `references/two-adjacent-convergence.md`: Leader CONVERGED + all reactors CONVERGED = loop closes. Any reactor ITERATING = next round. Max 5 rounds. Update progress: `step: "plan-round-N"`

**Small tier optimization:** For small-tier projects, spawn reactors at Sonnet (not Opus). If a reactor declares ITERATING, upgrade to Opus for the next round. This preserves perspective diversity at lower cost.

### Artifact Structure

```
<swarm-root>/iterations/planning/
├── round-1/
│   ├── prompt.md
│   ├── output/
│   │   ├── manifest.md
│   │   ├── dag.md
│   │   ├── phase-N-spec.md
│   │   ├── team-shapes.md
│   │   └── traceability.md
│   └── reactions/
│       ├── system-design/
│       │   └── manifest.md
│       └── requirements/
│           └── manifest.md
├── round-2/
│   └── ...
└── latest -> round-N/output/
```

## User Review (Gate 3)

> **Approving the plan** = "The execution sequence is right." You're confirming phase boundaries, ordering, team composition, and what "done" looks like per phase. Autonomous implementation begins after this.

**Artifacts shown:**
- Implementation DAG (ordering + dependencies)
- Per-phase specs
- Team shapes
- Requirements traceability matrix
- Paths to iteration directories for detailed review

### Feedback Routing

If feedback, first classify intensity per `references/complexity-scaling.md` § Feedback Amendment Protocol:

**Structural/Additive** (reorder phases, merge phases, move tests into implementation, add a phase, rename):
1. Orchestrator amends output files directly (Edit tool).
2. Write amended output to `round-N+1/output/` to preserve audit trail.
3. Update manifest: increment round, add "Changes from Previous Round" section, keep CONVERGED.
4. Update `latest` symlink. **No agent spawn. No reactors.**

**Substantive** (rethink phase boundaries, redesign workstreams, change fundamental approach):
1. Compose leader prompt with previous output + user feedback verbatim.
2. Spawn single code-arch leader. Leader writes complete new output.
3. Spawn reactors at tier's rubber-stamp model (Small/Medium = Sonnet, Large = Opus). Upgrade to Opus if any reactor declares ITERATING.

**Directional** (design problem surfaced):
1. Route to design stage. Null `design_approved` + `plan_approved`.
2. Persist feedback: Read `active.json`, set `.feedback = {"text": "<feedback>", "target_stage": "<stage>", "received_at": "<ISO timestamp>"}`, Write it back.
3. Inform user to re-enter via `swarm:design`.

**Gate clearing:** Only null `plan_approved` for substantive/directional feedback. Structural amendments don't clear the gate — they refine the existing approved direction.

## Persisting the Plan

Save to `<swarm-root>/plans/` per `references/plan-format.md`. If project root is a git repo, commit.

## Handoff to Implement

After user approves:

1. Record the plan gate: Read `<swarm-root>/meta.json`, set `.gates.plan_approved = "<ISO timestamp>"` and `.updated_at`, Write it back.
2. Update `active.json`/`meta.json`: set `phase: "implement"`, `step: "starting"` (Read, modify, Write each).
3. Announce:

> "Plan approved and saved to `<path>`. Ready to begin implementation. Invoke /swarm:implement to start, or review the plan further."

Do not automatically invoke `swarm:implement`.

## Key Principles

- Single coordination loop — code-arch leads, sys-arch + requirements react
- Session-keyed and resumable
- Fresh agents every round — persisted files are context
- Complete output each round — self-contained, not a diff
- Constructive reactor feedback — alternatives, not pass/fail
- Requirements traceability is mandatory

## References

- **`references/swarm-sessions.md`** — session model, lifecycle, resume protocol
- **`references/iterative-design-loop.md`** — coordination loop protocol, directory structure, manifest format
- **`references/two-adjacent-convergence.md`** — convergence criteria
- **`references/admissible-scope.md`** — scope constraints for leaders and reactors
- **`references/plan-format.md`** — canonical plan document structure
- **`references/complexity-scaling.md`** — tier classification, proportional sizing, feedback amendment protocol
