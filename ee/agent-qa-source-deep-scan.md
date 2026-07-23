# agent-qa Source Deep Scan

Ngay doc: 2026-07-22

Repo local: `/Users/nghi.khuc/Documents/pros/per/experiments/ee/agent-qa`

Trang tham chieu ban dau:

- https://vostride.com/docs/agent-qa
- https://vostride.com/docs/agent-qa/dashboard
- https://github.com/vostride/agent-qa

## 1. Executive Summary

`agent-qa` la mot monorepo TypeScript xay mot he thong QA agentic cho web va mobile. Gia tri san pham khong nam o dashboard don le, ma nam o vong lap:

1. Nguoi dung viet test bang ngon ngu tu nhien trong YAML.
2. Runtime quan sat UI thuc te bang Playwright/Appium.
3. LLM planner chon action co schema chat.
4. Adapter thuc thi action tren browser/device.
5. Verifier LLM kiem tra step da dat muc tieu chua.
6. Cache luu sub-action da verify de giam chi phi lan sau.
7. Memory curator rut kinh nghiem tu run passed/healed/failed va inject vao lan sau.
8. Dashboard/MCP/skills bien no thanh workflow cho developer va coding agent.

Kien truc hien tai la "local-first control plane": file YAML, memory, cache, auth-state, artifact, SQLite DB deu nam trong workspace `.agent-qa` hoac config-defined paths. Dashboard server chi la API + static UI + queue + runner wrapper cho CLI.

Ket luan quan trong neu muon "bien thanh cua minh": code nay rat phu hop lam technical reference hoac internal fork. Nhung license la FSL-1.1-ALv2, nen viec ban thanh commercial product/service thay the truc tiep la Competing Use bi han che cho den khi version cu the duoc future-license sang Apache 2.0 sau 2 nam. Neu muc tieu la commercial SaaS rieng, nen can clean-room rebuild hoac doi license.

## 2. License Va Rui Ro Ownership

File `LICENSE.md` khai bao:

- License hien tai: Functional Source License 1.1, ALv2 Future License.
- Permitted purpose: noi bo, non-commercial education/research, professional services cho licensee hop le.
- Competing Use: lam software thanh commercial product/service thay the agent-qa hoac san pham co function tuong tu.
- Future license: moi version duoc chuyen sang Apache 2.0 vao ngay ky niem thu 2 ke tu khi version do duoc cong bo.
- Trademark: khong co quyen dung trademark/product names ngoai viec hien thi license details/identify origin.

Khuyen nghi thuc te:

- Neu dung noi bo: co the fork va customize, nhung giu license/copyright notices.
- Neu ban dich vu/commercial fork: khong nen copy source hien tai lam base. Nen dung doc nay de viet clean-room spec, hoac xin commercial license.
- Neu doi brand: can thay tat ca brand surfaces `vostride`, `agent-qa`, package names, Docker images, env vars, MCP tool names, docs URLs, analytics/posthog project, skill names.

## 3. Business Scan

### 3.1 Khach Hang Muc Tieu

San pham danh cho:

- Developer/QA team muon viet E2E tests nhanh bang natural language.
- Startup/product team co UI thay doi lien tuc, test selector-based hay vo.
- Team dung coding agents va muon agent co kha nang tao/sua/chay/triage tests.
- Mobile team can test Android/iOS qua Appium/BrowserStack ma khong muon viet script thap.
- Team muon test assets reviewable trong git thay vi SaaS black-box.

### 3.2 Pain Points

No giai quyet cac van de:

- Playwright/Cypress selectors de vo khi UI drift.
- Manual QA ton nhieu effort.
- AI testing tool thieu observability va khong reviewable.
- E2E flaky khong biet vi app loi, selector loi, infra loi, auth loi, hay data loi.
- Mobile E2E setup phuc tap, Appium/device farm kho tich hop.
- Test result khong co reasoning/action trace du de debug.

### 3.3 Value Proposition

Core promise:

- Viet test bang ngon ngu tu nhien.
- Agent tu quan sat UI va chon hanh dong phu hop.
- Self-healing trong cung run khi action fail hoac verifier chua dong y.
- Memory giup run sau bot lap loi.
- Cache giam token/time khi man hinh tuong tu.
- Dashboard cho human inspect run, step, screenshot, logs, cost, memory.
- MCP/skills cho AI agent tao/sua/chay/triage test.

### 3.4 Moat Ky Thuat

Moat chinh:

- Schema-driven action tools: LLM bi gioi han vao action registry.
- Observe-plan-execute-verify loop co sub-action cache.
- Memory co curator, trust, FTS, security scanner, circuit breaker.
- Artifact model luu config/source/runtime/memory/errors de debug.
- Multi-platform adapters cung chung contract.
- Dashboard local-first, file-backed authoring, SQLite analytics.
- MCP facade cho coding agents.

## 4. Monorepo Architecture

Root:

