import { useEffect } from 'react'

import { normalizeRunStatus } from '@/lib/status'

export type RunFaviconState = 'default' | 'running' | 'passed' | 'failed' | 'cancelled'

export const DEFAULT_FAVICON_HREF = '/favicon.svg'

const FAVICON_LINK_SELECTOR = 'link[rel="icon"][type="image/svg+xml"]'
const DATA_URL_PREFIX = 'data:image/svg+xml,'
const LOGO_FILL = '#cb222a'
const BADGE_COLORS: Record<Exclude<RunFaviconState, 'default'>, string> = {
  running: '#3B82F6',
  passed: '#10B981',
  failed: '#EF4444',
  cancelled: '#737373',
}
const LOGO_PATH = 'M24 23H46V29H31V34H44V40H31V47H24V23Z'

function getCanonicalFaviconLink(): HTMLLinkElement {
  const existing = document.querySelector<HTMLLinkElement>(FAVICON_LINK_SELECTOR)
  if (existing) return existing

  const link = document.createElement('link')
  link.setAttribute('rel', 'icon')
  link.setAttribute('type', 'image/svg+xml')
  link.setAttribute('href', DEFAULT_FAVICON_HREF)
  document.head.appendChild(link)
  return link
}

function getBadgeSvg(state: Exclude<RunFaviconState, 'default'>): string {
  if (state === 'failed') {
    return '<path d="M43 32L58 47M58 32L43 47" stroke="#EF4444" stroke-width="5" stroke-linecap="round"/>'
  }

  return `<circle cx="51" cy="41" r="11" fill="${BADGE_COLORS[state]}"/>`
}

export function getRunFaviconState(status: string | null | undefined): RunFaviconState {
  switch (normalizeRunStatus(status)) {
    case 'running':
    case 'pending':
    case 'queued':
      return 'running'
    case 'passed':
    case 'flaky':
    case 'healed':
      return 'passed'
    case 'failed':
    case 'timeout':
      return 'failed'
    case 'cancelled':
      return 'cancelled'
    case 'skipped':
    case 'unknown':
      return 'default'
  }
}

export function getRunStatusFaviconHref(state: RunFaviconState): string {
  if (state === 'default') return DEFAULT_FAVICON_HREF

  const svg = [
    '<svg width="64" height="64" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">',
    '<rect width="64" height="64" fill="#fff6f6"/>',
    '<rect x="6" y="6" width="46" height="46" fill="#313331"/>',
    '<rect x="12" y="12" width="46" height="46" fill="#fff6f6" stroke="#313331" stroke-width="4"/>',
    `<path d="${LOGO_PATH}" fill="${LOGO_FILL}"/>`,
    getBadgeSvg(state),
    '</svg>',
  ].join('')

  return `${DATA_URL_PREFIX}${encodeURIComponent(svg)}`
}

export function useRunStatusFavicon(state: RunFaviconState): void {
  useEffect(() => {
    const link = getCanonicalFaviconLink()
    link.setAttribute('href', getRunStatusFaviconHref(state))

    return () => {
      getCanonicalFaviconLink().setAttribute('href', DEFAULT_FAVICON_HREF)
    }
  }, [state])
}
