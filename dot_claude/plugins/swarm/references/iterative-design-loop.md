# Coordination Loop Protocol

Every design and plan loop uses a single model: a fresh leader produces output, fresh reactors verify independently, the round repeats until all participants converge.

All artifacts live under the **swarm root** (`.claude/swarm/sessions/<swarm-id>/`). See `references/swarm-sessions.md` for the session model and resume protocol.

## Why It Works

Fresh agents catch blind spots the original author normalized. Reactors reviewing output independently — never having seen intermediate thinking — catch gaps and contradictions. Persisting every round's artifacts means the orchestrator never loses state.

## Core Model: Rounds Are Directories, Not Files

**The unit of iteration is a directory per round, not a file per round.**

Each round produces:
- A prompt file (written by orchestrator before spawning)
- An output directory containing as many files as the leader needs
- A manifest file listing what was produced and why
- A reactions directory with one subdirectory per reactor

A `latest` symlink always points to the most recent round's `output/` directory, updated atomically after the round completes.

## Artifact Directory Structure

All iterative design artifacts live under `<swarm-root>/iterations/`:

```
<swarm-root>/iterations/
├── requirements/                        # Phase 1: reqs leads
│   ├── round-1/
│   │   ├── prompt.md
│   │   ├── output/                      # Leader's output
│   │   │   ├── manifest.md
│   │   │   └── ...
│   │   └── reactions/
│   │       ├── system-design/
│   │       │   ├── manifest.md
│   │       │   └── ...
│   │       └── code-design/
│   │           ├── manifest.md
│   │           └── ...
│   ├── round-2/
│   │   └── ...
│   └── latest -> round-N/output/
│
├── architecture/                        # Phase 2: sys-arch leads
│   ├── round-1/
│   │   ├── prompt.md
│   │   ├── output/
│   │   │   ├── manifest.md
│   │   │   └── ...
│   │   └── reactions/
│   │       ├── requirements/
│   │       │   └── ...
│   │       └── code-design/
│   │           └── ...
│   ├── round-2/
│   │   └── ...
│   └── latest -> round-N/output/
│
├── code-design/                         # Phase 3: code-arch leads
│   ├── round-1/
│   │   ├── prompt.md
│   │   ├── output/
│   │   │   ├── manifest.md
│   │   │   └── ...
│   │   └── reactions/
│   │       ├── requirements/
│   │       │   └── ...
│   │       └── system-design/
│   │           └── ...
│   ├── round-2/
│   │   └── ...
│   └── latest -> round-N/output/
│
├── planning/                            # Phase 4: code-arch leads
│   ├── round-1/
│   │   ├── prompt.md
│   │   ├── output/
│   │   │   ├── manifest.md
│   │   │   ├── dag.md                   # Implementation DAG
│   │   │   ├── phase-N-spec.md          # Per-phase specifications
│   │   │   ├── team-shapes.md           # Per-phase team composition
│   │   │   └── traceability.md          # Requirements → phase mapping
│   │   └── reactions/
│   │       ├── system-design/
│   │       │   └── ...
│   │       └── requirements/
│   │           └── ...
│   └── latest -> round-N/output/
│
└── implementation/                      # Phase 5
    └── phase-N/
        ├── pre-flight/
        ├── replacement/
        └── post-review/
```

## The Manifest

Every round's output directory must contain `manifest.md` at its root — the next agent reads it first to understand the output shape.

YAML frontmatter for machine-readable fields, followed by free-form Markdown. Orchestrator parses frontmatter for convergence and file enumeration; agents read the full document.

```markdown
---
status: ITERATING | CONVERGED
round: 2
files:
  - path: boundaries.md
    purpose: Service boundary definitions and ownership
  - path: contracts.md
    purpose: Interface contracts between services
  - path: state-machines.md
    purpose: State machine diagrams for auth and session lifecycle
  - path: interfaces/auth.md
    purpose: Auth service interface definition
convergence:
  coordination_rounds: 2
  signal: negotiated
---

# Round 2 Output Manifest

## Convergence Notes
[If CONVERGED: why this is complete. If ITERATING: what still needs work.]

## Changes from Previous Round
(omit for round 1)
- Refined auth boundary — split auth-session from auth-identity
- Removed stale WebSocket contract (replaced by event bus)
```

### Frontmatter field reference

| Field | Required | Values | Purpose |
|-------|----------|--------|---------|
| `status` | yes | `ITERATING` or `CONVERGED` (exact, uppercase) | Canonical convergence signal |
| `round` | yes | integer | Must match directory name |
| `files` | yes | list of `{path, purpose}` | Exhaustive file inventory |
| `convergence` | no | object | Written by orchestrator after loop closes |

### Files list rules

- Must include every file in output directory except `manifest.md`
- Paths relative to output directory root (forward slashes for subdirs)
- File in directory but not in list = error
- File in list but not in directory = error

The manifest provides: discovery (what files exist), convergence signal (`status`), diff summary (Changes section).

## The Coordination Loop (Generic)

All paths below are relative to `<swarm-root>/iterations/`.

