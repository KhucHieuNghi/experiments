<div align="center">
  <h1>ETUS</h1>
  <p><strong>The self-improving Agentic QA harness with Memory</strong></p>
  <p>AI-powered end-to-end testing for web — write tests in natural language, let the agent handle the rest.</p>
</div>

---

## What is ETUS?

ETUS is an AI-powered testing platform that uses LLMs to autonomously navigate and test web applications. Instead of writing brittle CSS selectors and imperative scripts, you write test steps as natural language. The AI agent observes the screen, plans actions, executes them, and verifies outcomes — healing itself when things change.

---

## Features

### AI-Driven Test Execution
- **Natural-language test authoring** — Write steps like "Click the login button" or "Verify the dashboard shows a welcome message"
- **Observe → Plan → Execute → Verify loop** — The agent sees the screen, decides what to do, does it, and confirms the result
- **Self-healing execution** — When an action fails, ETUS re-observes the UI and tries alternative paths automatically
- **Multi-action steps** — A single step like "Fill the registration form" can expand into multiple sub-actions

### Multi-Platform Support
- **Web** — Playwright-based (Chromium, Firefox, WebKit)

### Smart Caching & Cost Optimization
- **Sub-action caching** — Validated action plans are cached and replayed on subsequent runs (cache hit = $0 LLM cost)
- **Screenshot compression** — Images resized before sending to LLM to reduce token usage
- **Prefix invalidation** — Cache automatically invalidates when earlier actions produce different results

### Memory System
- **Cross-run learning** — ETUS builds execution memory from observations and applies context to future runs
- **Self-curating** — Observations gain trust through repeated confirmation, low-trust entries decay
- **Selector hints, interaction patterns, failure recovery** — Memory helps avoid repeated mistakes

### Dashboard & Monitoring
- **Local web dashboard** — Real-time execution monitoring, step-by-step replay, insights charts
- **Live editor** — Edit and execute tests interactively via WebSocket
- **Run queue** — Concurrent execution with platform-aware scheduling
- **Token usage tracking** — Monitor LLM costs per run, per step

### Developer & Agent Workflows
- **CLI** — 20+ commands for test execution, config, auth, cache, validation
- **MCP Server** — 31 tools for IDE/agent integration (stdio + HTTP transports)
- **Skills** — Packaged skills for coding agents to author, triage, and debug tests

### Hook System
- **Docker-sandboxed execution** — Node, Bun, Python, Bash hooks in isolated containers
- **Setup/teardown automation** — Prepare state, call APIs, seed fixtures
- **Variable passing** — Hooks output variables consumed by subsequent hooks and tests
- **Resource limits** — 512MB memory, 1 CPU, read-only filesystem, no network by default

### Accessibility
- **WCAG auditing** — Axe-core integration checks accessibility per step
- **Configurable standard** — WCAG 2.0 AA or AAA
- **Non-blocking or fail-on-violation** modes

### Bring Your Own LLM
- **OpenAI-compatible** (OpenRouter, OpenAI, DeepSeek, local models)
- **Anthropic-compatible**
- **Gemini**
- **Subscription auth** (Codex, Claude Code via plugin)

---

## Quickstart

### Prerequisites

- Node.js >= 24
- pnpm 10.6+ (via `corepack enable`)
- Docker (for hooks — optional for basic web testing)

### Install & Run (from source)

```bash
# Clone and install
git clone <repo-url> && cd etus-agent
pnpm install

# Build all packages
pnpm build

# Start (auto-installs browsers, creates config, starts dashboard)
./start.sh
```

### Or use the one-liner start script:

```bash
./start.sh              # Full setup + start dashboard
./start.sh --skip-build # Quick start (already built)
./start.sh --rebuild    # Force rebuild
./start.sh --run <file> # Run a specific test
./start.sh --stop       # Stop dashboard
./start.sh --status     # Check services
```

### Manual Setup

```bash
# 1. Initialize config
node packages/cli/dist/cli.js init

# 2. Install browsers
node packages/cli/dist/cli.js install-browsers --chromium

# 3. Configure LLM (e.g., OpenRouter)
node packages/cli/dist/cli.js auth set --config openrouter --type api-key

# 4. Verify
node packages/cli/dist/cli.js auth test --config openrouter

# 5. Start dashboard
ETUS_AGENT_CLI_BIN=./packages/cli/dist/cli.js node packages/cli/dist/cli.js dashboard
```

### As an npm package

```bash
npm install -D etus-agent
npx etus-agent init
npx etus-agent install-browsers --chromium
npx etus-agent dashboard --open
```

---

## Writing Tests

