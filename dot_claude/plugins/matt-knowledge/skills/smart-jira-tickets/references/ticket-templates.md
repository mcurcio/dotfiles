# Jira Ticket Templates

## Quick Blurb (Task/Bug)

```
Summary: <one clear line>

Description:
<2-3 sentences or bullet list — what, where, optional repro steps>
```

## Full Ticket (Story/Task)

```
Summary: <one line>

Description:
- **Context**: <what and why>
- **Scope**: <what's included>
- **Related**: <KEY-123, Confluence page X> (from search)

Acceptance criteria:
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3
- [ ] Criterion 4 (optional)
- [ ] Criterion 5 (optional)
```

## Epic + Children

```
Epic:
  Summary: <goal>
  Description: <scope in 2-4 sentences>

Child issues (each):
  Summary: <work item>
  Description:
  - **Context**: <what this piece covers>
  - **Scope**: <boundaries>
  Parent: <epic key>
  Acceptance criteria:
  - [ ] Criterion 1
  - [ ] Criterion 2
```

## Atlassian MCP Tool Reference

### Resolution Tools
- `getAccessibleAtlassianResources` → cloudId
- `getVisibleJiraProjects` → projectKey
- `getJiraProjectIssueTypesMetadata` → valid issueTypeName (Epic, Story, Task, Bug, etc.)
- `lookupJiraAccountId` → resolve user names to account IDs for assignment

### Search Tools
- `search` (Rovo) → general search across Jira + Confluence
- `searchJiraIssuesUsingJql` → targeted Jira search with JQL
- `searchConfluenceUsingCql` → targeted Confluence search with CQL

### Creation Tools
- `createJiraIssue` → create with cloudId, projectKey, issueTypeName, summary, description, optional parent
- `addCommentToJiraIssue` → supplement existing issues with new context
- `editJiraIssue` → update existing issue fields

### Confluence Tools
- `getConfluenceSpaces` → list spaces
- `getPagesInConfluenceSpace` → find parent pages
- `createConfluencePage` → create new page
- `updateConfluencePage` → update existing page

### Workflow
1. Resolve: cloudId → projectKey → issueTypeName
2. Search: look for existing issues/epics
3. Decide: supplement existing or create new
4. Create: issue(s) with proper parent linkage
5. Link: add comments referencing related work

### URL Format
Always render Jira ticket references as full clickable URLs:
`https://ifitdev.atlassian.net/browse/KEY-123`
