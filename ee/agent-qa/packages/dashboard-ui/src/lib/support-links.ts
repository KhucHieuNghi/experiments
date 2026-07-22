export const GITHUB_ISSUE_URL = 'https://www.onpoint.vn'
export const GITHUB_REPOSITORY_URL = 'https://www.onpoint.vn'
export const SUPPORT_EMAIL = 'support@etus.com'
export const SUPPORT_FEEDBACK_SUBJECT = 'ETUS feedback'

export function buildFeedbackMailto(version?: string | null): string {
  const safeVersion = version?.trim() || 'unavailable'
  const body = [
    'Please describe what happened:',
    '',
    '---',
    'ETUS debug info',
    `version: ${safeVersion}`,
    'surface: dashboard',
  ].join('\n')

  return `mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(SUPPORT_FEEDBACK_SUBJECT)}&body=${encodeURIComponent(body)}`
}
