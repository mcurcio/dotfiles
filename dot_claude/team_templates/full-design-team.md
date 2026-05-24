# Full Design Team

## When to use

Greenfield features, major refactors, or any work that needs design, implementation, documentation, and validation as a coordinated effort across the assistant stack.

## Spawn prompt

```
Create an agent team with six teammates:

1. facilitator agent type — decompose my request into tasks, route work to the right agents, track progress, synthesize results, and escalate decisions to me. Do not design or write code.

2. system-architect agent type — design the system-level architecture: service boundaries, protocols, state machines, failure modes. Peer with code-architect; converge on shared interface contracts.

3. code-architect agent type — design the implementation architecture: module structure, types, dependency graph, build sequence. Peer with system-architect; challenge proposals that don't map to real code.

4. ts-implementer agent type — implement TypeScript/Node.js code per the approved design. Owns MCP servers, OpenClaw extensions, and TS service code. Do not start until the design is approved by the user.

5. infra-implementer agent type — implement Python, Bash, Docker, YAML, Makefile, and skill CLI code per the approved design. Owns key-broker, guardrails, compose config, entrypoints, and skills. Do not start until the design is approved by the user.

6. verifier agent type — write test suites and review implementations from both implementers against the design. Cover golden path, edge cases, and error conditions. Review for abstraction leakage, type safety, and security.

Coordination rules:
- Facilitator decomposes work and routes tasks. Agents message each other directly for domain work.
- Architects work in parallel as peers. They message each other to challenge, refine, and converge.
- Design must be approved by me before any implementation starts (hard gate).
- Implementers work in parallel on their respective surfaces after design approval.
- Verifier reviews after implementers finish.
- Nothing gets committed without my sign-off.
- Surface all disagreements, ambiguity, and high-blast-radius decisions to me — don't guess.
```

## Task breakdown guidance

Aim for 3-6 tasks per teammate depending on scope.

**Facilitator:**
- Decompose user request into design + implementation + verification tasks
- Route design tasks to architects, implementation to the right implementer(s)
- Surface design spec to user for approval (hard gate)
- Synthesize final state for user review

**Architects (parallel):**
- Analyze requirements and existing codebase
- Produce initial design from their perspective
- Review peer's design and challenge/refine
- Converge on shared interface contracts
- Document final design and open questions

**ts-implementer (after design approval):**
- Implement TypeScript changes in dependency order
- Write docblocks and module documentation
- Self-review against architect specs before handing to verifier

**infra-implementer (after design approval):**
- Implement Python/Bash/Docker/YAML changes in dependency order
- Write docblocks, SKILL.md for new skills
- Self-review against architect specs before handing to verifier

**Verifier (after implementers):**
- Write tests covering contracts, edge cases, and error paths
- Run test suites and report results
- Review implementations against both architect specs
- Produce findings report with severity ratings

## Variations

### Lightweight (skip system-architect, single implementer)

For changes scoped to a single service where system-level design isn't needed:

```
Create an agent team with four teammates:
1. facilitator agent type — decompose and coordinate
2. code-architect agent type — design the implementation
3. ts-implementer OR infra-implementer agent type — build it (pick the right surface)
4. verifier agent type — test and review
```

### Review-only (skip implementers)

For reviewing existing code or PRs:

```
Create an agent team with four teammates:
1. facilitator agent type — coordinate the review
2. system-architect agent type — review system-level design decisions
3. code-architect agent type — review implementation architecture
4. verifier agent type — validate test coverage and code quality
Have them review independently, then share findings with each other.
```

### Architects-only

For early-stage design exploration before any code is written:

```
Create an agent team with three teammates:
1. facilitator agent type — coordinate exploration and synthesize
2. system-architect agent type — design from the system perspective
3. code-architect agent type — design from the implementation perspective
Have the architects work as peers: share proposals, challenge each other, and converge.
```
