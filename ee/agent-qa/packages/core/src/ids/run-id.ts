import { generateRunId as generateSharedRunId } from '@etus/agent-ids'

export function generateRunId(): string {
  return generateSharedRunId()
}
