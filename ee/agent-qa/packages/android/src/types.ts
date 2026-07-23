import type { PlatformConfig } from '@etus/agent-core'

export interface AndroidAdapterConfig extends PlatformConfig {
  appiumUrl?: string
  browserName?: string
  appPackage?: string
  appActivity?: string
  avd?: string
}
