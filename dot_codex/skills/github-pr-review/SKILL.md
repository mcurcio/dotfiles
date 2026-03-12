---
name: github-pr-review
description: End-to-end GitHub pull request review lifecycle — generate review notes, post line-specific comments as a pending review, manage re-reviews after author updates, track finding status across iterations, and handle thread resolution/reactions. Use when the user wants to review a PR and post comments to GitHub, re-review a PR after the author pushes changes, resolve or react to review threads, track which findings were fixed/deferred/regressed, or manage the review lifecycle on a GitHub pull request. Complements the code-review and review-orchestrator skills (which produce the review content) by handling the GitHub interaction and iteration workflow.
---

# GitHub PR Review Lifecycle

## Phases

```
1. Generate  →  2. Post  →  3. Iterate  →  4. Manage threads  →  5. Submit
   (review)      (pending)    (re-review)    (resolve/react)       (only when asked)
```

Each phase requires explicit user direction to proceed to the next. Never auto-advance.

## Phase 1: Generate review notes

Delegate to the **code-review** or **review-orchestrator** skill. Present findings to the user in Cursor first. Do not post anything to GitHub until asked.

## Phase 2: Post comments as a pending review

### Boundary rules

- **Never submit** a review (APPROVE / REQUEST_CHANGES / COMMENT) without explicit permission.
- Create the review in **PENDING** state only. The user decides when and how to submit.
- Omit the `event` field entirely when calling the API — this creates a pending review.

### Line number accuracy

This is the most error-prone step. Wrong line numbers silently place comments in the wrong spot.

1. **Get file content from the PR branch** to determine correct line numbers:
   ```
   git fetch origin <branch>
   git show origin/<branch>:<path> | cat -n
   ```
2. Use the file line numbers (right-hand side of the diff), **not** diff hunk positions.
3. For multi-line comments, use `start_line` / `start_side` + `line` / `side`.
4. Always set `side: "RIGHT"` (comment on the new version of the file).

### API call

Use the REST API to create a pending review with all comments in one call:

```
POST /repos/{owner}/{repo}/pulls/{number}/reviews
{
  "commit_id": "<head SHA>",
  "body": "",
  "comments": [
    {
      "path": "<file>",
      "line": <end_line>,
      "side": "RIGHT",
      "start_line": <start_line>,   // omit for single-line
      "start_side": "RIGHT",        // omit for single-line
      "body": "<comment>"
    }
  ]
}
```

Get the head SHA from: `gh api repos/{owner}/{repo}/pulls/{number} --jq '.head.sha'`

### Verify placement

After posting, fetch the review comments and check `diff_hunk` content matches expectations:

```
gh api repos/{owner}/{repo}/pulls/{number}/reviews/{review_id}/comments
```

If placement is wrong, delete the pending review and recreate with corrected lines.

### Comment tone

- Positive, friendly, human-readable.
- Solution-oriented — suggest what to do, not just what's wrong.
- Non-judgmental — no finger-pointing, no "you should have".
- Question-first when intent is unclear.
- Include code suggestions when a fix is concrete and small.
- End each comment with the attribution tag the user specifies (e.g. `[ai authored; matt approved]`).

## Phase 3: Iterate (re-review after author updates)

When the author pushes changes in response to review feedback:

1. **Fetch latest**: `git fetch origin <branch>`
2. **Diff incrementally** against the commit the previous review was based on:
   ```
   git diff <previous_review_commit>..origin/<branch>
   ```
3. **Check CI**: `gh api repos/{owner}/{repo}/commits/{sha}/status` and check runs.
4. **Map previous findings** to current state for each item:
   - **Fixed**: the code changed to address the feedback.
   - **Deferred**: author acknowledged, will address separately (follow-up ticket).
   - **Regressed**: a fix introduced a new problem.
   - **New**: issue not present in original review.
5. **Present a comparison table** to the user before taking any action:

   | # | Finding | Status | Notes |
   |---|---------|--------|-------|
   | F1 | ... | Fixed | verified in `<file>:<line>` |
   | S2 | ... | Deferred | author acknowledged, follow-up planned |
   | — | ... | New | introduced in latest commit |

6. Wait for user direction on what to post, resolve, or react to.

## Phase 4: Manage threads

### Resolving conversations

Use the GraphQL mutation:
```
mutation { resolveReviewThread(input: { threadId: "<id>" }) { thread { isResolved } } }
```

To get thread IDs:
```graphql
{
  repository(owner: "<owner>", name: "<repo>") {
    pullRequest(number: <n>) {
      reviewThreads(first: 50) {
        nodes {
          id
          isResolved
          comments(first: 5) {
            nodes { author { login } body path }
          }
        }
      }
    }
  }
}
```

**Only resolve threads the user explicitly asks to resolve.** A finding being "fixed" does not automatically mean "resolve the thread" — that is the user's call.

### Adding reactions

To acknowledge a reply (e.g. thumbs-up on a deferred item):
```
mutation { addReaction(input: { subjectId: "<comment_node_id>", content: THUMBS_UP }) { reaction { content } } }
```

Get comment node IDs from the thread query above.

**Reactions and resolution are independent actions.** Do not bundle them unless the user says to.

### Reopening threads

If a thread was resolved prematurely:
```
mutation { unresolveReviewThread(input: { threadId: "<id>" }) { thread { isResolved } } }
```

## Phase 5: Submit

Only when the user explicitly asks. Use:
```
POST /repos/{owner}/{repo}/pulls/{number}/reviews/{review_id}/events
{ "event": "APPROVE" | "REQUEST_CHANGES" | "COMMENT" }
```

Or the `gh` equivalent: `gh api repos/{owner}/{repo}/pulls/{number}/reviews/{review_id}/events --method POST -f event=APPROVE`

## Key principles

- **Do exactly what is asked.** Do not infer additional actions. If asked to "add a reaction," do not also resolve the thread.
- **Present findings first, act second.** Always show the user what you plan to do and let them confirm.
- **Line numbers are fragile.** Always verify from the actual file content on the PR branch — never trust diff-relative positions alone.
- **The user owns the submit button.** Pending review state is the default; submission is always a conscious, user-initiated action.
