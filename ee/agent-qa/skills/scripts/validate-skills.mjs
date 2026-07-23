import { readFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'

const root = new URL('..', import.meta.url).pathname
const skills = ['etus-agent-authoring', 'etus-agent-result-triage', 'etus-agent-debug-fix']

for (const skill of skills) {
  const dir = join(root, skill)
  const skillPath = join(dir, 'SKILL.md')
  const openAiPath = join(dir, 'agents/openai.yaml')
  if (!existsSync(skillPath)) throw new Error(`${skill}: missing SKILL.md`)
  if (!existsSync(openAiPath)) throw new Error(`${skill}: missing agents/openai.yaml`)
  const body = readFileSync(skillPath, 'utf-8')
  if (!body.startsWith('---\nname: ')) throw new Error(`${skill}: missing frontmatter name`)
  if (!body.includes('description: ')) throw new Error(`${skill}: missing frontmatter description`)
  if (!body.includes('etus_agent_')) throw new Error(`${skill}: missing MCP tool guidance`)
  if (body.includes('agentqa_')) throw new Error(`${skill}: stale no-separator MCP tool prefix`)
}

const authoringReference = join(root, 'etus-agent-authoring/references/etus-agent-contracts.json')
const triageReference = join(root, 'etus-agent-result-triage/references/triage-categories.md')
if (!existsSync(authoringReference)) throw new Error('etus-agent-authoring: missing contract reference')
if (!existsSync(triageReference)) throw new Error('etus-agent-result-triage: missing triage reference')

console.log('ETUS skills pack validation passed')
