# Knowledge Coordinator — Architecture

## Components

| Component | Type | Role |
|-----------|------|------|
| **knowledge-coordinator** | Skill | Triage new information; delegate to Obsidian or public agent (or both) |
| **obsidian-knowledge-agent** | Agent | Updates Obsidian vault, organizes notes, maintains TODOs |
| **public-knowledge-agent** | Agent | Updates Jira and Confluence; search first, supplement or create |
| **obsidian-knowledge-loop** | Skill | Enriches context from vault; captures learnings (single-system) |
| **smart-jira-tickets** | Skill | Triages ideas into Jira tickets (single-system) |

## When to Use What

- **Single system, light capture** — Use obsidian-knowledge-loop (Obsidian) or smart-jira-tickets (Jira) directly.
- **Multiple systems or alignment** — Use knowledge-coordinator; it invokes the specialist agents.

## Flow

1. User (or main agent) has new information to capture across systems.
2. Knowledge-coordinator activates: triage → personal vs public vs both.
3. Coordinator invokes obsidian-knowledge-agent and/or public-knowledge-agent with clear payload.
4. Each agent uses its MCP tools (Obsidian MCP or Atlassian MCP) to search, then create or update.
5. Coordinator confirms what was written where.

## Alignment Protocol

When keeping bases aligned:
1. Send same summary to both agents with "match consistent wording" instruction.
2. After both complete, cross-link: Jira key in Obsidian note, Confluence URL in Jira description.
3. For periodic sync: both agents review project X and update their system to match.

## MCP Dependencies

- **Obsidian MCP**: must be configured in the user's MCP settings. Provides search_notes, read_note, write_note, patch_note, update_frontmatter, manage_tags, move_note, list_directory.
- **Atlassian MCP**: provided by the installed Atlassian marketplace plugin. Provides Jira and Confluence tools (search, create, update, comment).
