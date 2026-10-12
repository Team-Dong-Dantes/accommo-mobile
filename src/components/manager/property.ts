/**
 * One accommodation as the landlord/landlady's screens summarise it. The dashboard and
 * the properties page both built this shape (and the same health rule) from
 * their own queries, then rendered it with two copies of the same card.
 */

export interface Property {
  id: string
  name: string
  address: string
  status: string
  type: string
  image: string
  roomCount: number | null
  capacity: number
  filled: number
  /** Documents already past their expiry date. */
  expired: number
  /** Documents expiring within 30 days. */
  expiringSoon: number
}

/** Badge colour per accommodation status, shared by PropertyCard and PropertyRow. */
export const STATUS_TONE: Record<string, string> = {
  draft: 'grey',
  pending: 'warn',
  reviewing: 'warn',
  accredited: 'ok',
  needs_revision: 'warn',
  rejected: 'danger',
  expired: 'danger',
  suspended: 'danger',
  delisted: 'grey',
}

export type HealthTone = 'good' | 'warn' | 'danger'

/** Permit trouble first, then accreditation. Also orders the dashboard's list. */
export function healthTone(p: Property): HealthTone {
  if (p.expired > 0) return 'danger'
  if (p.expiringSoon > 0) return 'warn'
  if (p.status !== 'accredited') return 'warn'
  return 'good'
}
