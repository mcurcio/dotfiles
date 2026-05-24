# Two-Adjacent Convergence Protocol

Two independent perspectives must agree for a loop to close. The mechanism varies by loop type.

## Why Two-Adjacent

Single agent self-reporting "done" is unreliable. Fresh eyes catch what the original missed. Low cost of verification vs high cost of shipping gaps.

## Per-Loop-Type Rules

### Coordination Loops (Leader + Reactors)

**Convergence rule:** Leader CONVERGED AND all reactors CONVERGED in the same round → loop closes.

- Any reactor ITERATING → next round; leader incorporates feedback
- Reactors ARE the fresh eyes — no additional verification round needed
- Leader may declare ITERATING on a best-effort proposal to solicit feedback before committing

### Replacement Loops (Implementation Teams)

1. Team N reports done → shut down
2. Fresh team N+1 checks implementation against proposal
   - "No work to do" → CONVERGED
   - Work remaining → do it, shut down, spawn another

**Oscillation detection:** Replacement team undoes prior team's work (visible in reports or git diffs) → escalate immediately. Indicates proposal ambiguity.

**Escalation sequence:** Per-phase triad gets one clarification attempt (1 round max). Triad converges → restart replacement loop with corrected proposal. Triad can't clarify or oscillation recurs → escalate to human.

## Convergence Metadata

After any loop closes, the final manifest includes:

```yaml
convergence:
  coordination_rounds: 2
  signal: unanimous | negotiated | escalated
```

### Field Reference

| Field | Type | Purpose |
|---|---|---|
| `coordination_rounds` | int | Total coordination loop rounds |
| `signal` | enum | Summary classification |

### Signal Definitions

| Signal | Coordination Loops | Replacement Loops |
|---|---|---|
| **unanimous** | Leader + all reactors CONVERGED round 1 | First team + verification team agree (2 teams) |
| **negotiated** | Required 2+ rounds | Required 3+ teams |
| **escalated** | Hit round cap or needed human input | Hit replacement cap or needed human intervention |

### Where Convergence Metadata Lives

| Loop | Manifest Location |
|---|---|
| Coordination loop | The stage's `latest/manifest.md` (leader's final output) |
| Replacement loop | The converging replacement team's final report |

The orchestrator writes the `convergence` block after evaluating closure conditions. Agents only write `status`.

## How Signals Inform Downstream

Signals are advisory for process intensity, never a license to skip verification.

| Context | Signal | Implication |
|---|---|---|
| After plan synthesis | `unanimous` | Lighter pre-flight (plan likely stable) |
| After plan synthesis | `negotiated` | Thorough pre-flight; disagreements suggest unstable areas |
| After plan synthesis | `escalated` | Flag specific disagreement points in pre-flight prompts |
| After pre-flight | Pass-through or correction accepted | Normal replacement loop |
| After pre-flight | Escalated (disagreement) | Pause; present to user before implementation |

## Round Caps

- **Coordination loops:** 5 rounds max. Round 5 still has any reactor ITERATING → escalate.
- **Replacement loops:** 5 teams max. Team 5 still finds work → escalate.

Cap hit → orchestrator pauses, escalates to user. Signal set to `escalated`.
