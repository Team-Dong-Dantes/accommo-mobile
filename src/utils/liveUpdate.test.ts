import { describe, expect, it, vi } from 'vitest'
import type { BundleInfo } from '@capgo/capacitor-updater'

// A wrong answer here either strands every install behind the wall, ships a
// bundle to an APK whose native plugins can't run it, or reloads into an old or
// broken bundle.
vi.mock('@capgo/capacitor-updater', () => ({ CapacitorUpdater: {} }))
vi.mock('@capacitor/filesystem', () => ({ Filesystem: {}, Directory: {} }))
vi.mock('@capacitor/core', () => ({ Capacitor: {}, registerPlugin: () => ({}) }))

import { bundleStep, runningVersion, updateAction, type Release } from './liveUpdate'

const row = (over: Partial<Release> = {}): Release => ({
  latest_version_code: 50,
  latest_version_name: '1.68.50',
  min_supported_version_code: 40,
  apk_url: 'https://github.com/Team-Dong-Dantes/accommo-mobile/releases/latest/download/app-release.apk',
  release_notes: null,
  bundle_version: 50,
  bundle_url: 'https://github.com/Team-Dong-Dantes/accommo-mobile/releases/download/v50/bundle.zip',
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
  it('sends an APK older than the native minimum to a new APK', () => {
    expect(updateAction(row(), 39, 39)).toBe('apk')
  })

  it('fails open when the wall would have nothing to download', () => {
    expect(updateAction(row({ apk_url: ' ' }), 39, 39)).toBe('none')
  })

  it('updates a compatible APK with the newer bundle', () => {
    expect(updateAction(row(), 45, 45)).toBe('bundle')
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

  it('refuses a bundle hosted anywhere but the repo’s releases', () => {
    expect(updateAction(row({ bundle_url: 'https://evil.example/bundle.zip' }), 45, 45)).toBe('none')
    expect(updateAction(row({ bundle_url: 'https://github.com/Team-Dong-Dantes/accommo-mobile.evil/releases/download/v1/b.zip' }), 45, 45)).toBe('none')
  })

  it('never walls toward an APK hosted anywhere but the repo’s releases', () => {
    expect(updateAction(row({ apk_url: 'https://evil.example/app.apk' }), 39, 39)).toBe('none')
  })
})

describe('bundleStep', () => {
  it('switches to a bundle already downloaded', () => {
    expect(bundleStep([b('48', 'success'), b('50', 'pending')], '50')).toEqual({ step: 'set', id: 'id50' })
  })

  it('downloads when the bundle is missing or was cut off mid-download', () => {
    expect(bundleStep([b('48', 'success')], '50')).toEqual({ step: 'download' })
    expect(bundleStep([b('50', 'downloading')], '50')).toEqual({ step: 'download' })
  })

  it('gives up on a bundle that rolled back, rather than reload into it again', () => {
    expect(bundleStep([b('50', 'error')], '50')).toEqual({ step: 'broken' })
  })
})
