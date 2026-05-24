---
name: design
description: "This skill should be used when the user asks to \"design with the team\", \"start design\", \"start a design session\", \"architect this with the team\", \"swarm design\", \"brainstorm with the triad\", \"let's design this\", or invokes /swarm:design. Orchestrates collaborative design using the advisory triad (requirements + system-architect + code-architect) with three sequential coordination loops. Each triad member leads one loop while the others react. Swarm state is session-keyed and resumable."
argument-hint: "[topic or requirements]"
allowed-tools: ["Agent", "SendMessage", "Skill", "Read", "Bash", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "Write", "Edit"]
---

# Collaborative Design with the Advisory Triad

Three sequential coordination loops — each triad member gets a full leadership turn while the others react and refine.

**Announce at start:** "Using swarm:design to run an iterative triad-assisted design session."

## On Start: Session Setup

Read `references/swarm-sessions.md` for the full session model.
Read `references/complexity-scaling.md` for the scaling rubric.

| Condition | Action |
|---|---|
| `active.json` exists, `phase` = `design` | **Resume** — read swarm ID, current step, pick up from there |
| `active.json` exists, `phase` ≠ `design` | Past design. Suggest `swarm:plan` or `swarm:implement`. |
| `active.json` absent | **Start new swarm** |

**Starting a new swarm:**
```bash
TOPIC="<user's topic>"
SWARM_ID="$(date +%Y-%m-%d)-$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 40)-$(head -c4 /dev/urandom | xxd -p)"
SWARM_ROOT=".claude/swarm/sessions/$SWARM_ID"

mkdir -p "$SWARM_ROOT"/{iterations/{requirements,architecture,code-design},specs,plans}
# Write meta.json + active.json per references/swarm-sessions.md
```

**Tier classification:** Evaluate project complexity per `references/complexity-scaling.md` and record `"tier"` in `meta.json`. This determines artifact volume, reactor policy, and model selection for the session. Tier can be upgraded/downgraded mid-session if signals warrant.

**Resuming:** Read `.claude/swarm/active.json`, extract `swarm_id`. Set `SWARM_ROOT=".claude/swarm/sessions/<swarm_id>"`. Update `active.json` with new `session_id`; append to `meta.json` sessions array (both via Read + Write).

**Check gates on resume:** If step implies a gate was passed but gate timestamp is `null` in `meta.json` → re-present output for approval. Convergence ≠ approval.

**Check feedback on resume:** `feedback` field present → route to target stage's re-entry.

All paths below use `<swarm-root>` as shorthand.

## Configuration

Spec output: `<swarm-root>/specs/`. Iterations: `<swarm-root>/iterations/`.

## Checklist

Create all tasks via `TaskCreate`, chain with `addBlockedBy`:

```
TaskCreate({ subject: "Session setup", description: "Create or resume swarm session, write active.json and meta.json" })
TaskCreate({ subject: "Requirements coordination loop", description: "reqs leads, sys-arch + code-arch react until all CONVERGED" })
TaskCreate({ subject: "Requirements approval (Gate 1)", description: "Present converged requirements to user — hard gate" })
TaskCreate({ subject: "Architecture coordination loop", description: "sys-arch leads, reqs + code-arch react until all CONVERGED" })
TaskCreate({ subject: "Code design coordination loop", description: "code-arch leads, sys-arch + reqs react until all CONVERGED" })
TaskCreate({ subject: "Design approval (Gate 2)", description: "Present architecture + code design together to user — hard gate" })
TaskCreate({ subject: "Write spec", description: "Save the approved design to the spec location" })
TaskCreate({ subject: "Transition to plan", description: "Hand off to swarm:plan" })
```

Chain each task `addBlockedBy` the previous. Mark `in_progress` when starting, `completed` when done. On resume, skip tasks with existing `latest/` + CONVERGED manifests.

## Process

