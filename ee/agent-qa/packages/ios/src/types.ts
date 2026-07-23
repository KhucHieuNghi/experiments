import type { PlatformConfig } from '@etus/agent-core'

export interface IOSAdapterConfig extends PlatformConfig {
  appiumUrl?: string
  bundleId?: string
  udid?: string
}
