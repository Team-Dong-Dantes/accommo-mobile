/**
 * Shapes owned by StudentDashboard.vue and DashStayCard.vue. The `Task` row
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
