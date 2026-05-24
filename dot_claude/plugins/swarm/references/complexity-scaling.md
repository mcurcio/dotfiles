# Complexity Scaling Rubric

Proportional process intensity based on project complexity. The orchestrator evaluates tier at session start and adjusts artifact volume, reactor policy, model selection, and feedback handling accordingly.

## Tier Classification

Evaluate at swarm start using these signals. Use the **highest-matching** tier.

| Signal | Small | Medium | Large |
|--------|-------|--------|-------|
| Expected source files | ≤5 | 6–20 | 20+ |
| Service/process count | 1 | 1–2 | 3+ |
| External dependencies | ≤2 | 3–5 | 5+ |
| Internal module boundaries | 1–2 | 3–4 | 5+ |
| Cross-team coordination | None | Optional | Required |
| State machines / protocols | 0–1 | 2–3 | 4+ |

**Examples:**
- **Small:** mcp-auth-proxy, CLI tool, single MCP server, config utility
- **Medium:** MCP server with auth + persistence + admin UI, multi-module service
- **Large:** New platform service with API + workers + storage + cross-service contracts

Record the tier in `meta.json` as `"tier": "small" | "medium" | "large"`.

## Per-Tier Process Knobs

### Design Phase (swarm:design)

| Knob | Small | Medium | Large |
|------|-------|--------|-------|
| Architecture output files | 1–2 combined | 3–5 focused | 6–8 granular |
| Code design output files | 1–2 combined | 3–5 focused | 6–8 granular |
| Requirements output files | 1–2 | 2–3 | 3–4 |
| Documentation artifacts | 1 combined spec | 2–3 docs | Per-concern docs |
| Max recommended lines per output file | 200 | 300 | 400 |

**Small guidance:** Combine related concerns. A single `architecture.md` covering boundaries + interfaces + failure modes is better than 8 separate files for a 5-file service. The manifest still lists all concern areas — they're just sections, not files.

**Medium guidance:** Split by concern area, not by sub-concern. One `interfaces.md` not `interfaces/auth.md` + `interfaces/core.md` + `interfaces/transport.md`.

**Large guidance:** Full granularity. Separate files per concern, subdirectories for grouping. Each file stays focused enough for a single agent to consume without overflow.

### Plan Phase (swarm:plan)

| Knob | Small | Medium | Large |
|------|-------|--------|-------|
| Phase spec detail level | Compact (deliverables + files + verification) | Standard (full plan-format.md) | Detailed (full + integration notes) |
| Max recommended phases | 3–4 | 4–6 | 6–10 |
| Workstreams per phase | 1 | 1–2 | 2–4 |
| Traceability depth | AC → Phase mapping | AC → Phase + workstream | AC → Phase + workstream + file |

### Reactor Policy

Reactors always run. The triad exists for perspective diversity — each member catches what the others miss. The cost optimization is **model selection**, not skipping reactors.

| Knob | Small | Medium | Large |
|------|-------|--------|-------|
| Design loops: reactors | Both react at Sonnet (upgrade to Opus if any reactor ITERATING) | Both react at Opus | Both react at Opus |
| Plan loop: reactors | Both react at Sonnet (upgrade to Opus if any reactor ITERATING) | Both react at Opus | Both react at Opus |
| Reactor model (rubber-stamp round) | Sonnet | Sonnet | Opus |
| Reactor model (substantive feedback) | Opus | Opus | Opus |

**Reactor escalation:** If a Sonnet reactor declares ITERATING, the next round's reactors upgrade to Opus. The concern may require deeper reasoning than Sonnet can provide.

**The only case with zero reactors:** Orchestrator amendments on structural/additive user feedback (see § Feedback Amendment Protocol). The user IS the verifier — they gave the instruction. No triad member needs to validate "move tests into implementation phases."

### Model Selection

| Role | Small | Medium | Large |
|------|-------|--------|-------|
| Leader (design/plan) | Opus | Opus | Opus |
| Reactor (default) | Sonnet | Opus | Opus |
| Reactor (after any ITERATING) | Opus | Opus | Opus |
| Implementer | Sonnet | Sonnet | Sonnet |
| Verifier (replacement) | Sonnet | Sonnet | Opus |

Leaders always get Opus — creative synthesis requires full capability. Small-tier reactors start at Sonnet but upgrade to Opus the moment any reactor declares ITERATING (indicating the concern needs deeper reasoning). Medium and Large tier reactors always use Opus.

## Feedback Amendment Protocol

When user provides feedback on a converged artifact, the orchestrator classifies the feedback before deciding the response path.

### Classification

