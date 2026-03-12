#!/bin/bash
set -euo pipefail

# chezmoi autosync for macOS launchd.
#
# Design goals:
# - Keep managed local changes from sitting around in $HOME long enough to
#   block `chezmoi update`.
# - Preserve those changes by importing them back into the chezmoi source repo
#   before attempting any pull/apply work.
# - Make every run diagnosable from files on disk instead of relying on vague
#   macOS notification center entries or Console.app links.
#
# High-level flow:
# 1. Capture/publish
#    - Inspect `chezmoi status`.
#    - For paths with local managed drift, run `chezmoi add <target>` so the
#      current destination state is copied back into the source repo.
#    - Stage and commit only the captured source paths.
#    - Rebase that commit onto the current upstream branch and push it.
# 2. Pull/apply
#    - Only after the source repo is clean enough for unattended work, run
#      `chezmoi update --no-pager --no-tty`.
#
# Conflict model:
# - Local capture can succeed while publish later fails.
# - In that case the local autosync commit remains in the chezmoi source repo,
#   unpushed, and the pull/apply phase is intentionally blocked.
# - The status file records that state so the failure is explicit instead of
#   surfacing later as a confusing non-interactive `chezmoi update` error.
#
# Primary artifacts:
# - status.txt: one-screen summary of the latest run and its phase results
# - resolution.txt: operator-facing next steps tailored to the latest issue
# - last-error.txt: most recent error string
# - chezmoi-status.txt: raw `chezmoi status` output
# - git-status.txt: raw `git status --short --branch` output for the source repo
# - chezmoi-sync.latest.log: log for the current/most recent run
# - chezmoi-sync.log: append-only history log
#
# Supported environment toggles:
# - CHEZMOI_SYNC_DRY_RUN=1: log intended actions without mutating state
# - CHEZMOI_SYNC_DISABLE_PUBLISH=1: capture/commit locally but skip push
# - CHEZMOI_SYNC_DISABLE_PULL=1: skip `chezmoi update`
# - CHEZMOI_SYNC_NOTIFY_COOLDOWN_SECONDS=<n>: dedupe identical notifications
# - CHEZMOI_SYNC_LOG_DIR / CHEZMOI_SYNC_STATE_DIR: override artifact locations
#
LOG_DIR="${CHEZMOI_SYNC_LOG_DIR:-${HOME}/Library/Logs}"
STATE_DIR="${CHEZMOI_SYNC_STATE_DIR:-${HOME}/Library/Application Support/chezmoi-sync}"
LOG_FILE="${LOG_DIR}/chezmoi-sync.log"
LATEST_LOG_FILE="${LOG_DIR}/chezmoi-sync.latest.log"
LAUNCHD_STDOUT_FILE="${LOG_DIR}/chezmoi-sync.launchd.out.log"
LAUNCHD_STDERR_FILE="${LOG_DIR}/chezmoi-sync.launchd.err.log"
STATUS_FILE="${STATE_DIR}/status.txt"
RESOLUTION_FILE="${STATE_DIR}/resolution.txt"
LAST_ERROR_FILE="${STATE_DIR}/last-error.txt"
CHEZMOI_STATUS_FILE="${STATE_DIR}/chezmoi-status.txt"
GIT_STATUS_FILE="${STATE_DIR}/git-status.txt"
NOTIFY_STATE_FILE="${STATE_DIR}/notify-state"
LOCK_DIR="${STATE_DIR}/lock"

mkdir -p "${LOG_DIR}" "${STATE_DIR}"
: > "${LATEST_LOG_FILE}"
: > "${LAST_ERROR_FILE}"

# Ensure predictable PATH for launchd.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"

RUN_STARTED_AT="$(
  /bin/date '+%Y-%m-%dT%H:%M:%S%z'
)"
RUN_ID="${RUN_STARTED_AT}.$$"
HOSTNAME_SHORT="$(
  /usr/sbin/scutil --get LocalHostName 2>/dev/null || /bin/hostname -s 2>/dev/null || /bin/hostname
)"
NOTIFY_COOLDOWN_SECONDS="${CHEZMOI_SYNC_NOTIFY_COOLDOWN_SECONDS:-10800}"
DRY_RUN="${CHEZMOI_SYNC_DRY_RUN:-0}"
DISABLE_PUBLISH="${CHEZMOI_SYNC_DISABLE_PUBLISH:-0}"
DISABLE_PULL="${CHEZMOI_SYNC_DISABLE_PULL:-0}"

