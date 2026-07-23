# ETUS — Contributor Guide

> Development workflow, conventions, testing expectations, and package-specific rules for contributors.

---

## Table of Contents

1. [Development Setup](#1-development-setup)
2. [Workflow](#2-workflow)
3. [Code Style & Conventions](#3-code-style--conventions)
4. [Testing](#4-testing)
5. [Package-Specific Rules](#5-package-specific-rules)
6. [Branding](#6-branding)
7. [Security Practices](#7-security-practices)
8. [Pull Request Process](#8-pull-request-process)
9. [Common Tasks](#9-common-tasks)
10. [Architecture Decision Records](#10-architecture-decision-records)

---

## 1. Development Setup

### Prerequisites

```bash
node --version   # >= 24
pnpm --version   # 10.6.x (managed by corepack)
docker --version # For hook sandbox testing
```

### First-Time Setup

```bash
git clone <repo-url>
cd etus-agent

# Enable corepack for pnpm version management
corepack enable

# Install dependencies
pnpm install

# Build all packages (required before tests)
pnpm build

# Verify everything works
pnpm typecheck
pnpm test
```

### IDE Setup

- TypeScript: Use workspace TypeScript version (6.0+)
- Formatter: Prettier with project `.prettierrc`
- ESM: All packages use NodeNext module resolution

---


## 2. Workflow

### Daily Development Cycle

```
1. Work on a package        → Edit source in packages/<name>/src/
2. Build affected packages  → pnpm --filter <pkg> build
3. Run package tests        → pnpm --filter <pkg> test
4. Typecheck                → pnpm --filter <pkg> typecheck
5. Repeat until done
```

### Commands Reference

| Task | Command | When to Use |
|------|---------|-------------|
| Install deps | `pnpm install` | After pull, after changing package.json |
| Build all | `pnpm build` | First time, cross-package changes |
| Build one | `pnpm --filter <pkg> build` | Single-package iteration |
| Test all | `pnpm test` | Before PR, cross-package changes |
| Test one | `pnpm --filter <pkg> test` | Package-scoped changes |
| Typecheck all | `pnpm typecheck` | Before PR |
| Typecheck one | `pnpm --filter <pkg> typecheck` | During development |
| Validate skills | `pnpm run validate:skills` | After editing `skills/` |
| Validate publish | `pnpm run validate:publish` | Before release-facing changes |
| Namespace lint | `pnpm run lint:namespace` | After adding cross-package imports |
| Dev mode | `pnpm dev` | Watch + rebuild all packages |

### Build Order (Turbo-managed)

Turbo respects the dependency graph:
```
ids → core → web/android/ios/mcp → dashboard-server → dashboard-ui → cli
```

Each package's `build` task depends on `^build` (its dependencies must build first).

---

## 3. Code Style & Conventions

### Prettier Config (`.prettierrc`)

```json
{
  "semi": false,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100
}
```

### TypeScript

- **Strict mode** enabled everywhere
- **Module system:** NodeNext ESM (`"type": "module"` in all package.json)
- **File extensions:** Always use `.js` in import paths (TypeScript resolves `.ts` → `.js`)
- **No default exports:** Prefer named exports for discoverability
- **Zod for runtime validation:** All external inputs (config, YAML files, API payloads) validated with Zod schemas

### Naming Conventions

| Kind | Convention | Example |
|------|-----------|---------|
| Files | kebab-case | `file-cache.ts`, `auth-resolver.ts` |
| Classes | PascalCase | `LLMPlanner`, `FileActionCache` |
| Interfaces | PascalCase | `PlatformAdapter`, `Planner` |
| Functions | camelCase | `runTest`, `resolveConfig` |
| Constants | UPPER_SNAKE | `DEFAULT_DOCKER_BIN`, `ENV_MAPPING` |
| Zod schemas | PascalCase + Schema | `AgentQaConfigSchema`, `TestDefinitionSchema` |
| Types from Zod | PascalCase (inferred) | `type AgentQaConfig = z.infer<typeof AgentQaConfigSchema>` |
| Test files | `*.test.ts` | `runner.test.ts`, `config-schema.test.ts` |
| Package names | `@etus/agent-*` | `@etus/agent-core` |
| MCP tools | `etus_agent_*` (snake_case) | `etus_agent_run_test` |
| Env vars | `ETUS_AGENT_*` (UPPER_SNAKE) | `ETUS_AGENT_DASHBOARD_PORT` |

### Module Boundaries

- Do not add cross-package imports unless the target package is already a declared dependency
- Use the public export surface (package `index.ts`) — never deep-import internal modules
- Avoid circular dependencies between packages

---


## 4. Testing

### Framework

- **Test runner:** Vitest 4.1
- **Assertion:** Vitest built-in (`expect`)
- **Mocking:** Vitest built-in (`vi.mock`, `vi.fn`)
- **Test mode:** `vitest --run` (single-run, not watch mode)

### Test File Placement

```
packages/<name>/
  src/
    __tests__/           ← Unit tests (mirrors src structure)
      module.test.ts
    feature/
      __tests__/         ← Feature-scoped tests
        feature.test.ts
```

### Testing Rules

1. **Add or update tests for every change.** No exceptions.
2. **Test the package you changed.** Use focused package tests during iteration.
3. **Mock external dependencies.** LLM calls, filesystem, Docker — always mocked in unit tests.
4. **Test schemas independently.** Zod schema validation has its own test suites.
5. **Integration tests live in `__tests__/integration.test.ts`** and may run longer.

### Running Tests per Package

```bash
# Core runtime/schema changes
pnpm --filter @etus/agent-core test

# Web adapter changes
pnpm --filter @etus/agent-web test

# Android adapter changes
pnpm --filter @etus/agent-android test

# iOS adapter changes
pnpm --filter @etus/agent-ios test

# MCP server changes
pnpm --filter @etus/agent-mcp test

# Dashboard server changes
pnpm --filter @etus/agent-dashboard test

# Dashboard UI changes
pnpm --filter @etus/agent-dashboard-ui test

# CLI changes
pnpm --filter etus-agent test

# IDs package changes
pnpm --filter @etus/agent-ids test
```

### Test Patterns

```typescript
// Example: testing a schema
import { describe, it, expect } from 'vitest'
import { TestDefinitionSchema } from '../schema/test-schema.js'

describe('TestDefinitionSchema', () => {
  it('accepts a valid test definition', () => {
    const result = TestDefinitionSchema.safeParse({
      'test-id': 't_alpha-bravo-charlie-delta-echo-foxtrot-golf-hotel-india-juliet',
      name: 'Login test',
      steps: ['Navigate to login', 'Enter credentials', 'Click sign in'],
    })
    expect(result.success).toBe(true)
  })

  it('rejects missing test-id', () => {
    const result = TestDefinitionSchema.safeParse({
      name: 'Login test',
      steps: ['Step 1'],
    })
    expect(result.success).toBe(false)
  })
})
```

```typescript
// Example: testing an adapter method with mocks
import { describe, it, expect, vi } from 'vitest'

describe('WebPlatformAdapter', () => {
  it('returns screen state on observe', async () => {
    const mockPage = {
      evaluate: vi.fn().mockResolvedValue('<html>...</html>'),
      url: vi.fn().mockReturnValue('https://example.com'),
    }
    // ... test adapter.observe() with mocked page
  })
})
```

---


## 5. Package-Specific Rules

### `@etus/agent-ids`

- Zero runtime dependencies — keep it that way
- ID format: 10-word canonical IDs with prefix (`t_`, `s_`, `h_`, `obs_`, `r_`)
- Never hand-write IDs — always use generator functions
- Validation functions must be pure and synchronous

### `@etus/agent-core`

- **The contract package.** All interfaces consumed by other packages live here.
- Schema changes affect the entire monorepo — run full `pnpm typecheck` + `pnpm test`
- Do not add platform-specific code (Playwright, WebdriverIO) here
- Prefer extending existing schemas over creating new ones
- The tool registry is the single source of truth for action definitions

### `@etus/agent-web`

- Depends on Playwright — all Playwright APIs accessed through the adapter
- DOM extraction must handle shadow DOM and custom elements
- Smart waits are critical — changes here affect test stability
- Action validator prevents impossible actions (fill on non-input, etc.)
- Accessibility checks are optional per step — gated by config

### `@etus/agent-android` / `@etus/agent-ios`

- Depends on WebdriverIO — all Appium operations through the adapter
- Session management is complex (capabilities, farm support, context switching)
- Test native gesture handling carefully — coordinates matter
- iOS has pixel-to-point conversion for Retina displays

### `@etus/agent-mcp`

- All tool names use `etus_agent_*` prefix (snake_case)
- Tools delegate to dashboard API — do not implement execution logic here
- Validate all inputs with Zod before forwarding
- Both stdio and HTTP transports must be tested
- Analytics events fire for every tool invocation

### `@etus/agent-dashboard` (server)

- Raw Node.js HTTP server — no framework
- SQLite is the only persistence — no external databases
- All endpoints must be loopback-only by default
- WebSocket is only used for live editor sessions
- Job queue must handle graceful shutdown and orphan cleanup

### `@etus/agent-dashboard-ui`

- React 19 + Vite — standard SPA architecture
- TailwindCSS 4 for styling — no CSS modules
- Radix UI for accessible primitive components
- Monaco Editor for YAML editing — lazy loaded
- Publishes built assets only (no library entry point)
- Uses same-origin `/api/*` routes (no CORS in normal operation)

### `etus-agent` (CLI)

- The only package with a `bin` entry — owns the public `etus-agent` command
- Commander.js for command registration
- Config resolution (3-layer merge) is the most complex area
- Skills from `skills/` are packaged into this package at publish time
- Must pass `pnpm run validate:skills` before release

---

## 6. Branding

### Product Name

- **Always use:** `ETUS` in prose, documentation, UI copy, descriptions
- **Never use:** `Agent QA`, `AgentQA`, `AGENTQA`, `agentqa`

### Technical Identifiers (compatibility, do not rename)

These exist for backward compatibility and must not change without a migration:

| Kind | Format |
|------|--------|
| CLI command | `etus-agent` |
| Config file | `etus-agent.config.yaml` |
| Local override | `etus-agent.local.yaml` |
| Runtime directory | `.etus-agent/` |
| npm packages | `@etus/agent-*` |
| Docker images | `etus/etus-agent-*` |
| MCP tools | `etus_agent_*` |
| Env vars | `ETUS_AGENT_*` |

### TypeScript Names

- Preferred: `AgentQaConfig`, `AgentQaConfigSchema`
- Do not add no-separator aliases (`AgentQAConfig`, `agentqaConfig`)

---


## 7. Security Practices

### Never Commit

- `.env*` files (except `.env.example` templates)
- `etus-agent.local.yaml`
- Auth stores (`~/.etus-agent/auth.json`)
- Real PostHog project keys
- Subscription tokens or credential material
- `.etus-agent/`, `dist/`, `.turbo/`, `.pnpm-store/`, `node_modules/`

### Code Practices

- **No secret logging.** Never log API keys, bearer tokens, or redacted secret material in plain text.
- **Path validation.** Use existing workspace/path validation helpers when accepting user-provided paths.
- **Loopback by default.** Dashboard and MCP endpoints bind to 127.0.0.1 unless explicitly changed.
- **Hook isolation.** Hooks run in Docker with read-only FS, no network, memory limits.
- **Secret redaction.** All reporter output goes through the `SecretRedactor` interface.
- **Auth state redaction.** Browser storage state values are redacted before any output.

### Analytics Keys

- Analytics project keys are empty in source
- Injected only at release time by `scripts/release/posthog.mjs`
- Never hardcode real analytics keys in source

---

## 8. Pull Request Process

### Before Opening a PR

```bash
# 1. Build succeeds
pnpm build

# 2. Types check
pnpm typecheck

# 3. Tests pass (at minimum the affected package)
pnpm --filter <affected-pkg> test

# 4. If touching skills
pnpm run validate:skills

# 5. If touching public API surface
pnpm run validate:publish

# 6. If touching cross-package imports
pnpm run lint:namespace

# 7. For release-facing changes, run everything
pnpm typecheck && pnpm test && pnpm run validate:skills && pnpm run validate:publish
```

### PR Expectations

| Aspect | Expectation |
|--------|-------------|
| Scope | One logical change per PR |
| Tests | New or updated tests for every behavior change |
| Types | No `any` unless absolutely necessary (document why) |
| Breaking changes | Call out explicitly in PR description |
| Schema changes | Must be backward-compatible or include migration |
| New dependencies | Pinned versions, well-known packages only |
| Documentation | Update package AGENTS.md if adding new patterns |

### PR Title Format

```
<scope>: <concise description>

Examples:
  core: add context window overflow handling to planner
  web: fix smart-wait race condition on SPA navigation
  dashboard: add token usage chart to insights page
  cli: support --target flag in run command
  mcp: add etus_agent_search_memory tool
```

### Review Checklist

- [ ] Tests pass (`pnpm --filter <pkg> test`)
- [ ] Types check (`pnpm typecheck`)
- [ ] No new `@etus-agent/` namespace imports (use `@etus/agent-*`)
- [ ] No secrets or credentials in diff
- [ ] Branding correct (ETUS in prose, compatibility names in code)
- [ ] Schema changes validated
- [ ] Module boundaries respected (no new undeclared cross-package imports)

---


## 9. Common Tasks

### Adding a New Action Type

1. Define the tool in `packages/core/src/tools/registry.ts` (Zod schema + description)
2. Add handling in platform adapters that support it (`web/`, `android/`, `ios/`)
3. Adapters that don't support the action should return `{ success: false, error: 'Not supported' }`
4. Add tests for the new action in each affected adapter
5. The tool registry is automatically exposed to the LLM planner — no separate tool registration needed

### Adding a New MCP Tool

1. Define the tool in `packages/mcp/src/etus-agent-server.ts`
2. Use `etus_agent_` prefix for the tool name (snake_case)
3. Validate inputs with Zod
4. Delegate execution to dashboard API (POST to `/api/...`)
5. Add analytics event capture
6. Test with both stdio and HTTP transports

### Adding a New CLI Command

1. Create `packages/cli/src/commands/<name>.ts`
2. Export a `createXxxCommand()` function returning a `Command`
3. Register in `packages/cli/src/cli.ts`
4. Follow existing patterns (config resolution, error handling, picocolors output)
5. Run `pnpm --filter etus-agent test`

### Adding a New Schema Field

1. Update the Zod schema in `packages/core/src/schema/`
2. Make it optional with a default (backward compatibility)
3. Update config resolution in `packages/cli/src/config.ts` if it needs env mapping
4. Add schema test in `packages/core/src/__tests__/config-schema.test.ts`
5. Run `pnpm typecheck` (breaking type changes propagate across packages)

### Adding a New Dashboard API Route

1. Add the route in `packages/dashboard-server/src/server/routes.ts`
2. Implement handler logic (use `DashboardDatabase` for persistence)
3. Add matching API client function in `packages/dashboard-ui/src/lib/api.ts`
4. Add UI component if needed
5. Test the route in `packages/dashboard-server/src/__tests__/`

### Modifying Hook Sandbox Behavior

1. Changes to sandbox runner: `packages/core/src/hooks/sandbox-runner.ts`
2. Docker image changes: `docker/Dockerfile.hooks-*`
3. Test with `packages/core/src/hooks/__tests__/sandbox-runner.test.ts`
4. Rebuild hook images: `docker build -f docker/Dockerfile.hooks-<runtime> .`

---

## 10. Architecture Decision Records

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Zod over JSON Schema** | Co-located validation + TypeScript type inference, better composability |
| **Vercel AI SDK** | Unified interface across providers, tool_use support, streaming |
| **Raw Node.js HTTP (no framework)** | Minimal dependencies, full control, no framework lock-in |
| **SQLite over Postgres** | Zero-config local dashboard, single-file portability |
| **Docker for hooks** | Strong isolation guarantees, reproducible environments, no host pollution |
| **10-word IDs** | Human-readable, memorable, collision-resistant, prefix-separated |
| **Sub-action caching** | LLM cost reduction (cache hit = $0), deterministic replay |
| **Multi-action loop** | Single step → multiple UI actions (realistic user flows) |
| **Platform adapter pattern** | Swap browser/mobile without changing test logic or agent loop |
| **pnpm workspace + Turbo** | Fast installs, correct build ordering, minimal duplication |
| **Sharp for screenshots** | Reduce LLM token cost by compressing images before sending |
| **Memory observations** | Cross-run learning without retraining models |

### Package Boundaries Philosophy

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                   │
│  ids    → Pure computation. No I/O. No deps.                    │
│  core   → Contracts + engine. No platform-specific code.         │
│  web    → Playwright only. Implements core contracts.            │
│  android/ios → Appium only. Implements core contracts.           │
│  mcp    → Protocol layer. Validates + delegates.                 │
│  dashboard-server → Persistence + orchestration.                │
│  dashboard-ui → Presentation only. Calls server API.            │
│  cli    → User-facing glue. Imports everything. Entry point.    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

Each package owns exactly one concern. If a change requires modifying 3+ packages, consider whether the responsibility is in the right place.

---

## Appendix: Package AGENTS.md Files

Every package under `packages/*` has its own `AGENTS.md` with:
- Package-specific read-first files
- Local commands and scripts
- Constraints unique to that package

When editing files inside a package, always read its local `AGENTS.md` for additional context.

---

*For architecture details, see `docs/architecture.md`. For deployment, see `docs/deployment-guide.md`. For execution flow diagrams, see `docs/sequence-diagrams.md`.*
