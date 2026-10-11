SHELL := /bin/bash

CHEZMOI ?= chezmoi
SYNC_SCRIPT ?= $(HOME)/.local/bin/chezmoi-sync.sh
SYNC_STATE_DIR ?= $(HOME)/Library/Application\ Support/chezmoi-sync
SYNC_LOG_DIR ?= $(HOME)/Library/Logs
LAUNCH_AGENT_LABEL ?= com.dotfiles.chezmoi-sync
LAUNCH_AGENT_PLIST ?= $(HOME)/Library/LaunchAgents/$(LAUNCH_AGENT_LABEL).plist

.PHONY: help data doctor status diff apply update source-path sync-status sync-resolution sync-log sync-launchd dry-run-sync reload-launchagent

help:
	@printf '%s\n' \
	'doctor             Run chezmoi doctor' \
	'data               Show rendered chezmoi data' \
	'status             Show managed file drift with absolute paths' \
	'diff               Show chezmoi diff' \
	'apply              Apply source state to the home directory' \
	'update             Pull and apply remote changes' \
	'source-path        Print the chezmoi source directory' \
	'sync-status        Show the latest autosync summary' \
	'sync-resolution    Show the latest autosync resolution guidance' \
	'sync-log           Tail the latest autosync log' \
	'sync-launchd       Print launchd status for the autosync job' \
	'dry-run-sync       Preview autosync decisions without mutating state' \
	'reload-launchagent Re-render and reload the autosync LaunchAgent'

data:
	$(CHEZMOI) data

doctor:
	$(CHEZMOI) doctor

status:
	$(CHEZMOI) status --path-style absolute

diff:
	$(CHEZMOI) diff

apply:
	$(CHEZMOI) apply

update:
	$(CHEZMOI) update

source-path:
	$(CHEZMOI) source-path

sync-status:
	cat "$(SYNC_STATE_DIR)/status.txt"

sync-resolution:
	cat "$(SYNC_STATE_DIR)/resolution.txt"

sync-log:
	tail -n 100 "$(SYNC_LOG_DIR)/chezmoi-sync.latest.log"

sync-launchd:
	launchctl print "gui/$$(id -u)/$(LAUNCH_AGENT_LABEL)"

dry-run-sync:
	CHEZMOI_SYNC_DRY_RUN=1 "$(SYNC_SCRIPT)"

reload-launchagent:
	$(CHEZMOI) apply "$(LAUNCH_AGENT_PLIST)"
	launchctl bootout "gui/$$(id -u)" "$(LAUNCH_AGENT_PLIST)" 2>/dev/null || true
	launchctl bootstrap "gui/$$(id -u)" "$(LAUNCH_AGENT_PLIST)"
	launchctl kickstart -k "gui/$$(id -u)/$(LAUNCH_AGENT_LABEL)"
