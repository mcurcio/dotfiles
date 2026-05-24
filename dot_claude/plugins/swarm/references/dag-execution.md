# DAG Execution Protocol

Manages parallel dispatch of independent work units based on dependency graphs.

## Where DAG Execution Applies

### Implementation Phase (Primary)

Parse the plan's flow model into a dependency graph. Independent phases (no edge between them) run in parallel through their full lifecycle (pre-flight → replacement → post-review).

- Parse plan's flow model into dependency graph
- Compute ready set: phases with all dependencies satisfied
- Dispatch ready phases simultaneously
- On phase completion, recompute ready set and dispatch newly unblocked phases

### Plan Phase (Secondary)

Single coordination loop (code-arch leads, sys-arch and requirements react). If the plan identifies independent per-phase elaborations, those can run in parallel — edge case, not default.

## Execution Algorithm

```
1. Parse flow model into DAG
2. Compute ready set (all nodes with in-degree 0 or all predecessors complete)
3. For each node in ready set:
   a. Verify file isolation (non-overlapping scopes)
   b. Dispatch phase lifecycle (pre-flight → replacement → post-review)
4. Wait for any phase to complete
5. On completion:
   a. If post-review produced downstream delta → deliver to affected phases' pre-flight
   b. Recompute ready set
   c. Dispatch newly ready phases
6. Repeat until all phases complete
```

## File Isolation Requirement

Parallel phases MUST have non-overlapping file scopes. The plan's per-phase spec defines boundaries.

- Plan guarantees isolation → dispatch in parallel
- Plan does not guarantee isolation → execute sequentially, flag as plan quality issue
- Include file scope boundaries in every implementation agent's prompt

## DAG-Invalidation Check

**Trigger:** Pre-flight for Phase N produces a correction.

**Procedure:**

1. Read the correction diff
2. Check running parallel phases for shared interfaces, types, or dependencies with corrected elements
3. Affected → pause before convergence; unaffected → proceed

**Timing:** Immediately after pre-flight correction, before the replacement loop begins.

## Downstream Deltas and the DAG

**Structural invariant:** Deltas target only dependency-downstream phases, never parallel phases.

- Post-review writes a delta → orchestrator determines affected phases from DAG edges
- Only direct or transitive dependents receive the delta
- Deltas delivered to affected phases' pre-flight as input

## Completion Callback

When a phase completes:

1. Write status files (`replacement/status.json`, `post-review/status.json`)
2. If post-review signal is "adjust" → write downstream delta BEFORE dispatching dependents
3. Recompute ready set
4. Dispatch newly unblocked phases (their pre-flight reads any pending deltas)

## Task Structure

Per-phase tasks reflect the full lifecycle:

```
Phase N: Pre-flight
Phase N: Implementation (replacement loop)
Phase N: Post-review
Phase N: Complete
```

Parallel phases have independent task chains. The orchestrator tracks all simultaneously.

## Error Handling

- **Phase escalation:** Does not block parallel phases — independent by definition
- **Pre-flight correction affecting parallels:** Pause affected phases (per DAG-invalidation check)
- **Human escalation:** Only the specific phase pauses; parallel phases continue unless DAG-invalidation check implicates them
- **Cap hit in one phase:** Other phases continue independently
