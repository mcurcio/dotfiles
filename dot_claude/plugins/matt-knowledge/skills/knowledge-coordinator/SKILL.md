---
name: knowledge-coordinator
description: This skill should be used when the user asks to "update all my knowledge bases", "sync to Jira and Obsidian", "disseminate this", "capture everywhere", "sync knowledge", "put this in Obsidian and create a Jira ticket", "document this publicly", "capture to all systems", or when new information should be written to multiple systems (Obsidian, Jira, Confluence) to keep them aligned.
---

# Knowledge Coordinator

Coordinate knowledge capture so Obsidian, Jira, and Confluence stay aligned. Triage new information, then delegate to the right specialist agent(s). Do not perform writes directly — invoke subagents with clear payloads.

## When to Use This Skill

| Trigger | Action |
|---------|--------|
| "Update all my knowledge bases", "sync knowledge", "capture everywhere" | Triage and invoke one or both agents |
| "Put this in Obsidian and create a Jira ticket" | Invoke both agents with the same info |
| "Disseminate this to the team" / "document this publicly" | Invoke public-knowledge-agent only |
| "Add to my notes and organize my vault" | Invoke obsidian-knowledge-agent only |
| Batch of learnings or decisions to capture | Triage each item and delegate |

When the user only wants Obsidian (e.g., "add to my notes"), use the **obsidian-knowledge-loop** skill directly. When the user only wants Jira (e.g., "create a ticket"), use the **smart-jira-tickets** skill directly. Use the coordinator when **multiple systems** or **explicit alignment** is requested.

## Triage: Personal vs Public

| Destination | Content type | Agent to invoke |
|-------------|--------------|-----------------|
| **Personal** | Private notes, TODOs, personal learnings, how-I-work, drafts | **obsidian-knowledge-agent** |
| **Public** | Team/org work: tickets, decisions, runbooks, Confluence docs | **public-knowledge-agent** |
| **Both** | Decision affecting both (e.g., "we decided X" → note for you, ticket for team) | Invoke **both** agents |

If unclear, ask once: "Should this live in your personal notes (Obsidian), in Jira/Confluence for the team, or both?"

## Delegation Flow

1. **Summarize** the information to capture in 2-4 sentences or bullets. Include: what happened, key decision/finding, and any references (code, tickets, people).

2. **Choose** agent(s) based on triage.

3. **Invoke** with a clear, self-contained prompt:
   - Obsidian: "Capture this to Obsidian: [summary]. Organize under Knowledge/ or the relevant project folder. Add tags and frontmatter."
   - Public: "Capture this to Jira/Confluence: [summary]. Search for existing related issues/pages first. Create or update as appropriate; prefer commenting on existing issues over duplicates."

4. **For both**: invoke obsidian-knowledge-agent and public-knowledge-agent in parallel with the same summary.

5. **Confirm** with the user what was delegated and what each agent did.

## Keeping Bases Aligned

When the user asks to **align** or **sync** knowledge:

- **Same content, multiple places**: send the same summary to each agent. Mention "this should match what we put in [other system]" so agents use consistent wording.
- **Cross-links**: after both agents complete, ask the Obsidian agent to add a link to the Jira issue or Confluence page in the note. Ask the public agent to reference the decision in the ticket/page description.
- **Periodic sync**: "Review project X; update Obsidian and Jira/Confluence so they reflect the same decisions and status."

## Subagent Reference

| Agent | Use for |
|-------|---------|
| **obsidian-knowledge-agent** | Vault updates, organizing notes, TODOs, personal learnings |
| **public-knowledge-agent** | Jira issues, Confluence pages, team-facing documentation |

## Additional Resources

- **`references/architecture.md`** — System architecture overview, component relationships, and integration notes
