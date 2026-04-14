---
name: obsidian-knowledge-loop
description: This skill should be used when the user mentions "Obsidian", "my notes", "knowledge base", "check my notes", "what do I have on X", "add this to my notes", "remember this", "save this to Obsidian", "update my notes", or when starting tasks that may benefit from prior documented knowledge in the Obsidian vault. Enriches agent context with vault knowledge and captures learnings back into Obsidian via MCP.
---

# Obsidian Knowledge Loop

Integrate with the user's Obsidian vault via MCP to (1) enrich agent context with existing notes and (2) capture learnings back into Obsidian. All paths are relative to the vault root.

## 1. Enrichment: Fetch Obsidian Knowledge

When the current task could benefit from prior knowledge, search and read relevant notes before answering or implementing.

### When to Enrich

| Trigger | Action |
|---------|--------|
| "Check my notes", "what do I have on X", "look in Obsidian" | Search and read immediately |
| User asks about a topic, project, or concept | Search first; incorporate if relevant |
| Starting implementation, design, or debugging | Search for related notes (architecture, decisions, past solutions) |
| User mentions a specific note or folder | Read that note directly |

### Enrichment Workflow

1. **Search** using `search_notes` (Obsidian MCP):
   - `query`: key terms from the task (topic, project name, concept, error message)
   - `limit`: 5-10 (avoid context bloat)
   - `searchContent`: true
   - `searchFrontmatter`: true when looking for tagged or categorized notes

2. **Read** using `read_note` or `read_multiple_notes`:
   - `read_multiple_notes` when several search results are relevant (max 10)
   - `read_note` for a single known path

3. **Incorporate** findings into the response or implementation. Cite note paths when referencing them.

4. **Scope check** (optional): use `get_vault_stats` to understand vault size, `list_directory` to explore structure. Use sparingly.

## 2. Capture: Write to Obsidian

When significant knowledge emerges from the conversation, propose or perform updates.

### When to Capture

| Trigger | Action |
|---------|--------|
| "Add this to my notes", "remember this", "save this" | Capture immediately |
| "Update my notes", "add to knowledge base" | Search for related notes, then add or update |
| Task completion with new decisions, patterns, or solutions | Offer: "Want me to add this to Obsidian?" |
| User shares a reusable insight or convention | Offer to capture |

### Capture Workflow

1. **Search before writing** to avoid duplicates:
   - Use `search_notes` with topic or key terms
   - Strong match exists → use `patch_note` or `update_frontmatter` to augment
   - No match → use `write_note` for new content

2. **Choose the right tool**:
   - **New note**: `write_note` with path, content, optional frontmatter
   - **Small update**: `patch_note` with oldString → newString
   - **Metadata only**: `update_frontmatter` (merge: true)
   - **Tags**: `manage_tags` with operation: add

3. **Follow conventions** from `references/vault-conventions.md`:
   - Default folders: Knowledge/, Cursor-Learnings/, Projects/<name>/
   - Frontmatter: date, tags, source: cursor, related-topics
   - Filenames: descriptive, lowercase, hyphens

4. **Confirm** with the user before writing substantial changes. For quick adds (single bullet, tag), proceed and summarize.

## 3. Continuous Learning (Within Session)

- **Proactive offers**: after completing a task with reusable knowledge, offer to capture.
- **End-of-session**: "Should I capture any learnings from this session to Obsidian?"
- **Explicit capture**: when the user says "remember this", capture immediately.

## 4. Anti-Patterns

- Do not read the entire vault; use targeted search.
- Do not write without searching first when adding new knowledge.
- Do not overwrite large existing notes without user confirmation.
- Keep captured notes concise; link to code or docs when possible.
- Use `patch_note` for small edits instead of rewriting whole notes.

## Additional Resources

- **`references/vault-conventions.md`** — Vault layout, frontmatter template, naming conventions, and MCP tool parameters
