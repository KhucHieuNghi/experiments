# ETUS — Architecture & Engineering Deep Dive

> **Version:** July 2026  
> **Audience:** Engineers onboarding to the ETUS codebase  
> **Scope:** Monorepo structure, runtime architecture, execution model, data flow, and subsystem contracts

---

## Table of Contents

1. [Product Overview](#1-product-overview)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Monorepo Structure](#3-monorepo-structure)
4. [Package Dependency Graph](#4-package-dependency-graph)
5. [Core Runtime Engine](#5-core-runtime-engine)
6. [Agent Loop — Observe → Plan → Execute → Verify](#6-agent-loop)
7. [Platform Adapters](#7-platform-adapters)
8. [Configuration System](#8-configuration-system)
9. [Identity System](#9-identity-system)
10. [Auth & Credential Management](#10-auth--credential-management)
11. [Caching Architecture](#11-caching-architecture)
12. [Memory System](#12-memory-system)
13. [Hook System & Sandbox](#13-hook-system--sandbox)
14. [Dashboard Architecture](#14-dashboard-architecture)
15. [MCP Server](#15-mcp-server)
16. [CLI Command Map](#16-cli-command-map)
17. [Analytics & Telemetry](#17-analytics--telemetry)
18. [Data Flow Diagrams](#18-data-flow-diagrams)
19. [Technology Stack](#19-technology-stack)
20. [Getting Started](#20-getting-started)

---


## 1. Product Overview

ETUS is an **AI-powered end-to-end testing platform** that uses Large Language Models to autonomously navigate and test web and mobile applications. Instead of writing brittle selectors and imperative scripts, engineers author tests as natural-language step descriptions. The LLM agent observes the screen, plans actions, executes them through platform adapters, and verifies outcomes.

**Key Capabilities:**
- Natural-language test authoring (YAML-based)
- Multi-platform: Web (Playwright), Android (Appium/UiAutomator2), iOS (Appium/XCUITest)
- AI-driven self-healing with configurable retry strategies
- Sub-action caching for deterministic replay and cost reduction
- WCAG accessibility auditing integrated into test execution
- Docker-sandboxed hook system for setup/teardown automation
- Local dashboard with real-time execution monitoring
- MCP (Model Context Protocol) server for IDE/agent integration
- Memory system for cross-run learning and observation persistence

---

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER INTERFACES                              │
├──────────────┬──────────────────┬──────────────────┬────────────────┤
│   CLI        │   Dashboard UI   │   MCP Server     │  IDE Plugins   │
│  (etus-agent)  │  (React/Vite)    │  (stdio/HTTP)    │  (consumers)   │
└──────┬───────┴────────┬─────────┴────────┬─────────┴────────────────┘
       │                │                  │
       ▼                ▼                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      ORCHESTRATION LAYER                             │
├─────────────────────────────────────────────────────────────────────┤
│  Config Resolution │ Target Resolution │ Device Resolution           │
│  Run Queue         │ Job Scheduling    │ Reporter Multiplexer        │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      CORE RUNTIME ENGINE                             │
├─────────────────────────────────────────────────────────────────────┤
│  Runner (runTest / runTestWithRetry)                                 │
│  Agent Loop (executeStep)                                           │
│  ├── OBSERVE  → PlatformAdapter.observe()                           │
│  ├── PLAN     → LLMPlanner (Vercel AI SDK + tool_use)               │
│  ├── EXECUTE  → PlatformAdapter.execute(action)                     │
│  └── VERIFY   → LLMVerifier (optional)                              │
│  Hooks Orchestrator │ Action Cache │ Memory Provider                 │
└──────────┬──────────────────┬───────────────────┬───────────────────┘
           │                  │                   │
           ▼                  ▼                   ▼
┌────────────────┐  ┌─────────────────┐  ┌────────────────────┐
│ Platform       │  │  LLM Providers  │  │  Persistence       │
│ Adapters       │  │                 │  │                    │
├────────────────┤  ├─────────────────┤  ├────────────────────┤
│ Web(Playwright)│  │ OpenAI-compat   │  │ SQLite (dashboard) │
│ Android(Appium)│  │ Anthropic-compat│  │ FileCache (.etus-agent)│
│ iOS (Appium)   │  │ Gemini          │  │ JSON Auth Store    │
│ Farm (remote)  │  │ Subscription    │  │ Memory FS provider │
└────────────────┘  └─────────────────┘  └────────────────────┘
```

---


## 3. Monorepo Structure

```
etus-agent/
├── packages/
│   ├── ids/              @etus/agent-ids        — Canonical ID generation
│   ├── core/             @etus/agent-core       — Runtime engine & contracts
│   ├── web/              @etus/agent-web        — Playwright browser adapter
│   ├── android/          @etus/agent-android    — Appium Android adapter
│   ├── ios/              @etus/agent-ios        — Appium iOS adapter
│   ├── mcp/              @etus/agent-mcp        — MCP server (31 tools)
│   ├── dashboard-server/ @etus/agent-dashboard  — Dashboard HTTP + SQLite
│   ├── dashboard-ui/     @etus/agent-dashboard-ui — React dashboard assets
│   └── cli/              etus-agent                  — Public CLI entrypoint
├── docker/               Release Docker images (web, android, hook sandboxes)
├── scripts/              Release, validation, staging automation
├── skills/               Source skills for CLI packaging
└── demo-project/         Example project with config + tests
```

**Toolchain:** pnpm 10.6 workspaces, Turbo for orchestrated builds, TypeScript 6 (strict, NodeNext ESM), Vitest for testing, Prettier for formatting.

---

## 4. Package Dependency Graph

```
                    ┌──────────┐
                    │   ids    │  (zero dependencies)
                    └────┬─────┘
                         │
                         ▼
                    ┌──────────┐
                    │   core   │  (schemas, runner, auth, cache, memory, hooks)
                    └────┬─────┘
                         │
            ┌────────────┼────────────────┬─────────────┐
            │            │                │             │
            ▼            ▼                ▼             ▼
      ┌──────────┐ ┌──────────┐    ┌──────────┐  ┌──────────┐
      │   web    │ │ android  │    │   ios    │  │   mcp    │
      └────┬─────┘ └────┬─────┘    └────┬─────┘  └────┬─────┘
           │            │                │             │
           └────────────┼────────────────┘             │
                        │                              │
                        ▼                              │
              ┌──────────────────┐                     │
              │ dashboard-server │◄────────────────────┘
              └────────┬─────────┘
                       │
                       ▼
              ┌──────────────────┐
              │  dashboard-ui    │  (built assets served by server)
              └──────────────────┘
                       │
                       ▼
              ┌──────────────────┐
              │      cli         │  (imports all packages)
              └──────────────────┘
```

**Key dependencies (external):**
- `ai` (Vercel AI SDK) — LLM abstraction layer
- `@ai-sdk/openai`, `@ai-sdk/anthropic`, `@ai-sdk/google` — Provider adapters
- `zod` — Schema validation throughout
- `playwright` — Web browser automation
- `webdriverio` — Mobile automation (Appium client)
- `better-sqlite3` — Dashboard persistence
- `sharp` — Screenshot compression
- `posthog-node` — Analytics telemetry
- `ws` — WebSocket for live editor

---


## 5. Core Runtime Engine

The `@etus/agent-core` package is the heart of ETUS. It contains:

| Module | Responsibility |
|--------|---------------|
| `schema/` | Zod schemas for config, tests, suites, hooks, actions, memory observations |
| `agent/runner.ts` | Test execution orchestrator (step iteration, retries, hooks, screenshots) |
| `agent/loop.ts` | The agent loop — observe/plan/execute/verify cycle per step |
| `agent/planner.ts` | LLMPlanner — sends screen state + instruction to LLM via tool_use |
| `agent/verifier.ts` | LLMVerifier — validates action outcomes against expected state |
| `agent/provider.ts` | Model factory — creates LanguageModel instances per provider config |
| `tools/` | Action tool registry — defines available actions as LLM tools |
| `hooks/` | Hook orchestrator + Docker sandbox runner |
| `auth/` | Credential store, resolver, plugin system |
| `cache/` | FileActionCache with TTL and sub-action indexing |
| `memory/` | MemoryProvider interface + observation schemas |
| `analytics/` | PostHog-based telemetry service |
| `reporter/` | Reporter interface + MultiReporter multiplexer |
| `types/` | PlatformAdapter, Action, ScreenState, Result types |
| `logging/` | Scoped logger with structured output |

### Core Interfaces

```typescript
// The contract every platform adapter must implement
interface PlatformAdapter {
  platform: 'web' | 'android' | 'ios'
  setup(config: PlatformConfig): Promise<void>
  cleanup(): Promise<void>
  observe(opts?: { extractDom?: boolean }): Promise<ScreenState>
  execute(action: Action): Promise<ActionResult>
  screenshot(): Promise<Buffer>
  drainConsoleLogs?(): ConsoleLogEntry[]
  drainNetworkLogs?(): NetworkLogEntry[]
  startVideoRecording?(): Promise<void>
  stopVideoRecording?(): Promise<Buffer | null>
}

// What the LLM planner must satisfy
interface Planner {
  plan(step: string, screenState: ScreenState, context: StepContext, 
       abortSignal?: AbortSignal): Promise<PlanResult>
}

// Optional verification after action execution
interface Verifier {
  verify(step: string, before: ScreenState, after: ScreenState, 
         action: Action, screenshot?: Buffer, abortSignal?: AbortSignal): Promise<VerifyResult>
}
```

---


## 6. Agent Loop

The agent loop (`executeStep`) is the most critical path. Each natural-language step goes through an iterative multi-action cycle:

```
┌─────────────────────────────────────────────────────────────────┐
│                    executeStep(instruction)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  for actionIndex = 0 .. maxSubActions:                           │
│                                                                   │
│    ┌─────────┐     ┌──────────┐     ┌─────────┐     ┌────────┐ │
│    │ OBSERVE │────▶│   PLAN   │────▶│ EXECUTE │────▶│ VERIFY │ │
│    └─────────┘     └──────────┘     └─────────┘     └────────┘ │
│         │               │                │               │       │
│    adapter.observe  LLMPlanner       adapter.execute  LLMVerifier│
│    + screenshot()   (cache-first)                    (optional)  │
│                     then AI SDK                                   │
│                                                                   │
│    Exit conditions:                                               │
│    • plan.stepComplete = true  → SUCCESS                         │
│    • plan.stepFailed = true    → FAILURE                         │
│    • consecutiveFailures ≥ 3   → FAILURE (healing exhausted)     │
│    • actionIndex ≥ maxSubActions → FAILURE (timeout)             │
│    • deadline exceeded          → FAILURE (step timeout)         │
│    • abortSignal fired          → ABORTED                        │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Plan Phase Detail

```
LLMPlanner.plan()
  │
  ├── buildSystemPrompt(platform, agentRules)
  ├── buildStepPrompt(step, screenState, context)
  ├── buildTools(registry, { platform })        ← Action tool definitions
  │
  └── generateText({
        model,
        tools,
        toolChoice: 'required',
        messages: [{ text: prompt }, { image: screenshot }]
      })
        │
        └── toolCallToActionPlan(toolName, args, registry)
              │
              └── ActionPlan { reasoning, action, confidence, stepComplete, stepFailed }
```

### ActionPlan Schema

```typescript
{
  reasoning: string      // LLM's explanation for choosing this action
  action: Action         // Typed action (click, fill, navigate, scroll, etc.)
  confidence: number     // 0-1 confidence score
  stepComplete: boolean  // true = step goal achieved, exit loop
  stepFailed: boolean    // true = step impossible, abort with error
}
```

### Sub-Action Caching Strategy

Each step is hashed by `(instruction + platform + config + testFile + stepIndex)`. Sub-actions are cached by `(stepHash, actionIndex)`. On cache miss at index N, all cached entries from N onward are invalidated (prefix invalidation). This ensures:
- Deterministic replay when nothing changed
- Automatic invalidation when earlier actions produce different outcomes
- Significant cost reduction on re-runs

---


## 7. Platform Adapters

### Web Adapter (`@etus/agent-web`)

Built on **Playwright**. Supports:
- **DOM Extraction:** Deep tree traversal with shadow DOM, custom elements, depth limiting
- **Smart Waits:** DOM ready + network idle + loading indicators + CSS animations
- **Action Validation:** Role-based checks before execution (e.g., prevents `fill` on non-fillable elements)
- **Accessibility:** Axe-core integration for WCAG 2.0 AA/AAA auditing per step
- **Actions:** click, fill, select, navigate, scroll, keypress, hover, paste, fileUpload, copy, tab management, cookies, localStorage
- **Logging:** Console log capture, network request/response capture
- **Recording:** Video recording via Playwright's built-in tracing
- **Farm Adapter:** Remote browser execution via cloud providers

### Android Adapter (`@etus/agent-android`)

Built on **WebdriverIO + Appium UiAutomator2**. Supports:
- **Native Gestures:** tap, swipe, pinch, multiTap, longPress, doubleTap
- **Hybrid Mode:** Automatic context switching between NATIVE_APP and WEBVIEW
- **Native Selectors:** Spinner/NumberPicker via `nativeSelect`
- **Deep Links:** Direct intent-based navigation
- **Logging:** Logcat capture
- **Recording:** Screen recording via `adb screenrecord`
- **Session:** Configurable app package, activity, device profiles, farm support

### iOS Adapter (`@etus/agent-ios`)

Built on **WebdriverIO + Appium XCUITest**. Supports:
- **Native Gestures:** Same gesture vocabulary as Android
- **iOS-specific:** Picker wheel selection via `nativeSelect`, screenshot pixel-to-point alignment
- **Hybrid Mode:** WebView URL extraction + context switching (NATIVE_APP ↔ WEBVIEW_*)
- **Logging:** Syslog capture
- **Deep Links:** URL scheme-based navigation
- **Session:** Bundle ID, UDID, XCUITest capabilities, farm support

### Shared Action Type System

All adapters implement a unified `Action` discriminated union:

```typescript
type Action =
  | { type: 'click'; ref: string }
  | { type: 'fill'; ref: string; value: string }
  | { type: 'select'; ref: string; value: string }
  | { type: 'navigate'; url: string }
  | { type: 'scroll'; direction: 'up'|'down'|'left'|'right'; ref?: string }
  | { type: 'keypress'; key: string }
  | { type: 'hover'; ref: string }
  | { type: 'tap'; x: number; y: number }
  | { type: 'swipe'; startX: number; startY: number; endX: number; endY: number }
  | { type: 'assert'; condition: string; visual?: boolean }
  | { type: 'wait'; condition: string; timeout?: number }
  | { type: 'setVariable'; name: string; value: string }
  | { type: 'fileUpload'; ref: string; files: string[] }
  | ... // 20+ action types total
```

---


## 8. Configuration System

### 3-Layer Config Resolution

```
┌───────────────────────┐
│  etus-agent.config.yaml │  ← Primary config file
└───────────┬───────────┘
            │ merge
            ▼
┌───────────────────────┐
│  Environment Vars     │  ← ETUS_AGENT_* overrides
│  (ETUS_AGENT_DASHBOARD_PORT, ETUS_AGENT_CACHE_DIR, etc.)
└───────────┬───────────┘
            │ merge
            ▼
┌───────────────────────┐
│  CLI Flags            │  ← --headless, --no-cache, --log-level, etc.
└───────────────────────┘
```

Additional merge levels for test execution:
```
Global config → Suite-level use block → Test-level use block → CLI flags
```

### Config Schema (validated by Zod)

```yaml
workspace:
  testMatch: ['tests/**/*.yaml']       # Glob patterns for test discovery
  suiteMatch: ['suites/**/*.suite.yaml']
  hooksFile: hooks.yaml
  agentRules: ./agent-rules.md         # Custom instructions for the LLM planner
  envFile: .env
  secretsFile: .env.secrets.local

services:
  dashboard: { port: 3100, artifactsDir: .etus-agent/artifacts }
  mcp: { enabled: true, transport: http, host: 127.0.0.1, port: 3471 }
  cache: { dir: .etus-agent/cache, ttl: 7d }
  authState: { dir: .etus-agent/auth-states }
  accessibility: { enabled: true, standard: wcag2aa, runAfter: every-step }
  recording: { enabled: true }
  memory: { enabled: true, provider: local, dir: etus-agent-memory }
  logging: { level: warn }

registry:
  llms:                                # Named LLM configurations
    - name: default
      provider: openai-compatible
      model: gpt-4o
      baseURL: https://api.openai.com/v1
  targets:                             # Named app targets
    my-app: { platform: web, url: https://app.example.com }
  devices:                             # Device profiles (optional)
    pixel-7: { platform: android, transport: local }

plugins:
  auth:
    - package: '@etus/agent-subscription-auth'

use:
  browser: { name: chromium, headless: true, viewport: { width: 1280, height: 720 } }
  mobile: { appState: preserve }
  timeout: { step: 5m, test: 30m, navigation: 1m }
  healing: { maxAttempts: 3 }
  planner: { maxSubActions: 10, previousStepCount: 5 }
  logCapture: { console: true, network: true }
  parallel: false
  llm: default                         # Which named LLM to use
```

### Environment Variable Mapping

| Variable | Config Path | Type |
|----------|-------------|------|
| `ETUS_AGENT_DASHBOARD_PORT` | `services.dashboard.port` | number |
| `ETUS_AGENT_MCP_PORT` | `services.mcp.port` | number |
| `ETUS_AGENT_CACHE_DIR` | `services.cache.dir` | string |
| `ETUS_AGENT_CACHE_TTL` | `services.cache.ttl` | string |
| `ETUS_AGENT_LOG_LEVEL` | `services.logging.level` | string |
| `ETUS_AGENT_HEADLESS` | `use.browser.headless` | boolean |

---


## 9. Identity System

The `@etus/agent-ids` package generates **canonical persistent IDs** using a 10-word scheme from the `id-agent` library. Each entity type has a distinct prefix:

| Entity | Prefix | Example |
|--------|--------|---------|
| Test | `t_` | `t_alpha-bravo-charlie-delta-echo-foxtrot-golf-hotel-india-juliet` |
| Suite | `s_` | `s_kilo-lima-mike-november-oscar-papa-quebec-romeo-sierra-tango` |
| Hook | `h_` | `h_uniform-victor-whiskey-xray-yankee-zulu-alpha-bravo-charlie-delta` |
| Observation | `obs_` | `obs_echo-foxtrot-golf-hotel-india-juliet` (6-word legacy) |
| Run | `r_` | `r_kilo-lima-mike-november-oscar-papa-quebec-romeo-sierra-tango` |

**Design principles:**
- Human-readable and memorable
- Deterministic generation from content hash (tests/suites/hooks)
- Collision-resistant via 10-word space
- Validation functions: `isCanonicalTestId()`, `isCanonicalSuiteId()`, etc.
- Never hand-written — always use `generateTestId()`, `generateSuiteId()`, etc.

---

## 10. Auth & Credential Management

### Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│ Config Registry │────▶│  Auth Resolver    │────▶│  Model Factory   │
│ (llms[].name)   │     │  resolveLLMAuth() │     │  createModel()   │
└─────────────────┘     └────────┬─────────┘     └──────────────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
                    ▼            ▼            ▼
             ┌──────────┐ ┌──────────┐ ┌──────────────┐
             │ API Key  │ │ Bearer   │ │ OAuth/Plugin │
             │ (JSON    │ │ Token    │ │ (subscription│
             │  store)  │ │ (store)  │ │  auth-fetch) │
             └──────────┘ └──────────┘ └──────────────┘
```

### Credential Types

| Kind | Providers | Storage |
|------|-----------|---------|
| `api-key` | openai-compatible, anthropic-compatible, gemini | `~/.etus-agent/auth.json` |
| `bearer-token` | anthropic-compatible only | `~/.etus-agent/auth.json` |
| `auth-fetch` | subscription providers (via plugin) | OAuth tokens in store |
| `unauthenticated` | compatible providers (optional) | No stored credential |

### Plugin System

Subscription auth (Codex, Claude Code) uses a plugin pattern:
```typescript
interface LLMAuthProviderPlugin {
  providerId: string
  credentialProviderId: string
  label: string
  modelAdapter: 'openai-responses' | 'anthropic-messages'
  dashboardAuth: { mode: 'redirect' | 'manual-code' }
  startAuth?(opts: { configName: string }): Promise<AuthStartResult>
  exchangeCode?(opts: { code: string; sessionState: string }): Promise<OAuthTokens>
  createAuthFetch(opts: { getTokens; onRefreshed }): typeof fetch
}
```

---


## 11. Caching Architecture

### FileActionCache

```
.etus-agent/cache/
├── <stepHash>/
│   ├── sub-0.json     ← ActionPlan for sub-action 0
│   ├── sub-1.json     ← ActionPlan for sub-action 1
│   └── sub-2.json     ← ActionPlan for sub-action 2
└── meta.json          ← TTL metadata
```

### Cache Interface

```typescript
interface ActionCache {
  get(stepHash: string, screenHash: string): Promise<ActionPlan | null>
  set(stepHash: string, screenHash: string, plan: ActionPlan): Promise<void>
  invalidate(stepHash: string, screenHash: string): Promise<void>
  getSubAction(stepHash: string, index: number): Promise<ActionPlan | null>
  setSubAction(stepHash: string, index: number, plan: ActionPlan): Promise<void>
  invalidateSubActionsFrom(stepHash: string, fromIndex: number): Promise<void>
}
```

### Invalidation Strategy

- **Prefix invalidation:** Cache miss at sub-action index N triggers invalidation of all entries from N onward
- **Step hash includes:** instruction text, platform, config content, test file content, step index, suite context
- **Secret-aware:** Cached plans containing redacted secret markers (`[secret:NAME]`) are rejected on read
- **TTL-based expiry:** Configurable via `services.cache.ttl` (default: 7 days)

---

## 12. Memory System

The memory system enables cross-run learning through persisted observations.

### MemoryProvider Interface

```typescript
interface MemoryProvider {
  init(): Promise<void>
  queryForStep(step: string, context: MemoryQueryContext): Promise<MemoryEntry[]>
  writeObservation(observation: Observation): Promise<void>
  deleteObservation(id: string): Promise<void>
  searchForDuplicates(observation: Observation): Promise<Observation[]>
  acquireLock?(runId: string): Promise<boolean>
  releaseLock?(runId: string): Promise<void>
}
```

### Observation Schema

```yaml
# Stored in etus-agent-memory/ directory
id: obs_word1-word2-word3-word4-word5-word6
type: selector-hint | interaction-pattern | failure-recovery | ...
target: my-app
step: "Click the login button"
content: "Login button uses role=button with aria-label='Sign In'"
trustScore: 0.85
confirmationCount: 3
lastConfirmed: 2026-07-20T10:00:00Z
```

Observations accumulate trust through repeated confirmation. Low-trust observations decay and can be pruned.

---


## 13. Hook System & Sandbox

### Hook Definition (YAML)

```yaml
# hooks.yaml
hooks:
  - id: h_...
    name: setup-auth-token
    runtime: node          # node | bun | python | bash
    file: hooks/setup.mjs
    deps: [hooks/utils.mjs]
    timeout: 30s
    network: true          # allow outbound network in container
```

### Execution Model

```
┌────────────────────────────────────────────────────────────┐
│  runHooks(hooks[], options)                                  │
│                                                              │
│  Sequential execution with fail-fast:                        │
│                                                              │
│  Hook 1 ──▶ Hook 2 ──▶ Hook 3                              │
│    │           │           │                                 │
│    ▼           ▼           ▼                                 │
│  Docker     Docker     Docker                                │
│  Container  Container  Container                             │
│                                                              │
│  On failure: remaining hooks are skipped                     │
│  Variables: merged across hooks (hook 2 sees hook 1 vars)    │
└────────────────────────────────────────────────────────────┘
```

### Docker Sandbox Details

Each hook runs in an isolated Docker container:

| Constraint | Value |
|-----------|-------|
| Memory limit | 512 MB |
| CPU limit | 1 core |
| PID limit | 256 |
| Filesystem | Read-only (except `/tmp`) |
| Network | Disabled by default (`--network none`) |
| Timeout | Per-hook configurable |

**Runtime images:**
- `node` → `etus/etus-agent-hook-node`
- `bun` → `etus/etus-agent-hook-bun`
- `python` → `etus/etus-agent-hook-python`
- `bash` → `etus/etus-agent-hook-bash`

**Variable extraction:** Hooks write to `/tmp/etus-agent.env` inside the container. The orchestrator reads this file after execution and merges variables into subsequent hooks and the test run.

**Auth state integration:** When auth state is configured, the storage state file is mounted into the container and exposed via environment variables.

---


## 14. Dashboard Architecture

### Server (`@etus/agent-dashboard`)

**Stack:** Raw Node.js `http.createServer` + manual router (not Express/Hono), `better-sqlite3`, `ws` for WebSocket.

```
┌─────────────────────────────────────────────────┐
│           Dashboard Server (port 3100)           │
├─────────────────────────────────────────────────┤
│                                                   │
│  HTTP Routes (/api/*)                            │
│  ├── /api/runs/*         Run CRUD + trigger      │
│  ├── /api/tests/*        Test file management    │
│  ├── /api/suites/*       Suite file management   │
│  ├── /api/hooks/*        Hook registry + execute │
│  ├── /api/config/*       Config read/write       │
│  ├── /api/cache/*        Cache purge             │
│  ├── /api/memory/*       Memory observations     │
│  ├── /api/variables/*    Runtime variables        │
│  ├── /api/execution/*    Active execution state  │
│  ├── /api/queue/*        Job queue management    │
│  └── /api/agent-rules    Agent rules CRUD        │
│                                                   │
│  WebSocket (/ws)                                 │
│  └── Live Editor sessions (real-time editing)    │
│                                                   │
│  Static Files                                    │
│  └── Dashboard UI assets (from dashboard-ui pkg) │
│                                                   │
│  MCP Endpoint (/mcp)                             │
│  └── Embedded MCP server (HTTP transport)        │
│                                                   │
├─────────────────────────────────────────────────┤
│  Internal Services                               │
│  ├── DashboardDatabase (SQLite)                  │
│  ├── JobQueue (concurrency-controlled)           │
│  ├── DashboardReporter (persists results)        │
│  ├── ConfigManager (YAML read/write)             │
│  ├── HookRegistryManager                        │
│  └── AppiumManager (mobile session lifecycle)    │
└─────────────────────────────────────────────────┘
```

### SQLite Schema (7 tables)

```sql
runs           -- Run metadata (id, status, target, start/end time, attributes)
steps          -- Step results (run_id FK, name, status, duration, action, trace)
reasoning_traces -- LLM reasoning per sub-action (step_id FK)
logs           -- Console/network logs captured during execution
execution_logs -- Server-side execution audit trail
token_events   -- LLM token usage tracking (prompt/completion per call)
run_artifacts  -- Binary artifacts (screenshots, videos, reports)
```

### Job Queue

- **Concurrency control:** Configurable parallel slots
- **Platform-aware:** Mobile tests serialize per platform (one device at a time), web supports parallel
- **Priority scheduling:** Queue with FIFO ordering and priority override
- **Event-driven:** Execution trigger on job arrival

### UI (`@etus/agent-dashboard-ui`)

**Stack:** React 19, Vite, TailwindCSS 4, react-router 7, Radix UI primitives, Monaco Editor, recharts, dnd-kit, tanstack/react-table, motion (animations).

**Pages:**
- Runs — Run list, detail view with step-by-step replay
- Tests — Test file browser, YAML editor (Monaco), validation
- Suites — Suite management and composition
- Hooks — Hook registry, execute-and-inspect, sandbox details
- Memory — Observation browser with search and trust scores
- Insights — Analytics charts (pass rate, duration trends, token usage)
- Config — Visual config editor (planner, browser, timeout, LLM settings)
- Live Run — Real-time execution monitoring with step phases
- Editor — Interactive test authoring with live preview

---


## 15. MCP Server

The `@etus/agent-mcp` package exposes **31 tools** via the Model Context Protocol, enabling IDE agents and external tools to interact with ETUS programmatically.

### Transports

| Transport | Use Case | Default |
|-----------|----------|---------|
| stdio | IDE integration (stdin/stdout) | Used by `etus-agent mcp` command |
| HTTP | Dashboard-embedded, remote access | `127.0.0.1:3471/mcp` (loopback only) |

### Tool Categories (31 tools, `etus_agent_*` prefix)

| Category | Tools | Description |
|----------|-------|-------------|
| **Test Authoring** | `etus_agent_create_test`, `etus_agent_update_test`, `etus_agent_validate_test` | Create/edit/validate test YAML |
| **Suite Management** | `etus_agent_create_suite`, `etus_agent_update_suite`, `etus_agent_validate_suite` | Suite lifecycle |
| **Hook Management** | `etus_agent_create_hook`, `etus_agent_update_hook`, `etus_agent_run_hook` | Hook CRUD + execution |
| **Execution** | `etus_agent_run_test`, `etus_agent_run_suite`, `etus_agent_cancel_run` | Trigger and control runs |
| **Results** | `etus_agent_get_run`, `etus_agent_list_runs`, `etus_agent_get_steps` | Query execution results |
| **Config** | `etus_agent_get_config`, `etus_agent_update_config`, `etus_agent_get_targets` | Config management |
| **Memory** | `etus_agent_search_memory`, `etus_agent_write_observation` | Memory operations |
| **Cache** | `etus_agent_purge_cache` | Cache management |
| **Schema** | `etus_agent_get_schema` | Get validation schemas |
| **IDs** | `etus_agent_generate_id`, `etus_agent_validate_id` | ID generation/validation |

### Integration Pattern

```
IDE/Agent ──stdio──▶ MCP Server ──HTTP──▶ Dashboard Server ──▶ Core Runtime
                        │
                        ├── Schema validation (core schemas)
                        ├── ID generation (@etus/agent-ids)
                        └── Analytics capture (PostHog)
```

---

## 16. CLI Command Map

The `etus-agent` CLI (20 commands via Commander.js):

| Command | Description |
|---------|-------------|
| `init` | Interactive project initialization (creates config, examples, scripts) |
| `run` | Execute tests/suites (the main command) |
| `dashboard` | Start dashboard server (`--open` to launch browser) |
| `serve` | Alias for dashboard |
| `mcp` | Start MCP server (stdio transport) |
| `doctor` | Environment validation (Node, Docker, Playwright, Appium, LLM) |
| `auth login` | OAuth login for subscription providers |
| `auth set` | Save API key or bearer token |
| `auth status` | Show credential status for all LLMs |
| `auth test` | Verify LLM connection |
| `auth logout` | Remove stored credentials |
| `auth-state` | Manage browser auth state snapshots |
| `config get/set` | Read/write config values |
| `install-browsers` | Install Playwright browsers |
| `install-mobile-drivers` | Install Appium drivers |
| `queue` | View/manage run queue |
| `cache` | Cache operations |
| `validate` | Validate test/suite/hook files |
| `devices` | List device profiles |
| `ids` | Generate/validate IDs |
| `create-test` | Scaffold a new test file |
| `create-suite` | Scaffold a new suite file |
| `clean-memory` | Prune stale memory observations |
| `skills` | Manage packaged skills |

---


## 17. Analytics & Telemetry

**Provider:** PostHog (self-hosted compatible)

- Opt-out via config (`analytics.enabled: false`) or environment variable
- Privacy-first: no PII, no test content, no screenshots sent
- Events captured: run start/end, step outcomes, token usage, errors, provider latency
- Identity resolution: anonymous device ID (no user accounts)
- Project keys injected at release time (empty in source)

---

## 18. Data Flow Diagrams

### Test Execution Flow (Complete)

```
User
  │
  │ etus-agent run --target my-app tests/login.yaml
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│ CLI: createRunCommand()                                           │
├──────────────────────────────────────────────────────────────────┤
│ 1. resolveConfig() → merge YAML + env + flags                    │
│ 2. discoverWorkspaceFiles() → find matching tests/suites         │
│ 3. resolveTarget('my-app') → { platform: web, url: ... }         │
│ 4. resolveLLMModels() → resolve auth, create LanguageModel       │
│ 5. createPlatformAdapter() → WebPlatformAdapter                  │
│ 6. loadHooks() → parse hooks.yaml                                │
│ 7. runHooks(setupHooks) → Docker sandbox execution               │
│ 8. For each test/suite:                                          │
│    └── runTestWithRetry(test, config) ────────────────────────┐  │
│                                                                │  │
│  ┌─────────────────────────────────────────────────────────────┘  │
│  │                                                                │
│  ▼                                                                │
│ runTest()                                                         │
│  ├── For each step in test.steps:                                │
│  │    ├── Interpolate variables: {{var}} → value                 │
│  │    ├── Query memory: memoryProvider.queryForStep()             │
│  │    ├── executeStep(instruction, loopConfig, context) ──────┐  │
│  │    │                                                        │  │
│  │    │  ┌─────────────────────────────────────────────────────┘  │
│  │    │  │ Agent Loop (up to maxSubActions iterations)            │
│  │    │  │  1. OBSERVE → adapter.observe() + screenshot()        │
│  │    │  │  2. Check cache → hit? use cached plan                │
│  │    │  │  3. PLAN → LLMPlanner.plan() [AI SDK generateText]    │
│  │    │  │  4. EXECUTE → adapter.execute(action)                 │
│  │    │  │  5. Check stepComplete/stepFailed                     │
│  │    │  │  6. Loop or return StepResult                         │
│  │    │  └────────────────────────────────────────────────────── │
│  │    │                                                           │
│  │    ├── Run accessibility check (if enabled)                   │
│  │    ├── Capture screenshot (after)                             │
│  │    ├── Report step result → reporters                         │
│  │    └── Write memory observation (if learning enabled)         │
│  │                                                                │
│  ├── Run teardown hooks                                          │
│  └── Return TestResult { status, steps[], duration, tokens }     │
│                                                                   │
│ 9. Report results → DashboardReporter, console, file             │
│10. runHooks(teardownHooks)                                        │
│11. adapter.cleanup()                                              │
│12. flushAnalytics()                                               │
└──────────────────────────────────────────────────────────────────┘
```

### Dashboard Live Editing Flow

```
Browser (dashboard-ui)
  │
  │ WebSocket connect → /ws
  │
  ▼
┌─────────────────────────────┐     ┌────────────────────┐
│ SessionManager              │────▶│ Live Session        │
│ (manages editor sessions)   │     │ (per-test instance) │
└─────────────────────────────┘     └────────┬───────────┘
                                             │
                                    ┌────────┼────────────┐
                                    │        │            │
                                    ▼        ▼            ▼
                              Edit YAML  Execute Step  Full Run
                                    │        │            │
                                    ▼        ▼            ▼
                              Validate   executeStep()  runTest()
                              (schema)   (single loop)  (full test)
                                    │        │            │
                                    └────────┼────────────┘
                                             │
                                             ▼
                                    Real-time results
                                    streamed via WebSocket
```

---


## 19. Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| **Runtime** | Node.js | ≥ 24 |
| **Language** | TypeScript (strict, NodeNext ESM) | 6.0 |
| **Package Manager** | pnpm (workspaces) | 10.6 |
| **Build** | Turbo | 2.9 |
| **Test** | Vitest | 4.1 |
| **LLM SDK** | Vercel AI SDK (`ai`) | latest |
| **Schema** | Zod | latest |
| **Web Automation** | Playwright | latest |
| **Mobile Automation** | WebdriverIO + Appium | latest |
| **Database** | better-sqlite3 | latest |
| **UI Framework** | React | 19 |
| **UI Bundler** | Vite | latest |
| **UI Styling** | TailwindCSS | 4 |
| **UI Components** | Radix UI | latest |
| **Code Editor** | Monaco Editor | latest |
| **Charts** | recharts | latest |
| **WebSocket** | ws | latest |
| **Image Processing** | sharp | latest |
| **Analytics** | PostHog | latest |
| **Container** | Docker (hook sandboxes) | — |
| **CLI Framework** | Commander.js | latest |
| **YAML** | yaml (parse/stringify) | latest |

---

## 20. Getting Started

### Prerequisites

```bash
node --version   # Must be >= 24
pnpm --version   # Must be 10.x
docker --version # Required for hooks (optional for basic web testing)
```

### Setup

```bash
# 1. Install dependencies
pnpm install

# 2. Build all packages
pnpm build

# 3. Initialize a project
node packages/cli/dist/cli.js init

# 4. Configure LLM credentials
node packages/cli/dist/cli.js auth set --config <name> --type api-key

# 5. Verify environment
node packages/cli/dist/cli.js doctor

# 6. Install browsers (for web testing)
node packages/cli/dist/cli.js install-browsers

# 7. Start dashboard
node packages/cli/dist/cli.js dashboard --open

# 8. Run tests
node packages/cli/dist/cli.js run
```

### Development Workflow

```bash
# Run specific package tests
pnpm --filter @etus/agent-core test
pnpm --filter @etus/agent-web test
pnpm --filter @etus/agent-mcp test

# Typecheck everything
pnpm typecheck

# Validate skills and publish surface
pnpm run validate:skills
pnpm run validate:publish

# Check namespace import rules
pnpm run lint:namespace
```

### Writing a Test

```yaml
# tests/login.yaml
test-id: t_<generated-id>
name: User can log in with valid credentials
meta:
  retries: 1
steps:
  - Navigate to the login page
  - Enter "user@example.com" in the email field
  - Enter "password123" in the password field
  - Click the Sign In button
  - Verify the dashboard is displayed with welcome message
```

### Writing a Suite

```yaml
# suites/smoke.suite.yaml
suite-id: s_<generated-id>
name: Smoke Tests
setup:
  - setup-auth-token
tests:
  - tests/login.yaml
  - tests/navigation.yaml
  - tests/logout.yaml
teardown:
  - cleanup-session
```

---

## Appendix: Key File Paths

| Purpose | Path |
|---------|------|
| Main config | `etus-agent.config.yaml` |
| Local overrides | `etus-agent.local.yaml` |
| Runtime artifacts | `.etus-agent/` |
| Cache | `.etus-agent/cache/` |
| Auth states | `.etus-agent/auth-states/` |
| Credential store | `~/.etus-agent/auth.json` |
| Memory | `etus-agent-memory/` |
| Hooks file | `hooks.yaml` |
| Agent rules | `agent-rules.md` |
| Env file | `.env` |
| Secrets file | `.env.secrets.local` |

---

*Document generated from source analysis of the ETUS monorepo. For package-specific details, see the `AGENTS.md` files in each `packages/*` directory.*
