#!/usr/bin/env bash
# Subagent status line — mirrors main agent line 1 format
# Input: JSON with .tasks[] array, each with id, name, type, status, description, tokenCount, tokenSamples, cwd
# Output: one JSON line per task: {"id": "<id>", "content": "<row>"}

input=$(cat)
COLUMNS=$(echo "$input" | jq -r '.columns // 120')

CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
DIM=$'\033[2m'
RESET=$'\033[0m'

echo "$input" | jq -c '.tasks[]' | while IFS= read -r task; do
  ID=$(echo "$task" | jq -r '.id')
  NAME=$(echo "$task" | jq -r '.name // "agent"')
  TYPE=$(echo "$task" | jq -r '.type // ""')
  STATUS=$(echo "$task" | jq -r '.status // "running"')
  DESC=$(echo "$task" | jq -r '.description // ""')
  TOKENS=$(echo "$task" | jq -r '.tokenCount // 0')
  CWD=$(echo "$task" | jq -r '.cwd // ""')
  START_TIME=$(echo "$task" | jq -r '.startTime // 0')

  # Format tokens as k
  if [ "$TOKENS" -ge 1000 ]; then
    TOK_FMT="$((TOKENS / 1000))k"
  else
    TOK_FMT="${TOKENS}"
  fi

  # Directory basename
  DIR_SHORT=""
  [ -n "$CWD" ] && DIR_SHORT=$(basename "$CWD")

  # Duration from start time (epoch ms)
  DUR=""
  if [ "$START_TIME" -gt 0 ]; then
    NOW_MS=$(($(date +%s) * 1000))
    ELAPSED_S=$(( (NOW_MS - START_TIME) / 1000 ))
    if [ "$ELAPSED_S" -lt 0 ]; then ELAPSED_S=0; fi
    if [ "$ELAPSED_S" -ge 60 ]; then
      DUR="$((ELAPSED_S / 60))m"
    else
      DUR="${ELAPSED_S}s"
    fi
  fi

  # Status indicator
  case "$STATUS" in
    running)  STATUS_ICON="${GREEN}●${RESET}" ;;
    waiting)  STATUS_ICON="${YELLOW}○${RESET}" ;;
    complete) STATUS_ICON="${DIM}✓${RESET}" ;;
    error)    STATUS_ICON="${RED}✗${RESET}" ;;
    *)        STATUS_ICON="${DIM}·${RESET}" ;;
  esac

  # Context usage percentage (estimate from tokens if possible)
  # tokenSamples gives us historical data but tokenCount is the current total
  CTX_PCT=""
  if [ "$TOKENS" -gt 0 ]; then
    # Assume 200k context window for subagents
    PCT=$((TOKENS * 100 / 200000))
    [ "$PCT" -gt 100 ] && PCT=100

    if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
    elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
    else BAR_COLOR="$GREEN"; fi

    BAR_WIDTH=6
    FILLED=$((PCT * BAR_WIDTH / 100))
    EMPTY=$((BAR_WIDTH - FILLED))
    BAR=""
    [ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /█}"
    [ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

    CTX_PART="${BAR_COLOR}${BAR}${RESET} ${PCT}%"
  else
    CTX_PART="${DIM}░░░░░░ --${RESET}"
  fi

  # Build row: status name dir | bar pct | tokens | dur
  ROW="${STATUS_ICON} ${CYAN}${NAME}${RESET}"
  [ -n "$DIR_SHORT" ] && ROW="${ROW} ${DIM}${DIR_SHORT}${RESET}"
  ROW="${ROW} ${DIM}|${RESET} ${CTX_PART}"
  ROW="${ROW} ${DIM}${TOK_FMT}${RESET}"
  [ -n "$DUR" ] && ROW="${ROW} ${DIM}${DUR}${RESET}"

  # Truncate description for label if present
  if [ -n "$DESC" ]; then
    LABEL=$(echo "$DESC" | cut -c1-40)
    [ ${#DESC} -gt 40 ] && LABEL="${LABEL}…"
    ROW="${ROW} ${DIM}— ${LABEL}${RESET}"
  fi

  # Output as JSON line using jq for proper escaping
  printf '%s\n' "$ROW" | jq -Rc --arg id "$ID" '{"id": $id, "content": .}'
done
