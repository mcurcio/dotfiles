#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="${HOME}/Library/Logs"
LOG_FILE="${LOG_DIR}/chezmoi-sync.log"
mkdir -p "${LOG_DIR}"

# Ensure predictable PATH for launchd
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"

echo "=== $(date -Is) ===" >> "${LOG_FILE}"

# 1) Pull + apply
# update = git pull + apply
chezmoi update >> "${LOG_FILE}" 2>&1 || {
  /usr/bin/osascript -e 'display notification "chezmoi update failed (see Logs/chezmoi-sync.log)" with title "dotfiles"' || true
  exit 0
}

# 2) Drift detection (you edited target files without `chezmoi add`)
DIFF_OUT="$(chezmoi diff || true)"
if [[ -n "${DIFF_OUT}" ]]; then
  echo "${DIFF_OUT}" >> "${LOG_FILE}"
  /usr/bin/osascript -e 'display notification "Drift detected: run `chezmoi add <file>` then commit/push" with title "dotfiles"' || true
fi
