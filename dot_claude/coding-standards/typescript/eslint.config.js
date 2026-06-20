// @ts-check
//
// Portable ESLint flat-config reference enforcing the TypeScript conventions in
// ./conventions.md. Copy into a repo root as `eslint.config.js` and adjust the
// `files` globs to match the project layout. Requires:
//
//   npm i -D eslint typescript-eslint
//
// and `eslint` wired into package.json (`"lint": "eslint ."`) — never bare npx.
//
// Type-checked rules require a tsconfig reachable via `projectService`.

import tseslint from 'typescript-eslint';

export default tseslint.config(
  // -----------------------------------------------------------------------
  // Global ignores — only lint TS sources, not compiled output
  // -----------------------------------------------------------------------
  {
    ignores: [
      '**/dist/**',
      '**/node_modules/**',
      '**/*.js',        // compiled output
      '**/*.d.ts',
      '**/coverage/**',
    ],
  },

  // -----------------------------------------------------------------------
  // All TypeScript source files
  // Adjust these globs to the repo: e.g. ['src/**/*.ts'] for a single package,
  // ['packages/*/src/**/*.ts', 'test/**/*.ts'] for a monorepo.
  // -----------------------------------------------------------------------
  {
    files: ['src/**/*.ts', 'packages/*/src/**/*.ts', 'test/**/*.ts'],
    extends: [
      ...tseslint.configs.recommendedTypeChecked,
    ],
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // ---- Promise discipline ----
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/await-thenable': 'error',
      '@typescript-eslint/no-misused-promises': 'error',

      // ---- Type safety (conventions.md: no `as any`) ----
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unsafe-assignment': 'error',
      '@typescript-eslint/no-unsafe-call': 'error',
      '@typescript-eslint/no-unsafe-member-access': 'error',
      '@typescript-eslint/no-unsafe-return': 'error',
      '@typescript-eslint/no-unsafe-argument': 'error',

      // ---- Console (conventions.md: structured logger only) ----
      'no-console': 'error',

      // ---- Unused variables (underscore-prefix opt-out) ----
      '@typescript-eslint/no-unused-vars': ['error', {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
      }],

      // ---- Consistency ----
      '@typescript-eslint/consistent-type-imports': ['error', {
        prefer: 'type-imports',
        fixStyle: 'inline-type-imports',
      }],
      '@typescript-eslint/consistent-type-assertions': ['error', {
        assertionStyle: 'as',
        objectLiteralTypeAssertions: 'never',
      }],

      // ---- Enum safety ----
      // Catches comparing enum-typed vars to raw string literals
      '@typescript-eslint/no-unsafe-enum-comparison': 'error',
      // Forces exhaustive switch on enums
      '@typescript-eslint/switch-exhaustiveness-check': 'error',

      // ---- Type assertion safety ----
      '@typescript-eslint/no-unsafe-type-assertion': 'error',

      // ---- Non-null assertion warnings ----
      '@typescript-eslint/no-non-null-assertion': 'warn',

      // ---- Empty functions: warn (some best-effort teardown is intentionally empty) ----
      '@typescript-eslint/no-empty-function': 'warn',

      // ts-expect-error is the approved suppression mechanism (not @ts-ignore)
      '@typescript-eslint/prefer-ts-expect-error': 'error',
      '@typescript-eslint/ban-ts-comment': ['error', {
        'ts-expect-error': 'allow-with-description',
        'ts-ignore': true,
        'ts-nocheck': true,
      }],
    },
  },

  // -----------------------------------------------------------------------
  // OPTIONAL — project-specific syntax bans.
  // Uncomment and adapt. The string-union ban and empty-.catch() ban are
  // broadly useful; the protocol-enum literal ban is an example of catching
  // hardcoded method strings that should reference a shared enum module.
  // -----------------------------------------------------------------------
  // {
  //   files: ['src/**/*.ts', 'packages/*/src/**/*.ts'],
  //   ignores: ['**/*.spec.ts', '**/*.test.ts'],
  //   rules: {
  //     'no-restricted-syntax': ['error',
  //       {
  //         // Adapt the regex + message to the project's enum namespace.
  //         selector: "Literal[value=/^(domain|entity|event)\\.[a-z_]+$/]",
  //         message: 'Use a shared enum instead of a hardcoded method string. See conventions.md § Enums.',
  //       },
  //       {
  //         selector: "CallExpression[callee.property.name='catch'] > ArrowFunctionExpression[body.type='BlockStatement'][body.body.length=0]",
  //         message: 'Empty .catch() blocks swallow errors silently. Log the error or add an eslint-disable with justification.',
  //       },
  //       {
  //         selector: "TSTypeAliasDeclaration[typeAnnotation.type='TSUnionType'] > TSUnionType > TSLiteralType",
  //         message: 'Prefer an enum over a string union type. See conventions.md § Enums.',
  //       },
  //     ],
  //   },
  // },

  // -----------------------------------------------------------------------
  // Test files — relax unsafe rules (mocks, fixtures use broad types)
  // -----------------------------------------------------------------------
  {
    files: ['**/*.spec.ts', '**/*.test.ts', 'test/**/*.ts', '**/src/test/**/*.ts'],
    rules: {
      '@typescript-eslint/no-unsafe-assignment': 'off',
      '@typescript-eslint/no-unsafe-call': 'off',
      '@typescript-eslint/no-unsafe-member-access': 'off',
      '@typescript-eslint/no-unsafe-return': 'off',
      '@typescript-eslint/no-unsafe-argument': 'off',
      '@typescript-eslint/no-explicit-any': 'warn',
      // Vitest's expect(spy).toHaveBeenCalled() pattern triggers unbound-method — false positive
      '@typescript-eslint/unbound-method': 'off',
      '@typescript-eslint/no-unsafe-type-assertion': 'off',
      // Test fixtures frequently build partial objects and cast them — e.g. `{} as Entity`
      '@typescript-eslint/consistent-type-assertions': 'off',
    },
  },
);