- Package manager: `pnpm@10.6.1`.
- Node engine: `>=24`.
- Build orchestration: Turbo.
- Package build: `tsup`.
- UI build: Vite.
- Tests: Vitest.

Workspace packages:

| Package | Vai tro |
| --- | --- |
| `@vostride/agent-qa-ids` | Canonical ID helpers cho test/suite/hook/run/observation. |
| `@vostride/agent-qa-core` | Runtime schemas, parser, planner/verifier, runner, tools, reporters, auth, cache, memory, analytics, hooks, workspace contracts. |
| `@vostride/agent-qa-web` | Playwright adapter, DOM/ARIA extraction, action validation, smart wait, accessibility. |
| `@vostride/agent-qa-android` | WebdriverIO/Appium Android adapter va session creation. |
| `@vostride/agent-qa-ios` | WebdriverIO/Appium iOS adapter va session creation. |
| `@vostride/agent-qa-dashboard` | Local dashboard server, SQLite DB, run queue, routes, reporter, live editor, Appium ownership. |
| `@vostride/agent-qa-dashboard-ui` | React/Vite dashboard UI assets. |
| `@vostride/agent-qa-mcp` | MCP server/tools/resources/prompts. |
| `agent-qa` | Public CLI package va packaged skills. |

Repo co khoang:

- 905 files.
- 769 TypeScript/TSX files.
- 314 test/spec files.

## 5. Runtime Flow End-to-End

### 5.1 CLI Run Flow

File chinh: `packages/cli/src/commands/run.ts`

Luon di qua cac buoc:

1. Load config `agent-qa.config.yaml`.
2. Apply env override va CLI flags.
3. Resolve workspace paths, targets, devices, auth state, env vars, secrets.
4. Discover test/suite files theo `workspace.testMatch` va `workspace.suiteMatch`.
5. Parse YAML bang core parser.
6. Merge `use` blocks: global config -> suite -> test -> CLI.
7. Resolve LLM planner/verifier models va auth.
8. Tao platform adapter theo target platform.
9. Tao reporters: console, junit, stdout-live, dashboard.
10. Chay test/suite bang core runner.
11. Capture artifact, screenshots/video/logs/token/memory.
12. Update dashboard DB neu dashboard reporter bat.

Run command options quan trong:

- `--browser`
- `--platform`
- `--headless` / `--no-headless`
- `--no-cache`
- `--no-memory`
- `--bail`
- `--dry-run`
- `--list-tests`
- `--junit-output`
- `--screenshot-dir`
- `--screenshot-mode`
- `--reporter`
- `--record`
- `--config-debug`
- `--test`
- `--suite`
- `--all`
- `--device`
- `--var`
- `--run-attr`

### 5.2 Core Runner Flow

File chinh:

- `packages/core/src/agent/runner.ts`
- `packages/core/src/agent/loop.ts`

`runTest()` quan ly test-level:

- setup adapter.
- setup reporter.
- timeout/cancel handling.
- optional auth-state.
- memory provider init.
- setup/teardown hooks.
- inline hooks.
- inline web `runJS`.
- variable interpolation.
- per-step execute loop.
- screenshot/accessibility/log capture.
- memory curation sau run.

`executeStep()` quan ly step-level:

1. Observe live UI.
2. Compute step hash va screen hash.
3. Thu dung cache sub-action neu hop le.
4. Neu cache miss, goi LLM planner.
5. Validate tool/action schema.
6. Execute action qua adapter.
7. Neu action fail, re-observe va replan den max attempts.
8. Neu planner noi step complete, goi verifier LLM.
9. Neu verifier pass, cache sub-action va step pass.
10. Neu verifier reject, them feedback vao context va tiep tuc.
11. Neu vuot max sub-actions, step fail.

Default max sub-actions la 50, co the override qua planner config.

### 5.3 Planner/Verifier

Planner:

- File: `packages/core/src/agent/planner.ts`
- Dung AI SDK `generateText`.
- Bat buoc tool call (`toolChoice: 'required'`).
- Tool schema duoc build tu action registry.
- Co screenshot neu adapter cung cap.
- Neu khong co tool call hoac tool khong hop le, fail ro rang.

Verifier:

- File: `packages/core/src/agent/verifier.ts`
- Dung structured output object:
  - `success`
  - `reasoning`
  - `isAppError`
- Chi goi khi planner danh dau `stepComplete`.
- Neu `isAppError`, runtime coi day la loi ung dung thay vi tiep tuc heal.

### 5.4 Action Registry

File:

- `packages/core/src/tools/actions/index.ts`
- `packages/core/src/tools/builder.ts`
- `packages/core/src/tools/actions/platform-filters.ts`

Action set:

- Web/native common: `click`, `fill`, `select`, `navigate`, `scroll`, `delay`, `waitFor`, `assert`, `keypress`, `clearText`, `openLink`, `drag`, `tapCoordinate`, `setVariable`.
- Web-only: `hover`, `paste`, `keyDown`, `keyUp`, `refresh`, `navigateHistory`, `readConsoleLogs`, `readNetworkLogs`, `readCookies`, `setCookies`, `readLocalStorage`, `setLocalStorage`, `newTab`, `switchTab`, `doubleClick`, `rightClick`, `waitForUrl`, `fileUpload`, `copy`.
- Mobile-only: `tap`, `swipe`, `longpress`, `hideKeyboard`, `launchApp`, `stopApp`, `setOrientation`, `pinch`, `multiTap`, `executeScript`, `nativeSelect`.

Moi action tool input deu co:

- `reasoning`
- `confidence`
- `stepComplete`
- optional `stepFailed`
- action-specific fields.

## 6. Data Model Va File Model

### 6.1 Workspace Config

Demo config: `demo-project/agent-qa.config.yaml`

Required workspace keys:

- `workspace.testMatch`
- `workspace.suiteMatch`
- `workspace.hooksFile`
- `workspace.agentRules`
- `workspace.envFile`
- `workspace.secretsFile`

Runtime defaults:

- `.agent-qa`
- `.agent-qa/cache`
- `.agent-qa/auth-states`
- `.agent-qa/artifacts`
- `.agent-qa/artifacts/screenshots`
- `.agent-qa/artifacts/videos`
- `.agent-qa/runs.db`

### 6.2 Test YAML

Schema: `packages/core/src/schema/test-schema.ts`

Fields:

- `test-id`: canonical `t_...`
- `name`
- `target`
- optional `context`
- optional `use`
- optional `meta`
- optional `setup`
- optional `teardown`
- `steps`: string step hoac object step.

Step object supports:

- `step`
- `timeout`
- `retries`
- `screenshot`
- `capture`
- `maxAttempts`

Capture supports:

- `regex`
- `selector`
- `ai`

### 6.3 Suite YAML

Schema: `packages/core/src/schema/suite-schema.ts`

Fields:

- optional `suite-id`
- `name`
- optional `target`
- optional `context`
- optional `setup`
- optional `teardown`
- `tests`: array `{ test, id }`
- optional `use`

Suite execution creates parent/child run rows. Parent run status derives from child statuses.

### 6.4 SQLite Dashboard DB

Files:

- `packages/dashboard-server/src/db/schema.ts`
- `packages/dashboard-server/src/db/database.ts`

Tables:

- `runs`: run metadata, status, duration, attributes, platform, test/suite IDs, retry/parent info, model/provider, failure summary, memory log.
- `steps`: per-step result, action, reasoning, screenshots, token usage, sub-actions, console/network logs, variable snapshot, accessibility.
- `reasoning_traces`: observe/plan/execute/verify timing and reasoning.
- `logs`: structured logs by run/step/source/level.
- `execution_logs`: hook, appium-script, runjs logs.
- `token_events`: model token/cost analytics.
- `run_artifacts`: JSON artifact payload by run.

SQLite setup:

- `journal_mode = WAL`
- `busy_timeout = 5000`
- migration via `PRAGMA user_version`

### 6.5 Run Artifact

File: `packages/core/src/artifacts/run-artifact.ts`

Artifact schema v1 stores:

- `config`: raw config, parsed config, effective config, env/secrets metadata, hooks, model, runtime, timeouts, cache, memory.
- `source`: test/suite YAML, resolved definition, suite members.
- `runtime`: status, duration, video, failure summary.
- `memory`: curator log and deltas.
- `errors`: terminal errors with code/message/phase.
- `metadata`: run attributes.

Day la mot diem rat manh cua san pham: run khong chi co pass/fail ma co snapshot de debug va reproduce.

## 7. Platform Adapters

### 7.1 Shared Adapter Contract

File: `packages/core/src/types/platform.ts`

Adapter contract:

- `setup(config)`
- `cleanup()`
- `observe(options)`
- `execute(action)`
- optional `screenshot(options)`
- optional `drainConsoleLogs()`
- optional `drainNetworkLogs()`

`ScreenState` gom:

- accessibility/tree text.
- element refs.
- URL.
- timestamp.
- metadata: viewport, ref map, image dimensions, DOM context.

### 7.2 Web Adapter

Files:

- `packages/web/src/adapter.ts`
- `packages/web/src/observer.ts`
- `packages/web/src/action-validator.ts`
- `packages/web/src/smart-wait.ts`
- `packages/web/src/accessibility.ts`

Tech:

- Playwright core.
- Browser: chromium/firefox/webkit.
- Chromium launch args disable automation-controlled flag.
- Context supports viewport, video, auth-state storageState.
- Clipboard-write granted for Chromium.
- Init script sets `navigator.webdriver` false.

Observation:

- Dung Playwright `ariaSnapshot`.
- Gan refs `e1`, `e2`, ...
- Enrich bounding boxes bang bulk browser evaluate.
- Hide `[data-agent-qa-internal]` khi snapshot.
- DOM extraction optional, best effort.