SOURCE_DIR=""
CURRENT_BRANCH=""
REPO_STATUS=""
CHEZMOI_STATUS=""
LAST_ERROR=""
RESOLUTION_TITLE="Healthy"
RESOLUTION_SUMMARY="Autosync completed or no operator action is required."
NEXT_ACTION="cat \"${STATUS_FILE}\""
RESOLUTION_DETAILS="Review the status and latest log files if you want more detail."
CAPTURE_RESULT="skipped"
PUBLISH_RESULT="skipped"
PULL_RESULT="skipped"

DRIFT_TARGETS=()
PENDING_APPLY_TARGETS=()
CAPTURED_TARGETS=()
CAPTURED_SOURCE_PATHS=()
CAPTURED_SOURCE_RELATIVE_PATHS=()
SKIPPED_CAPTURE_TARGETS=()
FAILED_CAPTURE_TARGETS=()

timestamp() {
  /bin/date '+%Y-%m-%dT%H:%M:%S%z'
}

epoch_seconds() {
  /bin/date '+%s'
}

pretty_path() {
  case "$1" in
    "${HOME}"/*)
      printf '~/%s' "${1#${HOME}/}"
      ;;
    *)
      printf '%s' "$1"
      ;;
  esac
}

quote_command() {
  local quoted=""
  local arg
  for arg in "$@"; do
    if [ -n "${quoted}" ]; then
      quoted="${quoted} "
    fi
    quoted="${quoted}$(printf '%q' "${arg}")"
  done
  printf '%s' "${quoted}"
}

# All logging goes both to the append-only history log and the latest-run log.
# The latest-run log is truncated at startup so it can be inspected quickly.
log() {
  local level="$1"
  shift
  local line="[$(timestamp)] [${RUN_ID}] [${level}] $*"
  printf '%s\n' "${line}" >> "${LOG_FILE}"
  printf '%s\n' "${line}" >> "${LATEST_LOG_FILE}"
}

# Record multiline subprocess output line-by-line so the main log stays readable
# and each line remains tied to the command label that produced it.
record_command_output() {
  local label="$1"
  local output="$2"
  local line
  [ -z "${output}" ] && return 0
  while IFS= read -r line; do
    log INFO "${label}: ${line}"
  done <<EOF
${output}
EOF
}

# Run a command, capture its stdout/stderr, and store the combined output into
# the named shell variable passed as the first argument.
run_capture() {
  local __resultvar="$1"
  local label="$2"
  shift 2
  local tmp_file output rc

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/chezmoi-sync.XXXXXX")"
  log INFO "Running (${label}): $(quote_command "$@")"

  if "$@" >"${tmp_file}" 2>&1; then
    rc=0
  else
    rc=$?
  fi

  output="$(cat "${tmp_file}")"
  rm -f "${tmp_file}"
  record_command_output "${label}" "${output}"
  printf -v "${__resultvar}" '%s' "${output}"

  if [ "${rc}" -ne 0 ]; then
    log ERROR "${label} failed with exit ${rc}"
    return "${rc}"
  fi

  return 0
}

# Wrapper around run_capture that respects dry-run mode for mutating commands.
run_action() {
  local __resultvar="$1"
  local label="$2"
  shift 2

  if [ "${DRY_RUN}" = "1" ]; then
    log INFO "Dry run (${label}): $(quote_command "$@")"
    printf -v "${__resultvar}" '%s' "dry-run"
    return 0
  fi

  run_capture "${__resultvar}" "${label}" "$@"
}

# Persist the latest error both for the status file and for lightweight tooling
# that only wants the last failure reason.
set_last_error() {
  LAST_ERROR="$*"
  printf '%s\n' "${LAST_ERROR}" > "${LAST_ERROR_FILE}"
  log ERROR "${LAST_ERROR}"
}

# Record the latest operator guidance in a dedicated file so notifications can
# stay short while still pointing at a concrete, machine-generated checklist.
set_resolution() {
  RESOLUTION_TITLE="$1"
  RESOLUTION_SUMMARY="$2"
  NEXT_ACTION="$3"
  RESOLUTION_DETAILS="$4"
  write_resolution_file
}

# Shorten long path lists for notifications and status summaries.
render_path_summary() {
  local limit="$1"
  shift
  local count="$#"
  local rendered=""
  local index=0
  local path=""

  for path in "$@"; do
    index=$((index + 1))
    if [ "${index}" -le "${limit}" ]; then
      if [ -n "${rendered}" ]; then
        rendered="${rendered}, "
      fi
      rendered="${rendered}$(pretty_path "${path}")"
    fi
  done

  if [ "${count}" -gt "${limit}" ]; then
    rendered="${rendered}, +$((count - limit)) more"
  fi

  printf '%s' "${rendered}"
}

# launchd jobs do not have a useful "click through to the right log file" UX,
# so notifications intentionally carry short summaries only. The detailed state
# always lives in STATUS_FILE and the associated logs on disk.
notify() {
  local title="$1"
  local subtitle="$2"
  local message="$3"

  /usr/bin/osascript - "${message}" "${title}" "${subtitle}" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  set theMessage to item 1 of argv
  set theTitle to item 2 of argv
  set theSubtitle to item 3 of argv
  display notification theMessage with title theTitle subtitle theSubtitle
end run
APPLESCRIPT
}

# Suppress repeated notifications for the same failure mode within a cooldown
# window so a broken periodic job does not spam notification center.
maybe_notify() {
  local key="$1"
  local title="$2"
  local subtitle="$3"
  local message="$4"
  local now last_key last_epoch

  now="$(epoch_seconds)"
  last_key=""
  last_epoch=0

  if [ -f "${NOTIFY_STATE_FILE}" ]; then
    IFS='|' read -r last_key last_epoch < "${NOTIFY_STATE_FILE}" || true
  fi

  if [ "${last_key}" = "${key}" ] && [ $((now - last_epoch)) -lt "${NOTIFY_COOLDOWN_SECONDS}" ]; then
    log INFO "Notification suppressed for key ${key}"
    return 0
  fi

  printf '%s|%s\n' "${key}" "${now}" > "${NOTIFY_STATE_FILE}"
  notify "${title}" "${subtitle}" "${message}"
}

write_resolution_file() {
  {
    printf 'run_id: %s\n' "${RUN_ID}"
    printf 'issue: %s\n' "${RESOLUTION_TITLE}"
    printf 'summary: %s\n' "${RESOLUTION_SUMMARY}"
    printf 'next_action: %s\n' "${NEXT_ACTION}"
    printf 'status_file: %s\n' "$(pretty_path "${STATUS_FILE}")"
    printf 'log_file: %s\n' "$(pretty_path "${LATEST_LOG_FILE}")"
    printf 'source_dir: %s\n' "${SOURCE_DIR:-unknown}"
    printf 'branch: %s\n' "${CURRENT_BRANCH:-unknown}"
    printf '\nResolution steps:\n%b\n' "${RESOLUTION_DETAILS}"
  } > "${RESOLUTION_FILE}"
}

# Snapshot the chezmoi source repo state. This is the git repo where imported
# local changes are committed and from which remote changes are pulled.
refresh_repo_status() {
  run_capture REPO_STATUS "git status" git -C "${SOURCE_DIR}" status --short --branch
  printf '%s\n' "${REPO_STATUS}" > "${GIT_STATUS_FILE}"
}

# Decide whether the source repo is safe for unattended pull/apply work.
# Untracked files are ignored here because they do not block `git pull` or
# `chezmoi update` in the same way tracked modifications do.
repo_has_tracked_changes() {
  local status_text="$1"
  local line

  while IFS= read -r line; do
    [ -z "${line}" ] && continue
    case "${line}" in
      '## '*)
        ;;
      '?? '*)
        ;;
      *)
        return 0
        ;;
    esac
  done <<EOF
${status_text}
EOF

  return 1
}

# Split `chezmoi status` into two useful buckets:
# - DRIFT_TARGETS: first-column differences, meaning local destination state
#   drifted from what chezmoi last wrote and should be captured back into source
# - PENDING_APPLY_TARGETS: second-column differences, meaning source/target
#   state differs from destination and `chezmoi apply` would still change files
parse_chezmoi_status() {
  local status_text="$1"
  local line first second path

  DRIFT_TARGETS=()
  PENDING_APPLY_TARGETS=()

  while IFS= read -r line; do
    [ -z "${line}" ] && continue
    first="${line:0:1}"
    second="${line:1:1}"
    path="${line:3}"

    if [ "${first}" != " " ]; then
      DRIFT_TARGETS+=("${path}")
    fi

    if [ "${second}" != " " ]; then
      PENDING_APPLY_TARGETS+=("${path}")
    fi
  done <<EOF
${status_text}
EOF
}

refresh_chezmoi_status() {
  run_capture CHEZMOI_STATUS "chezmoi status" chezmoi status --path-style absolute --no-pager --no-tty
  printf '%s\n' "${CHEZMOI_STATUS}" > "${CHEZMOI_STATUS_FILE}"
  parse_chezmoi_status "${CHEZMOI_STATUS}"
}

# Import local managed drift back into the chezmoi source repo.
#
# Important behavior:
# - This only acts on first-column drift from `chezmoi status`, i.e. files that
#   changed under $HOME after chezmoi last wrote them.
# - Each target is fed through `chezmoi add`, which updates the corresponding
#   source file in the chezmoi repo.
# - Only the resulting source paths are staged and committed, so unrelated repo
#   changes are not swept into the autosync commit.
# - A successful capture does not imply a successful publish.
capture_local_changes() {
  local target_path source_path output

  CAPTURED_TARGETS=()
  CAPTURED_SOURCE_PATHS=()
  CAPTURED_SOURCE_RELATIVE_PATHS=()
  SKIPPED_CAPTURE_TARGETS=()
  FAILED_CAPTURE_TARGETS=()

  if [ "${#DRIFT_TARGETS[@]}" -eq 0 ]; then
    CAPTURE_RESULT="none"
    return 0
  fi

  CAPTURE_RESULT="started"
  log INFO "Found ${#DRIFT_TARGETS[@]} managed local change(s): $(render_path_summary 5 "${DRIFT_TARGETS[@]}")"

  for target_path in "${DRIFT_TARGETS[@]}"; do
    if [ ! -e "${target_path}" ]; then
      log WARN "Skipping non-existent managed path during capture: $(pretty_path "${target_path}")"
      SKIPPED_CAPTURE_TARGETS+=("${target_path}")
      continue
    fi

    if run_action output "chezmoi add $(pretty_path "${target_path}")" chezmoi add --no-tty -- "${target_path}"; then
      CAPTURED_TARGETS+=("${target_path}")
      source_path="$(chezmoi source-path "${target_path}")"
      CAPTURED_SOURCE_PATHS+=("${source_path}")
      CAPTURED_SOURCE_RELATIVE_PATHS+=("${source_path#${SOURCE_DIR}/}")
    else
      FAILED_CAPTURE_TARGETS+=("${target_path}")
    fi
  done

  if [ "${#FAILED_CAPTURE_TARGETS[@]}" -gt 0 ]; then
    CAPTURE_RESULT="failed"
    set_last_error "Failed to capture managed changes: $(render_path_summary 5 "${FAILED_CAPTURE_TARGETS[@]}")"
    set_resolution \
      "Autosync capture failed" \
      "Managed destination changes could not be imported back into the chezmoi source repo." \
      "cat $(pretty_path "${RESOLUTION_FILE}")" \
      "1. Inspect the latest autosync summary:\n   cat $(pretty_path "${STATUS_FILE}")\n2. Re-run capture manually for the failed files:\n   chezmoi add <failed-path>\n3. If that succeeds, commit/push from the chezmoi source repo:\n   cd $(pretty_path "${SOURCE_DIR}")\n   git status\n   git add .\n   git commit -m 'Resolve autosync capture failure'\n   git push"
    maybe_notify \
      "capture-failed" \
      "dotfiles" \
      "Autosync capture failed" \
      "Could not import local managed changes. Next: cat $(pretty_path "${RESOLUTION_FILE}")"
    return 1
  fi

  if [ "${#CAPTURED_SOURCE_PATHS[@]}" -eq 0 ]; then
    CAPTURE_RESULT="skipped"
    return 0
  fi

  if ! run_action output "git add captured source files" git -C "${SOURCE_DIR}" add -A -- "${CAPTURED_SOURCE_RELATIVE_PATHS[@]}"; then
    CAPTURE_RESULT="failed"
    set_last_error "Failed to stage captured source changes in ${SOURCE_DIR}"
    set_resolution \
      "Autosync staging failed" \
      "Captured source files were updated but could not be staged in the chezmoi git repo." \
      "cd $(pretty_path "${SOURCE_DIR}") && git status" \
      "1. Check the source repo state:\n   cd $(pretty_path "${SOURCE_DIR}")\n   git status\n2. Resolve any git errors or permissions issues.\n3. Stage and publish when ready:\n   git add .\n   git commit -m 'Resolve autosync staging failure'\n   git push"
    maybe_notify \
      "capture-stage-failed" \
      "dotfiles" \
      "Autosync staging failed" \
      "Captured files could not be staged. Next: cd $(pretty_path "${SOURCE_DIR}") && git status"
    return 1
  fi

  if [ "${DRY_RUN}" = "1" ]; then
    CAPTURE_RESULT="dry-run"
    return 0
  fi

  if git -C "${SOURCE_DIR}" diff --cached --quiet -- "${CAPTURED_SOURCE_RELATIVE_PATHS[@]}"; then
    CAPTURE_RESULT="no-op"
    return 0
  fi

  if ! run_action output \
    "git commit captured source files" \
    git -C "${SOURCE_DIR}" commit -m "autosync: capture local changes from ${HOSTNAME_SHORT}" -- "${CAPTURED_SOURCE_RELATIVE_PATHS[@]}"; then
    CAPTURE_RESULT="failed"
    set_last_error "Failed to commit captured managed changes"
    set_resolution \
      "Autosync commit failed" \
      "Captured source changes were staged but git could not create the autosync commit." \
      "cd $(pretty_path "${SOURCE_DIR}") && git status" \
      "1. Inspect the source repo:\n   cd $(pretty_path "${SOURCE_DIR}")\n   git status\n2. Resolve the git error shown in the latest log.\n3. Commit and publish manually:\n   git commit -m 'Resolve autosync commit failure'\n   git push"
    maybe_notify \
      "capture-commit-failed" \
      "dotfiles" \
      "Autosync commit failed" \
      "Captured changes were not committed. Next: cd $(pretty_path "${SOURCE_DIR}") && git status"
    return 1
  fi

  CAPTURE_RESULT="committed"
  return 0
}

# Publish any commit created by capture_local_changes().
#
# Sequence:
# - `git pull --rebase --autostash` rebases the autosync commit on top of the
#   latest upstream branch head.
# - If the rebase conflicts, this phase fails and the local autosync commit is
#   intentionally left in the source repo for manual resolution.
# - If the rebase succeeds but `git push` fails, the commit still remains local
#   and the status file points at that state.
publish_captured_changes() {
  local output

  if [ "${CAPTURE_RESULT}" != "committed" ]; then
    PUBLISH_RESULT="skipped"
    return 0
  fi

  if [ "${DISABLE_PUBLISH}" = "1" ]; then
    PUBLISH_RESULT="disabled"
    log INFO "Publish disabled by CHEZMOI_SYNC_DISABLE_PUBLISH=1"
    set_resolution \
      "Autosync publish paused" \
      "Managed changes were committed locally but automatic push is disabled." \
      "cd $(pretty_path "${SOURCE_DIR}") && git push origin HEAD:${CURRENT_BRANCH}" \
      "1. Review the local autosync commit:\n   cd $(pretty_path "${SOURCE_DIR}")\n   git status\n   git log --oneline -n 3\n2. Push it when ready:\n   git push origin HEAD:${CURRENT_BRANCH}\n3. Re-run a sync if needed:\n   chezmoi update --no-pager --no-tty"
    maybe_notify \
      "publish-disabled" \
      "dotfiles" \
      "Autosync publish paused" \
      "Managed changes were committed locally. Next: cd $(pretty_path "${SOURCE_DIR}") && git push origin HEAD:${CURRENT_BRANCH}"
    return 0
  fi

  if [ -z "${CURRENT_BRANCH}" ]; then
    PUBLISH_RESULT="failed"
    set_last_error "Cannot publish captured changes because the chezmoi source repo is detached"
    set_resolution \
      "Autosync publish blocked" \
      "The chezmoi source repo is detached and cannot accept an unattended push." \
      "cd $(pretty_path "${SOURCE_DIR}") && git status" \
      "1. Inspect the source repo:\n   cd $(pretty_path "${SOURCE_DIR}")\n   git status\n   git branch --show-current\n2. Check out the intended branch.\n3. Push the local commit manually once the repo is attached to a branch."
    maybe_notify \
      "publish-detached-head" \
      "dotfiles" \
      "Autosync publish blocked" \
      "The chezmoi source repo is detached. Next: cd $(pretty_path "${SOURCE_DIR}") && git status"
    return 1
  fi

  if ! run_action output \
    "git pull --rebase --autostash" \
    git -C "${SOURCE_DIR}" pull --rebase --autostash origin "${CURRENT_BRANCH}"; then
    PUBLISH_RESULT="failed"
    set_last_error "Failed to rebase captured local changes onto origin/${CURRENT_BRANCH}"
    set_resolution \
      "Autosync rebase conflict" \
      "Your local autosync commit was preserved, but it conflicts with newer upstream changes." \
      "cd $(pretty_path "${SOURCE_DIR}") && git status" \
      "1. Inspect the rebase state:\n   cd $(pretty_path "${SOURCE_DIR}")\n   git status\n2. Open and resolve the conflicted files listed by git.\n3. Mark them resolved:\n   git add <resolved-files>\n4. Continue the rebase:\n   git rebase --continue\n5. Publish the preserved autosync commit:\n   git push origin HEAD:${CURRENT_BRANCH}\n6. Resume pull/apply:\n   chezmoi update --no-pager --no-tty\n\nIf you intentionally want to discard the autosync commit instead, run:\n   git rebase --abort"
    maybe_notify \
      "publish-pull-failed" \
      "dotfiles" \
      "Autosync rebase conflict" \
      "Publish paused. Next: cd $(pretty_path "${SOURCE_DIR}") && git status"
    return 1
  fi

  if ! run_action output \
    "git push origin HEAD:${CURRENT_BRANCH}" \
    git -C "${SOURCE_DIR}" push origin "HEAD:${CURRENT_BRANCH}"; then
    PUBLISH_RESULT="failed"
    set_last_error "Failed to push captured changes to origin/${CURRENT_BRANCH}"
    set_resolution \
      "Autosync push failed" \
      "The autosync commit exists locally, but git could not push it upstream." \
      "cd $(pretty_path "${SOURCE_DIR}") && git status" \
      "1. Inspect the source repo and remote state:\n   cd $(pretty_path "${SOURCE_DIR}")\n   git status\n   git remote -v\n2. If the remote changed again, reconcile it:\n   git pull --rebase --autostash origin ${CURRENT_BRANCH}\n3. Push the local autosync commit:\n   git push origin HEAD:${CURRENT_BRANCH}\n4. Resume pull/apply:\n   chezmoi update --no-pager --no-tty"
    maybe_notify \
      "publish-push-failed" \
      "dotfiles" \
      "Autosync publish failed" \
      "The autosync commit is local only. Next: cd $(pretty_path "${SOURCE_DIR}") && git status"
    return 1
  fi

  PUBLISH_RESULT="success"
  set_resolution \
    "Healthy" \
    "Managed local changes were captured and published successfully." \
    "cat $(pretty_path "${STATUS_FILE}")" \
    "No operator action is required."
  return 0
}

# Pull/apply is intentionally conservative:
# - It only runs once the source repo is free of tracked local changes.
# - That prevents a later non-interactive `chezmoi update` from surfacing an
#   opaque TTY error when the real root cause was unresolved local repo state.
pull_remote_changes() {
  local output

  if [ "${DISABLE_PULL}" = "1" ]; then
    PULL_RESULT="disabled"
    log INFO "Pull/apply disabled by CHEZMOI_SYNC_DISABLE_PULL=1"
    set_resolution \
      "Pull/apply paused" \
      "Automatic publish succeeded, but automatic chezmoi update is disabled." \
      "chezmoi update --no-pager --no-tty" \
      "1. Run a manual update when you want to apply remote changes:\n   chezmoi update --no-pager --no-tty"
    return 0
  fi

  refresh_repo_status
  if repo_has_tracked_changes "${REPO_STATUS}"; then
    PULL_RESULT="blocked"
    set_last_error "Skipping pull/apply because the chezmoi source repo still has tracked local changes"
    set_resolution \
      "Autosync paused by local source changes" \
      "The chezmoi source repo is still dirty, so unattended pull/apply would be unsafe." \
      "cd $(pretty_path "${SOURCE_DIR}") && git status" \
      "1. Inspect the source repo:\n   cd $(pretty_path "${SOURCE_DIR}")\n   git status\n2. Finish the pending git work.\n   - If a rebase is in progress: resolve files, then run `git add <files>` and `git rebase --continue`.\n   - If local changes are intentional: commit and push them.\n3. When the repo is clean again, run:\n   chezmoi update --no-pager --no-tty"
    maybe_notify \
      "pull-blocked-dirty-repo" \
      "dotfiles" \
      "Autosync paused" \
      "The chezmoi source repo is dirty. Next: cd $(pretty_path "${SOURCE_DIR}") && git status"
    return 1
  fi

  if ! run_action output "chezmoi update" chezmoi update --no-pager --no-tty; then
    PULL_RESULT="failed"
    set_last_error "chezmoi update failed"
    set_resolution \
      "chezmoi update failed" \
      "The source repo was in a safe state, but chezmoi could not complete pull/apply." \
      "cat $(pretty_path "${STATUS_FILE}")" \
      "1. Inspect the autosync summary and latest log:\n   cat $(pretty_path "${STATUS_FILE}")\n   tail -n 100 $(pretty_path "${LATEST_LOG_FILE}")\n2. Re-run the update manually for a full terminal error:\n   chezmoi update --no-pager --no-tty"
    maybe_notify \
      "pull-update-failed" \
      "dotfiles" \
      "Autosync pull failed" \
      "chezmoi update did not complete. Next: cat $(pretty_path "${STATUS_FILE}")"
    return 1
  fi

  PULL_RESULT="success"
  set_resolution \
    "Healthy" \
    "Pull/apply completed successfully." \
    "cat $(pretty_path "${STATUS_FILE}")" \
    "No operator action is required."
  return 0
}

# Write a machine-readable-enough text summary for quick inspection.
# This is the main artifact notifications refer to because it captures both the
# high-level phase outcome and the raw repo/chezmoi state behind it.
write_status_file() {
  {
    printf 'run_id: %s\n' "${RUN_ID}"
    printf 'started_at: %s\n' "${RUN_STARTED_AT}"
    printf 'host: %s\n' "${HOSTNAME_SHORT}"
    printf 'dry_run: %s\n' "${DRY_RUN}"
    printf 'source_dir: %s\n' "${SOURCE_DIR}"
    printf 'branch: %s\n' "${CURRENT_BRANCH:-unknown}"
    printf 'capture_result: %s\n' "${CAPTURE_RESULT}"
    printf 'captured_target_count: %s\n' "${#CAPTURED_TARGETS[@]}"
    printf 'skipped_capture_count: %s\n' "${#SKIPPED_CAPTURE_TARGETS[@]}"
    printf 'publish_result: %s\n' "${PUBLISH_RESULT}"
    printf 'pull_result: %s\n' "${PULL_RESULT}"
    printf 'managed_drift_count: %s\n' "${#DRIFT_TARGETS[@]}"
    printf 'pending_apply_count: %s\n' "${#PENDING_APPLY_TARGETS[@]}"
    printf 'last_error: %s\n' "${LAST_ERROR:-none}"
    printf 'resolution_file: %s\n' "$(pretty_path "${RESOLUTION_FILE}")"
    printf 'resolution_title: %s\n' "${RESOLUTION_TITLE}"
    printf 'resolution_summary: %s\n' "${RESOLUTION_SUMMARY}"
    printf 'next_action: %s\n' "${NEXT_ACTION}"
    printf 'log_file: %s\n' "$(pretty_path "${LATEST_LOG_FILE}")"
    printf 'append_log_file: %s\n' "$(pretty_path "${LOG_FILE}")"
    printf 'launchd_stdout_file: %s\n' "$(pretty_path "${LAUNCHD_STDOUT_FILE}")"
    printf 'launchd_stderr_file: %s\n' "$(pretty_path "${LAUNCHD_STDERR_FILE}")"
    printf 'git_status_file: %s\n' "$(pretty_path "${GIT_STATUS_FILE}")"
    printf 'chezmoi_status_file: %s\n' "$(pretty_path "${CHEZMOI_STATUS_FILE}")"
    printf 'last_error_file: %s\n' "$(pretty_path "${LAST_ERROR_FILE}")"

    if [ "${#CAPTURED_TARGETS[@]}" -gt 0 ]; then
      printf '\n[captured managed targets]\n'
      local target_path
      for target_path in "${CAPTURED_TARGETS[@]}"; do
        printf '%s\n' "$(pretty_path "${target_path}")"
      done
    fi

    if [ "${#FAILED_CAPTURE_TARGETS[@]}" -gt 0 ]; then
      printf '\n[failed captures]\n'
      local failed_path
      for failed_path in "${FAILED_CAPTURE_TARGETS[@]}"; do
        printf '%s\n' "$(pretty_path "${failed_path}")"
      done
    fi

    if [ -n "${REPO_STATUS}" ]; then
      printf '\n[git status]\n%s\n' "${REPO_STATUS}"
    fi

    if [ -n "${CHEZMOI_STATUS}" ]; then
      printf '\n[chezmoi status]\n%s\n' "${CHEZMOI_STATUS}"
    fi

    printf '\n[resolution]\n%b\n' "${RESOLUTION_DETAILS}"
  } > "${STATUS_FILE}"
}

# EXIT trap: even when a phase fails, refresh the observable state on disk so
# the next inspection shows the final repo and chezmoi status after the error.
cleanup() {
  local rc="$?"

  if [ "${rc}" -ne 0 ] && [ -z "${LAST_ERROR}" ]; then
    set_last_error "Autosync exited unexpectedly with code ${rc}"
  fi

  if [ -n "${SOURCE_DIR}" ] && [ -d "${SOURCE_DIR}" ]; then
    refresh_repo_status || true
  fi
  refresh_chezmoi_status || true
  write_resolution_file || true
  write_status_file || true

  if [ -d "${LOCK_DIR}" ]; then
    rmdir "${LOCK_DIR}" 2>/dev/null || true
  fi
}

trap cleanup EXIT

# Basic overlap protection for periodic launchd execution.
if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
  log WARN "Skipping autosync run because another instance is already active"
  maybe_notify \
    "run-already-active" \
    "dotfiles" \
    "Autosync already running" \
    "Another autosync instance is still active. See $(pretty_path "${STATUS_FILE}")"
  exit 0
fi

log INFO "Starting autosync run on ${HOSTNAME_SHORT}"
log INFO "Status artifacts live under $(pretty_path "${STATE_DIR}")"

if ! run_capture SOURCE_DIR "chezmoi source-path" chezmoi source-path; then
  set_last_error "Failed to resolve the chezmoi source directory"
  set_resolution \
    "Autosync startup failed" \
    "The script could not determine the chezmoi source repo path." \
    "tail -n 100 $(pretty_path "${LATEST_LOG_FILE}")" \
    "1. Inspect the latest autosync log:\n   tail -n 100 $(pretty_path "${LATEST_LOG_FILE}")\n2. Verify chezmoi works in your shell:\n   chezmoi source-path"
  maybe_notify \
    "source-path-failed" \
    "dotfiles" \
    "Autosync startup failed" \
    "Could not resolve the chezmoi source directory. Next: tail -n 100 $(pretty_path "${LATEST_LOG_FILE}")"
  exit 1
fi

if ! run_capture CURRENT_BRANCH "git branch --show-current" git -C "${SOURCE_DIR}" branch --show-current; then
  set_last_error "Failed to determine the active branch for the chezmoi source repo"
  set_resolution \
    "Autosync startup failed" \
    "The script could not determine the active branch for the chezmoi source repo." \
    "cd $(pretty_path "${SOURCE_DIR}") && git status" \
    "1. Inspect the source repo state:\n   cd $(pretty_path "${SOURCE_DIR}")\n   git status\n   git branch --show-current"
  maybe_notify \
    "branch-detect-failed" \
    "dotfiles" \
    "Autosync startup failed" \
    "Could not determine the chezmoi source branch. Next: cd $(pretty_path "${SOURCE_DIR}") && git status"
  exit 1
fi

refresh_repo_status
refresh_chezmoi_status

if ! capture_local_changes; then
  exit 1
fi

if ! publish_captured_changes; then
  exit 1
fi

if ! pull_remote_changes; then
  exit 1
fi

refresh_repo_status
refresh_chezmoi_status

if [ "${#DRIFT_TARGETS[@]}" -gt 0 ] || [ "${#PENDING_APPLY_TARGETS[@]}" -gt 0 ]; then
  set_resolution \
    "Autosync still has pending work" \
    "Managed drift or unapplied source changes remain after the automated phases finished." \
    "cat $(pretty_path "${STATUS_FILE}")" \
    "1. Inspect the current summary:\n   cat $(pretty_path "${STATUS_FILE}")\n2. Review the raw states if needed:\n   cat $(pretty_path "${CHEZMOI_STATUS_FILE}")\n   cat $(pretty_path "${GIT_STATUS_FILE}")\n3. If the source repo is clean, apply pending changes manually:\n   chezmoi update --no-pager --no-tty\n4. If the source repo is dirty, resolve it first:\n   cd $(pretty_path "${SOURCE_DIR}")\n   git status"
  maybe_notify \
    "managed-drift-pending" \
    "dotfiles" \
    "Autosync needs attention" \
    "Pending work remains. Next: cat $(pretty_path "${STATUS_FILE}")"
fi

log INFO "Autosync run completed with capture=${CAPTURE_RESULT}, publish=${PUBLISH_RESULT}, pull=${PULL_RESULT}"
