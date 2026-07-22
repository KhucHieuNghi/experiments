import assert from 'node:assert/strict'
import test from 'node:test'
import { derivePublishOrder, publicPackageNames } from '../release/packages.mjs'

test('derives dependency-first individual package publish order', () => {
  const shuffled = [...publicPackageNames].reverse().map(name => ({ name, pkg: { name, private: false } }))
  const ordered = derivePublishOrder(shuffled).map(record => record.pkg.name)

  assert.deepEqual(ordered, [
    '@etus/agent-qa-ids',
    '@etus/agent-qa-core',
    '@etus/agent-qa-web',
    '@etus/agent-qa-android',
    '@etus/agent-qa-ios',
    '@etus/agent-qa-mcp',
    '@etus/agent-qa-dashboard-ui',
    '@etus/agent-qa-dashboard',
    'agent-qa',
  ])
})

test('rejects missing, duplicate, private, or extra public package records', () => {
  assert.throws(() => derivePublishOrder([]), /missing public package/)
  assert.throws(
    () => derivePublishOrder([
      ...publicPackageNames.map(name => ({ pkg: { name, private: false } })),
      { pkg: { name: 'agent-qa', private: false } },
    ]),
    /duplicate public package/,
  )
  assert.throws(
    () => derivePublishOrder(publicPackageNames.map(name => ({ pkg: { name, private: name === 'agent-qa' } }))),
    /private public package/,
  )
  assert.throws(
    () => derivePublishOrder([
      ...publicPackageNames.map(name => ({ pkg: { name, private: false } })),
      { pkg: { name: '@etus/agent-qa-extra', private: false } },
    ]),
    /extra public package/,
  )
})
