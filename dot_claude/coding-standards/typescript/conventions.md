# TypeScript Conventions

> Portable reference for writing TypeScript. A repo's own `CODING_STANDARDS.md` (if present) is the local source of truth and overrides this where they conflict. Companion: `eslint.config.js` in this directory enforces most of these mechanically.

## Type safety

### No `as any`

`as any` is a severe violation. Define proper interfaces for all shapes. If a cast is truly unavoidable, use `// @ts-expect-error` with an explanation of why. Never silence the compiler without documenting the reason.

```typescript
// Do
const payload: IdlePayload = event.payload;

// Don't
const payload = event.payload as any;
```

### Strict mode, no loosening

`strict: true` belongs in the base/root tsconfig. No package or file may loosen it. Address type errors properly rather than weakening the type system.

### ts-expect-error over ts-ignore

`@ts-expect-error` with a description is the approved suppression mechanism — it self-removes when the underlying error is fixed. Never use `@ts-ignore` or `@ts-nocheck`.

## Enums

### Prefer `export enum` over string union types

Use standard `export enum` with PascalCase name and PascalCase members. Avoid `const enum` (incompatible with some bundlers and declaration emit) and avoid string union types for finite sets.

```typescript
// Do
export enum StopReason {
  Completed = 'completed',
  Failed = 'failed',
  Interrupted = 'interrupted',
}

// Don't — string union type for a finite set
export type State = 'created' | 'starting' | 'active' | 'idle';

// Don't — const enum
const enum State { Created = 'created' }
```

### Reference enum members, never the underlying string

The enum is the single source of truth. Hardcoding its values as strings defeats the purpose — typos won't be caught, renames won't propagate, and collection types weaken from `ReadonlySet<StopReason>` to `ReadonlySet<string>`. This applies to sets, maps, switch cases, and comparisons.

```typescript
// Do
const TERMINAL: ReadonlySet<StopReason> = new Set([
  StopReason.Completed,
  StopReason.Failed,
]);

// Don't
const TERMINAL: ReadonlySet<string> = new Set(['completed', 'failed']);
```

## Modules and imports

### Local imports include the `.js` extension

Required by Node16 module resolution. (Exception: Vite/bundler-targeted packages using `"moduleResolution": "bundler"` — no `.js` rule there.)

```typescript
// Do
import { State } from './types.js';

// Don't
import { State } from './types';
```

### Decorator metadata ordering

When `emitDecoratorMetadata: true` is enabled, a type referenced via a decorator (e.g. `@Type()` from class-transformer) must be **declared before** the referencing class in the same file — otherwise the emitted metadata resolves to `undefined` at runtime.

```typescript
// Do — referenced type declared first
export class TokenUsage { /* ... */ }

export class IdlePayload {
  @Type(() => TokenUsage)
  usage!: TokenUsage;
}
```

## Interfaces and composition

### Interface-first design

Define protocols and contracts before concrete implementations. Depend on interfaces, not classes.

```typescript
// Do
export interface Adapter {
  start(opts: StartOpts): Promise<Handle>;
}

// Don't — depend on a concrete class
import { ConcreteAdapter } from '@scope/concrete';
```

### Composition over inheritance

Prefer flat object composition over class hierarchies. Use interfaces to define contracts.

```typescript
// Don't — deep class hierarchies
class Base extends EventEmitter {}
class Derived extends Base {}
```

### Factory functions over classes

When a module exposes a single behavior surface, prefer a factory function returning an interface over a class.

```typescript
// Do
export function createClient(deps: ClientDeps): Client {
  const { logger } = deps;
  return {
    send(command, payload) { /* ... */ },
  };
}

// Don't — class when only one public surface exists
export class Client {
  constructor(private logger: Logger) {}
  send(command: string, payload: Record<string, unknown>) { /* ... */ }
}
```

### Dependency injection via constructor objects

All external dependencies are passed as a typed `*Deps` interface. Never reach into globals or singletons.

```typescript
export interface ClientDeps {
  readonly logger: Logger;
  readonly store: Store;
}
```

## Documentation

### JSDoc on every export

Every exported function, class, interface, and type must have a JSDoc docblock.

```typescript
/**
 * Persistent record for an entity. PK: id.
 */
export interface EntityRecord {
  /** Unique identifier. */
  id: string;
  /** Current lifecycle state. */
  state: State;
}
```

### Module-level doc comments

Every `.ts` file should open with a `@module` docblock explaining its purpose.

```typescript
/**
 * Control client for outbound WebSocket communication.
 *
 * Encapsulates all outbound control-plane events.
 *
 * @module control-client
 */
```

### Inline comments explain WHY, not WHAT

Only comment when the reasoning is non-obvious. Never restate what the code does.

```typescript
// Do — explains a non-obvious constraint
// INVARIANT: these three string sets must remain disjoint; the deserializer
// uses `type` to discriminate between the envelope variants.

// Don't — restates the code
// Create a new record
const r = store.create(record);
```

## Naming

| Context | Casing | Examples |
|---|---|---|
| Interfaces | PascalCase, `I` prefix | `IAdapter`, `IProtocolEvent` |
| Types, enums, classes | PascalCase | `EntityRecord`, `StopReason`, `ProtocolEventDto` |
| Enum members | PascalCase | `StopReason.Completed` |
| Functions, variables, methods, properties | camelCase | `createClient`, `entityId` |
| Compile-time constants | SCREAMING_SNAKE_CASE | true compile-time constants only, not runtime config |

