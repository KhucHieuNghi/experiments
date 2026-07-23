import type { RunAttributes } from '@etus/agent-core'
import type { EventEmitter } from 'node:events'

export interface ExecuteOptions {
  runId: string
  args: string[]
  source: string
  attributes?: RunAttributes
  timeout?: number
  maxRetries?: number
  env?: Record<string, string>
}

export interface ExecutionBackend extends EventEmitter {
  execute(opts: ExecuteOptions): void
  kill(runId: string): boolean
  killAll(): void
  getActiveExecutions(): { runId: string; status: string; startedAt: string; duration: number }[]
}
