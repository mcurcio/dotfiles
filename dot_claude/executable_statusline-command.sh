#!/usr/bin/env bash
# Claude Code status line — 2-line layout
# Line 1: persistent identity/context/cost
# Line 2: conditional git dirty state + context warnings

input=$(cat)

# --- Extract fields ---
MODEL=$(echo "$input" | jq -r '.model.display_name // .model.id // "?"')
MODEL_SHORT=$(echo "$MODEL" | sed 's/^Claude //')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
DIR_SHORT=$(basename "$CWD")
SESSION_ID=$(echo "$input" | jq -r '.session_id // "none"')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
LINES_ADD=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CACHE_WRITE=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
CACHE_READ=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
EXCEEDS_200K=$(echo "$input" | jq -r '.exceeds_200k_tokens // false')
WORKTREE_NAME=$(echo "$input" | jq -r '.worktree.name // empty')
GIT_WORKTREE=$(echo "$input" | jq -r '.workspace.git_worktree // empty')
AGENT_NAME=$(echo "$input" | jq -r '.agent.name // empty')
VIM_MODE=$(echo "$input" | jq -r '.vim.mode // empty')

# --- Colors ---
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

# --- Context bar (color by threshold) ---
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /█}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

# --- Format cache (compact: k units) ---
fmt_tokens() {
  local t=$1
  if [ "$t" -ge 1000 ]; then
    echo "$((t / 1000))k"
  else
    echo "${t}"
  fi
}
CACHE_W_FMT=$(fmt_tokens "$CACHE_WRITE")
CACHE_R_FMT=$(fmt_tokens "$CACHE_READ")

# --- Duration ---
MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))
if [ "$MINS" -gt 0 ]; then
  DUR="${MINS}m"
else
  DUR="${SECS}s"
fi

# --- Cost ---
COST_FMT=$(printf '$%.2f' "$COST")

# --- Git branch (cached) ---
CACHE_FILE="/tmp/statusline-git-cache-$SESSION_ID"
CACHE_MAX_AGE=5

cache_is_stale() {
  [ ! -f "$CACHE_FILE" ] || \
  [ $(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0))) -gt $CACHE_MAX_AGE ]
}

if cache_is_stale; then
  if [ -n "$CWD" ] && git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
    BRANCH=$(GIT_OPTIONAL_LOCKS=0 git -C "$CWD" symbolic-ref --short HEAD 2>/dev/null)
    STAGED=$(GIT_OPTIONAL_LOCKS=0 git -C "$CWD" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$(GIT_OPTIONAL_LOCKS=0 git -C "$CWD" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    UNTRACKED=$(GIT_OPTIONAL_LOCKS=0 git -C "$CWD" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    echo "$BRANCH|$STAGED|$MODIFIED|$UNTRACKED" > "$CACHE_FILE"
  else
    echo "|||" > "$CACHE_FILE"
  fi
fi

IFS='|' read -r BRANCH STAGED MODIFIED UNTRACKED < "$CACHE_FILE"

# --- Build Line 1 ---
# [Model effort] dir | branch (worktree) | ████░░░░░░ 42% | cache:5k/2k | $0.47 | 23m
L1=""

# Model + effort
if [ -n "$EFFORT" ] && [ "$EFFORT" != "high" ]; then
  L1="${CYAN}${MODEL_SHORT} ${EFFORT}${RESET}"
else
  L1="${CYAN}${MODEL_SHORT}${RESET}"
fi

# Directory
L1="${L1} ${DIM}${DIR_SHORT}${RESET}"

# Git branch + worktree
if [ -n "$BRANCH" ]; then
  GIT_PART="${BRANCH}"
  if [ -n "$WORKTREE_NAME" ]; then
    GIT_PART="${GIT_PART}:${WORKTREE_NAME}"
  elif [ -n "$GIT_WORKTREE" ]; then
    GIT_PART="${GIT_PART}:${GIT_WORKTREE}"
  fi
  L1="${L1} ${DIM}|${RESET} ${GIT_PART}"
fi

# Context bar
L1="${L1} ${DIM}|${RESET} ${BAR_COLOR}${BAR}${RESET} ${PCT}%"

# Cache
if [ "$CACHE_WRITE" != "0" ] || [ "$CACHE_READ" != "0" ]; then
  L1="${L1} ${DIM}c:${CACHE_W_FMT}/${CACHE_R_FMT}${RESET}"
fi

# Cost + duration
L1="${L1} ${DIM}|${RESET} ${YELLOW}${COST_FMT}${RESET} ${DIM}${DUR}${RESET}"

# Vim mode
[ -n "$VIM_MODE" ] && L1="${L1} ${DIM}[${VIM_MODE}]${RESET}"

# Agent name (if running as named agent)
[ -n "$AGENT_NAME" ] && L1="${L1} ${DIM}(${AGENT_NAME})${RESET}"

echo -e "$L1"

# --- Build Line 2 (conditional) ---
L2_PARTS=()

# Context warning
if [ "$EXCEEDS_200K" = "true" ]; then
  L2_PARTS+=("${RED}> 200k tokens${RESET}")
fi

# Git dirty state
GIT_DIRTY=""
[ "$STAGED" -gt 0 ] && GIT_DIRTY="${GREEN}+${STAGED} staged${RESET}"
[ "$MODIFIED" -gt 0 ] && GIT_DIRTY="${GIT_DIRTY}${GIT_DIRTY:+ }${YELLOW}~${MODIFIED} modified${RESET}"
[ "$UNTRACKED" -gt 0 ] && GIT_DIRTY="${GIT_DIRTY}${GIT_DIRTY:+ }${DIM}?${UNTRACKED} untracked${RESET}"
[ -n "$GIT_DIRTY" ] && L2_PARTS+=("$GIT_DIRTY")

# Lines changed
if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ]; then
  L2_PARTS+=("${GREEN}+${LINES_ADD}${RESET} ${RED}-${LINES_DEL}${RESET} lines")
fi

# Only print line 2 if there's something to show
if [ ${#L2_PARTS[@]} -gt 0 ]; then
  L2=$(IFS='x'; printf '%s' "${L2_PARTS[0]}")
  for ((i=1; i<${#L2_PARTS[@]}; i++)); do
    L2="${L2} ${DIM}|${RESET} ${L2_PARTS[$i]}"
  done
  echo -e "$L2"
fi
