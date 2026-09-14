import { beforeEach, describe, expect, it, vi } from 'vitest'

// The whole point of this helper is the native branch: window.open is dropped
// by Capacitor's WebView, so on a device the URL has to be a navigation. A
// regression here is invisible in the browser and silent on the phone — the
// Update button, OSAS documents and Directions all just stop doing anything.
let native = false
vi.mock('@capacitor/core', () => ({
  Capacitor: { isNativePlatform: () => native },
}))

import { openExternal } from './openExternal'

const open = vi.fn()
const location = { href: '' }

beforeEach(() => {
  open.mockClear()
  location.href = ''
  vi.stubGlobal('window', { open, location })
})

describe('on a device', () => {
  beforeEach(() => {
    native = true
  })

  it('navigates, so Capacitor can fire the ACTION_VIEW intent', () => {
    openExternal('https://example.com/app-release.apk')
    expect(location.href).toBe('https://example.com/app-release.apk')
    expect(open).not.toHaveBeenCalled()
  })
})

describe('on the web', () => {
  beforeEach(() => {
    native = false
  })

  it('opens a tab instead of navigating away from the app', () => {
    openExternal('https://example.com/doc.pdf')
    expect(open).toHaveBeenCalledWith('https://example.com/doc.pdf', '_blank', 'noopener')
    expect(location.href).toBe('')
  })
})

describe('with no url', () => {
  it('does nothing on either platform', () => {
    for (const platform of [true, false]) {
      native = platform
      openExternal('')
      expect(open).not.toHaveBeenCalled()
      expect(location.href).toBe('')
    }
  })
})
