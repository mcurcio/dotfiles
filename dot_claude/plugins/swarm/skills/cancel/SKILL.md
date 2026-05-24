---
name: cancel
description: "This skill should be used when the user asks to \"cancel the swarm\", \"stop the swarm\", \"abort the build\", \"kill the swarm\", \"end this swarm\", \"swarm cancel\", or invokes /swarm:cancel. Cancels the active swarm, marks it as cancelled in meta.json, removes active.json, and shuts down any live agents."
allowed-tools: ["Read", "Bash", "SendMessage", "TaskList", "TaskUpdate"]
---

# Cancel Active Swarm

Stop the active swarm, mark it as cancelled, and clean up.

**Announce at start:** "Cancelling the active swarm."

## Process

1. **Check for active swarm.** Read `.claude/swarm/active.json`. If it does not exist:

> "No active swarm to cancel."

2. **Read session metadata.** Read `.claude/swarm/active.json`, extract `swarm_id`. Set `SWARM_ROOT=".claude/swarm/sessions/<swarm_id>"`.

3. **Confirm with user.** Show the swarm topic and current phase/step. Ask for explicit confirmation before proceeding.

4. **Mark cancelled in meta.json:** Read `<swarm-root>/meta.json`, set `status: "cancelled"`, `phase: "cancelled"`, `step: "cancelled"`, `updated_at: "<ISO timestamp>"`, and `ended_at` on any session with `ended_at: null`. Write it back.

5. **Remove active.json** (deactivates guard hook): `Bash(rm -f .claude/swarm/active.json)`

6. **Cancel outstanding tasks.** Read TaskList. Mark any non-completed tasks as `cancelled`.

7. **Report:**

> "Swarm `<swarm-id>` cancelled. Session artifacts preserved at `<swarm-root>/` for reference."
