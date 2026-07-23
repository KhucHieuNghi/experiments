# ETUS — Deployment Guide

> How to build, package, and deploy ETUS in different environments.

---

## Table of Contents

1. [Docker Images](#1-docker-images)
2. [Image Architecture](#2-image-architecture)
3. [Building Docker Images Locally](#3-building-docker-images-locally)
4. [Running with Docker](#4-running-with-docker)
5. [Release Pipeline](#5-release-pipeline)
6. [Environment Setup](#6-environment-setup)
7. [Production Considerations](#7-production-considerations)
8. [CI/CD Integration](#8-cicd-integration)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Docker Images

ETUS ships 6 Docker images under the `etus/` namespace:

| Image | Purpose | Base | Platforms |
|-------|---------|------|-----------|
| `etus/etus-agent-web` | Web testing (Playwright + all browsers) | `node:24-slim` | linux/amd64 |
| `etus/etus-agent-android` | Web + Android (Appium + UiAutomator2) | `node:24-slim` | linux/amd64 |
| `etus/etus-agent-hook-node` | Hook sandbox (Node 24) | `node:24-slim` | linux/amd64, linux/arm64 |
| `etus/etus-agent-hook-bun` | Hook sandbox (Bun 1.x) | `oven/bun:1-slim` | linux/amd64, linux/arm64 |
| `etus/etus-agent-hook-python` | Hook sandbox (Python 3.12) | `python:3.12-slim` | linux/amd64, linux/arm64 |
| `etus/etus-agent-hook-bash` | Hook sandbox (Alpine + bash/curl/jq) | `alpine:3.21` | linux/amd64, linux/arm64 |

---


## 2. Image Architecture

### Web Image (Multi-Stage Build)

```
┌─────────────────────────────────────────────────────┐
│ Stage 1: builder                                     │
├─────────────────────────────────────────────────────┤
│ FROM node:24-slim                                    │
│ • corepack enable + pnpm 10.6.1                     │
│ • Copy package manifests (layer caching)            │
│ • pnpm install --frozen-lockfile                    │
│ • Copy source + pnpm build                          │
│ • pnpm prune --prod                                 │
└─────────────────────────┬───────────────────────────┘
                          │ COPY --from=builder
                          ▼
┌─────────────────────────────────────────────────────┐
│ Stage 2: runtime                                     │
├─────────────────────────────────────────────────────┤
│ FROM node:24-slim                                    │
│ • ca-certificates only                              │
│ • Full built monorepo at /etus-agent                  │
│ • CLI symlink: /usr/local/bin/etus-agent              │
│ • Playwright browsers installed (--all --with-deps) │
│ • WORKDIR /tests (mount point for user project)     │
│ • ENTRYPOINT ["etus-agent"]                           │
└─────────────────────────────────────────────────────┘
```

### Android Image (extends Web)

Same multi-stage pattern, plus:
- OpenJDK 17 JRE
- Android SDK (cmdline-tools) with platform-tools, API 36, x86_64 system image
- Pre-created AVD (`etus_agent_api_36` on Pixel 6)
- Appium + UIAutomator2 driver globally installed
- Playwright browsers

### Hook Runner Images (Minimal)

Hook runner images are intentionally minimal — just a runtime + non-root user:

```
┌───────────────────────────────┐
│ Hook Runner (node/bun/python) │
├───────────────────────────────┤
│ • Runtime only (no ETUS code) │
│ • Non-root user: hookuser     │
│ • WORKDIR /workspace          │
│ • No network by default       │
│ • Read-only filesystem        │
└───────────────────────────────┘
```

The bash runner adds `curl`, `jq`, and `tini` as an init process.

---

## 3. Building Docker Images Locally

```bash
# From repo root

# Web image
docker build -f docker/Dockerfile.web -t etus/etus-agent-web .

# Android image (large — includes Android SDK)
docker build -f docker/Dockerfile.android -t etus/etus-agent-android .

# Hook runners (fast — minimal images)
docker build -f docker/Dockerfile.hooks-node -t etus/etus-agent-hook-node .
docker build -f docker/Dockerfile.hooks-bun -t etus/etus-agent-hook-bun .
docker build -f docker/Dockerfile.hooks-python -t etus/etus-agent-hook-python .
docker build -f docker/Dockerfile.hooks-bash -t etus/etus-agent-hook-bash .
```

Verify local builds:
```bash
pnpm run release:docker:check
```

---


## 4. Running with Docker

### Web Testing

```bash
# Run a specific test file
docker run --rm \
  -v $(pwd):/tests \
  -e OPENROUTER_API_KEY=sk-or-... \
  etus/etus-agent-web run --target my-app tests/login.yaml

# Start dashboard inside container
docker run --rm -p 3100:3100 \
  -v $(pwd):/tests \
  etus/etus-agent-web dashboard --host 0.0.0.0

# Run all tests with custom config
docker run --rm \
  -v $(pwd):/tests \
  -v $(pwd)/etus-agent.config.yaml:/tests/etus-agent.config.yaml \
  etus/etus-agent-web run
```

### Android Testing

```bash
# Requires KVM for emulator acceleration
docker run --rm --privileged \
  -v $(pwd):/tests \
  --device /dev/kvm \
  etus/etus-agent-android run --target my-android-app
```

### Environment Variables in Docker

```bash
docker run --rm \
  -v $(pwd):/tests \
  -e ETUS_AGENT_HEADLESS=true \
  -e ETUS_AGENT_LOG_LEVEL=debug \
  -e ETUS_AGENT_DASHBOARD_PORT=3100 \
  etus/etus-agent-web run
```

### Using Secrets

```bash
# Mount secrets file (never bake into image)
docker run --rm \
  -v $(pwd):/tests \
  -v $(pwd)/.env.secrets.local:/tests/.env.secrets.local:ro \
  etus/etus-agent-web run
```

---

## 5. Release Pipeline

The release process follows a strict gate-based sequence:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Release Gate Plan                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1.  pnpm install --frozen-lockfile                              │
│  2.  Release preflight checks                                    │
│  3.  Write shared version (semver 0.x.x across all packages)    │
│  4.  Write PostHog project key (release-time injection)          │
│  5.  pnpm typecheck                                              │
│  6.  pnpm test                                                   │
│  7.  pnpm build                                                  │
│  8.  pnpm run validate:skills                                    │
│  9.  pnpm run validate:publish                                   │
│ 10.  Stage packages (.release/staged-packages/)                  │
│ 11.  Release postbuild verification                              │
│ 12.  Create release commit and tag                               │
│ 13.  git push                                                    │
│ 14.  npm publish (trusted publishing, no NPM_TOKEN)             │
│ 15.  Subscription auth publish                                   │
│ 16.  GitHub release publish                                      │
│ 17.  Docker publish                                              │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Release Scripts

| Script | Command | Purpose |
|--------|---------|---------|
| `release:dry-run` | `pnpm run release:dry-run` | Simulate full release without publishing |
| `release:verify` | `pnpm run release:verify` | Run preflight + postbuild verification |
| `release:publish` | `pnpm run release:publish` | Publish staged packages to npm |
| `release:docker` | `pnpm run release:docker` | Build + push Docker images |
| `release:github` | `pnpm run release:github` | Create GitHub release with changelog |

### Package Publishing

- **Registry:** npm public registry
- **Auth:** GitHub Actions trusted publishing (OIDC, no NPM_TOKEN)
- **npm version requirement:** >= 11.5.1
- **Publish order:** Derived from dependency graph (ids → core → adapters → mcp → dashboard → cli)
- **Version strategy:** Shared single version across all `@etus/agent-*` packages (0.x.x semver)
- **Required files:** Every published package must include `package.json`, `LICENSE.md`, `NOTICE.md`, and `dist/`

### Docker Publishing

- **Namespace:** `etus/` (hardcoded, validated)
- **Tags:** `<version>` + `latest`
- **Platforms:** amd64 for runtime images, amd64+arm64 for hook runners

---


## 6. Environment Setup

### Local Development

| Requirement | Minimum | Check |
|-------------|---------|-------|
| Node.js | 24.x | `node --version` |
| pnpm | 10.6.x | `pnpm --version` |
| Docker | 20.x+ | `docker --version` |
| Playwright browsers | Latest | `etus-agent install-browsers` |

### For Android Testing (additional)

| Requirement | Details |
|-------------|---------|
| Java JDK | 17+ (for Android SDK tools) |
| Android SDK | API 36, platform-tools, emulator |
| Appium | Global install + UiAutomator2 driver |
| KVM | Required for emulator acceleration on Linux |

### For iOS Testing (additional)

| Requirement | Details |
|-------------|---------|
| macOS | Required (Xcode only runs on macOS) |
| Xcode | Latest stable |
| Appium | Global install + XCUITest driver |
| iOS Simulator | Or physical device with UDID configured |

### LLM Provider Setup

At minimum one LLM provider must be configured:

```bash
# Option A: Direct API key (OpenRouter, OpenAI, Anthropic, Gemini)
etus-agent auth set --config <name> --type api-key

# Option B: Subscription auth (Codex, Claude Code)
etus-agent auth login --config <name>
```

### Health Check

```bash
# Validates entire environment
etus-agent doctor
```

The `doctor` command checks:
- Node version compatibility
- Config file presence and schema validity
- Secrets file accessibility
- Docker availability
- LLM credential status and connection test
- Playwright browser installation
- Appium/driver installation (if mobile configured)
- Android SDK / Xcode availability (if mobile configured)
- Test file discovery
- Project structure validation

---

## 7. Production Considerations

### Security

| Concern | Mitigation |
|---------|-----------|
| LLM API keys | Stored in `~/.etus-agent/auth.json` (user-level), never in config YAML |
| Secrets in tests | Use `secretsFile` (.env.secrets.local), auto-redacted in logs |
| Hook isolation | Docker sandbox: read-only FS, no network, memory/CPU/PID limits |
| Dashboard binding | Loopback only (127.0.0.1) by default |
| MCP endpoint | Loopback only (127.0.0.1) by default |
| Auth state files | Redacted in reporter output, not committed |

### Performance

| Dimension | Strategy |
|-----------|----------|
| LLM cost | Sub-action caching (TTL-based), screenshot compression (sharp) |
| Execution speed | Parallel web tests, cache-first planning |
| Memory | Screenshot compression to configurable max size |
| Disk | TTL-based cache expiry (default 7d), memory observation pruning |

### Scaling Patterns

```
┌─────────────────────────────────────────────────────┐
│ Single Machine (Default)                             │
├─────────────────────────────────────────────────────┤
│ CLI → Local browser/emulator → Dashboard (SQLite)   │
│ Best for: dev, small CI pipelines                    │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ Docker Container (CI)                                │
├─────────────────────────────────────────────────────┤
│ Docker image → Headless browsers → Artifacts out    │
│ Best for: CI/CD pipelines, parallel matrix runs     │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ Farm / Cloud Provider                                │
├─────────────────────────────────────────────────────┤
│ CLI → BrowserStack/remote Appium grid               │
│ Config: registry.providers + registry.devices       │
│ Best for: cross-browser, real-device mobile testing │
└─────────────────────────────────────────────────────┘
```

### Artifact Management

| Artifact | Location | Retention |
|----------|----------|-----------|
| Screenshots | `.etus-agent/artifacts/` | Per run, managed by dashboard |
| Videos | `.etus-agent/artifacts/` | Per run, optional |
| Cache | `.etus-agent/cache/` | TTL-controlled (default 7d) |
| SQLite DB | `.etus-agent/dashboard.sqlite` | Persistent, backed up manually |
| Memory | `etus-agent-memory/` | Persistent, prunable via `clean-memory` |
| Auth store | `~/.etus-agent/auth.json` | Persistent, user-level |

### Networking

| Endpoint | Default | Configurable |
|----------|---------|--------------|
| Dashboard UI + API | `127.0.0.1:3100` | `services.dashboard.port` / `ETUS_AGENT_DASHBOARD_PORT` |
| MCP HTTP | `127.0.0.1:3471` | `services.mcp.port` / `ETUS_AGENT_MCP_PORT` |
| MCP stdio | stdin/stdout | N/A (transport-level) |

To expose the dashboard in Docker or on a network, bind to `0.0.0.0`:
```bash
etus-agent dashboard --host 0.0.0.0
```

---


## 8. CI/CD Integration

### GitHub Actions Example

```yaml
name: E2E Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: etus/etus-agent-web:latest

    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        run: |
          etus-agent auth set --config default --type api-key "$OPENAI_API_KEY"
          etus-agent run --no-cache

      - name: Upload artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-artifacts
          path: .etus-agent/artifacts/
```

### GitLab CI Example

```yaml
e2e-tests:
  image: etus/etus-agent-web:latest
  variables:
    ETUS_AGENT_HEADLESS: "true"
    ETUS_AGENT_LOG_LEVEL: "info"
  script:
    - etus-agent auth set --config default --type api-key "$OPENAI_API_KEY"
    - etus-agent run
  artifacts:
    when: always
    paths:
      - .etus-agent/artifacts/
    expire_in: 7 days
```

### Parallel Execution in CI

```yaml
# GitHub Actions matrix strategy
jobs:
  test:
    strategy:
      matrix:
        suite: [smoke, auth, checkout, admin]
    steps:
      - run: etus-agent run suites/${{ matrix.suite }}.suite.yaml
```

### Docker Compose for Full Stack

```yaml
# docker-compose.yml
services:
  etus-agent:
    image: etus/etus-agent-web:latest
    volumes:
      - .:/tests
      - ./.env.secrets.local:/tests/.env.secrets.local:ro
    environment:
      - ETUS_AGENT_HEADLESS=true
    ports:
      - "3100:3100"
    command: ["dashboard", "--host", "0.0.0.0"]
```

---

## 9. Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| `Config file not found` | Run `etus-agent init` or ensure `etus-agent.config.yaml` exists |
| `Missing credential` | Run `etus-agent auth set --config <name> --type api-key` |
| `Browser not installed` | Run `etus-agent install-browsers --all --with-deps` |
| `Docker not available` | Install Docker and ensure daemon is running (needed for hooks) |
| `Hook timed out` | Increase `timeout` in hook definition or check network flag |
| `Model context exceeded` | Increase `contextWindow` on LLM config or reduce `previousStepCount` |
| `Step timed out` | Increase `use.timeout.step` in config |
| `Cache stale results` | Run `etus-agent cache purge` or use `--no-cache` flag |

### Debug Mode

```bash
# Maximum verbosity
etus-agent run --log-level debug --verbose

# Or via environment
ETUS_AGENT_LOG_LEVEL=debug etus-agent run
```

### Validate Without Running

```bash
# Check config is valid
etus-agent doctor

# Validate test files parse correctly
etus-agent validate tests/**/*.yaml

# Verify publish surface (release check)
pnpm run validate:publish
```
