# Knowledge Coordinator — Architecture

## Overview

| Component | Type | Role |
|-----------|------|------|
| **knowledge-coordinator** | Skill | Triage new information; delegate to Obsidian or public agent (or both). |
| **obsidian-knowledge-agent** | Subagent | Updates Obsidian vault, organizes notes, maintains TODOs. |
| **public-knowledge-agent** | Subagent | Updates Jira and Confluence; search first, supplement or create. |

## When to Use What

- **Single system, light capture** — Use **obsidian-knowledge-loop** (Obsidian) or **smart-jira-tickets** (Jira) directly.
- **Multiple systems / alignment** — Use **knowledge-coordinator**; it invokes the specialist agents.

## Flow

1. User (or main agent) has new information and wants it captured everywhere or in multiple places.
2. Main agent applies **knowledge-coordinator**: triage → personal vs public vs both.
3. Main agent invokes **obsidian-knowledge-agent** and/or **public-knowledge-agent** with a clear payload.
4. Each agent uses its MCP (Obsidian or Atlassian) to search, then create or update.
5. Coordinator (or main agent) confirms what was written where.

## Alignment

When the user asks to "keep knowledge bases aligned", the coordinator sends the same summary to both agents and asks for cross-links (e.g. Jira key in Obsidian note, Confluence link in Jira description).

## "Scheduled" check (every conversation)

To make the agent **check at conversation start and at break points** whether knowledge bases should be updated:

1. Copy **knowledge-check-rule.mdc** from this skill folder into your **project's** `.cursor/rules/` directory.
2. The rule has `alwaysApply: true`, so it applies to every conversation in that project.
3. The agent will offer once per break point: "Should I update your knowledge bases with what we just did?"

**Scope:** Rules are per-project. For every project where you want this behavior, add the rule to that project's `.cursor/rules/`. Or add it to your project template so new repos get it automatically.
