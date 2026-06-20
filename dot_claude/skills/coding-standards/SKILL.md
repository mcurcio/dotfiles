---
name: coding-standards
description: Use when writing or reviewing code in a language with a standard in ~/.claude/coding-standards/ (currently TypeScript). Loads portable conventions (type safety, enums, modules, naming, logging, errors, testing) and a reference linter config. A repo's own CODING_STANDARDS.md overrides these where they conflict.
---

# Coding Standards

Portable, language-organized coding standards. Read the relevant language file before writing or reviewing code in that language.

## Index

Read [`~/.claude/coding-standards/index.md`](~/.claude/coding-standards/index.md) for the full language map.

## TypeScript

- **Conventions:** read [`~/.claude/coding-standards/typescript/conventions.md`](~/.claude/coding-standards/typescript/conventions.md) — type safety (`no as any`), enums over string unions, `.js` import extensions, factory+interface over classes, `*Deps` injection, JSDoc on exports, structured logging, no swallowed errors, Vitest, Luxon timestamps.
- **Linting:** bootstrap from [`~/.claude/coding-standards/typescript/eslint.config.js`](~/.claude/coding-standards/typescript/eslint.config.js) — copy to the repo root and adjust the `files` globs.

## Precedence

A repo's own `CODING_STANDARDS.md` is the local source of truth and overrides these where they conflict.
