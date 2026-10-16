/**
 * Shapes owned by StudentDashboard.vue and DashTiles.vue. The `Task` row
 * both dashboards share lives in `components/shared/dashboard.ts`.
 */

export interface Stay {
  id: string
  status: string
  startDate: string
  endDate: string
  monthlyRent: number
  accommodationId: string
  accommodationName: string
  roomNumber: string | null
  roomLabel: string | null
  lat: number | null
  lng: number | null
  photoUrl: string
  /**
   * What moving in costs — the advance months of rent and the deposit, all due
   * on the move-in date — and how much of it is left. Null when nothing is.
   */
  moveIn: { due: number; left: number } | null
}

/** The next unpaid month of rent, off the ledger. */
export interface NextPayment {
  amount: number
  month: string
  dueDate: string | null
  overdue: boolean
}

export interface Manager {
  id: string
  name: string
  initials: string
  avatarUrl: string | null
  replyMinutes: number | null
  /** Landlord, Landlady, or Landlord/Landlady when sex is unknown. */
  title?: string
}

/** One of the two small tiles under the stay row: icon, what, one short line. */
export interface DashTile {
  icon: string
  /** A --m-* colour family with a -soft partner, or 'muted' for the idle grey. */
  tone: string
  title: string
  sub: string
  route: string
}
