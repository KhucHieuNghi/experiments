# ETUS package instructions: @etus/agent-qa-web

Inherit the root ETUS branding, security, and release rules.

## Scope

This package owns browser automation through Playwright, DOM extraction, action
validation, smart waits, scrolling helpers, farm adapters, screenshots, and
accessibility checks.

## Read First

- `package.json`
- `src/adapter.ts`
- `src/action-validator.ts`
- `src/dom-extractor.ts`
- `src/element-resolver.ts`
- `src/observer.ts`
- `src/accessibility.ts`
- Relevant `src/__tests__/*.test.ts`

## Commands

- Test: `pnpm --filter @etus/agent-qa-web test`
- Typecheck: `pnpm --filter @etus/agent-qa-web typecheck`
- Build: `pnpm --filter @etus/agent-qa-web build`

## Local Rules

- Preserve Playwright adapter contracts used by core, CLI, dashboard, and tests.
- Keep DOM extraction stable and avoid adding noisy page mutations.
- Maintain accessibility behavior through `@axe-core/playwright`.
- Browser install errors should stay actionable and user-facing.
- Screenshot and DOM payload changes must respect core compression and planner
  contracts.

## Verification

Run focused web tests after behavior changes:

```bash
pnpm --filter @etus/agent-qa-web test
pnpm --filter @etus/agent-qa-web typecheck
```