Read `references/iterative-design-loop.md` for the coordination loop protocol, directory structure, manifest format, convergence criteria, and safety rails.

### Phase 1: Requirements Coordination Loop

**Leader:** requirements | **Reactors:** sys-arch (missing technical requirements, feasibility), code-arch (ambiguous criteria, implementability)

**Round 1:**
1. Compose leader prompt: user's goal, project context, requirements instructions. Include **Boundary** zoom scope block for **requirements** / **leader** per `references/admissible-scope.md`. Include tier-scaled guidance from `references/complexity-scaling.md` § Per-Tier Process Knobs → Design Phase (target output file count for requirements).
2. Persist prompt to `<swarm-root>/iterations/requirements/round-1/prompt.md`.
3. Spawn fresh `requirements` agent → writes to `round-1/output/`, sets manifest status to CONVERGED or ITERATING. Leader may declare ITERATING to solicit reactor feedback.
4. Shut down. Validate manifest. Update `latest` symlink. Update step: `requirements-round-1`.

**Reactors (after each leader round):**
5. Spawn in parallel:
   - **sys-arch:** reads `latest/manifest.md`, writes to `round-N/reactions/system-design/`. Boundary zoom / reactor framing.
   - **code-arch:** reads `latest/manifest.md`, writes to `round-N/reactions/code-design/`. Boundary zoom / reactor framing.
   - Reactors provide constructive alternatives when flagging problems.
6. Shut down both.

**Convergence:** Leader CONVERGED + all reactors CONVERGED → proceed to Gate 1. Any ITERATING → next round with reactor feedback paths.

**Round 2+:** Same protocol. Leader prompt adds: previous `latest/manifest.md` + reactor feedback paths. Leader must address alternatives, not just acknowledge. Update step: `requirements-round-N`.

Max 5 rounds. Cap hit → escalate.

### Gate 1: Requirements Approval

> **Approving requirements** = "The problem is stated correctly." Confirms *what* to build — scope, acceptance criteria, priority ordering, test cases.

**Artifacts shown:** requirements with acceptance criteria, scope boundaries, priority ordering, test cases (Given/When/Then).

- **Approve** → proceed to architecture
- **Feedback** → re-enter requirements at round N+1

Hard gate — architecture does not begin until approved.

On feedback: Read `active.json`, set `.feedback = {"text": "<user feedback>", "target_stage": "requirements", "received_at": "<ISO timestamp>"}`, Write it back. Re-enter requirements. Next leader prompt includes feedback verbatim. Clear `feedback` after re-entry begins.

On approval: Read `<swarm-root>/meta.json`, set `.gates.requirements_approved = "<ISO timestamp>"` and `.updated_at`, Write it back. Update step: `requirements-approved`.

### Phase 2: Architecture Coordination Loop

**Leader:** sys-arch | **Reactors:** requirements (compliance), code-arch (coupling, testability, dependency risks)

**Round 1:**
1. Compose sys-arch prompt: path to approved requirements (`iterations/requirements/latest/`), project context. **Boundary** zoom / **leader** framing. Include tier-scaled guidance from `references/complexity-scaling.md` § Per-Tier Process Knobs → Design Phase (target file count and max lines per file).
2. Persist to `iterations/architecture/round-1/prompt.md`.
3. Spawn `system-architect` → writes to `round-1/output/`. Typical output: boundary definitions, interface contracts, state machines, failure modes, dependency sequencing.
4. Shut down. Validate. Update `latest`. Step: `architecture-round-1`.

**Reactors:**
5. Spawn in parallel:
   - **requirements:** compliance with acceptance criteria. Boundary / reactor.
   - **code-arch:** coupling, testability, structural feasibility. Provides constructive alternatives. Boundary / reactor.
6. Shut down.

**Convergence:** Same as Phase 1. Leader must address reactor alternatives.

**Round 2+:** Sys-arch prompt adds: own `latest/manifest.md` + reactor feedback + approved requirements. Step: `architecture-round-N`.

