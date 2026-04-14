---
name: review-orchestrator
description: This skill should be used when the user asks to "review this", "review my PR", "review this design", "code review", "architecture review", "check this before I merge", "give me feedback on this", "review notes", "look at this PR", "check this code", "review this RFC", "review this ADR", or any request to analyze code, PRs, designs, ADRs, or RFCs for quality. Orchestrates parallel review agents and produces unified, evidence-backed findings in a question-first tone.
---

# Review Orchestrator

Unified entry point for all review requests. Triage the input, dispatch the right agents in parallel, collect raw findings, merge and deduplicate, then present in a consistent format.

## 1. Triage

Classify the input and determine which review lenses apply:

| Input | Signals | Agents to dispatch |
|---|---|---|
| PR number or URL | `gh pr view`, branch diff | code-reviewer; add marketplace agents per routing-table.md |
| PR with new modules, services, or domain concepts | PR diff shows new directories, new service boundaries, domain model changes | code-reviewer + design-reviewer |
| Design doc, ADR, RFC, or proposal | No code diff; document content | design-reviewer only |
| Local files or directory | Files on disk, no PR context | code-reviewer only |
| Explicit "design review" or "architecture review" | User says "design" or "architecture" | design-reviewer (+ code-reviewer if code exists) |

When in doubt about whether design review applies, check: does the diff introduce new modules, change service boundaries, alter data models, or modify cross-cutting concerns (auth, infra, rollout)? If yes, include design-reviewer.

## 2. Workspace Setup

Follow `references/repo-conventions.md`:

- All repositories live under `~/Code`. Resolve repo paths there first.
- For PR reviews, create a temporary worktree for the PR branch:
  ```
  git fetch origin <branch>
  git worktree add /tmp/review-<branch> origin/<branch>
  ```
- Read files from the worktree for accurate line numbers and full context.
- Clean up worktrees after review completes.
- Fall back to `git show origin/<branch>:<path> | cat -n` only if worktree creation fails.
- Use GitHub API blob fetching only as a last resort.

## 3. Dispatch

Launch agents in parallel. Consult `references/routing-table.md` for the full agent selection matrix.

For each agent:
- Pass the relevant context (diff, files, document)
- Include the shared principles from `references/review-philosophy.md`
- Specify `model: opus` for all agents, including marketplace agents

Wait for all dispatched agents to return before proceeding to merge.

## 4. Collect and Merge

When agents return raw findings:

1. **Deduplicate** — if two agents flag the same issue, keep one note:
   - Design note when the fix requires a decision or contract change
   - Code note when the fix is patch-level and localized
   - Prefer the most actionable framing

2. **Classify** each finding into a group: Questions (Q), Fix before merge (F), Suggestions (S), Nits (N), What's good (G)

3. **Number** each finding with its group prefix: Q1, F1, S1, N1, G1

4. **Determine verdict**: APPROVE, REQUEST_CHANGES, or COMMENT_ONLY based on whether any F-items exist

## 5. Format

Apply `references/output-format.md`. Two modes:

- **Brief mode** (default): one-line per finding, scannable. Use when presenting in terminal.
- **Structured mode**: full evidence/why/comment per finding. Triggered when user says "for PR comments", "detailed", "structured review", or "for a PR".

Always include:
- Executive summary (3-6 bullets)
- Single verdict with 1-2 sentence rationale
- Grouped, numbered findings (omit empty groups)

## 6. Post-Review Offer

If reviewing a PR, offer after presenting findings:

> "Want me to post these as a pending review on PR #N?"

Do not post without explicit confirmation.

## 7. Re-Review

When the user says "re-review" or the author pushed changes:

1. Fetch incremental diff: `git diff <previous_review_commit>..origin/<branch>`
2. Check CI status: `gh api repos/{owner}/{repo}/commits/{sha}/status`
3. Map previous findings to current state:
   - **Fixed**: code changed to address feedback
   - **Deferred**: author acknowledged, will address separately
   - **Regressed**: fix introduced a new problem
   - **New**: issue not present in original review
4. Present comparison table before taking action:

   | # | Finding | Status | Notes |
   |---|---------|--------|-------|
   | F1 | ... | Fixed | verified in `file:line` |
   | S2 | ... | Deferred | author acknowledged |
   | — | ... | New | introduced in latest commit |

5. Wait for user direction before posting updates.

## Additional Resources

### Reference Files

- **`references/output-format.md`** — Complete format spec for brief and structured modes
- **`references/voice-guide.md`** — Tone and phrasing for PR comments
- **`references/review-philosophy.md`** — Shared principles for all review agents
- **`references/routing-table.md`** — Agent selection matrix and dispatch rules
- **`references/repo-conventions.md`** — Workspace and worktree conventions
