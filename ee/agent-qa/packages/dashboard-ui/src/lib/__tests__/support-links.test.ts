import { describe, expect, it } from 'vitest'

import {
  GITHUB_ISSUE_URL,
  GITHUB_REPOSITORY_URL,
  SUPPORT_EMAIL,
  SUPPORT_FEEDBACK_SUBJECT,
  buildFeedbackMailto,
} from '@/lib/support-links'

const FORBIDDEN_SENTINELS = [
  'agent-qa.config.yaml',
  'https://app.example.test',
  'checkout flow',
  'memory observation',
  'sk_live_secret',
  'auth-state-prod',
  'r_secret-run-id',
  '/Users/pranshu/project',
  'AGENT_QA_SECRET',
  'localStorage',
  'screenshot.png',
  'recording.webm',
  'Error: boom',
]

const FORBIDDEN_NO_SEPARATOR_BRAND = ['Agent', 'QA'].join('')

function parseFeedbackMailto(url: string) {
  const prefix = `mailto:${SUPPORT_EMAIL}?`
  expect(url.startsWith(prefix)).toBe(true)

  const params = new URLSearchParams(url.slice(prefix.length))
  return {
    params,
    subject: params.get('subject'),
    body: params.get('body'),
  }
}

describe('support link constants', () => {
  it('defines exact static support targets', () => {
    expect(GITHUB_ISSUE_URL).toBe('https://www.onpoint.vn')
    expect(GITHUB_ISSUE_URL).not.toContain('?')
    expect(GITHUB_REPOSITORY_URL).toBe('https://www.onpoint.vn')
    expect(SUPPORT_EMAIL).toBe('support@etus.com')
    expect(SUPPORT_FEEDBACK_SUBJECT).toBe('ETUS feedback')
  })
})

describe('buildFeedbackMailto', () => {
  it.each([undefined, null, '   '])('falls back to an unavailable version for %s', (version) => {
    const { subject, body } = parseFeedbackMailto(buildFeedbackMailto(version))

    expect(subject).toBe('ETUS feedback')
    expect(body).toBe(
      [
        'Please describe what happened:',
        '',
        '---',
        'ETUS debug info',
        'version: unavailable',
        'surface: dashboard',
      ].join('\n'),
    )
  })

  it('includes a trimmed safe version and dashboard surface', () => {
    const { subject, body } = parseFeedbackMailto(buildFeedbackMailto(' 0.1.18 '))

    expect(subject).toBe('ETUS feedback')
    expect(body).toContain('version: 0.1.18')
    expect(body).toContain('surface: dashboard')
  })

  it('uses ETUS public copy', () => {
    const { subject, body } = parseFeedbackMailto(buildFeedbackMailto('0.1.18'))

    expect(subject).toContain('ETUS')
    expect(subject).not.toContain(FORBIDDEN_NO_SEPARATOR_BRAND)
    expect(body).toContain('ETUS debug info')
    expect(body).not.toContain(FORBIDDEN_NO_SEPARATOR_BRAND)
  })

  it('percent-encodes subject and body query values without plus signs', () => {
    const url = buildFeedbackMailto('0.1.18')

    expect(url).toContain('subject=ETUS%20feedback')
    expect(url).toContain('body=Please%20describe%20what%20happened%3A')
    expect(url).toContain('%0A---%0AETUS%20debug%20info%0A')
    expect(url).not.toContain('+')
  })

  it('excludes forbidden local-data sentinels from the URL and decoded body', () => {
    const url = buildFeedbackMailto('0.1.18')
    const { body } = parseFeedbackMailto(url)

    for (const sentinel of FORBIDDEN_SENTINELS) {
      expect(url).not.toContain(sentinel)
      expect(body).not.toContain(sentinel)
    }
  })
})
