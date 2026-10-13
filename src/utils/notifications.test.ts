import { describe, expect, it } from 'vitest'
import { resolveNotifLink } from './notifications'

const LISTING = '/manager/properties/00000000-0000-4000-8000-000000000307'

describe('resolveNotifLink', () => {
  it('opens the listing an accreditation decision is about', () => {
    expect(resolveNotifLink(LISTING, 'verification', 'manager')).toBe(LISTING)
  })

  it('never sends a student into a landlord/landlady screen', () => {
    expect(resolveNotifLink(LISTING, 'verification', 'student')).toBe('/student/support')
  })

  it('falls back by type for an accommo-web link', () => {
    expect(resolveNotifLink('/verifications?focus=verification:abc', 'verification', 'manager')).toBe('/manager/osas')
  })

  it('does not take a made-up id path as a route', () => {
    expect(resolveNotifLink('/manager/properties/not-an-id', 'accommodation', 'manager')).toBe('/manager/properties')
  })

  it('gives OSAS system notices a screen instead of a dead row', () => {
    expect(resolveNotifLink('/profile', 'system', 'manager')).toBe('/manager/profile')
    expect(resolveNotifLink('/profile', 'security', 'student')).toBe('/student/profile')
  })

  it('opens the tenant a payment or leave request is about', () => {
    const tenant = '/manager/tenant/00000000-0000-4000-8000-000000000101'
    expect(resolveNotifLink(tenant, 'payment', 'manager')).toBe(tenant)
  })
})
