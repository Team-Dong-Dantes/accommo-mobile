// A student's concern as the list shows it, and the list's filters.

export const FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'open', label: 'Open' },
  { key: 'in_progress', label: 'In progress' },
  { key: 'resolved', label: 'Resolved' },
] as const

export interface Concern {
  id: string
  category: string
  description: string
  status: string
  reportedAt: string
  acknowledgedAt: string | null
  inProgressAt: string | null
  resolvedAt: string | null
  managerResponse: string
  photoUrl: string
  where: string
  escalatedTicketNo: number | null
}
