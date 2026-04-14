# GitHub PR Review API Patterns

REST and GraphQL recipes for the PR review lifecycle.

## Create Pending Review (REST)

Post all comments in a single call. Omit `event` to create as PENDING.

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
      "start_line": <start_line>,
      "start_side": "RIGHT",
      "body": "<comment>"
    }
  ]
}
```

Get head SHA:
```bash
gh api repos/{owner}/{repo}/pulls/{number} --jq '.head.sha'
```

For single-line comments, omit `start_line` and `start_side`.

## Verify Comment Placement

After posting, fetch comments and check `diff_hunk` content matches expectations:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews/{review_id}/comments
```

If placement is wrong, delete the pending review and recreate with corrected lines.

## Delete Pending Review

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews/{review_id} --method DELETE
```

## List Existing Reviews

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews
```

Filter for state: PENDING to find stale reviews to replace.

## Submit Review

Only when user explicitly requests:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews/{review_id}/events \
  --method POST -f event=APPROVE
```

Options: APPROVE, REQUEST_CHANGES, COMMENT.

## Get Review Thread IDs (GraphQL)

```graphql
{
  repository(owner: "<owner>", name: "<repo>") {
    pullRequest(number: <n>) {
      reviewThreads(first: 50) {
        nodes {
          id
          isResolved
          comments(first: 5) {
            nodes {
              id
              author { login }
              body
              path
            }
          }
        }
      }
    }
  }
}
```

## Resolve Thread (GraphQL)

```graphql
mutation {
  resolveReviewThread(input: { threadId: "<id>" }) {
    thread { isResolved }
  }
}
```

## Unresolve Thread (GraphQL)

```graphql
mutation {
  unresolveReviewThread(input: { threadId: "<id>" }) {
    thread { isResolved }
  }
}
```

## Add Reaction (GraphQL)

```graphql
mutation {
  addReaction(input: { subjectId: "<comment_node_id>", content: THUMBS_UP }) {
    reaction { content }
  }
}
```

Get comment node IDs from the thread query above.

## Check CI Status

```bash
gh api repos/{owner}/{repo}/commits/{sha}/status
gh api repos/{owner}/{repo}/commits/{sha}/check-runs
```

## Line Number Rules

1. Get file content from the PR branch using local worktree (see repo-conventions.md)
2. Use file line numbers (right-hand side of diff), NOT diff hunk positions
3. For multi-line comments, use `start_line` / `start_side` + `line` / `side`
4. Always set `side: "RIGHT"` (comment on the new version of the file)
5. Verify placement after posting — wrong line numbers silently misplace comments
