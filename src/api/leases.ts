import { supabase } from '@/utils/supabase'
import { LEASE_CORE } from './selects'

/**
 * Lease reads, in one place.
 *
 * Seventeen files queried `leases` directly and did not agree on what a
 * "current" lease is: StudentConcernsPage looked for active or leave_requested,
 * StudentProfilePage also counted pending. A student with only a pending
 * application therefore had a manager to raise a concern against on one screen
 * and not on the other. The status sets are named here so that disagreement has
 * to be deliberate.
 */

/** A lease the student is actually living under. */
export const OCCUPYING_STATUSES = ['active', 'leave_requested'] as const

/** As above, plus an application that has not been decided yet. */
export const OPEN_STATUSES = ['active', 'pending', 'leave_requested'] as const

/** Statuses that need the manager to do something. */
export const MANAGER_ACTION_STATUSES = ['pending', 'leave_requested'] as const

export interface CurrentLease {
  id: string
  status: string
  accommodation_manager_id: string
  rooms?: { room_number: string | null; accommodations?: { name: string | null } | null } | null
}

/**
 * The student's current lease, newest first.
 *
 * `includePending` decides whether an undecided application counts. Screens
 * that need someone to talk to (concerns, messaging) should say false; screens
 * showing the student where they stand should say true.
 */
export async function fetchCurrentLease(
  studentId: string,
  includePending = false,
): Promise<CurrentLease | null> {
  const { data, error } = await supabase
    .from('leases')
    .select('id, status, accommodation_manager_id, rooms(room_number, accommodations(name))')
    .eq('student_id', studentId)
    .in('status', [...(includePending ? OPEN_STATUSES : OCCUPYING_STATUSES)])
    .order('start_date', { ascending: false })
    .limit(1)
    .maybeSingle()
  if (error) throw error
  return (data as unknown as CurrentLease) ?? null
}

/** Every lease between one student and one manager, newest first. */
export async function fetchSharedLeaseHistory(studentId: string, managerId: string) {
  const { data, error } = await supabase
    .from('leases')
    .select('id, status, start_date, end_date, monthly_rent, rooms(room_number, label, accommodations(name))')
    .eq('student_id', studentId)
    .eq('accommodation_manager_id', managerId)
    .order('start_date', { ascending: false })
  if (error) throw error
  return data ?? []
}

/** How many leases are waiting on this manager — the nav badge count. */
export async function countLeasesAwaitingManager(managerId: string): Promise<number> {
  const { count, error } = await supabase
    .from('leases')
    .select('id', { count: 'exact', head: true })
    .eq('accommodation_manager_id', managerId)
    .in('status', [...MANAGER_ACTION_STATUSES])
  if (error) throw error
  return count ?? 0
}

/** The student's tenancies with everything My Stay and the tenant list read. */
export async function fetchLeasesForStudent(studentId: string) {
  const { data, error } = await supabase
    .from('leases')
    .select(LEASE_CORE)
    .eq('student_id', studentId)
    .order('start_date', { ascending: false })
  if (error) throw error
  return data ?? []
}