Max 5 rounds. Cap hit → escalate.

### Phase 3: Code Design Coordination Loop

**Leader:** code-arch | **Reactors:** sys-arch (modules align with boundaries), requirements (all requirements map to modules)

Code-arch's primary constructive phase — full module design deferred from architecture.

**Inputs:** converged requirements (`iterations/requirements/latest/`) + converged architecture (`iterations/architecture/latest/`)

**Round 1:**
1. Compose code-arch prompt: paths to requirements + architecture, project context. **Structural** zoom / **leader** framing. Include tier-scaled guidance from `references/complexity-scaling.md` § Per-Tier Process Knobs → Design Phase (target file count and max lines per file).
2. Persist to `iterations/code-design/round-1/prompt.md`.
3. Spawn `code-architect` → writes to `round-1/output/`. Expected: module decomposition, interfaces, dependency graph, type hierarchies, test architecture.
4. Shut down. Validate. Update `latest`. Step: `code-design-round-1`.

**Reactors:**
5. Spawn in parallel:
   - **sys-arch:** modules align with system boundaries. Structural / reactor.
   - **requirements:** all requirements trace to modules. Structural / reactor.
6. Shut down.

**Convergence:** Same as Phase 1.

**Round 2+:** Code-arch prompt adds: own `latest/manifest.md` + reactor feedback + requirements + architecture. Step: `code-design-round-N`.

Max 5 rounds. Cap hit → escalate.

### Gate 2: Design Approval

> **Approving design** = "The solution is sound and decomposable." Confirms *how* to build — system boundaries, contracts, module structure, interfaces.

**Artifacts shown:** system boundaries + contracts (architecture), module decomposition + interfaces (code design), dependency graph, test architecture, requirements traceability.

Include: synthesized summary, compliance status, paths to output files.

- **Approve** → proceed to spec writing and plan handoff
- **Feedback** → orchestrator drives clarifying conversation (see below)

Hard gate — planning does not begin until approved.

### User Feedback Routing

At Gate 2, understand the concern before routing.

**Step 0 — Classify feedback intensity** per `references/complexity-scaling.md` § Feedback Amendment Protocol:
- **Structural/Additive** (reorder, merge, add concern) → Orchestrator amends in-place. No agent spawn. No gate nullification.
- **Substantive** (rethink approach, change boundary) → Re-run leader + reactors at tier's rubber-stamp model (Small/Medium = Sonnet, Large = Opus; upgrade to Opus if any reactor ITERATING).
- **Directional** (reject decision, pivot scope) → Full loop re-entry (below).

**Step 1 — Clarify** (directional/substantive only):
- Affects *what* we're building (scope, criteria)? → Requirements
- Affects *system boundaries, contracts, service structure*? → Architecture
- Affects *module decomposition, interfaces, internal structure*? → Code Design

**Step 2 — Route** to appropriate stage with clarified feedback in leader prompt.

If ambiguous after clarification → state classification, ask user to confirm.

**Gate nullification on re-entry:** Read `<swarm-root>/meta.json`, null the appropriate gates per the table in `references/swarm-sessions.md`, set `updated_at`, Write it back. Only nullify gates for directional feedback — structural amendments don't affect gate status.

**Feedback persistence:** Read `active.json`, set `.feedback = {"text": "<clarified feedback>", "target_stage": "<requirements|architecture|code-design>", "received_at": "<ISO timestamp>"}`, Write it back.

Re-entry starts round N+1 (preserving audit trail). If re-entering upstream stage, subsequent stages re-run fresh from round 1.

### Brainstorming Integration

Invoke `superpowers:brainstorming` for the initial user conversation. Override its terminal state — transition to `swarm:plan` after spec approval, not `superpowers:writing-plans`.

**Fallback:** If unavailable, run manual brainstorming: explore context, ask clarifying questions, propose 2-3 approaches.