| Feedback type | Signal | Response |
|---------------|--------|----------|
| **Structural** | Reorder, merge, split, rename, move sections between phases, eliminate a phase | Orchestrator amends in-place |
| **Additive** | Add a concern, include tests with code, add a new phase | Orchestrator amends in-place |
| **Substantive** | Rethink an approach, change a boundary, redesign an interface | Re-run leader + Sonnet reactors (upgrade to Opus if any reactor ITERATING) |
| **Directional** | Change fundamental assumptions, pivot scope, reject a design decision | Re-enter the appropriate loop with full protocol |

### Amendment Path (structural / additive feedback)

1. Orchestrator reads the converged output files
2. Orchestrator edits files directly (Edit tool, not a spawned agent)
3. Orchestrator updates manifest: increment round, add "Changes from Previous Round" section, keep status CONVERGED
4. Write output to `round-N+1/output/` (preserves audit trail)
5. Update `latest` symlink
6. **No reactor spawning.** The user IS the verifier for their own feedback.

### Re-run Path (substantive feedback)

1. Compose leader prompt with: previous output + user feedback (verbatim) + interpretation
2. Spawn single leader agent (Opus)
3. Leader writes new complete output to `round-N+1/output/`
4. Spawn reactors at the tier's rubber-stamp model (see § Model Selection: Small/Medium = Sonnet, Large = Opus). If any reactor declares ITERATING, upgrade to Opus for the next round.

### Directional Feedback

Full loop re-entry per existing protocol (gate nullification, re-run from appropriate stage).

### Feedback Classification Heuristic

When in doubt, ask yourself: "Does this feedback require creative judgment, or is it a mechanical transformation?"

- **Mechanical:** "move X into Y", "split this into two", "rename", "include tests with implementation", "eliminate phase N" → Amend
- **Judgment:** "this boundary feels wrong", "I'm not sure about the auth approach", "what if we used X instead?" → Re-run or directional

## Tier Upgrade / Downgrade

The initial classification can be wrong. Watch for these signals:

**Upgrade triggers** (complexity is higher than expected):
- Architecture loop produces >5 rounds
- Multiple cross-cutting concerns discovered during code design
- Reactors consistently produce substantive (non-rubber-stamp) feedback
- Plan synthesis reveals >6 phases needed

**Downgrade triggers** (complexity is lower than expected):
- All loops converge unanimously round 1
- Architecture output is mostly boilerplate / padded
- Code design reveals the project is simpler than the file count suggests
- Requirements are few and unambiguous

**On upgrade:** Update `meta.json` tier field to the new value (Read + Write pattern per `references/swarm-sessions.md`). Switch to the higher tier's knobs immediately. Already-completed loops retain their output (don't re-run).

**On downgrade:** Update `meta.json` tier field to the new value. Reduce artifact requirements for remaining loops. Consolidate existing output if entering planning (combine redundant architecture files into fewer documents).

## Integration Points

This rubric is referenced by:
- `skills/design/SKILL.md` — orchestrator evaluates tier at session start, injects file-count guidance into leader prompts
- `skills/plan/SKILL.md` — orchestrator uses tier for plan detail level and reactor policy
- `skills/implement/SKILL.md` — orchestrator uses tier for pre-flight/post-review intensity
- `references/iterative-design-loop.md` — reactor spawning respects tier-based model selection
- `references/triad-lifecycle.md` — model selection per tier

## Redundancy Elimination

The design → plan pipeline has a structural redundancy problem: interface contracts get defined in architecture, restated with more detail in code-design, then restated again in phase specs. Each restatement costs tokens to produce and tokens for the next agent to read.

**Rule: downstream stages reference, not restate.**

| Stage | Owns | References |
|-------|------|-----------|
| Architecture | System boundaries, protocol choices, failure modes, interface shapes | Requirements |
| Code design | Module decomposition, file layout, type definitions, dependency graph | Architecture |
| Plan | Build order, file assignment, verification commands, scope boundaries | Code design + Architecture |

**What this means for plan phase specs:**
- DON'T include method signatures, constructor args, response formats — those are in code-design
- DO include: which spec section to implement, file path, verification command, scope boundary
- The implementer reads the design spec directly. The plan tells them WHAT to build and in what ORDER, not HOW (the spec does that).

**Exception:** Large-tier projects may inline critical interface details when the implementer agent would otherwise need to read 5+ upstream files to assemble context. Even then, prefer a summary table with spec-section references over full restating.

## Invariants

- Tier classification does not affect convergence criteria (still requires leader + reactor agreement)
- Tier classification does not affect gate requirements (still hard-gated on user approval)
- Tier classification does not reduce the number of coordination loops (still 3 in design, 1 in plan)
- The amendment path is always available regardless of tier when feedback is structural/additive
- Leaders always get Opus regardless of tier
