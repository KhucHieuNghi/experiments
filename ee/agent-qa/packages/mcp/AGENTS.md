# ETUS package instructions: @etus/agent-mcp

Inherit the root ETUS branding, security, and release rules.

## Scope

This package owns the Model Context Protocol server, local HTTP transport,
stdio transport, tool schemas, schema references, and dashboard-backed authoring
and run tools.

## Read First

- `package.json`
- `src/server.ts`
- `src/local-http.ts`
- `src/schema-reference.ts`
- `src/index.ts`
- `src/__tests__/`
- `references/`

## Commands

- Test: `pnpm --filter @etus/agent-mcp test`
- Typecheck: `pnpm --filter @etus/agent-mcp typecheck`
- Build: `pnpm --filter @etus/agent-mcp build`

## Local Rules

- Public MCP tools use `etus_agent_*`.
- Do not introduce a stale no-separator MCP tool prefix.
- Keep schema references synchronized with core schemas.
- Authoring and run tools that need dashboard state must keep explicit dashboard
  URL handling and clear errors when the dashboard is unavailable.
- Keep local HTTP defaults loopback-only unless a plan explicitly changes
  networking behavior.
- Do not expose secrets through MCP tool responses.

## Verification

Run focused MCP checks:

```bash
pnpm --filter @etus/agent-mcp test
pnpm --filter @etus/agent-mcp typecheck
```