```yaml
# tests/login.yaml
test-id: t_<generated-id>
name: User can log in with valid credentials
steps:
  - Navigate to the login page
  - Enter "user@example.com" in the email field
  - Enter "password123" in the password field
  - Click the Sign In button
  - Verify the dashboard displays a welcome message
```

Run it:
```bash
node packages/cli/dist/cli.js run tests/login.yaml
# or
./start.sh --run tests/login.yaml
```

---

## Configuration

Config file: `etus-agent.config.yaml`

```yaml
workspace:
  testMatch: ['tests/**/*.yaml']
  suiteMatch: ['suites/**/*.suite.yaml']

services:
  dashboard: { port: 3100 }
  cache: { dir: .etus-agent/cache, ttl: 7d }
  accessibility: { enabled: true, standard: wcag2aa }
  memory: { enabled: true, dir: etus-agent-memory }

registry:
  llms:
    - name: openrouter
      provider: openai-compatible
      model: anthropic/claude-sonnet-4
      baseURL: https://openrouter.ai/api/v1
  targets:
    my-app: { platform: web, url: https://myapp.com }

use:
  browser: { name: chromium, headless: true }
  healing: { maxAttempts: 3 }
  planner: { maxSubActions: 10 }
  llm: openrouter
```

---

## Architecture

```
CLI / Dashboard UI / MCP Server
        │
        ▼
   Core Runtime Engine
   ├── OBSERVE  → Platform Adapter (Playwright)
   ├── PLAN     → LLM Planner (AI SDK + tool_use)
   ├── EXECUTE  → Platform Adapter
   └── VERIFY   → LLM Verifier (optional)
        │
        ▼
   Cache │ Memory │ Hooks │ Reporter
```

See full details in [docs/architecture.md](docs/architecture.md).

---

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | System design, package map, subsystems |
| [Sequence Diagrams](docs/sequence-diagrams.md) | Detailed interaction flows |
| [Deployment Guide](docs/deployment-guide.md) | Docker, CI/CD, production setup |
| [Contributor Guide](docs/contributor-guide.md) | Dev workflow, PR process, conventions |
| [Product Onboarding](docs/onboarding/product-business.md) | Business context |
| [Technical Onboarding](docs/onboarding/technical-architecture.md) | Architecture deep-dive |

---

## Roadmap — Coming Soon

| Feature | Description | Status |
|---------|-------------|--------|
| **Reduce Token Usage** | Intelligent context pruning, smaller screenshots, DOM summarization to cut LLM costs by 60-80% | Planned |
| **Full Video Recording** | End-to-end video capture of every test run with timeline sync to steps and assertions | Planned |
| **AI Scenario Suggestions** | LLM analyzes your app and auto-generates test scenarios covering critical paths, edge cases, and user flows | Planned |
| **Auto Bypass CAPTCHA** | Intelligent CAPTCHA detection and bypass for testing environments (reCAPTCHA, hCaptcha, Cloudflare Turnstile) | Planned |
| **Docker-First Execution** | Run entire test suites inside Docker containers with zero local setup — single `docker run` command | Planned |
| **Cloud Device Farm** | Native BrowserStack/Sauce Labs integration for cross-browser testing at scale | Planned |
| **Mobile Testing (Android & iOS)** | Native mobile app testing with Appium — UiAutomator2 (Android) and XCUITest (iOS), gestures, hybrid apps | Planned |
| **Parallel Test Execution** | Run tests concurrently across multiple browser instances with intelligent load balancing | Planned |
| **Visual Regression** | Screenshot comparison with AI-powered diff analysis — detect visual changes beyond pixel matching | Planned |
| **API Testing Integration** | Combine UI tests with API validation — verify frontend matches backend responses | Planned |
| **Test Generation from Production** | Record real user sessions and auto-generate test suites from production traffic patterns | Planned |
| **Slack/Teams Notifications** | Real-time alerts on test failures with context, screenshots, and suggested fixes | Planned |
| **Custom Reporter Plugins** | Extend reporting with custom formats (JUnit XML, Allure, custom dashboards) | Planned |
| **Multi-language Test Authoring** | Write test steps in Vietnamese, Japanese, Korean, or any language — LLM handles translation | Planned |
| **Scheduled Runs** | Cron-based test execution with configurable schedules and alerting | Planned |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Runtime | Node.js >= 24 |
| Language | TypeScript 6 (strict, NodeNext ESM) |
| LLM | Vercel AI SDK |
| Web Automation | Playwright |
| Database | SQLite (better-sqlite3) |
| UI | React 19, Vite, TailwindCSS 4 |
| Build | pnpm workspaces + Turbo |

---

## License

See [LICENSE.md](LICENSE.md) and [NOTICE.md](NOTICE.md).
