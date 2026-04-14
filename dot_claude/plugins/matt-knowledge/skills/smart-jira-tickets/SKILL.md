---
name: smart-jira-tickets
description: This skill should be used when the user asks to "create a Jira ticket", "write up an idea", "turn this into a ticket", "create a bug report", "make a story for this", "create an epic", "triage this idea", "file a ticket", "create a task in Jira", or when converting errors, feature ideas, or rough descriptions into well-structured Jira tickets. Searches for existing tickets to avoid duplicates and enriches context from Jira, Confluence, and the codebase.
---

# Smart Jira Ticket Workflow

Triage rough ideas or error descriptions, then either write a quick ticket, ask clarifying questions, enrich with ecosystem search, or produce an epic with child tickets. Always search for existing tickets and epics to supplement instead of creating duplicates.

## 1. Triage

Evaluate the input and follow exactly one branch:

| Branch | When | Action |
|--------|------|--------|
| **Quick blurb** | Single, clear ask (e.g., "fix typo on login", "add retry for payment API") | Write short summary + minimal description. Offer to create as Task/Bug. |
| **Clarify** | Vague or missing who/what/success criteria | Reply with 3-5 concrete questions |
| **Search first** | References existing system, component, error, or "like the X we did" | Run Enrich (step 2), then draft |
| **Architecture then epic** | New capability, multiple components, "design", "architect" | Run Architecture (step 4), then epic + children |

## 2. Enrich (Search Ecosystem)

When triage is "Search first" or when the idea references code, a service, or existing work:

### Jira and Confluence (Atlassian MCP)

- Use `search` (Rovo) for general search across Jira + Confluence
- Use `searchJiraIssuesUsingJql` for targeted Jira search (by project, label, text)
- Use `searchConfluenceUsingCql` for targeted Confluence search
- Require `cloudId`: use `getAccessibleAtlassianResources` first

### Codebase

- Search the codebase for the referenced project and related services
- Use grep to find entrypoints, config, dependencies, and imports
- Look for related services: shared libs, API clients, event producers/consumers
- Include relevant file paths and module names in the ticket

### Existing Tickets and Epics (Always)

**Always** search Jira for existing issues before creating:

- **Strong match (likely duplicate)**: propose supplementing instead of creating. Use `addCommentToJiraIssue` to add context, or create a subtask. Present to user: "This overlaps with KEY-123. Add a comment there, or create new?"
- **Related epic**: propose adding as child. "Existing epic KEY-456 covers this area. Create child issue(s) under it?"
- **No match**: proceed to draft and create.

## 3. Draft and Create

### Templates

See `references/ticket-templates.md` for full templates.

- **Quick blurb**: summary + 2-3 sentences
- **Full ticket**: summary + description + 3-5 acceptance criteria
- **Epic + children**: epic summary/description, then child issues with parent set

### Creating Issues (Atlassian MCP)

1. Resolve cloud and project: `getAccessibleAtlassianResources` → `getVisibleJiraProjects`
2. Resolve issue types: `getJiraProjectIssueTypesMetadata`
3. Create: `createJiraIssue` with cloudId, projectKey, issueTypeName, summary, description
4. Epic with children: create epic first, then children with `parent` set to epic key
5. Optional: `addCommentToJiraIssue` to attach links to related issues/pages

Only create after user confirms. If project or issue type is unclear, ask once.

Jira ticket references: always render as full clickable URLs (e.g., `https://ifitdev.atlassian.net/browse/KEY-123`).

## 4. Architecture Step

When triage = "Architecture then epic":

1. **Scope**: 2-4 sentences stating the goal and main components
2. **Work breakdown**: 3-7 concrete work items, one line each
3. **Output**: one epic + one issue per work item, using full-ticket template

## 5. End of Workflow

- For quick blurb or full ticket: present draft and optionally the created issue URL
- For epic + children: present epic summary, list of child issues with URLs
- When Enrich was used: note what was found ("Used: Jira search, Confluence page X, codebase paths A/B")

## Additional Resources

- **`references/ticket-templates.md`** — Templates for each ticket type and Atlassian MCP tool reference
