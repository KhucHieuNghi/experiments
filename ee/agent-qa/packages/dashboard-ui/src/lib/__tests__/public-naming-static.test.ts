import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const demoConfig = readFileSync(
  new URL('../../../../../demo-project/etus-agent.config.yaml', import.meta.url),
  'utf-8',
)
const sampleUploadFixture = readFileSync(
  new URL('../../../../../demo-project/tests/fixtures/sample-upload.txt', import.meta.url),
  'utf-8',
)
const releaseUploadFixture = readFileSync(
  new URL('../../../../../demo-project/release-action-pack/upload-fixture.txt', import.meta.url),
  'utf-8',
)
const releasePreflight = readFileSync(
  new URL('../../../../../demo-project/scripts/release-action-preflight.mjs', import.meta.url),
  'utf-8',
)

describe('public naming static contract', () => {
  it('uses ETUS in public demo fixture copy', () => {
    expect(demoConfig).toContain('# ETUS Demo Project')
    expect(sampleUploadFixture.trim()).toBe('ETUS file upload fixture')
    expect(releaseUploadFixture.trim()).toBe('ETUS release file-upload fixture')
    expect(releasePreflight).toContain('Run the ETUS package build before release suite execution.')
  })
})