Logs:

- Console buffer max 1000.
- Network buffer max 500.
- Network response body truncate 32KB.

Action validation:

- Prevent fill into non-fillable roles.
- Prevent select into non-selectable roles.
- Unknown roles permissive de khong block LLM qua muc.

### 7.3 Android Adapter

Files:

- `packages/android/src/adapter.ts`
- `packages/android/src/session.ts`

Tech:

- WebdriverIO + Appium UiAutomator2.
- Appium URL tu `AGENT_QA_APPIUM_URL`, config, hoac default `http://localhost:4723`.
- Supports browser mode, local app path, AVD, serial, platformVersion, appPackage/appActivity.
- BrowserStack/farmSession support.
- `appState` map sang `noReset`.
- Co logcat parsing va PID filter neu `AGENT_QA_ANDROID_USE_MOBILE_SHELL=1`.

### 7.4 iOS Adapter

Files:

- `packages/ios/src/adapter.ts`
- `packages/ios/src/session.ts`

Tech:

- WebdriverIO + Appium XCUITest.
- Supports browser mode, bundleId/app path/UDID/platformVersion.
- BrowserStack/farmSession support.
- `showIOSLog: true`.
- Handles BrowserStack iOS `DELETE /actions` unsupported case.
- Parses syslog/Appium logs.
- Screenshot alignment tu physical pixels ve logical window.

## 8. Cache System

Files:

- `packages/core/src/cache/file-cache.ts`
- `packages/core/src/cache/hasher.ts`
- `packages/core/src/agent/observation.ts`

Cache la file-based action cache:

- Path: `dir/stepHash/screenHash.json` cho old API.
- Sub-action path: `dir/stepHash/screenHash/sub-N.json`.
- Versioned by `CACHE_SCHEMA_VERSION`.
- TTL enforced.
- Invalid JSON = cache miss.
- Khi planner cache miss o sub-action N, invalidates tu N tro di.
- Neu runtime step co secret templates, cache cu co redacted secret marker bi invalidate.

Hash step dua vao:

- instruction.
- platform.
- config content.
- test file content.
- step index.
- suite file content.
- suite test index.

## 9. Memory System

### 9.1 Storage Model

Files:

- `packages/core/src/memory/local-provider.ts`
- `packages/core/src/memory/observation-io.ts`
- `packages/core/src/memory/schema.ts`
- `packages/core/src/memory/memory-index.ts`

Memory la file-backed markdown observation:

- product scope: `products/<product>/obs_*.md`
- suite scope: `suites/<suiteId>/obs_*.md`
- test scope: `tests/<testId>/obs_*.md`

Observation frontmatter:

- `id`
- `title`
- `trust`
- `created`
- `last_confirmed`
- `confirmed_count`
- `contradicted_count`
- `source_test`
- suite-only: `position`, `suite_snapshot`

Body la `content`.

### 9.2 Query

Local provider dung SQLite FTS5 in-memory index:

- Query theo sanitized step text.
- Filter `trust >= minTrust`.
- Sort theo rank * trust.
- Limit `maxInjections`.
- Inject format `<memory-context>`.
- Warning ro rang: memory chi la hypothesis, live observation la truth.

### 9.3 Curator

File: `packages/core/src/memory/curator.ts`

Sau run:

- Neu test failed, `deprecateOnFailure()` giam trust cua observation da inject vao failed step.
- Neu passed, curator LLM chon A.U.D.N:
  - ADD observation moi.
  - UPDATE/confirm observation cu.
  - DEPRECATE observation sai.
  - NOOP.

Trust logic:

- Add moi: trust `0.5`.
- Confirm: tang trust theo `trustConfirmDelta`, default `0.02`, cap `1.0`.
- Contradict/deprecate: giam trust theo `trustContradictDelta`, default `0.05`.
- Trust ve 0 thi delete observation.
- Suite stale cleanup: neu `suite_snapshot` doi, delete suite observation cu.

### 9.4 Memory Safety

File: `packages/core/src/memory/security-scanner.ts`

Blocks:

- prompt injection phrases.
- role/system override.
- bypass restrictions.
- exfiltration qua curl/wget.
- secret file reads.
- SSH backdoor/access patterns.
- invisible unicode.

### 9.5 Circuit Breaker

File: `packages/core/src/memory/circuit-breaker.ts`

Memory co circuit breaker:

- So sanh fail rate khi co memory voi baseline.
- Trip neu memory lam fail rate tang qua threshold.
- Default window 20, baseline 3, threshold 0.15.

Day la chi tiet product tot: memory co the sai, nen phai co co che tu tat.

## 10. Hooks And Sandbox

Files:

- `packages/core/src/hooks/sandbox-runner.ts`
- `packages/core/src/hooks/schema.ts`
- `packages/core/src/hooks/types.ts`

Hooks chay trong Docker sandbox:

