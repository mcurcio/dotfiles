# Obsidian Vault Conventions

## Suggested Vault Layout

Use this layout if the vault has no existing structure. Paths are relative to vault root.

| Folder | Purpose |
|--------|---------|
| `Inbox/` | Quick captures, unprocessed; move to other folders when processed |
| `Knowledge/` | Evergreen learnings, patterns, decisions (reference material) |
| `Cursor-Learnings/` | Session-specific captures; can merge into Knowledge later |
| `Projects/<name>/` | Notes for a specific project |
| `Areas/` | Ongoing responsibilities or themes (e.g., `Areas/backend/`) |
| `TODOs/` or `Tasks/` | TODO notes; e.g., `TODOs.md` or one file per area |

**Flow**: Capture → Inbox; then move or link into Knowledge, Projects, or Areas. Session captures can go to Cursor-Learnings/ or directly to Knowledge/ if evergreen.

Ask the user if the vault already has a different structure.

## Frontmatter Template

```yaml
---
date: YYYY-MM-DD
tags: [cursor, patterns, topic]
source: cursor
related-topics: [topic1, topic2]
---
```

| Field | Use |
|-------|-----|
| `date` | Capture date (YYYY-MM-DD) |
| `tags` | For search and organization |
| `source` | `cursor` when captured from a coding session |
| `related-topics` | Optional; for cross-linking |

## Note Naming

- Descriptive, lowercase, hyphens: `api-retry-pattern.md`, `auth-decision-log.md`
- Avoid generic names: `notes.md`, `misc.md`, `untitled.md`

## Obsidian MCP Tool Parameters

### search_notes
- `query` (required): search text
- `limit`: 5-20 (default 5)
- `searchContent`: true (search note bodies)
- `searchFrontmatter`: true (search tags/categories)

### write_note
- `path` (required): relative to vault root
- `content` (required): note body
- `frontmatter`: optional YAML object
- `mode`: `overwrite` | `append` | `prepend`

### patch_note
- `path`, `oldString`, `newString` (required)
- `replaceAll`: false (default) — fails if multiple matches

### update_frontmatter
- `path`, `frontmatter` (required)
- `merge`: true (default) — merges with existing frontmatter

### manage_tags
- `path` (required)
- `operation`: `add` | `remove` | `list`
- `tags`: array (required for add/remove)

### Other Tools
- `read_note` / `read_multiple_notes` — read note content
- `get_notes_info` — metadata only (no content)
- `move_note` — oldPath, newPath (organize/rename)
- `list_directory` — explore vault structure
- `get_vault_stats` — vault size, recent files (use sparingly)