### Spec Output

Save approved design to `<swarm-root>/specs/`. Include "Requirements Traceability" section mapping components → requirements. If project root is a git repo, commit.

### Handoff to Plan

After approval:
1. Record gate: Read `<swarm-root>/meta.json`, set `.gates.design_approved = "<ISO timestamp>"` and `.updated_at`, Write it back.
2. Update `active.json`/`meta.json`: set `phase: "plan"`, `step: "starting"` (Read, modify, Write each).
3. Announce: "Design approved and saved to `<path>`. Invoking swarm:plan to produce the implementation plan with the triad."
4. Invoke `swarm:plan`.

## Documentation Artifact Mandate

Each leader MUST write/update their owned documentation in the project repo during their coordination loop — not just iteration artifacts under `<swarm-root>/`. These are living documents that get refined through rounds and across phases.

| Leader | Documentation Artifact | Location |
|--------|----------------------|----------|
| requirements | System specification / requirements docs | Project `docs/` or `specs/` directory (outside source code) |
| sys-arch | System architecture documentation | Both in-code (module-level) and external (`docs/architecture/`) |
| code-arch | API, interface, and schema documentation | Project docs alongside the code they describe |

**Rules:**
- Leaders write/update repo docs as part of their round output (in addition to iteration files)
- Docs are iterable — they may change across rounds and even across phases (e.g., architecture loop may trigger requirements doc updates via the requirements reactor)
- By the time a gate is approved, the corresponding docs reflect the approved state
- Implementation agents work against these committed docs, not iteration artifacts
- The manifest `files` list should reference repo doc paths that were created/updated in that round
- These docs are the source of truth for interface contracts and type definitions. Plan phase specs reference them by section — not restate them (see `references/complexity-scaling.md` § Redundancy Elimination)

**What this means per phase:**
- After Phase 1 converges + Gate 1 approval: requirements docs exist in the repo
- After Phase 2 converges: architecture docs exist in the repo, consistent with requirements
- After Phase 3 converges + Gate 2 approval: interface/schema docs exist in the repo, consistent with architecture and requirements
- Implementation phase reads repo docs as source of truth

## Key Principles

- Session-keyed and resumable — all state under swarm session directory
- Every loop is a coordination loop — leader + at least one reactor
- Each triad member leads once — reqs → sys-arch → code-arch
- Sequential — architecture depends on requirements; code design depends on architecture
- Rounds are directories — manifest + as many output files as needed
- Fresh agents every round — persisted files are context
- Convergence is earned — all participants CONVERGED in same round
- Leaders may solicit feedback via ITERATING
- Reactors provide constructive alternatives
- Complete output each round — self-contained, not a diff
- Two gates — requirements (problem) and design (solution)
- Triad advises, user decides

## Resume Protocol

1. Read `active.json` for phase/step
2. Read `meta.json` for gate states
3. `feedback` field present → route to re-entry
4. Scan iteration directories for last `latest` symlink
5. `active.json` step ahead of directory state → trust directory state

Resume granularity: last fully-completed round. Partial rounds are discarded.

## Additional Resources

- **`references/swarm-sessions.md`** — session model, lifecycle, resume protocol, cleanup
- **`references/iterative-design-loop.md`** — coordination loop protocol, directory structure, manifest format, convergence criteria
- **`references/two-adjacent-convergence.md`** — convergence rules for coordination loops
- **`references/admissible-scope.md`** — scope block contract for leader and reactor prompts
- **`references/triad-lifecycle.md`** — spawning, health checks, authority model
- **`references/complexity-scaling.md`** — tier classification, proportional artifact sizing, feedback amendment protocol

## Prerequisites

- **superpowers plugin** — `superpowers:brainstorming` skill (graceful fallback if absent)
- **Agent definitions** — `requirements`, `system-architect`, `code-architect` in `~/.claude/agents/`
