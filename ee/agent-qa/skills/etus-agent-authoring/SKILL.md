---
name: etus-agent-authoring
description: Use when creating, editing, validating, or running ETUS tests, suites, or hooks. Prefer ETUS MCP tools, enforce canonical ETUS IDs, and use the bundled schema reference to avoid hallucinated config keys or YAML fields.
metadata:
  short-description: Author ETUS tests safely
---

# ETUS Authoring

## Workflow

1. Discover the local surface with `etus_agent_discover`.
2. Inspect active config with `etus_agent_get_config`, especially targets, devices, providers, and `services.mcp`.
3. Load `references/etus-agent-contracts.json` when you need exact schema fields or ID contracts.
4. Generate every new ID with ETUS tooling:
   - MCP: `etus_agent_generate_id`
   - CLI fallback: `etus-agent ids generate <test|suite|hook|run|observation>`
   - npx fallback: `npx --yes etus-agent ids generate <type>`
5. Never hand-write IDs. Validate existing IDs with `etus_agent_validate_id` or `etus-agent ids validate <type> <id> --json`.
6. Validate definitions before saving:
   - Tests: `etus_agent_validate_test` or `etus_agent_validate_definition` with `kind: "test"`
   - Suites: `etus_agent_validate_suite` or `etus_agent_validate_definition` with `kind: "suite"`
   - Hooks: `etus_agent_validate_definition` with `kind: "hooks"`
7. Prefer MCP authoring mutations:
   - Tests: `etus_agent_create_test`, `etus_agent_update_test`, `etus_agent_delete_test`
   - Suites: `etus_agent_create_suite`, `etus_agent_update_suite`, `etus_agent_delete_suite`
   - Hooks: `etus_agent_create_hook`, `etus_agent_update_hook`, `etus_agent_delete_hook`
8. Use CLI/YAML fallback only when MCP is unavailable. Keep file paths matched by `workspace.testMatch` or `workspace.suiteMatch`.

## Required ID Contracts

- Test IDs: `t_` + 10 id-agent words.
- Suite IDs: `s_` + 10 id-agent words.
- Hook IDs: `h_` + 10 id-agent words.
- Run IDs: `r_` + 10 id-agent words.
- Observation IDs: `obs_` + 10 id-agent words.

## Before Running

- Validate YAML first.
- Prefer `etus_agent_enqueue_test_run` and `etus_agent_enqueue_suite_run` over shelling out.
- If using CLI fallback, run only after validation succeeds.

## Do Not

- Do not invent config keys.
- Do not use legacy root config buckets.
- Do not hand-write IDs.
- Do not mutate files outside the configured workspace patterns.