### Interfaces use an `I` prefix

Name interfaces `IAdapter`, `IProtocolEvent` — the prefix marks the abstraction at every use site. A class `implements` an interface; it never serves as the de-facto contract. Consumers depend on (and import as a type) the interface, not the class. When a class carries runtime machinery an interface can't (decorators, validation), it still `implements` the interface and callers still depend on the interface. Enforce with `@typescript-eslint/naming-convention` (`selector: interface, prefix: ['I']`).

### Names reflect purpose, not technology

```
Do:    EventBus, EntityManifest, ControlClient
Don't: KinesisEventBus, RedisEventBus
```

## State machines

### Separate FSMs for separate lifecycle domains

Distinct lifecycle domains are never conflated into a single state machine. Each domain has its own states, transitions, and terminal conditions.

### Pure transition functions

State transition validators are pure functions with no side effects — they validate that a transition is legal and nothing more.

```typescript
// Do
function assertTransition(from: State, to: State): void { /* ... */ }

// Don't — side effect in a validator
function transition(from: State, to: State): void {
  store.update(id, to);
}
```

### Terminal state sets

Define terminal states as `ReadonlySet` constants for O(1) lookup.

```typescript
export const TERMINAL_STATES: ReadonlySet<State> =
  new Set([State.Completed, State.Failed, State.Canceled]);
```

## Logging

### Structured logger only — no `console.*`

No `console.log` / `console.error` / `console.warn`. Route all logging through a structured logger (e.g. pino). Core interfaces accept a `logger: Logger`.

```typescript
// Do
logger.info({ entityId, childId }, 'child started');
logger.error({ err, entityId }, 'failed to start child');

// Don't
console.log('child started:', entityId);
```

### Pass context objects as the first argument

```typescript
// Do
logger.info({ entityId, state, priorState }, 'state changed');

// Don't — string interpolation
logger.info(`entity ${entityId} changed from ${priorState} to ${state}`);
```

## Error handling

### Custom error classes

Define domain-specific error classes for typed catch blocks and structured handling.

```typescript
export class InvalidTransitionError extends Error {
  constructor(from: State, to: State) {
    super(`Invalid transition: ${from} -> ${to}`);
    this.name = 'InvalidTransitionError';
  }
}
```

### No swallowed errors

Every `catch` must either log the error or re-throw it. Silent and empty catch blocks are forbidden.

```typescript
// Do
try { /* ... */ } catch (err) {
  logger.error({ err, entityId }, 'operation failed');
  throw err;
}

// Don't
try { /* ... */ } catch (err) { /* silently ignored */ }
```

### Normalized error shapes

Transports (REST, WebSocket) share the same error-shape foundation. Don't invent a separate error format per transport.

## Testing

Use **Vitest**.

- **Naming:** `*.test.ts` or `*.spec.ts`, co-located with source.
- **Bug fixes are TDD:** first write a test that reproduces the bug — it must fail before the fix and pass after.
- **Test behavior, not implementation.**

## Scripts

### `npm run` scripts only — never bare `npx`

All build, test, and dev commands must be runnable via `npm run <script>` (or `npm test` / `npm start`). Wrap tool invocations in `package.json` scripts rather than calling `npx tsc` / `npx vitest` directly in docs or CI.

```jsonc
// package.json
{
  "scripts": {
    "build": "tsc -p tsconfig.build.json",
    "test": "vitest run",
    "lint": "eslint ."
  }
}
```

## Architecture

### Dependencies flow strictly downward

Never upward, never sideways between layers. A leaf module must never import from a composition root or a sibling at the same layer.

### Idempotency by default

Polling, merging, and state updates should be idempotent. `start()` / `stop()` lifecycle methods must be idempotent. A transition already at the target state is a no-op.

### Security is architectural

Least-privilege, trust models, and authorization are baked into the design — not bolted on as middleware. Policy/authorization logic that can be pure should be pure (no dependencies).

## Timestamps and durations

Use Luxon for timestamps and durations in new code.

- **Instants:** `DateTime.utc().toISO()` for storage; `DateTime.fromISO(str, { zone: 'utc' })` to parse.
- **Durations:** `Duration.fromObject({ minutes: 5 })` — never raw `number` milliseconds.
- **Conversion:** `duration.toMillis()` when calling Node APIs (`setTimeout`) that require ms.
- **Anti-pattern:** variables named `*Ms` / `*Timeout` / `*Delay` typed as bare `number` in new modules.

## Anti-pattern summary

| Anti-pattern | Correct alternative |
|---|---|
| `as any` | Define a proper interface, or `// @ts-expect-error` with explanation |
| `export type Foo = 'a' \| 'b'` for finite sets | `export enum Foo { A = 'a', B = 'b' }` |
| `const enum` | Standard `export enum` |
| `console.log` / `console.error` | Structured logger (pino) |
| Imports without `.js` extension | Include `.js` for local imports (Node16) |
| Class where a factory + interface suffices | `createX(deps): XInterface` |
| Conflating lifecycle domains into one FSM | Separate state machines per domain |
| Technology-derived naming (`KinesisEventBus`) | Purpose-derived naming (`EventBus`) |
| Deep class hierarchies | Flat composition via interfaces |
| Singletons / global state | Dependency injection via `*Deps` interfaces |
| Silent / empty catch blocks | Log or re-throw in every catch |
| Hardcoded enum value strings | Use enum members |
| `@ts-ignore` | `@ts-expect-error` with a description |
