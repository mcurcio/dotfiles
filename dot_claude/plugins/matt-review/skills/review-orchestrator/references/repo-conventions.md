# Repository and Workspace Conventions

## Repo Locations

All repositories live under `~/Code`. When resolving a repo path, check `~/Code/<repo-name>` first.

## Worktree Preference

Always prefer local worktree checkouts over GitHub API blob fetching.

When reviewing a PR branch:

1. Fetch the branch: `git fetch origin <branch>`
2. Create a temporary worktree: `git worktree add /tmp/review-<branch> origin/<branch>`
3. Read files from the worktree for accurate line numbers and full context
4. Clean up worktree after review: `git worktree remove /tmp/review-<branch>`

Do NOT use `gh api` to fetch file blobs unless the repo is not available locally. Worktrees provide:

- Accurate line numbers (no API pagination issues)
- Full file context for surrounding code
- Ability to run local tools (grep, tests) against the PR branch
- Consistent path references in findings

## When Worktree Is Not Possible

Fall back to: `git show origin/<branch>:<path> | cat -n`

Only use GitHub API blob fetching as a last resort.

## Path References in Findings

When citing evidence in review findings, use paths relative to the repository root (e.g., `src/api/handler.ts:42-58`), not absolute paths or worktree paths.
