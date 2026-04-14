---
name: github-pr-lifecycle
description: This skill should be used when the user asks to "post this review to GitHub", "post PR comments", "update the PR review", "re-review this PR", "resolve review threads", "manage PR review", "submit the review", "post these findings", or when posting, iterating, or managing review comments on GitHub pull requests.
---

# GitHub PR Review Lifecycle

Manage the full lifecycle of posting, iterating, and managing review comments on GitHub pull requests. Each phase requires explicit user direction to proceed to the next. Never auto-advance.

## Phase 1: Generate

Delegate to the review-orchestrator skill. Do not generate review content independently. Present findings to the user first. Do not post anything to GitHub until asked.

## Phase 2: Post

Create a pending review via the pr-publisher agent.

### New review
1. Get head SHA: `gh api repos/{owner}/{repo}/pulls/{number} --jq '.head.sha'`
2. Post all comments in a single API call as a PENDING review
3. Omit the `event` field entirely — this creates a pending review
4. Verify placement after posting

### Updating an existing review
1. Check for existing pending review: `gh api repos/{owner}/{repo}/pulls/{number}/reviews`
2. If a PENDING review exists from a previous pass, delete it first
3. Post a fresh PENDING review with updated findings
4. Verify placement

### Boundary rules
- **Never submit** a review (APPROVE / REQUEST_CHANGES / COMMENT) without explicit permission
- PENDING state only. The user decides when and how to submit.

## Phase 3: Iterate

When the author pushes changes in response to review feedback:

1. Fetch latest: `git fetch origin <branch>`
2. Diff incrementally: `git diff <previous_review_commit>..origin/<branch>`
3. Check CI status
4. Map previous findings to current state:
   - **Fixed**: code changed to address feedback
   - **Deferred**: author acknowledged, will address separately
   - **Regressed**: fix introduced a new problem
   - **New**: issue not present in original review
5. Present comparison table before acting
6. Wait for user direction on what to post, resolve, or react to

## Phase 4: Manage Threads

### Resolve conversations
Use GraphQL mutation `resolveReviewThread`. Only resolve threads the user explicitly asks to resolve. A finding being "fixed" does not automatically mean "resolve the thread."

### Add reactions
Use GraphQL mutation `addReaction` to acknowledge replies (e.g., thumbs-up on deferred items).

### Reopen threads
Use `unresolveReviewThread` if a thread was resolved prematurely.

Reactions and resolution are independent actions. Do not bundle unless the user says to.

## Phase 5: Submit

Only when the user explicitly asks. Options: APPROVE, REQUEST_CHANGES, or COMMENT.

## Key Principles

- **Do exactly what is asked.** Do not infer additional actions.
- **Present findings first, act second.** Show the user what will be posted and let them confirm.
- **Line numbers are fragile.** Always verify from actual file content on the PR branch via worktree checkout.
- **The user owns the submit button.** Pending review state is the default.

## Additional Resources

- **`references/api-patterns.md`** — REST and GraphQL API recipes for all lifecycle operations
