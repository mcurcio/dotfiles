#!/bin/bash

# Captures session_id at session start and writes it to a known location
# so swarm skills can read it when constructing active.json and meta.json.
trap 'exit 0' ERR
set -uo pipefail

SESSION_ID=$(jq -r '.session_id // empty')
if [ -z "$SESSION_ID" ]; then
  exit 0
fi

mkdir -p "${CLAUDE_PROJECT_DIR:-.}/.claude/swarm"
printf '%s' "$SESSION_ID" > "${CLAUDE_PROJECT_DIR:-.}/.claude/swarm/.session-id"
