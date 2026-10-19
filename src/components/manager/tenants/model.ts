// The shapes My Boarders reads, and its list filters.

export interface Lease {
  id: string
  status: string
  studentId: string
  studentName: string
  avatarColor: string | null
  avatarUrl: string | null
  startDate: string
  monthlyRent: number
  addedByLandlord: boolean
}
export interface Room {
  id: string
  label: string
  capacity: number | null
  /** rooms.status: only an 'available' room takes a new boarder. */
  status: string
  leases: Lease[]
}
export interface Accommodation {
  id: string
  name: string
  status: string
  coverUrl: string
  rooms: Room[]
}

export const FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'pending', label: 'Applications' },
  { key: 'active', label: 'Boarders' },
  { key: 'leave_requested', label: 'Leave requests' },
] as const
