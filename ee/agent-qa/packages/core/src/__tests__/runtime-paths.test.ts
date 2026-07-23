import { describe, expect, it } from 'vitest'
import {
  DEFAULT_ETUS_AGENT_ARTIFACTS_DIR,
  DEFAULT_ETUS_AGENT_AUTH_STATES_DIR,
  DEFAULT_ETUS_AGENT_CACHE_DIR,
  DEFAULT_ETUS_AGENT_RUNS_DB_PATH,
  DEFAULT_ETUS_AGENT_RUNTIME_DIR,
  DEFAULT_ETUS_AGENT_SCREENSHOTS_DIR,
  DEFAULT_ETUS_AGENT_VIDEOS_DIR,
  LEGACY_ETUS_AGENT_DASHBOARD_DB_PATH,
} from '../runtime-paths.js'

describe('runtime path defaults', () => {
  it('keeps generated runtime output under .etus-agent', () => {
    expect(DEFAULT_ETUS_AGENT_RUNTIME_DIR).toBe('.etus-agent')
    expect(DEFAULT_ETUS_AGENT_CACHE_DIR).toBe('.etus-agent/cache')
    expect(DEFAULT_ETUS_AGENT_AUTH_STATES_DIR).toBe('.etus-agent/auth-states')
    expect(DEFAULT_ETUS_AGENT_ARTIFACTS_DIR).toBe('.etus-agent/artifacts')
    expect(DEFAULT_ETUS_AGENT_AUTH_STATES_DIR.startsWith(`${DEFAULT_ETUS_AGENT_RUNTIME_DIR}/`)).toBe(true)
  })

  it('keeps screenshots and videos under the artifacts tree', () => {
    expect(DEFAULT_ETUS_AGENT_SCREENSHOTS_DIR).toBe('.etus-agent/artifacts/screenshots')
    expect(DEFAULT_ETUS_AGENT_VIDEOS_DIR).toBe('.etus-agent/artifacts/videos')
    expect(DEFAULT_ETUS_AGENT_SCREENSHOTS_DIR.startsWith(`${DEFAULT_ETUS_AGENT_ARTIFACTS_DIR}/`)).toBe(true)
    expect(DEFAULT_ETUS_AGENT_VIDEOS_DIR.startsWith(`${DEFAULT_ETUS_AGENT_ARTIFACTS_DIR}/`)).toBe(true)
  })

  it('names the durable run database separately from the legacy dashboard DB', () => {
    expect(DEFAULT_ETUS_AGENT_RUNS_DB_PATH).toBe('.etus-agent/runs.db')
    expect(LEGACY_ETUS_AGENT_DASHBOARD_DB_PATH).toBe('.etus-agent/dashboard.db')
  })
})
