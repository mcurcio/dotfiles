---
name: start
description: "This skill should be used when the user asks to \"start the swarm\", \"run swarm\", \"continue the swarm\", \"resume swarm\", or invokes /swarm or /swarm:start. Unified entry point that auto-routes to the correct swarm phase based on session state."
argument-hint: "[topic or nothing to resume]"
allowed-tools: ["Read", "Bash", "Skill"]
---

# Swarm Entry Point

Reads state and delegates to the appropriate phase skill. Does not execute work.

**Announce at start:** "Checking swarm state and routing."

## Process

### 1. Check Session State

Read `.claude/swarm/active.json` (if it exists). Extract `phase`, `step`, `swarm_id`, and `feedback`. If the file does not exist, treat as no active swarm.

### 2. Route

| Condition | Action |
|---|---|
| No active swarm + topic provided | Invoke `swarm:design` with topic |
| No active swarm + no topic | Prompt: "No active swarm. What would you like to design?" |
| `feedback` field non-null | Report target stage, invoke appropriate skill |
| `phase` = `design` | Invoke `swarm:design` |
| `phase` = `plan` | Invoke `swarm:plan` |
| `phase` = `implement` | Invoke `swarm:implement` |
| `phase` = `done` | Report: "Swarm complete. Artifacts at `.claude/swarm/sessions/<id>/`." |

**Feedback routing:** `requirements`/`architecture`/`code-design` → `swarm:design`. `plan` → `swarm:plan`. The invoked skill reads the feedback field internally.

### 3. Invoke

Use the Skill tool. Pass the user's topic as argument for new swarms; no argument for resume.

## Explicit Phase Overrides

`/swarm:design`, `/swarm:plan`, `/swarm:implement` remain available to force a specific phase. Those skills validate prerequisites independently.

## Internal Routing Targets

- `design/requirements` — Phase 1
- `design/architecture` — Phase 2
- `design/code` — Phase 3
- `plan` — Phase 4
- `implement` — Phase 5
