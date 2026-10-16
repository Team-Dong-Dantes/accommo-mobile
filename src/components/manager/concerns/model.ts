// A boarder's concern as the inbox shows it, and the inbox filters.

export const FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'open', label: 'Open' },
  { key: 'acknowledged', label: 'Acknowledged' },
  { key: 'in_progress', label: 'In progress' },
  { key: 'resolved', label: 'Resolved' },
  { key: 'rejected', label: 'Rejected' },
] as const

export interface Concern {
  id: string
  leaseId: string
  studentId: string
  category: string
  description: string
  status: string
  reportedAt: string
  managerResponse: string
  photoUrl: string
  accommodationId: string | null
  where: string
  studentName: string
  avatarColor: string | null
  avatarUrl: string | null
  /** Set once this concern has gone to OSAS — one ticket per concern (DB-unique). */
  escalatedTicketNo: number | null
}