```
1. Compose leader's round prompt:
   - Context: user's goal, project state, relevant upstream outputs
   - Previous output: <stage>/round-(N-1)/output/manifest.md (if round > 1)
   - Reactor feedback: <stage>/round-(N-1)/reactions/<reactor-domain>/ (if round > 1)
   - Instruction: read manifest, read all listed files, incorporate feedback, produce new complete output

2. Persist prompt: <stage>/round-N/prompt.md

3. Spawn fresh leader agent:
   - subagent_type matching the role
   - Self-contained prompt with: round prompt path, output directory path,
     instruction to write manifest.md first then all output files,
     scope boundaries, SendMessage to orchestrator when done

4. Leader writes round-N/output/manifest.md + all output files, reports done.

5. Shut down leader.

6. Validate manifest (orchestrator, via Bash):
   - Parse YAML frontmatter: must contain status, round, files
   - Every files entry must exist; no unlisted files in output/
   - Validation fails → do NOT update latest. Log and escalate.

7. Update latest symlink: ln -sfn round-N/output <stage>/latest

8. Spawn fresh reactor agents in parallel:
   - Each reads leader's round-N/output/ via manifest
   - Each writes to round-N/reactions/<reactor-domain>/ with own manifest
   - SendMessage to orchestrator when done

9. Shut down all reactors.

10. Evaluate convergence:
    - Leader CONVERGED + all reactors CONVERGED → loop closes.
      Write convergence metadata into final manifest.
    - Any participant ITERATING → go to step 1 for round N+1.
    - Round count hits cap (5) → escalate to human.

11. Update active.json and meta.json with current step.
```

## Leader Assignments

| Stage | Leader | Reactors |
|-------|--------|----------|
| Requirements (Phase 1) | requirements | sys-arch, code-arch |
| Architecture (Phase 2) | sys-arch | requirements, code-arch |
| Code Design (Phase 3) | code-arch | sys-arch, requirements |
| Plan Synthesis (Phase 4) | code-arch | sys-arch, requirements |

## Reactor Manifest

Reactors use the same manifest format. Convergence semantics:
- **CONVERGED** — no objections; leader's output is acceptable
- **ITERATING** — has feedback; output files contain specific concerns the leader must address

Reactor output is domain-scoped:
- requirements reactor: compliance gaps, missing acceptance criteria
- sys-arch reactor: boundary integrity, system feasibility
- code-arch reactor: module structure, coupling, testability

Reactors provide constructive alternatives when flagging problems — "this boundary is untestable — here's a restructuring that preserves intent while enabling isolation."

## Convergence

- Leader CONVERGED + all reactors CONVERGED in same round = loop closes
- Reactors are the fresh eyes — no additional verification round needed
- Leader may declare ITERATING to solicit reactor feedback before committing
- Max 5 coordination rounds. Cap hit → escalate.

## Convergence Metadata (written by orchestrator)

```yaml
convergence:
  coordination_rounds: 2
  signal: unanimous | negotiated | escalated
```

Signal definitions:
- **unanimous** — all participants declared CONVERGED in round 1
- **negotiated** — required 2+ rounds
- **escalated** — hit 5-round cap or required human intervention

Orchestrator writes this block; agents never write it.

## File Naming and Organization

- One file per concern area
- Subdirectories for grouping related files
- Descriptive filenames reflecting content
- Manifest is the index — filenames don't need to be exhaustively self-documenting
- Cross-reference by relative path when needed
- No writing outside designated output directory for iteration artifacts
- Manifest is required — omitting it is an error

## Documentation Artifact Output

In addition to iteration artifacts, leaders MUST write/update their owned documentation in the project repo during each round:

- **requirements** leader → system specification docs in project `docs/` or `specs/`
- **sys-arch** leader → architecture documentation (external and in-code module-level docs)
- **code-arch** leader → API, interface, and schema documentation

These repo docs are the primary deliverable — iteration files are the working record. The manifest should list repo paths that were created/updated. Docs are iterable across rounds; by gate approval they reflect the converged state.

## Safety Rails

- Max 5 coordination rounds. Cap hit → escalate.
- All artifacts persist. Never delete previous rounds.
- Fresh agents only. Never reuse across rounds.
- Orchestrator reads, agents write.
- Atomic latest/ updates via `ln -sfn`.
- Complete output each round — self-contained, not a diff.
- Every loop must have at least one reactor. Zero reactors = invalid. The only zero-reactor path is orchestrator amendments on structural user feedback (user IS the verifier).
- Update progress after each round.
- Artifact volume must be proportional to project complexity (see `references/complexity-scaling.md`). A 5-file service does not need 8 architecture documents.

## Integration with swarm:design

Three sequential coordination loops. Each gives one triad member a full constructive leadership pass.

1. Requirements loop (reqs leads, sys-arch + code-arch react) → **Gate 1: user approval**
2. Architecture loop (sys-arch leads, requirements + code-arch react)
3. Code design loop (code-arch leads, sys-arch + requirements react) → **Gate 2: user approval** (architecture + code design as unified view)
4. User feedback → orchestrator classifies, routes to appropriate stage, re-enters at round N+1
5. Final approval → save spec, transition to plan

## Integration with swarm:plan

Single coordination loop (code-arch leads, sys-arch + requirements react) producing:
- Implementation DAG (phase ordering with dependencies)
- Per-phase detailed specifications (interfaces, modules, files, tests, verification criteria)
- Per-phase team shapes (number of implementers, language specialties, testers)
- Requirements traceability per phase

Expected to converge in 1–2 rounds given rich upstream inputs. The 5-round cap is a safety net.

**Gate 3: user approval** before implementation begins.