- Runtimes: node, bun, python, bash.
- Images:
  - `vostride/agent-qa-hook-runner-node`
  - `vostride/agent-qa-hook-runner-bun`
  - `vostride/agent-qa-hook-runner-python`
  - `vostride/agent-qa-hook-runner-bash`
- Pull policy: `if-not-present` default, ho tro `always`, `never`.
- Docker run hardening:
  - `--rm`
  - `--init`
  - workspace mounted read/write vao temp workspace.
  - `--memory 512m`
  - `--cpus 1`
  - `--pids-limit 256`
  - `--read-only`
  - optional `--network none`

Hook outputs:

- stdout/stderr captured.
- return variables tu `/tmp/agent-qa.env`.
- reserved auth-state vars bi strip.
- values match known secrets bi strip/redacted.

Use cases:

- login/API setup.
- seed fixtures.
- upload test files.
- clean data.
- tao variables runtime cho steps.

## 11. Auth, Secrets, Auth-State

### 11.1 LLM Auth

Files:

- `packages/cli/src/llm-utils.ts`
- `packages/core/src/auth/resolver.ts`

Providers:

- `openai-compatible`
- `anthropic-compatible`
- `openai-subscription`
- `anthropic-subscription`
- `gemini`

Credential types:

- API key.
- Bearer token.
- OAuth via auth plugin.

Compatible providers co optional auth trong mot so truong hop. Other providers can require plugins.

### 11.2 Runtime Secrets

CLI requires `workspace.secretsFile`.

Secrets file:

- Co the empty, nhung phai ton tai.
- Parsed into `SecretStore`.
- Redacted by `SecretRedactor`.
- Runtime variable syntax tach biet `{{secret:NAME}}` voi `{{env:NAME}}`.

Parser se reject bare variable `{{FOO}}` va goi y dung namespace ro rang.

### 11.3 Web Auth-State

Files:

- `packages/core/src/auth-state/resolver.ts`
- `packages/core/src/auth-state/store.ts`
- `packages/core/src/auth-state/schema.ts`
- `packages/core/src/auth-state/redaction.ts`

Auth-state chi support web:

- Payload: Playwright storageState JSON.
- Metadata: `{ version: 1, kind: "web", target, name, capturedAt }`.
- Path: `.agent-qa/auth-states/<target>/<name>.json` va `.meta.json`.
- Names match regex `^[a-z][a-z0-9-]*[a-z0-9]$`.
- Mobile auth-state bi reject; native mobile dung `use.mobile.appState: preserve`.

Redaction:

- StorageState payload bi redact.
- Auth-like keys token/cookie/authorization/csrf/session/bearer bi redact.
- Hook auth env/path/json bi redact.

## 12. Dashboard Server

Files:

- `packages/dashboard-server/src/server/server.ts`
- `packages/dashboard-server/src/server/routes.ts`
- `packages/dashboard-server/src/execution/test-runner.ts`
- `packages/dashboard-server/src/queue/job-queue.ts`
- `packages/dashboard-server/src/live-editor/*`

Dashboard server la Node HTTP server:

- Serve static UI assets.
- Create API router.
- Create WebSocket server for live editor.
- Optional local MCP HTTP endpoint.
- Create `TestRunner` wrapper around CLI child process.
- Create `JobQueue` backed by dashboard DB.

### 12.1 TestRunner

`TestRunner` spawn CLI:

- command: `agent-qa run ...`
- env `AGENT_QA_LIVE_EVENTS=true`.
- For queued single run: `AGENT_QA_RUN_ID`.
- For suite: `AGENT_QA_SUITE_QUEUE_ID`.
- For retries: `AGENT_QA_PARENT_RUN_ID`, `AGENT_QA_MAX_RETRIES`.

It parses stdout lines prefixed `AGENT_QA_EVENT:` for live events.

Ground truth completion:

- Reporter `test-complete` event determines test status.
- Process exit code alone is not trusted, esp. mobile cleanup can exit non-zero.

Stale detection:

- heartbeat interval default 10s.
- stale threshold default 30s.
- stale process killed.

Cancellation:

- SIGINT then SIGKILL after 5s grace.

### 12.2 Queue

`JobQueue`:

- DB-backed pending runs.
- concurrency default CPU count.
- Sequential web jobs need exclusive slots.
- Parallel web jobs can fill available slots.
- Mobile jobs serialize per platform (`ios`/`android`) to avoid device/Appium contention.
- Cancel pending/running run updates parent and child artifacts best-effort.

### 12.3 API Surfaces

Important routes in `routes.ts`:

