import { generateRunId as generateSharedRunId } from '@etus/agent-qa-ids'

export function generateRunId(): string {
  return generateSharedRunId()
}
