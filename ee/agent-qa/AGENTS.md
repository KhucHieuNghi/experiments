# ETUS Agent Instructions

These instructions apply to the ETUS repository. Package-level `AGENTS.md`
files under `packages/*` add narrower rules for their package and take precedence
for files inside that package.

## Branding

Use `ETUS` for product prose, dashboard copy, docs, public descriptions, and
brand-facing support text.

Allowed forms:

- Product name in prose: `ETUS`

Compatibility-only technical identifiers that must not be renamed without a
dedicated migration:

- Public CLI command: `agent-qa`
- Config file: `agent-qa.config.yaml`
- Local-only override file: `agent-qa.local.yaml`
- Runtime artifact directory: `.agent-qa/`
- Scoped npm packages: `@etus/agent-qa-*`
- Docker images: `etus/agent-qa-*`
- MCP tools and snake_case public names: `agent_qa_*`
- Environment variables and stdout sentinels: `AGENT_QA_*`

Future changes must not introduce compatibility CLI/package names, legacy brand names,
or no-separator variants as brand prose. Keep legacy technical identifiers only
where existing APIs, package names, config file names, MCP tools, or runtime
paths require them.

<!-- branding-forbidden:start -->
Forbidden brand examples for new work: `Agent QA`, `AgentQA`, `AGENTQA`,
`agentqa`, `agentqa_`, and legacy product prose.

Use preferred TypeScript API names such as `AgentQaConfig` and
`AgentQaConfigSchema`; do not add no-separator compatibility aliases.
<!-- branding-forbidden:end -->

## Repo Map

- `packages/` - pnpm workspace packages.
- `docker/` - release Docker images for web, Android, and hook sandboxes.
- `scripts/` - release, validation, and package staging automation.
- `skills/` - source skills that are copied into the public CLI package.

Package map:

- `@etus/agent-qa-ids` - canonical persistent ID helpers.
- `@etus/agent-qa-core` - runtime schemas, parser, runner, reporters,
  auth, cache, memory, analytics, hooks, and shared platform contracts.
- `@etus/agent-qa-web` - Playwright browser adapter, DOM extraction,
  action validation, smart waits, and accessibility checks.
- `@etus/agent-qa-android` - WebdriverIO/Appium Android adapter.
- `@etus/agent-qa-ios` - WebdriverIO/Appium iOS adapter.
- `@etus/agent-qa-mcp` - Model Context Protocol server, tools, schema
  references, and local HTTP/stdio transports.
- `@etus/agent-qa-dashboard-ui` - React/Vite dashboard UI assets.
- `@etus/agent-qa-dashboard` - local dashboard server, SQLite database,
  run queue, routes, reporter, live editor, and service ownership.
- The compatibility CLI package owns the public entrypoint and packaged skills.

## Commands

Run commands from the ETUS project root unless a task says otherwise.

- Install dependencies: `pnpm install`
- Build all packages: `pnpm build`
- Test all packages: `pnpm test`
- Typecheck all packages: `pnpm typecheck`
- Run package tests: `pnpm --filter <package-name> test`
- Run package typecheck: `pnpm --filter <package-name> typecheck`
- Validate source skills: `pnpm run validate:skills`
- Validate package publishing surface: `pnpm run validate:publish`
- Check forbidden internal namespace imports: `pnpm run lint:namespace`

Prefer focused package commands while iterating. Run the root checks when a
change crosses package boundaries, changes public contracts, or touches release
automation.

## Code Style

- Use TypeScript strict mode and the existing NodeNext ESM setup.
- Follow `.prettierrc`: no semicolons, single quotes, trailing commas, and
  print width 100.
- Preserve existing module boundaries and public exports. Avoid new
  cross-package imports unless the package already depends on the target.
- Keep generated artifacts out of source changes unless the plan explicitly
  asks for them.
- Prefer existing schema, parser, reporter, auth, memory, analytics, and
  dashboard patterns over new abstractions.
- When editing YAML, configs, tests, suites, hooks, or memory files, use the
  existing schema and ID helpers instead of ad hoc string edits.

## Testing

- Add or update focused tests for the package you change.
- For CLI changes, run `pnpm --filter agent-qa test`.
- For core runtime/schema changes, run `pnpm --filter @etus/agent-qa-core test`.
- For dashboard server changes, run `pnpm --filter @etus/agent-qa-dashboard test`.
- For dashboard UI changes, run `pnpm --filter @etus/agent-qa-dashboard-ui test`.
- For MCP changes, run `pnpm --filter @etus/agent-qa-mcp test`.
- Before release-facing changes are complete, run `pnpm typecheck`,
  `pnpm run validate:skills`, and `pnpm run validate:publish`.

## Security

- Never commit `.env*`, `agent-qa.local.yaml`, auth stores, real PostHog keys,
  subscription tokens, or local credential material.
- Do not commit `.agent-qa/`, `dist/`, `.turbo/`, `.pnpm-store/`, or
  `node_modules/`.
- Do not log LLM API keys, bearer tokens, subscription-auth tokens, or
  redacted secret material in plain text.
- Keep analytics project keys on the existing release-time path. Source
  checkouts should keep analytics key material empty unless a release script is
  explicitly writing it.
- Use existing workspace/path validation helpers when accepting user-provided
  paths.
- Keep dashboard and MCP endpoints on loopback by default unless a task
  explicitly changes networking behavior.

## Package Notes

- Public packages keep `private: false`, Node `>=24`, FSL license metadata,
  npm publish config, and explicit `files` allowlists.
- Workspace dependencies between `@etus/agent-qa-*` packages should remain
  `workspace:*` in source manifests.
- The public CLI package is the only package named `agent-qa` and owns the
  `bin.agent-qa` entry.
- The dashboard UI package intentionally publishes built assets and does not
  expose a library entry unless a dedicated plan changes that.
- Do not modify `LICENSE.md` or `NOTICE.md` wording unless the task is
  specifically about licensing or release metadata.

## Skills And MCP

- Public MCP tools use the `agent_qa_*` prefix.
- Never hand-write canonical test, suite, hook, run, or observation IDs. Use
  the existing ID generation helpers or MCP tools.
- When editing `skills/` or packaged CLI skills, run `pnpm run validate:skills`.
- Keep source skills and packaged skills in sync through the existing
  `copy:skills` flow.

## Nested Instructions

Every package under `packages/*` has its own `AGENTS.md`. When editing a file
inside a package, read that package file in addition to this root file. The
package file owns local read-first files, commands, and package-specific
constraints; this root file owns shared branding, security, release, and
monorepo rules.
