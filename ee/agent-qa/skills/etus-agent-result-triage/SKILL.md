---
name: etus-agent-result-triage
description: Use when investigating failed ETUS runs, inspecting artifacts, classifying failures, or comparing recent runs. Prefer ETUS MCP run/artifact tools and produce evidence-backed triage.
metadata:
  short-description: Triage ETUS run failures
---

# ETUS Result Triage

## Workflow

1. Start with `etus_agent_get_run` for run status, suite child context, steps, and attempts.
2. Fetch evidence before deciding:
   - `etus_agent_get_run_artifact`
   - `etus_agent_get_run_steps`
   - `etus_agent_get_run_logs`
   - `etus_agent_get_run_execution_logs`
3. Call `etus_agent_classify_failure` and use its category as the default classification unless stronger evidence contradicts it.
4. Compare recent related runs when available in the classifier output.
5. Return a concise triage result: category, confidence, evidence, likely fix area, and next action.
6. For code changes, switch to `etus-agent-debug-fix` after triage is complete.

## Categories

Use one of the fixed categories from `references/triage-categories.md`:

- `timeout`
- `appium_startup`
- `browser_disconnect`
- `element_not_found`
- `assertion_failure`
- `hook_failure`
- `infrastructure`
- `unknown_failure`

## Evidence Rules

- Quote or summarize concrete artifact/log/step evidence.
- Mention missing artifact sections if they limit confidence.
- Do not invent screenshots, videos, logs, or memory context that was not returned by MCP.
- If MCP is unavailable, use dashboard REST APIs or `etus-agent` CLI output as fallback and say which evidence was unavailable.
