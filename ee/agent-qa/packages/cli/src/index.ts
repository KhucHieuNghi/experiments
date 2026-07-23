import { getAgentQaVersion } from '@etus/agent-core'

export * from '@etus/agent-core'
export const VERSION = getAgentQaVersion()
export * from './config.js'
export * from './targets.js'
export { purgeTest, purgeAll } from './commands/cache.js'
