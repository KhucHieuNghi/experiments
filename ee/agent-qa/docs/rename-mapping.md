# Rename Mapping: agent-qa → etus-agent

## Naming Convention (Option B)

### Package Names (@etus/ scope)
| Old | New |
|-----|-----|
| `@etus/agent-qa-ids` | `@etus/agent-ids` |
| `@etus/agent-qa-core` | `@etus/agent-core` |
| `@etus/agent-qa-web` | `@etus/agent-web` |
| `@etus/agent-qa-android` | `@etus/agent-android` |
| `@etus/agent-qa-ios` | `@etus/agent-ios` |
| `@etus/agent-qa-mcp` | `@etus/agent-mcp` |
| `@etus/agent-qa-dashboard` | `@etus/agent-dashboard` |
| `@etus/agent-qa-dashboard-ui` | `@etus/agent-dashboard-ui` |
| `@etus/agent-qa-subscription-auth` | `@etus/agent-subscription-auth` |
| `agent-qa` (CLI package) | `etus-agent` |
| `agent-qa-monorepo` (root) | `etus-agent-monorepo` |

### CLI Binary
| Old | New |
|-----|-----|
| `agent-qa` (bin command) | `etus-agent` |

### Config Files
| Old | New |
|-----|-----|
| `agent-qa.config.yaml` | `etus-agent.config.yaml` |
| `agent-qa.local.yaml` | `etus-agent.local.yaml` |
| `agent-qa.release.config.yaml` | `etus-agent.release.config.yaml` |

### Runtime Directory
| Old | New |
|-----|-----|
| `.agent-qa/` | `.etus-agent/` |
| `.agent-qa/cache` | `.etus-agent/cache` |
| `.agent-qa/artifacts` | `.etus-agent/artifacts` |
| `.agent-qa/auth-states` | `.etus-agent/auth-states` |
| `~/.agent-qa/auth.json` | `~/.etus-agent/auth.json` |

### Docker Images
| Old | New |
|-----|-----|
| `etus/agent-qa-web` | `etus/etus-agent-web` |
| `etus/agent-qa-android` | `etus/etus-agent-android` |
| `etus/agent-qa-hook-runner-node` | `etus/etus-agent-hook-node` |
| `etus/agent-qa-hook-runner-bun` | `etus/etus-agent-hook-bun` |
| `etus/agent-qa-hook-runner-python` | `etus/etus-agent-hook-python` |
| `etus/agent-qa-hook-runner-bash` | `etus/etus-agent-hook-bash` |

### MCP Tools
| Old | New |
|-----|-----|
| `agent_qa_*` | `etus_agent_*` |

### Environment Variables
| Old | New |
|-----|-----|
| `AGENT_QA_*` | `ETUS_AGENT_*` |
| `AGENT_QA_DASHBOARD_PORT` | `ETUS_AGENT_DASHBOARD_PORT` |
| `AGENT_QA_MCP_PORT` | `ETUS_AGENT_MCP_PORT` |
| `AGENT_QA_CACHE_DIR` | `ETUS_AGENT_CACHE_DIR` |
| `AGENT_QA_CACHE_TTL` | `ETUS_AGENT_CACHE_TTL` |
| `AGENT_QA_LOG_LEVEL` | `ETUS_AGENT_LOG_LEVEL` |
| `AGENT_QA_HEADLESS` | `ETUS_AGENT_HEADLESS` |
| `AGENT_QA_CLI_BIN` | `ETUS_AGENT_CLI_BIN` |
| `AGENT_QA_POSTHOG_KEY` | `ETUS_AGENT_POSTHOG_KEY` |

### TypeScript API Names (unchanged)
| Name | Status |
|------|--------|
| `AgentQaConfig` | Keep (preferred TS name per AGENTS.md) |
| `AgentQaConfigSchema` | Keep |

### Internal String Identifiers
| Old | New |
|-----|-----|
| `agent-qa.trigger` (run attribute) | `etus-agent.trigger` |
| `agent-qa.runner` (run attribute) | `etus-agent.runner` |
| `agent-qa.dashboard.*` (analytics) | `etus-agent.dashboard.*` |
| `/tmp/agent-qa.env` (hook output) | `/tmp/etus-agent.env` |
| `agent-qa-hook-` (tmp dir prefix) | `etus-agent-hook-` |
| `agent-qa-memory` (default memory dir) | `etus-agent-memory` |

### Lint Rule
| Old | New |
|-----|-----|
| `grep '@agent-qa/'` | `grep '@agent-qa/' (remove — no longer applicable)` |

### Monaco Editor Themes
| Old | New |
|-----|-----|
| `agent-qa-dark` | `etus-agent-dark` |
| `agent-qa-light` | `etus-agent-light` |

### Cookie Names
| Old | New |
|-----|-----|
| `agent_qa_update_notice_dismissed` | `etus_agent_update_notice_dismissed` |
