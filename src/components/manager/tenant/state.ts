// One lease: the boarder, their stay, what is owed and paid, their history,
// and the live subscription that keeps it fresh.
import { AVATAR, COVER, resolveAsset } from '@/utils/cloudinaryUrl'
import { type LedgerRow, isBillSettled, manilaToday, toLedger } from '@/utils/payments'
import { type TimelineStay } from '@/components/shared/BoardingTimeline.vue'
import { UTILITIES, type UtilityKey, isBilledMonthly, roomTypeLabel } from '@/utils/listings'
import { computed, reactive, ref } from 'vue'
import { errorMessage } from '@/utils/errors'
import { initialsOf, stayProgress } from '@/utils/format'
import { signRows } from '@/utils/upload'
import { supabase } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { useNotify } from '@/utils/notify'
import { useRoute, useRouter } from 'vue-router'

export function createTenantState() {
  const route = useRoute()
  const router = useRouter()
  const notify = useNotify()

  const loading = ref(true)
  const error = ref('')
  const deciding = ref(false)

  const lease = reactive({
    status: '',
    studentId: '',
    studentName: '',
    studentInitials: '?',
    studentAvatarUrl: '' as string | null,
    email: '',
    phone: '',
    roomLabel: '',
    accommodationName: '',
    startDate: '',
    endDate: '',
    leaveDate: '' as string | null,
    monthlyRent: 0,
    addedByLandlord: false,
    allowPartial: false,
    partialMinPct: 10,
    rentDueDay: null as number | null,
    graceDays: 3,
  })

  // What is owed on this stay (lease_ledger): the balance line and the partial-
  // payment terms below read it; the database enforces both.
  const ledger = ref<LedgerRow[]>([])
  async function loadLedger() {
    if (!leaseId.value || lease.status === 'pending') { ledger.value = []; return }
    const { data } = await supabase.rpc('lease_ledger', { p_lease: leaseId.value })
    ledger.value = toLedger(data)
  }

  // The deposit still held: what was paid toward it, less what it has paid for.
  // It can be used once the stay is ending (UseDepositSheet).
  const depositOpen = ref(false)
  const depositReturned = ref(false)
  const depositHeld = computed(() => {
    if (depositReturned.value) return 0
    const paidIn = payments.value.filter((p) => p.kind === 'deposit' && p.status === 'paid').reduce((s, p) => s + p.amount, 0)
    const usedUp = payments.value.filter((p) => p.method === 'deposit' && p.status === 'paid').reduce((s, p) => s + p.amount, 0)
    return Math.max(paidIn - usedUp, 0)
  })
  const depositUsable = computed(
    () => ['leave_requested', 'ended', 'terminated'].includes(lease.status) || (!!lease.endDate && lease.endDate.slice(0, 7) <= today.slice(0, 7)),
  )

  const coverUrl = ref('')
  const payments = ref<
    {
      id: string
      month: string
      kind: string
      billId: string | null
      amount: number
      status: string
      method: string
      description: string
      txnReference: string
      proofUrl: string
      paidAt: string | null
      verifiedByName: string
      rejectionReason: string
      note: string
      promiseDate: string | null
      createdAt: string
      batchId: string | null
    }[]
  >([])
  const history = ref<TimelineStay[]>([])
  const tenantReview = ref<{ rating: number; comment: string } | null>(null)

  // Utilities this place bills monthly, and the bills posted against this lease.
  const billing = ref<Record<UtilityKey, string | null>>({ water: null, electric: null, wifi: null })
  const monthlyUtilities = computed(() =>
    UTILITIES.filter((u) => isBilledMonthly(billing.value[u.key])).map((u) => ({ key: u.key, label: u.label, billing: billing.value[u.key] as string })),
  )
  const canPostBill = computed(() => monthlyUtilities.value.length > 0 && (lease.status === 'active' || lease.status === 'leave_requested'))
  type Bill = { id: string; utility: UtilityKey; month: string; amount: number; note: string; dueDate: string; settled: boolean }
  const bills = ref<Bill[]>([])
  // Which utility each bill is, for the statement's labels.
  const billUtility = computed(() => Object.fromEntries(bills.value.map((b) => [b.id, b.utility])))
  const postBillOpen = ref(false)
  const today = manilaToday()

  const leaseId = computed(() => String(route.params.leaseId || ''))

  // The Overview's stay bar. A stay that never began has nothing to measure.
  const stay = computed(() =>
    lease.status === 'pending' ? { pct: 0, label: 'Starts once you accept' }
      : lease.status === 'rejected' ? { pct: 0, label: 'Declined — this stay never started' }
        : stayProgress(lease.startDate, lease.endDate, today),
  )

  async function load(silent = false) {
    if (!silent) loading.value = true
    error.value = ''
    try {
      const { data, error: loadError } = await supabase
        .from('leases')
        .select(
          'id,status,start_date,end_date,leave_date,deposit_returned_at,monthly_rent,allow_partial,partial_min_pct,rent_due_day,grace_days,student_id,landlord_id,room_id,added_by_landlord,water_billing,electric_billing,wifi_billing,users!leases_student_id_fkey(full_name,initials,avatar_url,cover_url),contact:users_full!leases_student_id_fkey(email,phone),rooms(label,room_number,room_type,accommodation_id,accommodations(name,accommodation_images(url,sort_order)))',
        )
        .eq('id', leaseId.value)
        .maybeSingle()
      if (loadError) throw loadError
      if (!data) {
        error.value = 'This boarder record could not be found.'
        return
      }

      // E-mail and phone come from users_full, which answers only while the lease
      // is current; a past tenant keeps their name here but not their contacts.
      const contact = data.contact as unknown as { email: string | null; phone: string | null } | null
      const person = data.users as unknown as { full_name: string | null; initials: string | null; avatar_url: string | null; cover_url: string | null } | null
      const student = person ? { ...person, email: contact?.email ?? null, phone: contact?.phone ?? null } : null
      const room = data.rooms as unknown as {
        label: string | null
        room_number: string | null
        room_type: string | null
        accommodation_id: string
        accommodations: {
          name: string | null
          accommodation_images: { url: string; sort_order: number | null }[] | null
        } | null
      } | null
      // The terms this tenant's lease was agreed under decide which bills can
      // be posted for them — not whatever the room says today.
      billing.value = { water: data.water_billing, electric: data.electric_billing, wifi: data.wifi_billing }

      lease.status = data.status
      lease.addedByLandlord = data.added_by_landlord
      lease.studentId = data.student_id
      lease.studentName = student?.full_name || 'A student'
      lease.studentInitials = student?.initials || initialsOf(lease.studentName)
      lease.studentAvatarUrl = student?.avatar_url ? resolveAsset(student.avatar_url, AVATAR) : null
      lease.email = student?.email || ''
      lease.phone = student?.phone || ''
      lease.roomLabel = room?.label || (room?.room_number ? `Room ${room.room_number}` : 'Room')
      lease.accommodationName = room?.accommodations?.name || 'Accommodation'

      const cover = [...(room?.accommodations?.accommodation_images ?? [])].sort(
        (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
      )[0]
      // The student's own cover photo when they set one; the boarding house otherwise.
      const coverSrc = student?.cover_url || cover?.url
      coverUrl.value = coverSrc ? resolveAsset(coverSrc, COVER) : ''
      lease.startDate = data.start_date
      lease.endDate = data.end_date
      lease.leaveDate = data.leave_date
      lease.monthlyRent = Number(data.monthly_rent ?? 0)
      lease.allowPartial = Boolean(data.allow_partial)
      lease.partialMinPct = Number(data.partial_min_pct ?? 10)
      lease.rentDueDay = data.rent_due_day
      lease.graceDays = data.grace_days
      depositReturned.value = !!data.deposit_returned_at
      void loadLedger()

      const [{ data: paymentRows }, { data: historyRows }, { data: billRows }] = await Promise.all([
        supabase
          .from('payments')
          .select(
            'id,month,amount,status,method,kind,bill_id,description,txn_reference,proof_url,paid_at,rejection_reason,note,promise_date,created_at,batch_id,verified_by_user:users!payments_verified_by_fkey(full_name)',
          )
          .eq('lease_id', leaseId.value)
          .order('month', { ascending: false }),
        supabase
          .from('boarding_history')
          .select('id,accommodation_name,room_type,period_start,period_end,end_reason,accommodations(landlord_id)')
          .eq('student_id', data.student_id)
          .order('period_start', { ascending: false }),
        supabase
          .from('utility_bills')
          .select('id,utility,month,amount,note,due_date,payments(status, amount)')
          .eq('lease_id', leaseId.value)
          .order('month', { ascending: true }),
      ])
      bills.value = (billRows ?? []).map((b) => ({
        id: b.id,
        utility: b.utility as UtilityKey,
        month: b.month,
        amount: Number(b.amount),
        note: b.note || '',
        dueDate: b.due_date,
        settled: isBillSettled(b.payments, Number(b.amount)),
      }))
      await signRows('payments', paymentRows, 'proof_url')
      payments.value = (paymentRows ?? []).map((p) => ({
        id: p.id,
        month: p.month,
        kind: p.kind,
        billId: p.bill_id,
        amount: Number(p.amount),
        status: p.status,
        method: p.method,
        description: p.description || '',
        txnReference: p.txn_reference || '',
        proofUrl: p.proof_url || '',
        paidAt: p.paid_at,
        verifiedByName: (p.verified_by_user as { full_name: string | null } | null)?.full_name || '',
        rejectionReason: p.rejection_reason || '',
        note: p.note || '',
        promiseDate: p.promise_date,
        createdAt: p.created_at,
        batchId: p.batch_id,
      }))
      // Only this landlord/landlady's leases are readable here, so the lease's
      // landlord_id is the viewer — no extra auth round trip.
      history.value = (historyRows ?? []).map((h) => ({
        id: h.id,
        name: h.accommodation_name || 'Accommodation',
        room: roomTypeLabel(h.room_type),
        start: h.period_start,
        end: h.period_end,
        endReason: h.end_reason,
        mine: (h.accommodations as { landlord_id: string } | null)?.landlord_id === data.landlord_id,
      }))

      if (data.status === 'ended' || data.status === 'terminated') {
        // The review this landlord/landlady wrote, read back through the "written by me"
        // view. `unique (lease_id)` now guarantees at most one row, which is what
        // maybeSingle() always assumed — a second row used to make it throw.
        const { data: reviewRow } = await supabase
          .from('review_written_leases')
          .select('rating,comment')
          .eq('kind', 'tenant')
          .eq('lease_id', leaseId.value)
          .maybeSingle()
        tenantReview.value = reviewRow ? { rating: reviewRow.rating ?? 0, comment: reviewRow.comment || '' } : null
      }
    } catch (e) {
      error.value = errorMessage(e, 'Something went wrong.')
    } finally {
      loading.value = false
    }
  }

  // Kept alive per lease id (see MainLayout's KEEP_ALIVE_PAGES + the
  // route.fullPath key), so lease and payment changes push here instead of the
  // page re-asking on return. utils/useLiveData.ts owns the whole policy — the
  // key folds in the lease id so each tenant gets its own freshness clock.
  useLiveData({
    key: () => `manager-tenant:${leaseId.value}`,
    load,
    watch: () =>
      leaseId.value
        ? [
            { table: 'leases', filter: `id=eq.${leaseId.value}` },
            { table: 'payments', filter: `lease_id=eq.${leaseId.value}` },
          ]
        : [],
  })

  return {
    route,
    router,
    notify,
    loading,
    error,
    deciding,
    lease,
    ledger,
    loadLedger,
    depositOpen,
    depositReturned,
    depositHeld,
    depositUsable,
    coverUrl,
    payments,
    history,
    tenantReview,
    billing,
    monthlyUtilities,
    canPostBill,
    bills,
    billUtility,
    postBillOpen,
    today,
    leaseId,
    stay,
    load,
  }
}
