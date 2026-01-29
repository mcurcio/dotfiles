---
name: smart-jira-tickets
description: Triages rough ideas into Jira tickets (quick blurbs, full stories, or epics with child issues). Searches for existing tickets and epics to supplement or merge instead of creating duplicates; asks for clarification when vague; searches Jira, Confluence, and the codebase for context; kicks off a short architecture design for complex work. Use when the user wants to create a Jira ticket, write up an idea, or turn an error or feature idea into tickets.
---

# Smart Jira Ticket Workflow

Triages the user's rough idea or error description, then either writes a quick ticket, asks clarifying questions, enriches with ecosystem search (Jira, Confluence, codebase), or runs a short architecture pass and produces an epic with child tickets. Always searches for existing tickets and epics so the agent can supplement or merge instead of creating duplicates.

## 1. Triage (choose one path)

Evaluate the user's input and follow exactly one branch:

| Branch | When | Action |
|--------|------|--------|
| **Quick blurb** | Single, clear ask (e.g. "fix typo on login", "add retry for payment API"). No "design" or "figure out". | Write short summary + minimal description. Offer to create as Task/Bug. |
| **Clarify** | Vague (e.g. "something's broken", "we need to improve X") or missing who/what/success criteria. | Reply with 3–5 concrete questions: who is affected, what exactly happens, steps to reproduce, success looks like, existing ticket or system? |
| **Search first** | User mentions an existing system, component, error, or "like the X we did" / "related to Y". | Run **Enrich** (step 2), then draft ticket(s) using findings. |
| **Architecture then epic** | New capability, multiple components, "design", "architect", or "this will need several pieces". | Run **Architecture step** (step 4), then produce one Epic + 2–5 child issues. |

## 2. Enrich (search ecosystem)

When triage is **Search first** (or when the idea references code, a service, or existing work), gather context before drafting.

### 2a. Jira and Confluence (Atlassian MCP)

- Use the **`search`** tool (Rovo Search) with a short query (e.g. component name, error message, feature name) to find related Jira issues and Confluence pages. Prefer this for general Jira + Confluence search unless CQL/JQL is required.
- For targeted Jira search: use **`searchJiraIssuesUsingJql`** (e.g. by project, label, text in summary/description).
- For targeted Confluence search: use **`searchConfluenceUsingCql`** when CQL syntax is needed.
- Require **cloudId**: use **`getAccessibleAtlassianResources`** first if not already known.
- Summarize relevant findings (issue keys, page titles, snippets) and use them in the ticket description and acceptance criteria. Add links to related Jira/Confluence in the ticket or in a comment after creation.

### 2c. Search for existing tickets and epics (avoid duplicates)

**Always** search Jira for existing issues and epics that might be the same or closely related work before drafting or creating:

- Use **`search`** (Rovo) or **`searchJiraIssuesUsingJql`** with queries derived from the user's idea: key terms, component/service name, error message, or feature name. Include Epics and Stories/Tasks/Bugs in results.
- Look for: same or very similar scope, same component, existing epic that could parent this work, or recent ticket describing the same bug/feature.
- **If you find a strong match (likely duplicate or same work):**
  - **Supplement instead of create:** Propose adding to the existing issue (e.g. new comment with the user's details, or a new subtask under it). Use **`addCommentToJiraIssue`** to add context, or create a single **Subtask** with `parent` set to the existing issue key.
  - Present the existing issue(s) to the user and ask: "This looks like it may overlap with [KEY-123]. Prefer adding a comment/subtask there, or create a new ticket and link to it?"
- **If you find a related epic or parent issue (same theme, but this is additional work):**
  - **Merge into existing:** Propose adding the new work as a **child** of that epic (create new Story/Task with `parent` set to the epic key). In the description, reference the epic and any related issue keys.
  - Present the epic to the user: "Existing epic [KEY-456] covers this area. Create new child issue(s) under it?"
- **If no relevant match:** Proceed to draft and (after confirmation) create new issue(s) as in section 3. Optionally link to related but distinct issues in the description.

### 2b. Codebase and related services (GitHub / workspace)

- Search the **codebase** for the **referenced project** and any **related or referenced services**:
  - Identify the project or service name from the user's idea (e.g. "checkout", "payment retry", "webhook handler").
  - Use codebase search and grep to find: entrypoints, config, dependencies, and imports that define or reference that project and its callers/callees.
  - Look for related services: shared libs, API clients, event producers/consumers, or services mentioned in config/docs.
- Include in the ticket:
  - Relevant file paths, module names, or function names.
  - Short note on how the change fits (e.g. "Touchpoints: `src/checkout/`, `src/payments/`").
- If the workspace has multiple repos or the user names a repo, search the open project first; if the user specifies another repo, note it and search that codebase if available.

## 3. Draft and optionally create in Jira

### Templates

**Short blurb (Task/Bug):**
- Summary: one clear line.
- Description: 2–3 sentences or bullet list (what, where, optional repro).

**Full ticket (Story/Task):**
- Summary: one line.
- Description: context, scope, and (if from search) "Related: LINK-123, Confluence page X".
- Acceptance criteria: 3–5 bulleted items.

**Epic + children:**
- Epic: summary + short description (goal and scope).
- Each child: summary + description + 2–4 acceptance criteria; link via `parent` when creating.

### Creating issues (Atlassian MCP)

**Before creating:** Run the **existing-tickets check** (section 2c) if not already done—e.g. for "Quick blurb" where Enrich was skipped. Search for existing tickets/epics that match or relate; if a strong match exists, offer to supplement/merge instead of creating. Only create new issue(s) when the user confirms that no existing issue should be reused.

1. **Resolve cloud and project:** Use **`getAccessibleAtlassianResources`** then **`getVisibleJiraProjects`** to get `cloudId` and `projectKey`.
2. **Resolve issue types:** Use **`getJiraProjectIssueTypesMetadata`** for the chosen project to get valid `issueTypeName` (e.g. Epic, Story, Task, Bug).
3. **Create:** Use **`createJiraIssue`** with `cloudId`, `projectKey`, `issueTypeName`, `summary`, and `description` (Markdown). For subtasks or epic children, set `parent` to the parent issue key.
4. **Epic with children:** Create the Epic first, then create each child issue with `parent` set to the new Epic's key.
5. **Optional:** Use **`addCommentToJiraIssue`** to attach links to related Jira issues or Confluence pages found during Enrich.

Only create issues after the user confirms (e.g. "create it" or "create in Jira"). If project or issue type is unclear, ask once before creating.

## 4. Architecture step (when triage = Architecture then epic)

When the work is complex or multi-component:

1. **Scope:** In 2–4 sentences, state the goal and main components/capabilities.
2. **Work breakdown:** List 3–7 concrete work items (e.g. "API contract + handler", "DB migration", "Event producer", "Tests and docs"). One line each.
3. **Output:** One Epic (summary + short description) and one Jira issue per work item, using the full-ticket template. Create Epic first, then children with `parent` set.

Optionally reference an existing architecture-design skill if the user has one; otherwise follow the short breakdown above.

## 5. End of workflow

- For **quick blurb** or **full ticket:** Present the draft (and optionally the created issue key/link).
- For **epic + children:** Present Epic summary, list of child issues with keys/links, and optionally a one-line mapping (work item → issue key).
- When Enrich was used: briefly note what was found (e.g. "Used: Jira search, Confluence page X, codebase paths A/B").
