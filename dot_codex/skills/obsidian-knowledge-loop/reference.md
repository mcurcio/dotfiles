# Obsidian Knowledge Loop — Reference

## Suggested vault layout

Use this layout if you don't have one yet. Paths are relative to vault root.

| Folder | Purpose |
|--------|---------|
| `Inbox/` | Quick captures, unprocessed; move to other folders when processed |
| `Knowledge/` | Evergreen learnings, patterns, decisions (reference material) |
| `Cursor-Learnings/` | Session-specific captures from Cursor; can merge into Knowledge later |
| `Projects/<name>/` | Notes for a specific project (e.g. `Projects/my-app/`) |
| `Areas/` | Ongoing responsibilities or themes (e.g. `Areas/backend/`, `Areas/on-call/`) |
| `TODOs/` or `Tasks/` | TODO notes; e.g. `TODOs.md` or one file per area |

**Flow:** Capture → Inbox; then move or link into Knowledge, Projects, or Areas. Cursor-learned content can go to `Cursor-Learnings/` or directly to `Knowledge/` if it's evergreen.

## Folder conventions (short)

| Folder | Purpose |
|--------|---------|
| `Knowledge/` | General learnings, patterns, decisions |
| `Cursor-Learnings/` | Session-specific captures from Cursor |
| `Projects/<name>/` | Project-specific notes |
| `Inbox/` | Unprocessed captures (optional) |
| `TODOs/` or `Tasks/` | TODO lists (optional) |

User may override; ask if unsure.

## Frontmatter Template

```yaml
---
date: 2025-01-28
tags: [cursor, patterns, api]
source: cursor
related-topics: [retry, resilience]
---
```

| Field | Use |
|-------|-----|
| `date` | Capture date (YYYY-MM-DD) |
| `tags` | For search and organization |
| `source` | `cursor` when captured from Cursor |
| `related-topics` | Optional; for linking |

## Note Naming

- Descriptive, lowercase, hyphens: `api-retry-pattern.md`, `auth-decision-log.md`
- Avoid generic names: `notes.md`, `misc.md`

## Obsidian MCP Tool Parameters

### search_notes
- `query` (required): Search text
- `limit`: 5–20 (default 5)
- `searchContent`: true
- `searchFrontmatter`: true when searching tags/categories

### write_note
- `path` (required), `content` (required)
- `frontmatter`: optional object
- `mode`: `overwrite` | `append` | `prepend`

### patch_note
- `path`, `oldString`, `newString` (required)
- `replaceAll`: false (default) — fails if multiple matches

### update_frontmatter
- `path`, `frontmatter` (required)
- `merge`: true (default)

### manage_tags
- `path`, `operation`: `add` | `remove` | `list`
- `tags`: array (required for add/remove)