- Runs: `/api/runs`, `/api/runs/:id`, `/api/runs/:id/steps`, `/api/runs/:id/artifact`, `/api/runs/:id/logs`, `/api/runs/:id/execution-logs`, `/api/runs/:id/accessibility`, `/api/runs/:id/cancel`, delete run.
- Artifacts media: `/api/screenshots/:runId/:filename`, `/api/videos/:runId/:filename`.
- Stats/analytics: `/api/stats`, `/api/stats/costs`, `/api/token-events/stats`, `/api/analytics/tests`, `/api/analytics/suites/:suiteId`, `/api/analytics/breakdowns`, `/api/analytics/events`.
- Queue/execution: `/api/queue/enqueue`, `/api/queue/status`, `/api/runs/trigger`, `/api/execution/active`, `/api/execution/events`.
- Tests/suites: `/api/tests`, `/api/tests/:t_id`, `/api/tests/validate`, `/api/suites`, `/api/suites/:suite-id`, `/api/suites/validate`.
- Config/auth/LLM: `/api/config`, `/api/config/targets`, `/api/config/llms`, `/api/config/default-llm`, `/api/config/settings`, `/api/auth/status`, `/api/auth/credential`, `/api/auth/:configName`, `/api/llm/providers`, `/api/llm/test`, `/api/auth/plugin/*`.
- Hooks: `/api/hooks`, `/api/hooks/:hookId`, `/api/hooks/:hookId/run`.
- Agent rules and variables: `/api/agent-rules`, `/api/agent-rules/create`, `/api/variables`, `/api/variables/env`, `/api/variables/hooks`.
- Live editor: `/api/live-editor/sessions`, `/api/live-editor/sessions/:id/auth-state`.
- Memory: `/api/memory/catalog`, `/api/memory/products/:product`, `/api/memory/scopes/:scope/:key`, legacy `/api/memory/observations/:testId`.

## 13. Dashboard UI

Files:

- `packages/dashboard-ui/src/app.tsx`
- `packages/dashboard-ui/src/lib/api.ts`
- `packages/dashboard-ui/src/pages/*`
- `packages/dashboard-ui/src/components/*`

Tech:

- React.
- React Router.
- Vite.
- Tailwind/shadcn-style UI primitives.
- Lucide icons.
- Sonner toasts.
- Lazy-loaded pages.

Routes:

- `/runs`
- `/runs/:id`
- `/runs/:id/live`
- `/tests`
- `/tests/new`
- `/test/:t_id`
- `/test/:t_id/edit`
- `/suites`
- `/suites/new`
- `/suite/:suite-id`
- `/suite/:suite-id/edit`
- `/hooks`
- `/hooks/new`
- `/hook/:id`
- `/hook/:id/edit`
- `/memory`
- `/memory/:product`
- `/insights`
- `/config`

Key UI capabilities:

- Runs table with filters/search/status/platform/attributes.
- Run detail tree of steps/sub-actions/execution logs.
- Screenshot/video viewer.
- Reasoning pipeline.
- Console/network/a11y tabs.
- Artifact drawer for config/env/memory/run attributes.
- Live run page with SSE events.
- Test editor/viewer with YAML, visual builder, validation.
- Suite editor/viewer with test rows, hooks, live mode.
- Hook workspace/editor/run workbench.
- Config manager for providers, LLM, targets, devices, timeouts, healing, cache, memory, accessibility, recording, analytics, auth-state.
- Memory workspace page with outline, filters, markdown copy.
- Insights charts for pass rate, duration, cost/token and breakdowns.

## 14. MCP Architecture

Files:

- `packages/mcp/src/server.ts`
- `packages/mcp/src/agent-qa-server.ts`
- `packages/mcp/src/schema-reference.ts`
- `packages/mcp/src/local-http.ts`

MCP supports:

- stdio transport.
- local HTTP endpoint when dashboard enables it.

Important design: MCP is mostly facade over dashboard API, not its own runner.

Tools:

- Discovery/config/schema:
  - `agent_qa_discover`
  - `agent_qa_get_config`
  - `agent_qa_schema_reference`
  - `agent_qa_validate_definition`
- IDs:
  - `agent_qa_generate_id`
  - `agent_qa_validate_id`
- Tests:
  - `agent_qa_list_tests`
  - `agent_qa_read_test`
  - `agent_qa_validate_test`
  - `agent_qa_create_test`
  - `agent_qa_update_test`
  - `agent_qa_delete_test`
- Suites:
  - `agent_qa_list_suites`
  - `agent_qa_read_suite`
  - `agent_qa_validate_suite`
  - `agent_qa_create_suite`
  - `agent_qa_update_suite`
  - `agent_qa_delete_suite`
- Hooks:
  - `agent_qa_list_hooks`
  - `agent_qa_read_hook`
  - `agent_qa_create_hook`
  - `agent_qa_update_hook`
  - `agent_qa_delete_hook`
  - `agent_qa_run_hook`
- Runs:
  - `agent_qa_enqueue_test_run`
  - `agent_qa_enqueue_suite_run`
  - `agent_qa_get_run`
  - `agent_qa_get_run_steps`
  - `agent_qa_get_run_logs`
  - `agent_qa_get_run_execution_logs`
  - `agent_qa_get_run_artifact`
  - `agent_qa_cancel_run`
  - `agent_qa_classify_failure`

Resources:

