# Agent Routing Table

Which agents to dispatch for each review type. All agents use model: opus.

## Agent Matrix

| Agent | Source | When to dispatch | Model |
|---|---|---|---|
| matt-review:code-reviewer | Custom | Always for code changes | opus |
| matt-review:design-reviewer | Custom | New modules, services, domain concepts, ADRs, RFCs, or explicit design/architecture review request | opus |
| pr-review-toolkit:silent-failure-hunter | Marketplace | Error handling or catch blocks changed in diff | opus (override) |
| pr-review-toolkit:pr-test-analyzer | Marketplace | Test files added or changed | opus (override) |
| pr-review-toolkit:type-design-analyzer | Marketplace | New types or interfaces introduced | opus (override) |
| matt-review:pr-publisher | Custom | User requests PR posting or update | opus |

## Dispatch Rules

### Standard code PR
- **Always**: code-reviewer
- **If error handling / catch blocks changed**: + silent-failure-hunter
- **If test files changed**: + pr-test-analyzer
- **If new types/interfaces introduced**: + type-design-analyzer

### PR with architecture changes
Signals: new directories, new service boundaries, domain model changes, cross-cutting concern modifications (auth, infra, rollout).
- **Always**: code-reviewer + design-reviewer
- **Plus** applicable marketplace agents per above

### Design doc / ADR / RFC only
- **Only**: design-reviewer

### Local files (no PR)
- **Only**: code-reviewer

### PR publishing
- **Only when user explicitly asks**: pr-publisher

## Marketplace Agent Overrides

When dispatching marketplace agents from pr-review-toolkit, always specify `model: opus` to override their defaults. Pass the review context (diff, changed files) as task input.
