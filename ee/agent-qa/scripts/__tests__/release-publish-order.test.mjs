import assert from 'node:assert/strict'
import test from 'node:test'
import { derivePublishOrder, publicPackageNames } from '../release/packages.mjs'

test('derives dependency-first individual package publish order', () => {
  const shuffled = [...publicPackageNames].reverse().map(name => ({ name, pkg: { name, private: false } }))
  const ordered = derivePublishOrder(shuffled).map(record => record.pkg.name)

  assert.deepEqual(ordered, [
    '@etus/agent-ids',
    '@etus/agent-core',
    '@etus/agent-web',
    '@etus/agent-android',
    '@etus/agent-ios',
    '@etus/agent-mcp',
    '@etus/agent-dashboard-ui',
    '@etus/agent-dashboard',
    'etus-agent',
  ])
})

test('rejects missing, duplicate, private, or extra public package records', () => {
  assert.throws(() => derivePublishOrder([]), /missing public package/)
  assert.throws(
    () => derivePublishOrder([
      ...publicPackageNames.map(name => ({ pkg: { name, private: false } })),
      { pkg: { name: 'etus-agent', private: false } },
    ]),
    /duplicate public package/,
  )
  assert.throws(
    () => derivePublishOrder(publicPackageNames.map(name => ({ pkg: { name, private: name === 'etus-agent' } }))),
    /private public package/,
  )
  assert.throws(
    () => derivePublishOrder([
      ...publicPackageNames.map(name => ({ pkg: { name, private: false } })),
      { pkg: { name: '@etus/agent-extra', private: false } },
    ]),
    /extra public package/,
  )
})
