# ETUS package instructions: @etus/agent-ids

Inherit the root ETUS branding, security, and release rules.

## Scope

This package owns canonical persistent ID helpers and product placeholder logic.
Changes here can affect tests, suites, hooks, runs, observations, MCP tools, and
dashboard authoring surfaces.

## Read First

- `package.json`
- `src/index.ts`
- `src/persistent-id.ts`
- `src/product-placeholders.ts`
- `src/__tests__/persistent-id.test.ts`
- `src/__tests__/product-placeholders.test.ts`

## Commands

- Test: `pnpm --filter @etus/agent-ids test`
- Typecheck: `pnpm --filter @etus/agent-ids typecheck`
- Build: `pnpm --filter @etus/agent-ids build`

## Local Rules

- Never hand-write canonical persistent IDs in fixtures, tests, suites, hooks, or
  memory files.
- Preserve existing ID prefixes and validation behavior unless a plan explicitly
  defines a migration.
- Keep ID helpers deterministic and free of runtime service dependencies.
- Do not add dependencies unless they are required for ID generation or parsing.

## Verification

Run focused ID tests after any change:

```bash
pnpm --filter @etus/agent-ids test
pnpm --filter @etus/agent-ids typecheck
```