- `agent-qa://schema/<name>`

Prompt:

- `agent_qa_authoring_context`

Failure classifier is heuristic:

- timeout.
- appium_startup.
- browser_disconnect.
- element_not_found.
- assertion_failure.
- hook_failure.
- infrastructure.
- unknown_failure.

## 15. CLI Surface

Top-level command: `agent-qa`

Subcommands:

- `run`
- `init`
- `install-browsers`
- `install-mobile-drivers`
- `doctor`
- `dashboard`
- `serve`
- `mcp`
- `config`
- `queue`
- `cache`
- `validate`
- `auth`
- `auth-state`
- `devices`
- `ids`
- `create-test`
- `create-suite`
- `clean-memory`
- `skills`

Business meaning:

- CLI is developer primary interface.
- Dashboard is local control plane.
- MCP is agent control interface.
- Skills are packaged guidance for AI agents.

## 16. Canonical IDs

Package: `@vostride/agent-qa-ids`

File: `packages/ids/src/persistent-id.ts`

ID types:

- test: prefix `t_`
- suite: prefix `s_`
- hook: prefix `h_`
- observation: prefix `obs_`
- run: prefix `r_`

All canonical IDs use `id-agent` with 10 words. Observation legacy IDs with 6 words are still accepted in some read paths.

For own product:

- Neu fork source, giu ID contract se de migration hon.
- Neu clean-room product, nen define brand-neutral ID contract ngay tu dau.
- Doi prefix sau khi da co DB/memory/test files se tao migration lon.

## 17. Analytics

Files:

- `packages/core/src/analytics/*`
- `packages/dashboard-server/src/server/routes.ts`
- `packages/dashboard-ui/src/lib/analytics.ts`

Analytics backend:

- PostHog transport.
- Noop/mock support.
- `analytics.privacy: true` disables capture.

Tracked surfaces:

- CLI run reporter.
- MCP lifecycle/tool invocation.
- Dashboard opened/events.
- Server analytics bridge.

For rebrand:

- Remove or replace PostHog project key/host.
- Audit all event names `agent-qa.*`.
- Provide strong privacy default if selling enterprise/on-prem.

## 18. Security Model

Security strengths:

- Workspace path traversal guards for tests/suites/hooks/auth-state.
- Strict Zod schemas for config/test/suite/hooks.
- MCP config masking.
- Secrets require namespace and redaction.
- Auth-state redaction.
- Hook Docker sandbox with resource limits.
- MCP host must be loopback.
- Memory security scanner blocks prompt injection/exfil patterns.
- Dashboard artifact media path resolution avoids arbitrary file serving.

Important residual risks:

- LLM planner can still choose destructive UI actions if test instruction asks it.
- Hooks can access network by default unless configured off.
- Browser automation runs in real browser context and can touch target app data.
- Local dashboard exposes powerful APIs; should stay loopback-only.
- Memory false positives can guide LLM wrong, though circuit breaker helps.
- Clean-room commercial fork must not copy protected implementation if license is a concern.

## 19. Rebrand / Make-It-Yours Checklist

### 19.1 Legal First

Choose one path:

- Internal fork: keep license notices, rename for internal use, avoid commercial competing service.
- Commercial negotiated fork: get license from owner.
- Clean-room rebuild: use behavior/spec ideas, write new codebase independently.

### 19.2 Brand Surfaces To Replace

Search/change:

- `agent-qa`
- `Agent QA`
- `vostride`
- `@vostride/agent-qa-*`
- Docker images `vostride/agent-qa-*`
- MCP tool names `agent_qa_*`
- env vars `AGENT_QA_*`
- runtime dir `.agent-qa`
- config file `agent-qa.config.yaml`
- docs URLs `vostride.com/docs/agent-qa`
- npm package `agent-qa`
- skills folder names.

### 19.3 Product Decisions

Decide:

- Local-first CLI/dashboard only or SaaS control plane.
- BYO LLM only or managed LLM billing.
- Web-only MVP or web+mobile.
- Whether Memory is enabled by default.
- Whether hooks allow network by default.
- Whether tests live in git or dashboard DB.
- Whether dashboard has multi-user auth.
- Whether run artifacts can be uploaded/shared.

### 19.4 Technical Refactor Priorities

If forking internally:

1. Rename package scopes and binaries.
2. Replace analytics project.
3. Replace Docker image registry.
4. Replace docs/assets/README branding.
5. Audit AGENTS branding guardrails.
6. Update runtime dirs/env vars only if migration acceptable.
7. Run full `pnpm test`, `pnpm typecheck`, `pnpm build`.

If clean-room rebuilding:

1. Define public spec: YAML schema, action registry, adapter contract, artifact schema.
2. Implement web-only runner first.
3. Add dashboard DB/artifact model.
4. Add cache.
5. Add memory after runner stable.
6. Add MCP after dashboard API exists.
7. Add mobile adapters last.

## 20. Clean-Room MVP Blueprint

