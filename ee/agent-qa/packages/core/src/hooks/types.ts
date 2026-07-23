export type HookRuntime = 'node' | 'bun' | 'python' | 'bash'

export interface HookDefinition {
  id: string
  name: string
  runtime: HookRuntime
  file: string
  deps: string[]
  packageFile?: string
  timeout: number
  network: boolean
}

export interface HookResult {
  success: boolean
  variables: Record<string, string>
  output: string
  stdout: string
  stderr: string
  duration: number
  error?: string
}

export const RUNTIME_IMAGE_MAP: Record<HookRuntime, string> = {
  node: 'etus/etus-agent-hook-node',
  bun: 'etus/etus-agent-hook-bun',
  python: 'etus/etus-agent-hook-python',
  bash: 'etus/etus-agent-hook-bash',
}
