import { describe, expect, it, vi } from 'vitest'
import type { BundleInfo } from '@capgo/capacitor-updater'

// A wrong answer here either strands every install behind the wall, ships a
// bundle to an APK whose native plugins can't run it, or reloads into an old or
// broken bundle.
vi.mock('@capgo/capacitor-updater', () => ({ CapacitorUpdater: {} }))
vi.mock('@capacitor/app', () => ({ App: {} }))

import { pickBundle, runningVersion, updateAction, type Release } from './liveUpdate'

const row = (over: Partial<Release> = {}): Release => ({
  latest_version_code: 50,
  latest_version_name: '1.68.50',
  min_supported_version_code: 40,
  apk_url: 'https://example.com/app.apk',
  release_notes: null,
  bundle_version: 50,
  bundle_url: 'https://example.com/bundle.zip',
  bundle_checksum: 'ab12',
  ...over,
})

const b = (version: string, status: BundleInfo['status']) =>
  ({ id: `id${version}`, version, status, downloaded: '', checksum: '' }) as BundleInfo

describe('runningVersion', () => {
  it('reads the built-in code as the APK build and a bundle as its own number', () => {
    expect(runningVersion(45, { id: 'builtin', version: '1.69.45' })).toBe(45)
    expect(runningVersion(45, { id: 'x', version: '48' })).toBe(48)
  })
})

describe('updateAction', () => {
  it('walls an APK older than the native minimum', () => {
    expect(updateAction(row(), 39, 39)).toBe('wall')
  })

  it('fails open when the wall would have nothing to download', () => {
    expect(updateAction(row({ apk_url: ' ' }), 39, 39)).toBe('none')
  })

  it('stages a newer bundle on a compatible APK', () => {
    expect(updateAction(row(), 45, 45)).toBe('stage')
  })

  it('does nothing once the latest web code is running', () => {
    expect(updateAction(row(), 45, 50)).toBe('none')
  })

  it('does nothing for a bundle with no checksum, which the plugin would reject', () => {
    expect(updateAction(row({ bundle_checksum: null }), 45, 45)).toBe('none')
  })

  it('does nothing before any bundle has been published', () => {
    expect(updateAction(row({ bundle_version: null, bundle_url: null }), 45, 45)).toBe('none')
  })
})

describe('pickBundle', () => {
  it('picks the newest usable bundle newer than what is running', () => {
    expect(pickBundle([b('48', 'pending'), b('50', 'success'), b('49', 'pending')], 45)?.version).toBe('50')
  })

  it('skips bundles that rolled back or are still downloading', () => {
    expect(pickBundle([b('50', 'error'), b('49', 'downloading'), b('48', 'pending')], 45)?.version).toBe('48')
  })

  it('never goes back to an older bundle', () => {
    expect(pickBundle([b('44', 'success')], 45)).toBeUndefined()
  })
})