Recommended MVP scope:

- Web only.
- YAML tests with natural language steps.
- Playwright adapter.
- LLM planner with strict action tools.
- Optional verifier.
- Run artifact JSON + screenshots.
- SQLite dashboard DB.
- Simple dashboard: runs, run detail, screenshots, logs.
- File action cache.
- No mobile, no hooks, no Memory in v0.

MVP modules:

- `core/schema`
- `core/parser`
- `core/tools`
- `core/runner`
- `web-adapter`
- `cli`
- `dashboard-server`
- `dashboard-ui`

Later add:

- Memory curator.
- Hook sandbox.
- MCP.
- Appium mobile.
- Device farms.
- Auth plugins.
- Analytics/cost.

## 21. Engineering Quality Observations

Strong points:

- Clear package boundaries.
- Schema-first validation.
- Tests across core/dashboard/UI/scripts.
- Runner has explicit cancellation/timeout handling.
- Dashboard reporter/artifact model is thoughtful.
- Memory has trust, security, dedup, lock, circuit breaker.
- Dashboard server avoids framework lock-in.
- MCP is cleanly layered over dashboard API.

Complexity risks:

- `run.ts` is very large and owns too many concerns.
- `routes.ts` is very large and manually routes many APIs.
- Dashboard server mixes queue, Appium lease, runner finalization, MCP startup and static serving.
- Memory and cache behavior are subtle and need strong regression tests.
- Rebrand touches many public contracts.
- Mobile support depends on external Appium/BrowserStack/runtime environment.

Refactor ideas if owning long-term:

- Split CLI run orchestration into service modules.
- Split dashboard router by domain.
- Define OpenAPI or typed route contracts shared by UI/MCP.
- Extract artifact writer/finalizer service.
- Add migration tooling for runtime dirs/env/prefixes if rebranding.
- Add integration smoke harness for web demo project.

## 22. Source Map For Future Deep Work

Core:

- `packages/core/src/agent/runner.ts`
- `packages/core/src/agent/loop.ts`
- `packages/core/src/agent/planner.ts`
- `packages/core/src/agent/verifier.ts`
- `packages/core/src/tools/actions/index.ts`
- `packages/core/src/types/platform.ts`
- `packages/core/src/schema/*.ts`
- `packages/core/src/parser/*.ts`
- `packages/core/src/cache/*.ts`
- `packages/core/src/memory/*.ts`
- `packages/core/src/hooks/*.ts`
- `packages/core/src/auth-state/*.ts`
- `packages/core/src/artifacts/run-artifact.ts`
- `packages/core/src/workspace/workspace-paths.ts`

Adapters:

- `packages/web/src/adapter.ts`
- `packages/web/src/observer.ts`
- `packages/web/src/action-validator.ts`
- `packages/android/src/adapter.ts`
- `packages/android/src/session.ts`
- `packages/ios/src/adapter.ts`
- `packages/ios/src/session.ts`

Dashboard:

- `packages/dashboard-server/src/server/server.ts`
- `packages/dashboard-server/src/server/routes.ts`
- `packages/dashboard-server/src/db/schema.ts`
- `packages/dashboard-server/src/db/database.ts`
- `packages/dashboard-server/src/execution/test-runner.ts`
- `packages/dashboard-server/src/queue/job-queue.ts`
- `packages/dashboard-server/src/live-editor/*`
- `packages/dashboard-ui/src/app.tsx`
- `packages/dashboard-ui/src/lib/api.ts`
- `packages/dashboard-ui/src/pages/*`
- `packages/dashboard-ui/src/components/*`

CLI/MCP:

- `packages/cli/src/cli.ts`
- `packages/cli/src/commands/run.ts`
- `packages/cli/src/config.ts`
- `packages/cli/src/llm-utils.ts`
- `packages/mcp/src/agent-qa-server.ts`
- `packages/mcp/src/server.ts`
- `packages/mcp/src/schema-reference.ts`

Release/support:

- `docker/Dockerfile.*`
- `scripts/release/*.mjs`
- `scripts/validate-publish-surface.mjs`
- `skills/*/SKILL.md`
- `demo-project/*`

## 23. Practical Next Step

Neu muc tieu la so huu san pham rieng nhanh nhat ma it legal risk:

1. Dung source hien tai lam reference/internal prototype only.
2. Viet spec rieng tu doc nay.
3. Build clean-room web-only MVP.
4. Them dashboard DB/artifact truoc Memory.
5. Them Memory/MCP sau khi run loop da on dinh.
6. Chi them mobile/Appium khi da co khach hang can that.

Neu muc tieu la internal tool trong cong ty:

1. Fork repo.
2. Rebrand noi bo.
3. Doi analytics/privacy defaults.
4. Giu `.agent-qa` va ID format trong phase dau de tranh migration.
5. Them config enterprise: disable telemetry, enforce loopback, hook network default off.
6. Build internal docs va examples theo app cua minh.
