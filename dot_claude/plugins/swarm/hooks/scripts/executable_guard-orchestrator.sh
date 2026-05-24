#!/bin/bash

# All errors must fail closed (exit 2 = block). Never exit 1 — Claude Code
# treats non-2 non-zero exits as non-blocking (fail-open).
trap 'echo "BLOCKED: guard-orchestrator.sh encountered an unexpected error. Failing closed." >&2; exit 2' ERR
set -uo pipefail

# Flag file is now active.json (contains orchestrator session_id + swarm metadata).
# If absent, no swarm is active — allow everything.
FLAG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/swarm/active.json"
if [ ! -f "$FLAG_FILE" ]; then
  exit 0
fi

input=$(cat)

# Only guard Write and Edit tools
tool_name=$(echo "$input" | jq -r '.tool_name')
if [[ "$tool_name" != "Write" && "$tool_name" != "Edit" ]]; then
  exit 0
fi

# Extract orchestrator session_id. If active.json is corrupt, fail closed.
orchestrator_session=$(jq -r '.session_id // empty' "$FLAG_FILE" 2>/dev/null)
if [ -z "$orchestrator_session" ]; then
  echo "BLOCKED: active.json exists but session_id could not be read. Fix or remove .claude/swarm/active.json." >&2
  exit 2
fi

# Caller must have a session_id. If absent, fail closed — unknown callers
# do not get write access during an active swarm.
caller_session=$(echo "$input" | jq -r '.session_id // empty')
if [ -z "$caller_session" ]; then
  echo "BLOCKED: tool call has no session_id. Cannot verify caller identity during active swarm." >&2
  exit 2
fi

# If caller's session_id differs from the orchestrator's, this is a subagent — allow.
if [ "$caller_session" != "$orchestrator_session" ]; then
  exit 0
fi

# --- This is the orchestrator (or in-process subagent sharing its session_id). ---

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
if [ -z "$file_path" ]; then
  exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-.}"

# Allow writes to the project's .claude/swarm/ directory (session state, iteration artifacts).
if [[ "$file_path" == "$project_dir/.claude/swarm/"* ]]; then
  exit 0
fi

# Allow writes to ~/.claude/ (memory, team config, settings).
if [[ "$file_path" == "$HOME/.claude/"* ]]; then
  exit 0
fi

# Block everything else
echo "BLOCKED: Orchestrator attempted to write outside ~/.claude/ and project .claude/swarm/ during an active swarm. Dispatch to a subagent instead." >&2
exit 2
