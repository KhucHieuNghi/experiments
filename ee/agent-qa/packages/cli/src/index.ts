import { getAgentQaVersion } from '@etus/agent-qa-core'

export * from '@etus/agent-qa-core'
export const VERSION = getAgentQaVersion()
export * from './config.js'
export * from './targets.js'
export { purgeTest, purgeAll } from './commands/cache.js'
