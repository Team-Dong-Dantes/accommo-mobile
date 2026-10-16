// The current stay and its money: the lease, payments, bills, what is owed
// (lease_ledger), balances left on past stays, and the live subscription.
import { AMENITY_META, UTILITIES, UTILITY_SELECT, type UtilityKey, isBilledMonthly, roomTypeLabel, utilitiesFromRow } from '@/utils/listings'
import { type Bill, type Lease, type Payment, yesNo } from './model'
import { COVER, resolveAsset } from '@/utils/cloudinaryUrl'
import { type LedgerRow, isBillSettled, manilaToday, toLedger } from '@/utils/payments'
import { POLICY_FULL } from '@/api/selects'
import { authUser, supabase } from '@/utils/supabase'
import { computed, ref } from 'vue'
import { errorMessage } from '@/utils/errors'
import { initialsOf, landlordTitle } from '@/utils/format'
import { isTablet } from '@/utils/useTabletMode'
import { signRows } from '@/utils/upload'
import { useDeskPanels } from '@/utils/useDeskPanels'
import { useLiveData } from '@/utils/useLiveData'
import { useNotify } from '@/utils/notify'
import { useRoute, useRouter } from 'vue-router'

export function createStayState() {
  const router = useRouter()
  const route = useRoute()
  const notify = useNotify()
  // The student's landlord/landlady, titled by their sex, for running text.
  const myLandlord = computed(() => (lease.value?.managerTitle ?? landlordTitle(null)).toLowerCase())

  const loading = ref(true)
  const error = ref('')
  const lease = ref<Lease | null>(null)
  const payments = ref<Payment[]>([])
  const bills = ref<Bill[]>([])
  // Which utility each bill is, for the statement's labels.
  const billUtility = computed(() => Object.fromEntries(bills.value.map((b) => [b.id, b.utility])))
  // Utilities this stay bills monthly (own meter or split), for "not posted yet".
  const metered = computed(() =>
    lease.value ? UTILITIES.filter((u) => isBilledMonthly(lease.value!.utilities[u.key].billing)).map((u) => ({ key: u.key, label: u.label })) : [],
  )
  // The statement covers the current room; the rest is in History.
  const currentLeasePayments = computed(() =>
    lease.value ? payments.value.filter((p) => p.leaseId === lease.value!.id) : payments.value,
  )
  // The deposit still held on this stay (paid in, less what it has paid for).
  const depositReturned = ref(false)
  const depositHeld = computed(() => {
    if (depositReturned.value) return 0
    const rows = currentLeasePayments.value.filter((p) => p.status === 'paid')
    return Math.max(rows.filter((p) => p.kind === 'deposit').reduce((s, p) => s + p.amount, 0) - rows.filter((p) => p.method === 'deposit').reduce((s, p) => s + p.amount, 0), 0)
  })
  // Deep links to the old /student/payments path (quick actions, settings,
  // stored notification link_urls from before this merge) land straight on the
  // Payments tab instead of needing a separate page.
  const activeTab = ref<'stay' | 'payments'>(route.path === '/student/payments' ? 'payments' : 'stay')

  const { panelsIs, panelIs, panelsProps } = useDeskPanels(activeTab, isTablet)

  // Balances on ended stays other than the one shown (student_past_balance).
  interface PastOwed { leaseId: string; landlordId: string; place: string; balance: number; allowPartial: boolean; partialMinPct: number }
  const pastOwed = ref<PastOwed[]>([])
  const pastPay = ref<PastOwed | null>(null)
  // What is owed, from the database (lease_ledger). It refuses anything that
  // breaks its rules; the form only says so first. Empty until loaded, when the
  // older payment-list rules below stand in.
  const ledger = ref<LedgerRow[]>([])
  async function loadLedger() {
    if (!lease.value || lease.value.status === 'pending') { ledger.value = []; return }
    const { data } = await supabase.rpc('lease_ledger', { p_lease: lease.value.id })
    ledger.value = toLedger(data)
  }
  // A stay that ended with something still owed: shown so it can be settled.
  const leaseClosed = computed(() => lease.value?.status === 'ended' || lease.value?.status === 'terminated')
  const paymentDetailOpen = ref(false)
  const selectedPayment = ref<Payment | null>(null)
  function openPaymentDetail(p: Payment) {
    selectedPayment.value = p
    paymentDetailOpen.value = true
  }

  // A pending application isn't an accepted lease yet, so there's nothing to pay.
  const canPay = computed(() => lease.value?.status !== 'pending')

  const LEASE_SELECT = `id, room_id, status, start_date, end_date, leave_date, deposit_returned_at, monthly_rent, allow_partial, partial_min_pct, landlord_id, ${UTILITY_SELECT}, rooms(room_number, label, room_type, custom_room_type, capacity, accommodations(id, name, address, barangay, city, accommodation_amenities(amenity), accommodation_policies(${POLICY_FULL})))`

  async function load(silent = false) {
    if (!silent) loading.value = true
    error.value = ''
    try {
      const { data: authData } = await authUser()
      const user = authData?.user
      if (!user) {
        error.value = 'Not logged in.'
        return
      }

      // The current lease (for the Stay tab) and all-time payment history (for
      // the Payments tab) are independent — a student with no active lease can
      // still have real payments on file from a past stay, so the Payments tab
      // must not be gated on there being a lease right now.
      const [
        { data: currentLease, error: leaseError },
        { data: paymentRows, error: paymentsError },
        { data: billRows, error: billsError },
      ] = await Promise.all([
        supabase
          .from('leases')
          .select(LEASE_SELECT)
          .eq('student_id', user.id)
          .in('status', ['active', 'pending', 'leave_requested'])
          .order('start_date', { ascending: false })
          .limit(1)
          .maybeSingle(),
        supabase
          .from('payments')
          .select(
            'id, lease_id, month, amount, status, method, kind, bill_id, description, txn_reference, proof_url, paid_at, rejection_reason, note, promise_date, receipt_no, created_at, batch_id, verified_by_user:users!payments_verified_by_fkey(full_name), leases!inner(student_id, rooms(room_number, label, accommodations(name)))',
          )
          .eq('leases.student_id', user.id)
          .order('month', { ascending: false }),
        supabase
          .from('utility_bills')
          .select('id, lease_id, utility, month, amount, note, due_date, payments(status, amount), leases!inner(student_id)')
          .eq('leases.student_id', user.id),
      ])
      if (leaseError) throw leaseError
      if (paymentsError) throw paymentsError
      if (billsError) throw billsError

      bills.value = (billRows ?? []).map((b) => ({
        id: b.id,
        leaseId: b.lease_id,
        utility: b.utility as UtilityKey,
        month: b.month,
        amount: Number(b.amount),
        note: b.note || '',
        dueDate: b.due_date,
        overdue: b.due_date < manilaToday(),
        settled: isBillSettled(b.payments, Number(b.amount)),
      }))

      await signRows('payments', paymentRows, 'proof_url')
      payments.value = (paymentRows ?? []).map((p) => {
        const payLease = p.leases as unknown as {
          rooms: { room_number: string | null; label: string | null; accommodations: { name: string | null } | null } | null
        }
        const payRoom = payLease.rooms
        const verifier = p.verified_by_user as unknown as { full_name: string | null } | null
        return {
          id: p.id,
          leaseId: p.lease_id,
          month: p.month,
          kind: p.kind,
          billId: p.bill_id,
          amount: Number(p.amount),
          status: p.status,
          method: p.method,
          roomLabel: payRoom?.label || (payRoom?.room_number ? `Room ${payRoom.room_number}` : 'Your room'),
          accommodationName: payRoom?.accommodations?.name || 'Your accommodation',
          description: p.description || '',
          txnReference: p.txn_reference || '',
          proofUrl: p.proof_url || '',
          paidAt: p.paid_at,
          verifiedByName: verifier?.full_name || '',
          rejectionReason: p.rejection_reason || '',
          note: p.note || '',
          promiseDate: p.promise_date,
          receiptNo: p.receipt_no || '',
          createdAt: p.created_at,
          batchId: p.batch_id,
        }
      })

      // Ended stays with something still owed: it blocks applying elsewhere, so
      // it stays on this screen until settled. With no current stay, the latest
      // of them takes the main card; any others get a "Pay" row of their own.
      const { data: owed } = await supabase.rpc('student_past_balance', { p_student: user.id })
      let leaseRow = currentLease
      if (!leaseRow && owed?.[0]) {
        leaseRow = (await supabase.from('leases').select(LEASE_SELECT).eq('id', owed[0].lease_id).maybeSingle()).data
      }
      const others = (owed ?? []).filter((o) => o.lease_id !== leaseRow?.id)
      const { data: otherLeases } = others.length
        ? await supabase.from('leases').select('id, landlord_id, allow_partial, partial_min_pct').in('id', others.map((o) => o.lease_id))
        : { data: [] }
      pastOwed.value = others.map((o) => {
        const l = otherLeases?.find((x) => x.id === o.lease_id)
        return {
          leaseId: o.lease_id,
          landlordId: l?.landlord_id ?? '',
          place: `${o.accommodation} · ${o.room}`,
          balance: Number(o.balance),
          allowPartial: Boolean(l?.allow_partial),
          partialMinPct: Number(l?.partial_min_pct ?? 10),
        }
      })
      if (!leaseRow) {
        lease.value = null
        return
      }

      const room = leaseRow.rooms as unknown as {
        room_number: string | null
        label: string | null
        room_type: string | null
        custom_room_type: string | null
        capacity: number | null
        accommodations: {
          id: string
          name: string | null
          address: string | null
          barangay: string | null
          city: string | null
          accommodation_amenities: { amenity: string }[] | null
          accommodation_policies: Record<string, unknown>[] | Record<string, unknown> | null
        } | null
      } | null

      const acc = room?.accommodations
      const amenities = ((acc?.accommodation_amenities ?? []) as { amenity: string }[]).map((a) => a.amenity).filter((a) => a in AMENITY_META)
      const policyRows = acc?.accommodation_policies
      const policy = (Array.isArray(policyRows) ? policyRows[0] : policyRows) as Record<string, unknown> | null | undefined
      const rules = policy
        ? (
            [
              { label: 'Curfew', value: String(policy.curfew_time ?? '') },
              { label: 'Quiet hours', value: String(policy.quiet_hours ?? '') },
              { label: 'Visitors', value: String(policy.visitor_policy ?? '') },
              { label: 'Cooking', value: yesNo(policy.cooking as boolean | null) },
              { label: 'Laundry', value: yesNo(policy.laundry as boolean | null) },
              { label: 'Pets', value: yesNo(policy.pets as boolean | null) },
              { label: 'Contract type', value: String(policy.contract_type ?? '') },
            ] as { label: string; value: string }[]
          ).filter((r) => r.value)
        : []

      const [{ data: manager }, { data: profile }, roommateResult, { data: cover }] = await Promise.all([
        supabase.from('users').select('full_name, initials, avatar_url, sex').eq('id', leaseRow.landlord_id).maybeSingle(),
        supabase
          .from('landlord_profiles')
          .select('avg_response_minutes')
          .eq('user_id', leaseRow.landlord_id)
          .maybeSingle(),
        leaseRow.room_id
          ? supabase
              .from('leases')
              .select('id', { count: 'exact', head: true })
              .eq('room_id', leaseRow.room_id)
              .eq('status', 'active')
              .neq('student_id', user.id)
          : Promise.resolve({ count: null }),
        acc?.id
          ? supabase.from('accommodation_images').select('url').eq('accommodation_id', acc.id).order('sort_order', { ascending: true }).limit(1).maybeSingle()
          : Promise.resolve({ data: null }),
      ])

      lease.value = {
        id: leaseRow.id,
        managerId: leaseRow.landlord_id,
        managerName: manager?.full_name || landlordTitle(manager?.sex),
        managerTitle: landlordTitle(manager?.sex),
        managerInitials: manager?.initials || initialsOf(manager?.full_name || '?'),
        managerAvatarUrl: manager?.avatar_url ? resolveAsset(manager.avatar_url) : null,
        replyMinutes: profile?.avg_response_minutes ?? null,
        accommodationName: room?.accommodations?.name || 'Your accommodation',
        roomLabel: room?.label || (room?.room_number ? `Room ${room.room_number}` : ''),
        photoUrl: cover?.url ? resolveAsset(cover.url, COVER) : '',
        status: leaseRow.status as Lease['status'],
        monthlyRent: Number(leaseRow.monthly_rent ?? 0),
        allowPartial: Boolean(leaseRow.allow_partial),
        partialMinPct: Number(leaseRow.partial_min_pct ?? 50),
        startDate: leaseRow.start_date,
        endDate: leaseRow.end_date,
        leaveDate: leaseRow.leave_date,
        roomType: roomTypeLabel(room?.custom_room_type || room?.room_type),
        capacity: room?.capacity ?? null,
        address: acc?.address || [acc?.barangay, acc?.city].filter(Boolean).join(', ') || '',
        amenities,
        // The terms this lease was agreed under, copied from the room at move-in
        // (like monthly_rent) — a later change to the room doesn't reach it.
        utilities: utilitiesFromRow(leaseRow),
        rules,
        roommateCount: roommateResult.count,
      }
      depositReturned.value = !!leaseRow.deposit_returned_at
      await loadLedger()
    } catch (e) {
      error.value = errorMessage(e, 'Something went wrong.')
    } finally {
      loading.value = false
    }
  }

  // Kept alive across navigation (see MainLayout's KEEP_ALIVE_PAGES), so the
  // database pushes lease changes here instead of the page re-asking on every
  // return. utils/useLiveData.ts owns the whole policy — first load, the
  // subscription's lifetime, and how stale the data may be on return.
  const { refresh } = useLiveData({
    key: 'student-stay',
    load,
    // leases/payments are not in the realtime publication; confirmations and
    // rejections notify the student, so their notifications are the signal.
    watch: (uid) => [
      { table: 'leases', filter: `student_id=eq.${uid}` },
      { table: 'notifications', filter: `user_id=eq.${uid}` },
    ],
  })

  // Pull-to-refresh goes through useLiveData's refresh rather than load(): it
  // loads silently (no skeleton behind the spinner) and resets the freshness
  // clock, so returning to the screen does not immediately fetch again.
  function onPull(done: () => void) {
    void refresh().finally(done)
  }

  return {
    router,
    route,
    notify,
    myLandlord,
    loading,
    error,
    lease,
    payments,
    bills,
    billUtility,
    metered,
    currentLeasePayments,
    depositReturned,
    depositHeld,
    activeTab,
    panelsIs,
    panelIs,
    panelsProps,
    pastOwed,
    pastPay,
    ledger,
    loadLedger,
    leaseClosed,
    paymentDetailOpen,
    selectedPayment,
    openPaymentDetail,
    canPay,
    LEASE_SELECT,
    load,
    refresh,
    onPull,
  }
}
