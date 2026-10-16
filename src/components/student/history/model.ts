// History's tabs, and the lease rows it reads.
import { type Stay } from '@/components/student/StayDetailSheet.vue'

export type Tab = 'history' | 'reviews' | 'payments'
export const TABS: { key: Tab; label: string }[] = [
  { key: 'history', label: 'Boarding history' },
  { key: 'reviews', label: 'Ratings' },
  { key: 'payments', label: 'Payments' },
]

export interface LeaseRow {
  id: string
  status: string
  start_date: string
  end_date: string
  leave_date: string | null
  monthly_rent: number | null
  ended_reason: string | null
  landlord_id: string
  rooms: {
    label: string | null
    room_number: string | null
    room_type: string | null
    custom_room_type: string | null
    accommodation_id: string
    accommodations: { name: string | null; address: string | null; barangay: string | null; city: string | null } | null
  } | null
}
export const STATE: Record<string, Stay['state']> = { active: 'now', leave_requested: 'leaving', ended: 'ended', terminated: 'terminated' }
