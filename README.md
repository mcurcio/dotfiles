# Dotfiles Guide

Managed with [chezmoi](https://www.chezmoi.io/).

## Table of Contents
- [TL;DR Cheat Sheet](#tldr-cheat-sheet)
- [Bootstrap](#bootstrap)
- [Core Workflows](#core-workflows)
- [Advanced Configuration](#advanced-configuration)
- [Feature Inventory](#feature-inventory)

## TL;DR Cheat Sheet

```bash
# Pull and apply latest changes
chezmoi update

# See what the background autosync most recently decided
cat ~/Library/Application\ Support/chezmoi-sync/status.txt

# Inspect local drift
chezmoi status --path-style absolute

# Add/update a managed file
chezmoi add ~/.zshrc
chezmoi apply

# Commit and publish
cd "$(chezmoi source-path)"
git add .
git commit -m "Update dotfiles"
git push
```

Auto-sync diagnostics:
```bash
launchctl print "gui/$(id -u)/com.dotfiles.chezmoi-sync"
cat ~/Library/Application\ Support/chezmoi-sync/status.txt
cat ~/Library/Application\ Support/chezmoi-sync/resolution.txt
tail -n 100 ~/Library/Logs/chezmoi-sync.latest.log
tail -n 100 ~/Library/Logs/chezmoi-sync.launchd.err.log

# Preview the autosync decision tree without changing files
CHEZMOI_SYNC_DRY_RUN=1 ~/.local/bin/chezmoi-sync.sh
```

## Bootstrap

### Prerequisites
- `git`
- `chezmoi`
- macOS for LaunchAgent auto-sync support

Install chezmoi:
```bash
brew install chezmoi
```

Create `~/.config/chezmoi/chezmoi.toml`:
```toml
[data]
autosync = true
profile = "personal"
profiles = ["personal"]

[data.features]
shairport = false
```

Initialize and apply:
```bash
chezmoi init --apply mcurcio
chezmoi doctor
chezmoi diff
```

## Core Workflows

### Sync from cloud
```bash
chezmoi update
```

### Understand the background autosync loop
Background autosync now runs in two phases:
- Capture/publish: detect managed local drift, run `chezmoi add` for those paths, commit the resulting source changes, and push them upstream when possible.
- Pull/apply: once the chezmoi source repo is in a safe state, run `chezmoi update --no-tty --no-pager`.

Every run writes a current summary to `~/Library/Application Support/chezmoi-sync/status.txt` plus detailed logs under `~/Library/Logs/`.
For blocking issues, it also writes operator guidance to `~/Library/Application Support/chezmoi-sync/resolution.txt`, and notifications now point at the exact next command to run.

If capture succeeds but publish hits an upstream conflict, the local autosync commit is kept in the chezmoi source repo and pull/apply is paused until that repo state is resolved. The status file records that explicitly.

### Reload the LaunchAgent after plist changes
Script-only changes take effect on the next run after `chezmoi apply`, because the LaunchAgent keeps calling the same script path.

If the LaunchAgent plist template changes, re-render the target plist with chezmoi and then reload that rendered file on each machine:
```bash
chezmoi apply ~/Library/LaunchAgents/com.dotfiles.chezmoi-sync.plist
launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.dotfiles.chezmoi-sync.plist 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.dotfiles.chezmoi-sync.plist
launchctl kickstart -k "gui/$(id -u)/com.dotfiles.chezmoi-sync"
```

### Add a new file and publish changes
1. Add file to source state:
```bash
chezmoi add ~/.zshrc
```
2. Validate and apply:
```bash
chezmoi diff
chezmoi apply
```
3. Commit and push:
```bash
cd "$(chezmoi source-path)"
git add .
git commit -m "Add zshrc"
git push
```

### Recover from drift
```bash
chezmoi status --path-style absolute
chezmoi add <file>
chezmoi apply
```

If background autosync is enabled, the same drift should usually be captured and committed automatically. When it is blocked, inspect `~/Library/Application Support/chezmoi-sync/status.txt` for the exact phase and file list.

## Advanced Configuration

### Profile and feature model
- `profiles`: identity/context tags (examples: `personal`, `work`, `macbook`, `homelab`)
- `features.*`: capability toggles (examples: `shairport`, `k8s`)

Example:
```toml
[data]
profiles = ["personal", "work", "client-acme"]

[data.features]
shairport = true
```

### Adding a profile
1. Add the new tag to `profiles` in `~/.config/chezmoi/chezmoi.toml`.
2. Apply:
```bash
chezmoi apply
```

### Multi-profile machines
Assign multiple tags in `profiles` for a single computer. This supports mixed-use machines without creating separate profile names for every combination.

### Conditional deployment patterns
Pattern 1: use templates when file content varies by profile/feature.

`dot_zshrc.tmpl`:
```gotemplate
{{- $profiles := .profiles | default (list .profile) -}}
export EDITOR=vim

{{- if has "work" $profiles }}
export AWS_PROFILE=work
{{- end }}
```

Pattern 2: keep files literal and conditionally include/exclude via `.chezmoiignore`.

`.chezmoiignore`:
```gotemplate
{{- if not .features.shairport }}
.config/shairport-sync/shairport-sync.conf
{{- end }}
```

Guidelines:
- `.chezmoiignore` matches target paths.
- Define feature keys in `[data.features]` to prevent missing-key template errors.
- Use templates for content differences and `.chezmoiignore` for file-level inclusion.

## Feature Inventory

Maintainer note: keep this section aligned with actual capabilities.

### AI Development Skills and Agent Configuration (Codex, Cursor, Windsurf, Codeium)
Shared agent/skill/rule setup keeps AI assistants aligned across tools so prompts, workflows, and behavior remain consistent.

### Guardrailed Configuration and Knowledge Writes
Protected workflows require explicit approval before sensitive configuration changes or external knowledge-base writes are performed.

### Automated Cloud Sync and Drift Awareness
Optional background sync captures managed local drift into the chezmoi source repo, publishes it quickly when possible, and records clear per-run status and failure details for troubleshooting.

### Terminal and Editor Baseline
Consistent shell/editor defaults provide predictable behavior across new and existing machines.

### Profile- and Feature-Based Machine Composition
Machine identity (`profiles`) and capability toggles (`features`) allow selective rollout of config without duplicating entire file sets.
