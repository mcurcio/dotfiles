#!/bin/bash
INPUT=$(cat)

CWD=$(echo "$INPUT" | jq -r '.cwd')
SOURCE=$(echo "$INPUT" | jq -r '.source // "startup"')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
BASENAME=$(basename "$CWD")

SUMMARY=""
if [[ "$SOURCE" == "resume" && -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
  SUMMARY=$(jq -r 'select(.subtype == "away_summary") | .content' "$TRANSCRIPT" \
    | tail -1 \
    | sed 's/^You //' \
    | cut -d. -f1 \
    | head -c 50)
fi

if [[ -z "$SUMMARY" ]]; then
  BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ -n "$BRANCH" ]]; then
    SUMMARY="$BRANCH"
  fi
fi

if [[ -n "$SUMMARY" ]]; then
  TITLE="claude - $BASENAME - $SUMMARY"
else
  TITLE="claude - $BASENAME"
fi

printf '\033]0;%s\007' "$TITLE"
