// What the landlord/landlady does from the profile: decide an application or
// a leave request, end the stay, set payment terms, forgive or fix a bill,
// open a payment, rate the boarder.
import { BILL_TAG, type LedgerRow, manilaToday } from '@/utils/payments'
import { type FixBill } from '@/components/manager/BillFixSheet.vue'
import { type ForgiveTarget } from '@/components/manager/ForgiveSheet.vue'
import { authUser, supabase } from '@/utils/supabase'
import { computed, reactive, ref } from 'vue'
import { confirmAction } from '@/utils/confirmAction'
import { requirePin } from '@/utils/requirePin'
import { errorMessage } from '@/utils/errors'
import { formatDate, formatMonth } from '@/utils/format'
import { respondToApplication } from '@/utils/applications'
import type { createTenantState } from './state'

export function createTenantActions(ctx: ReturnType<typeof createTenantState>) {
  const { notify, deciding, lease, ledger, loadLedger, tenantReview, bills, today, leaseId, load } = ctx
  const savingPartial = ref(false)
  async function setPartial(allow: boolean, pct = lease.partialMinPct) {
    if (savingPartial.value) return
    savingPartial.value = true
    const { error: e } = await supabase.from('leases').update({ allow_partial: allow, partial_min_pct: pct }).eq('id', leaseId.value)
    savingPartial.value = false
    if (e) return notify.error(errorMessage(e, 'Could not change partial payments.'))
    lease.allowPartial = allow
    lease.partialMinPct = pct
    notify.success(allow ? `Partial payments on — at least ${pct}% at a time.` : 'Partial payments off.')
  }
  // When rent falls due each month, and how long before it counts as overdue.
  const moveInDay = computed(() => Math.min(Number(lease.startDate.slice(8, 10)) || 1, 28))
  function ordinal(n: number): string {
    const s = n % 100 >= 11 && n % 100 <= 13 ? 'th' : ({ 1: 'st', 2: 'nd', 3: 'rd' } as Record<number, string>)[n % 10] ?? 'th'
    return `${n}${s}`
  }
  const dueDayOptions = computed(() => [
    { label: `on the move-in day (${ordinal(moveInDay.value)})`, value: 0 },
    ...Array.from({ length: 28 }, (_, i) => ({ label: `every ${ordinal(i + 1)}`, value: i + 1 })),
  ])
  const savingTerms = ref(false)
  async function setDueTerms(day: number | null, grace: number) {
    if (savingTerms.value) return
    savingTerms.value = true
    const { error: e } = await supabase.from('leases').update({ rent_due_day: day, grace_days: grace }).eq('id', leaseId.value)
    savingTerms.value = false
    if (e) return notify.error(errorMessage(e, 'Could not change when rent is due.'))
    lease.rentDueDay = day
    lease.graceDays = grace
    notify.success(`Rent is due every ${ordinal(day ?? moveInDay.value)}${grace ? `, overdue ${grace} days later` : ''}.`)
    void loadLedger()
  }

  const termsOpen = ref(false)
  const termsLine = computed(() => {
    const grace = lease.graceDays ? `${lease.graceDays} days grace` : 'no grace'
    const partial = lease.allowPartial ? `partial payments of ${lease.partialMinPct}% or more` : 'no partial payments'
    return `${grace} · ${partial}`
  })

  // Forgiving what's left of an item (ForgiveSheet → waive_balance).
  const logOpen = ref(false)
  const forgiveOpen = ref(false)
  const forgiveTarget = ref<ForgiveTarget | null>(null)
  function forgiveRow(r: LedgerRow) {
    const b = r.kind === 'bill' ? bills.value.find((x) => x.id === r.billId) : undefined
    forgiveTarget.value = b
      ? { kind: 'bill', month: b.month, billId: b.id, balance: r.balance, label: `the ${BILL_TAG[b.utility].toLowerCase()} for ${formatMonth(b.month).split(' ')[0]}` }
      : { kind: r.kind, month: r.month ?? today, billId: null, balance: r.balance, label: r.kind === 'rent' ? `${formatMonth(r.month).split(' ')[0]} rent` : 'the deposit' }
    forgiveOpen.value = true
  }

  // Correcting a bill posted with the wrong amount (BillFixSheet).
  const fixOpen = ref(false)
  const fixBill = ref<FixBill | null>(null)
  function openFixBill(billId: string) {
    const b = bills.value.find((x) => x.id === billId)
    if (!b) return
    const row = ledger.value.find((r) => r.billId === billId)
    fixBill.value = {
      id: b.id,
      label: `${BILL_TAG[b.utility]} · ${formatMonth(b.month).split(' ')[0]}`,
      amount: b.amount,
      paid: row ? row.confirmed + row.pending + row.waived : 0,
    }
    fixOpen.value = true
  }

  const decisionReasonFor = ref<'' | 'reject' | 'keep' | 'end'>('')
  const decisionReason = ref('')

  async function decide(next: 'active' | 'rejected') {
    if (deciding.value) return
    if (next === 'rejected' && !decisionReason.value.trim()) return
    deciding.value = true
    try {
      await respondToApplication(leaseId.value, next, next === 'rejected' ? decisionReason.value.trim() : undefined)
      lease.status = next
      notify.success(next === 'active' ? 'Application accepted.' : 'Application declined.')
      decisionReasonFor.value = ''
    } catch (e) {
      notify.error(errorMessage(e, 'Could not update this application.'))
    } finally {
      deciding.value = false
    }
  }

  async function approveLeave() {
    const today = manilaToday()
    const later = !!lease.leaveDate && lease.leaveDate > today
    if (!(await requirePin({
      confirm: true,
      title: 'Approve this leave request?',
      message: later
        ? `The stay runs until ${formatDate(lease.leaveDate)}, then ends and the room is freed.`
        : 'Their stay ends today and the room is freed.',
    }))) return
    if (deciding.value) return
    deciding.value = true
    try {
      // approve_leave (20261012010000) runs the stay to the leave date, or ends
      // it today if that day has come. Ending stamps the end date and writes the
      // stay into the student's history (tg_lease_history) server-side.
      const { error: rpcError } = await supabase.rpc('approve_leave', { p_lease: leaseId.value })
      if (rpcError) throw rpcError
      notify.success(later ? `Approved — they move out ${formatDate(lease.leaveDate)}.` : 'Leave request approved.')
      void load(true)
    } catch (e) {
      notify.error(errorMessage(e, 'Could not approve the leave request.'))
    } finally {
      deciding.value = false
    }
  }

  // The landlord/landlady closes a stay the student never asked to leave: the term
  // is over, they moved out without a word, or (terminate) they broke the house
  // rules. The student is told the reason; the database requires one.
  async function endStay(terminate: boolean) {
    const reason = decisionReason.value.trim()
    if (deciding.value || !reason) return
    if (!(await confirmAction({
      title: terminate ? 'Terminate this stay?' : 'End this stay?',
      message: 'It ends today and the room is freed. The student sees your reason.',
    }))) return
    deciding.value = true
    try {
      const { error: updateError } = await supabase
        .from('leases')
        .update({
          status: terminate ? 'terminated' : 'ended',
          ended_reason: terminate ? 'terminated' : 'stay_ended',
          decision_reason: reason,
        })
        .eq('id', leaseId.value)
      if (updateError) throw updateError
      lease.status = terminate ? 'terminated' : 'ended'
      decisionReasonFor.value = ''
      notify.success(terminate ? 'Stay terminated.' : 'Stay ended.')
      void load(true)
    } catch (e) {
      notify.error(errorMessage(e, 'Could not end this stay.'))
    } finally {
      deciding.value = false
    }
  }

  async function declineLeave() {
    const reason = decisionReason.value.trim()
    if (deciding.value || !reason) return
    if (!(await requirePin({ title: 'Refuse this leave request?' }))) return
    deciding.value = true
    try {
      const { error: updateError } = await supabase
        .from('leases')
        .update({ status: 'active', leave_requested_at: null, leave_date: null, decision_reason: reason })
        .eq('id', leaseId.value)
      if (updateError) throw updateError
      lease.status = 'active'
      notify.success('Leave request declined.')
      decisionReasonFor.value = ''
    } catch (e) {
      notify.error(errorMessage(e, 'Could not update the leave request.'))
    } finally {
      deciding.value = false
    }
  }

  const paymentDetailOpen = ref(false)
  const selectedPayment = ref<(typeof ctx.payments.value)[number] | null>(null)
  function openPaymentDetail(p: (typeof ctx.payments.value)[number]) {
    selectedPayment.value = p
    paymentDetailOpen.value = true
  }

  const reviewOpen = ref(false)
  const submittingReview = ref(false)
  const reviewForm = reactive({ rating: 0, comment: '' })

  function openReview() {
    reviewForm.rating = 0
    reviewForm.comment = ''
    reviewOpen.value = true
  }

  async function submitTenantReview() {
    if (submittingReview.value) return
    if (!reviewForm.rating) {
      notify.error('Give a star rating.')
      return
    }
    submittingReview.value = true
    try {
      const { data: authData } = await authUser()
      const managerId = authData?.user?.id
      if (!managerId) throw new Error('Not logged in.')

      const { error: insertError } = await supabase.from('reviews').insert({
        kind: 'tenant',
        lease_id: leaseId.value,
        student_id: lease.studentId,
        landlord_id: managerId,
        rating: reviewForm.rating,
        comment: reviewForm.comment.trim() || null,
      })
      if (insertError) throw insertError

      tenantReview.value = { rating: reviewForm.rating, comment: reviewForm.comment.trim() }
      reviewOpen.value = false
      notify.success('Rating submitted.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not submit your rating.'))
    } finally {
      submittingReview.value = false
    }
  }

  return {
    savingPartial,
    setPartial,
    moveInDay,
    ordinal,
    dueDayOptions,
    savingTerms,
    setDueTerms,
    termsOpen,
    termsLine,
    logOpen,
    forgiveOpen,
    forgiveTarget,
    forgiveRow,
    fixOpen,
    fixBill,
    openFixBill,
    decisionReasonFor,
    decisionReason,
    decide,
    approveLeave,
    endStay,
    declineLeave,
    paymentDetailOpen,
    selectedPayment,
    openPaymentDetail,
    reviewOpen,
    submittingReview,
    reviewForm,
    openReview,
    submitTenantReview,
  }
}
