/**
 * Shapes shared by StudentDashboard.vue and its three presentational children.
 * One `Task` covers every row the dashboard can show — the checklist and the
 * attention list used to be separate types that both meant "something you may
 * have to act on", which is why the screen showed two competing to-do lists.
 */

export interface Task {
  id: string
  icon: string
  /** Short uppercase source label: 'Rent', 'OSAS', 'Messages'… */
  kind: string
  label: string
  hint: string
  /** Relative time, or '' when the task isn't time-based. */
  when: string
  /** '' means there is nothing to do but wait. */
  action: string
  route: string
  tone: 'danger' | 'warn' | 'info' | 'done'
  /** Lower sorts first. Rank 0 is the most urgent thing on the screen. */
  rank: number
}

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
  advancePaid: boolean
  depositPaid: boolean
}

export interface Manager {
  id: string
  name: string
  initials: string
  avatarUrl: string | null
  replyMinutes: number | null
}
