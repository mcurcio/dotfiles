---
name: review-orchestrator
description: Produce a single cohesive review by orchestrating both design-review and code-review lenses. Use when the user asks for a comprehensive PR review, a "design + code" review, pre-PR validation, or review notes that cover architecture and implementation together. Supports two output modes — "brief" (default, concise for experienced engineers in Cursor) and "structured" (full evidence/why/comment for PR comments and tool integration). Decide whether to run design review, code review, or both based on the artifacts provided (PR/diff vs ADR/RFC/proposal). Output one unified Verdict and grouped, numbered, evidence-backed notes.
---

# Review orchestrator (design + code)

## Goal
Produce one set of review notes covering:
- **Design intent & architecture** (tradeoffs, boundaries, invariants, rollout)
- **Implementation quality** (correctness, readability, tests, docs, safety)

## Routing rules
- **PR/diff/branch**: Full code review. Add design review if the change introduces new modules/services, domain concepts, patterns, or affects cross-cutting concerns (auth, data model, infra, rollout).
- **Design doc/proposal/ADR/RFC**: Design review only. Don't invent code-level critiques.
- **Both**: Both lenses, merged without duplication.

## Analysis process
Always perform the full analysis using the code-review and design-review checklists (priority-ordered). Walk through every checklist item internally. The depth of analysis is the same regardless of output mode — only the presentation changes.

## Output modes

### Brief mode (default)
Use when presenting to an engineer in Cursor. One numbered line per finding. Scannable.

```
### Unified Review: <title>

**Verdict: APPROVE | REQUEST_CHANGES | COMMENT_ONLY**
<1-2 sentence rationale>

#### Summary
1. <intent>
2. <key risk or finding>
3. …

#### Questions
Q1. **<title>** — `<evidence>` — <pointed question>

#### Fix before merge
F1. **<title>** — `<evidence>` — <what's wrong + what to do>

#### Suggestions
S1. **<title>** — `<evidence>` — <proposed improvement>

#### Nits
N1. **<title>** — `<evidence>` — Nit: <observation>

#### What's good
G1. <concise praise>
```

Brief mode rules:
- Each note is ONE line (two max for genuinely complex items).
- Evidence is inline after the title, not a separate field.
- No separate "Why it matters" or "Comment" sections — fold both into the description.
- Summary bullets are numbered.
- Omit empty groups.

### Structured mode
Use when output will feed into tools: PR review comments, Jira tickets, automated pipelines. Triggered when the user says "structured review", "for PR comments", "for a PR", or "detailed review".

```
### Unified Review: <title>

### 1) Executive summary
- <3-6 bullets: intent, risk areas, top findings>

### 2) Verdict
Verdict: APPROVE | REQUEST_CHANGES | COMMENT_ONLY
<1-2 sentences>

### 3) Notes

#### Questions
Q1. **<title>**
  - **Evidence**: `<path>:<line>` or `<doc> — <section>` — "<quote>"
  - **Why it matters**: <impact>
  - **Comment**: <question-first phrasing; propose alternative>

#### Fix before merge
F1. **<title>**
  - **Evidence**: …
  - **Why it matters**: …
  - **Comment**: …

#### Suggestions
S1. …

#### Nits
N1. …

#### What's good
G1. …
```

## Shared rules (both modes)
- Question-first tone for ambiguity.
- `Nit:` prefix for purely stylistic feedback.
- Every note must cite evidence (code: `<path>:<line>`; doc: `<doc> — <section>`). If evidence is unavailable, ask rather than speculate.
- Number each item: Q1, F1, S1, N1, G1, etc.
- Prefer one strong note over multiple weak ones.
- Omit empty groups.

## Merge strategy (avoid duplicate comments)
- Design note when the fix requires a decision or contract change.
- Code note when the fix is patch-level and localized.
- Deduplicate across lenses — prefer the most actionable framing.
