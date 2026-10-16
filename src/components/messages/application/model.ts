// The application handshake's room summary, step names and date helpers.
import { type UtilityKey, type UtilityTerms } from '@/utils/listings'
import { manilaToday } from '@/utils/payments'

export interface RoomBrief {
  id: string
  label: string
  accommodation: string
  rent: number
  capacity: number
  rentBasis: 'room' | 'person'
  advanceMonths: number
  depositMonths: number
  /** Copied onto the lease when it is written (tg_lease_utility_terms). */
  utilities: Record<UtilityKey, UtilityTerms>
}

export function todayStr(): string {
  return manilaToday()
}

export function addMonths(dateStr: string, months: number): string {
  const d = new Date(dateStr)
  d.setMonth(d.getMonth() + months)
  return d.toISOString().slice(0, 10)
}

export function roomLabelOf(r: { label: string | null; room_number: string | null } | null): string {
  return r?.label || (r?.room_number ? `Room ${r.room_number}` : 'this room')
}

export const STUDENT_STEPS = ['Ask', 'Get form', 'Apply', 'Decision'] as const

/** What the component hands its state: its props and emit. */
export interface Seed {
  props: { conversationId: string; role: 'manager' | 'student'; me: string; otherId: string; otherName: string; roomId?: string | undefined }
  emit: (e: 'system', body: string) => void
}
