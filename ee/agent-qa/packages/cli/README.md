# ETUS

The self-improving Agentic QA harness with Memory.

Write tests in natural language for web. ETUS learns from past runs,
adapts to UI changes, and catches regressions before you ship.

## Features

- **Natural-language test authoring** — Define actions and assertions in human language while agents work from visible roles, labels, and screen state
- **Self-healing execution** — When any sub-action fails, ETUS re-observes the UI and tries a different path in the same run
- **Memory-aware runs** — Builds execution memory from every run and applies context to future runs
- **Smart cache** — Reuses validated action plans across runs to reduce LLM costs and runtime
- **Web testing** — Playwright-based (Chromium, Firefox, WebKit)
- **Dashboard + MCP** — Visual dashboard for humans, MCP tools for coding agents
- **Sandboxed hooks** — Node, Bun, Python, Bash hooks in Docker containers
- **Accessibility checks** — WCAG 2.0 AA/AAA auditing per step via axe-core
- **Bring your own LLM** — OpenAI-compatible, Anthropic-compatible, Gemini, or subscription auth

## Install

```sh
npm install -D etus-agent
```

For Codex or Claude Code subscription auth:

```sh
npm install -D @etus/agent-subscription-auth
```

Docker is required for hooks (Node, Bun, Python, Bash sandbox containers).

## Quickstart

```sh
# Initialize project
npx etus-agent init

# Install browser support
npx etus-agent install-browsers --chromium

# Start dashboard
npx etus-agent dashboard --open
```

## Run Tests

```sh
# Run a single test
npx etus-agent run tests/login.yaml

# Run all tests
npx etus-agent run

# Run a suite
npx etus-agent run suites/smoke.suite.yaml
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `init` | Initialize project (creates config, examples) |
| `run` | Execute tests or suites |
| `dashboard` | Start web dashboard |
| `mcp` | Start MCP server (for IDE integration) |
| `auth set` | Save LLM API key |
| `auth test` | Verify LLM connection |
| `auth status` | Show credential status |
| `auth login` | OAuth login for subscription providers |
| `doctor` | Validate environment |
| `install-browsers` | Install Playwright browsers |
| `config get/set` | Manage config values |
| `validate` | Validate test/suite files |
| `cache` | Manage action cache |
| `clean-memory` | Prune stale observations |

## Configuration

Config file: `etus-agent.config.yaml`

```yaml
workspace:
  testMatch: ['tests/**/*.yaml']
  suiteMatch: ['suites/**/*.suite.yaml']

registry:
  llms:
    - name: default
      provider: openai-compatible
      model: anthropic/claude-sonnet-4
      baseURL: https://openrouter.ai/api/v1
  targets:
    my-app: { platform: web, url: https://myapp.com }

use:
  browser: { name: chromium, headless: true }
  llm: default
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `ETUS_AGENT_DASHBOARD_PORT` | Dashboard port (default: 3100) |
| `ETUS_AGENT_MCP_PORT` | MCP server port (default: 3471) |
| `ETUS_AGENT_CACHE_DIR` | Cache directory |
| `ETUS_AGENT_CACHE_TTL` | Cache TTL (e.g., "7d") |
| `ETUS_AGENT_LOG_LEVEL` | Log level (debug/info/warn/error) |
| `ETUS_AGENT_HEADLESS` | Browser headless mode (true/false) |

## Roadmap

| Feature | Status |
|---------|--------|
| Reduce Token Usage (context pruning, DOM summarization) | Coming Soon |
| Full Video Recording (end-to-end with timeline sync) | Coming Soon |
| AI Scenario Suggestions (auto-generate test cases) | Coming Soon |
| Auto Bypass CAPTCHA (reCAPTCHA, hCaptcha, Turnstile) | Coming Soon |
| Docker-First Execution (single `docker run`) | Coming Soon |
| Cloud Device Farm (BrowserStack, Sauce Labs) | Coming Soon |
| Mobile Testing (Android & iOS) | Coming Soon |
| Visual Regression (AI-powered screenshot diff) | Coming Soon |
| Scheduled Runs (cron-based execution) | Coming Soon |

## Links

- [License](LICENSE.md)
- [Notice](NOTICE.md)
