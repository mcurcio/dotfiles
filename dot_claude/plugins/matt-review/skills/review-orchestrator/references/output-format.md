# Output Format Specification

Two presentation modes. The depth of analysis is the same regardless of mode — only the presentation changes.

## Brief Mode (Default)

Use when presenting to an engineer in the terminal. One numbered line per finding. Scannable.

```
### Unified Review: <title>

**Verdict: APPROVE | REQUEST_CHANGES | COMMENT_ONLY**
<1-2 sentence rationale>

#### Summary
1. <intent>
2. <key risk or finding>
3. ...

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

### Brief mode rules
- Each note is ONE line (two max for genuinely complex items).
- Evidence is inline after the title, not a separate field.
- No separate "Why it matters" or "Comment" sections — fold both into the description.
- Summary bullets are numbered.
- Omit empty groups.

## Structured Mode

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
  - **Why it matters**: <impact on correctness / design / readability / testability / safety / ops>
  - **Comment**: <question-first phrasing; propose alternative when appropriate>

#### Fix before merge
F1. **<title>**
  - **Evidence**: ...
  - **Why it matters**: ...
  - **Comment**: ...

#### Suggestions
S1. ...

#### Nits
N1. ...

#### What's good
G1. ...
```

## Shared Rules (Both Modes)

- Question-first tone for ambiguity.
- `Nit:` prefix for purely stylistic feedback.
- Every note must cite evidence (code: `<path>:<line>`; doc: `<doc> — <section>`). If evidence is unavailable, ask rather than speculate.
- Number each item: Q1, F1, S1, N1, G1, etc.
- Prefer one strong note over multiple weak ones.
- Omit empty groups.

## Merge Strategy (Avoid Duplicate Findings)

When merging findings from multiple agents:
- Design note when the fix requires a decision or contract change.
- Code note when the fix is patch-level and localized.
- Deduplicate across lenses — prefer the most actionable framing.
