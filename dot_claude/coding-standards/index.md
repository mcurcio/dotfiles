# Coding Standards

Portable, language-organized coding standards — reference material for any repo. A repo's own `CODING_STANDARDS.md` is the local source of truth and overrides these where they conflict.

Each language gets a directory containing a top-level conventions doc plus any language-specific assets (linter configs, formatters).

## Languages

| Language | Conventions | Assets |
|---|---|---|
| TypeScript | [typescript/conventions.md](typescript/conventions.md) | [typescript/eslint.config.js](typescript/eslint.config.js) — portable flat-config |

## When to use

- **Writing/reviewing TypeScript** → read `typescript/conventions.md`. Bootstrap linting from `typescript/eslint.config.js` (adjust `files` globs to the repo).
- **Adding a language** → create `<language>/conventions.md`, add any linter config alongside it, and add a row above.

## Layout

```
coding-standards/
  index.md                  # this file
  typescript/
    conventions.md          # type safety, enums, modules, naming, logging, errors, testing
    eslint.config.js        # typescript-eslint flat config enforcing conventions.md
```
