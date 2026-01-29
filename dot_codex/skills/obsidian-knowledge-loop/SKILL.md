---
name: obsidian-knowledge-loop
description: Enriches agent context with Obsidian vault knowledge and captures learnings from Cursor interactions back into Obsidian. Uses Obsidian MCP to search, read, and write notes. Use when the user mentions Obsidian, notes, knowledge base, "check my notes", "what do I have on X", "add this to my notes", "remember this", or when starting tasks that may benefit from prior documented knowledge.
---

# Obsidian Knowledge Loop

Integrates with the user's Obsidian vault via MCP to (1) **enrich** agent context with existing notes and (2) **capture** learnings from Cursor interactions into Obsidian. All paths are relative to the vault root.

## 1. Enrichment: Fetch Obsidian Knowledge

When the user's task could benefit from prior knowledge, search and read relevant notes **before** answering or implementing.

### When to Enrich

| Trigger | Action |
|---------|--------|
| User says "check my notes", "what do I have on X", "look in Obsidian" | Search and read immediately |
| User asks about a topic, project, or concept | Search first; if relevant notes exist, read and incorporate |
| Starting implementation, design, or debugging | Search for related notes (e.g. architecture, decisions, past solutions) |
| User mentions a specific note or folder | Read that note (and related ones if useful) |

### Enrichment Workflow

1. **Search** using `search_notes` (Obsidian MCP):
   - `query`: key terms from the task (topic, project name, concept, error message)
   - `limit`: 5–10; avoid context bloat
   - `searchContent`: true (default)
   - `searchFrontmatter`: true when looking for tagged or categorized notes

2. **Read** using `read_note` or `read_multiple_notes`:
   - Use `read_multiple_notes` when several search results are relevant (max 10)
   - Use `read_note` for a single known path

3. **Incorporate** findings into your response or implementation. Cite note paths when referencing them.

### Optional: Scope Check

For broad tasks, use `get_vault_stats` to understand vault size and `list_directory` to explore structure. Use sparingly to save tokens.

---

## 2. Learning: Capture to Obsidian

When significant knowledge emerges from the conversation, **propose or perform** updates to Obsidian.

### When to Capture

| Trigger | Action |
|---------|--------|
| User says "add this to my notes", "remember this", "save this" | Capture immediately |
| User says "update my notes", "add to knowledge base" | Search for related notes, then add or update |
| Task completion with new decisions, patterns, or solutions | Proactively offer: "Would you like me to add this to your Obsidian?" |
| User shares a reusable insight, convention, or lesson | Offer to capture |

### Learning Workflow

1. **Search before writing** to avoid duplicates:
   - Use `search_notes` with the topic or key terms
   - If a strong match exists: use `patch_note` or `update_frontmatter` to augment
   - If no match: use `write_note` for new content

2. **Choose the right tool**:
   - **New note**: `write_note` with `path`, `content`, optional `frontmatter`
   - **Small update**: `patch_note` with `oldString` → `newString`
   - **Metadata only**: `update_frontmatter` (merge: true)
   - **Tags**: `manage_tags` with operation `add`

3. **Conventions** (see [reference.md](reference.md) for details):
   - Default folder: `Knowledge/` or `Cursor-Learnings/` (user may override)
   - Frontmatter: `date`, `tags`, `source: cursor`, `related-topics`
   - Filename: descriptive, lowercase, hyphens (e.g. `api-retry-pattern.md`)

4. **Confirm** with the user before writing when the change is substantial. For quick adds (single bullet, tag), proceed and summarize.

---

## 3. Tool Reference (Obsidian MCP)

| Tool | Use |
|------|-----|
| `search_notes` | Find notes by content or frontmatter; limit 5–20 |
| `read_note` | Read one note by path |
| `read_multiple_notes` | Read up to 10 notes by path array |
| `write_note` | Create or overwrite; modes: overwrite, append, prepend |
| `patch_note` | Replace a specific string (efficient for small edits) |
| `update_frontmatter` | Update YAML frontmatter without touching content |
| `manage_tags` | Add, remove, or list tags |
| `get_notes_info` | Metadata only (no content) |
| `get_vault_stats` | Vault size, recent files |
| `list_directory` | List vault folders/files |

Use the Obsidian MCP tools when the vault is configured. Tool names match exactly.

---

## 4. Continuous Learning (Within Session)

Cursor does not persist conversation history across sessions. "Continuous learning" works **within the current conversation**:

- **Proactive offers**: After completing a task with reusable knowledge, offer: "I can add this to your Obsidian knowledge base if you'd like."
- **End-of-session habit**: When the user wraps up, ask: "Should I capture any learnings from this session to Obsidian?"
- **Explicit capture**: When the user says "remember this" or "add to notes", capture immediately.

For cross-session learning, the user can manually trigger capture at session end or rely on the habit above.

---

## 5. Anti-Patterns

- **Don't** read the entire vault; use targeted search.
- **Don't** write without searching first when adding new knowledge.
- **Don't** overwrite existing notes without user confirmation for large changes.
- **Do** keep captured notes concise; link to code or docs when possible.
- **Do** use `patch_note` for small edits instead of rewriting whole notes.
