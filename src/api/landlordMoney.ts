import { supabase, authUser } from '@/utils/supabase'
import { resolveAsset, AVATAR } from '@/utils/cloudinaryUrl'
import { manilaToday, toLedger } from '@/utils/payments'
import { isBilledMonthly, UTILITIES, type UtilityKey } from '@/utils/listings'
import type { CollectionLease, CollectionLedgerRow, CollectionPayment } from '@/utils/collections'

/** A collections lease plus what the rent history and boarder history need. */
export interface MoneyLease extends CollectionLease {
  roomId: string
  monthlyRent: number
  endDate: string
  endedReason: string | null
}

export interface MoneyRoom {
  id: string
  label: string
  capacity: number
  monthlyRent: number
  accommodationId: string
  accommodationName: string
}

export interface LandlordMoney {
  leases: MoneyLease[]
  ledger: CollectionLedgerRow[]
  payments: CollectionPayment[]
  billUtility: Record<string, UtilityKey>
  /** `${leaseId}:${utility}` for every bill already posted this month. */
  billed: Set<string>
  rooms: MoneyRoom[]
}

/**
 * Everything the landlord/landlady's money screens (Payments, Rent history, the
 * dashboard) are built from: every stay they've had, the ledger, payments still
 * waiting or promised, and their rooms. Throws on error.
 */
export async function fetchLandlordMoney(landlordId?: string): Promise<LandlordMoney> {
  let me = landlordId
  if (!me) {
    const { data: auth } = await authUser()
    me = auth?.user?.id
  }
  if (!me) throw new Error('Not logged in.')
  const [{ data: leaseRows, error: e1 }, { data: ledgerRows, error: e2 }, { data: roomRows, error: e5 }] = await Promise.all([
    supabase
      .from('leases')
      .select('id,status,student_id,room_id,start_date,end_date,ended_reason,monthly_rent,leave_date,water_billing,electric_billing,wifi_billing,users!leases_student_id_fkey(full_name,avatar_color,avatar_url),rooms(label,room_number,accommodation_id,accommodations(name))')
      .eq('landlord_id', me)
      .in('status', ['active', 'leave_requested', 'ended', 'terminated']),
    supabase.rpc('landlord_ledger'),
    supabase
      .from('rooms')
      .select('id,label,room_number,capacity,monthly_rent,accommodation_id,accommodations!inner(name,landlord_id)')
      .eq('accommodations.landlord_id', me),
  ])
  if (e1) throw e1
  if (e2) throw e2
  if (e5) throw e5
  // The demo client's rpc() stub returns false, not rows.
  const leaseList = Array.isArray(leaseRows) ? leaseRows : []
  const ledgerList = Array.isArray(ledgerRows) ? ledgerRows : []
  const roomList = Array.isArray(roomRows) ? roomRows : []
  const ids = leaseList.map((l) => l.id)
  const today = manilaToday()
  const [{ data: payRows, error: e3 }, { data: billRows, error: e4 }] = await Promise.all([
    ids.length
      ? supabase
          .from('payments')
          .select('id,batch_id,lease_id,amount,method,status,kind,month,bill_id,description,created_at,promise_date')
          .in('lease_id', ids)
          .or(`status.eq.pending_verification,promise_date.gte.${today}`)
      : Promise.resolve({ data: [], error: null }),
    ids.length ? supabase.from('utility_bills').select('id,lease_id,utility,month').in('lease_id', ids) : Promise.resolve({ data: [], error: null }),
  ])
  if (e3) throw e3
  if (e4) throw e4
  const payList = Array.isArray(payRows) ? payRows : []
  const billList = Array.isArray(billRows) ? billRows : []

  const leases: MoneyLease[] = leaseList.map((l) => {
    const u = l.users as unknown as { full_name: string | null; avatar_color: string | null; avatar_url: string | null } | null
    const room = l.rooms as unknown as { label: string | null; room_number: string | null; accommodation_id: string; accommodations: { name: string | null } | null } | null
    const billing: Record<UtilityKey, string | null> = { water: l.water_billing, electric: l.electric_billing, wifi: l.wifi_billing }
    return {
      id: l.id,
      studentId: l.student_id,
      studentName: u?.full_name || 'A student',
      avatarColor: u?.avatar_color ?? null,
      avatarUrl: u?.avatar_url ? resolveAsset(u.avatar_url, AVATAR) : null,
      roomLabel: room?.label || (room?.room_number ? `Room ${room.room_number}` : 'Room'),
      accommodationId: room?.accommodation_id ?? '',
      accommodationName: room?.accommodations?.name?.trim() || 'Accommodation',
      status: l.status,
      startDate: l.start_date,
      leaveDate: l.leave_date,
      metered: UTILITIES.filter((x) => isBilledMonthly(billing[x.key])).map((x) => x.key),
      roomId: l.room_id,
      monthlyRent: Number(l.monthly_rent ?? 0),
      endDate: l.end_date,
      endedReason: l.ended_reason,
    }
  })
  const rooms: MoneyRoom[] = roomList.map((r) => {
    const a = r.accommodations as unknown as { name: string | null }
    return {
      id: r.id,
      label: r.label || (r.room_number ? `Room ${r.room_number}` : 'Room'),
      capacity: r.capacity ?? 1,
      monthlyRent: Number(r.monthly_rent ?? 0),
      accommodationId: r.accommodation_id,
      accommodationName: a?.name?.trim() || 'Accommodation',
    }
  })
  const thisMonth = `${today.slice(0, 7)}-01`
  return {
    leases,
    ledger: ledgerList.map((r) => ({ ...toLedger([r])[0]!, leaseId: r.lease_id })),
    payments: payList.map((p) => ({
      id: p.id,
      batchId: p.batch_id,
      leaseId: p.lease_id,
      amount: Number(p.amount),
      method: p.method,
      status: p.status,
      kind: p.kind,
      month: p.month,
      billId: p.bill_id,
      description: p.description,
      createdAt: p.created_at,
      promiseDate: p.promise_date,
    })),
    billUtility: Object.fromEntries(billList.map((b) => [b.id, b.utility as UtilityKey])),
    billed: new Set(billList.filter((b) => b.month === thisMonth).map((b) => `${b.lease_id}:${b.utility}`)),
    rooms,
  }
}
