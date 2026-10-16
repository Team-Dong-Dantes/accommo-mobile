// What the boarder does from My Stay: ask to leave, pay or resubmit a
// payment, withdraw one.
import { type Payment } from './model'
import { type Resubmit } from '@/components/shared/PaySheet.vue'
import { authUser, supabase } from '@/utils/supabase'
import { confirmAction } from '@/utils/confirmAction'
import { errorMessage } from '@/utils/errors'
import { manilaToday } from '@/utils/payments'
import { ref } from 'vue'
import type { createStayState } from './state'

export function createStayActions(ctx: ReturnType<typeof createStayState>) {
  const { notify, myLandlord, lease, currentLeasePayments, paymentDetailOpen, load } = ctx
  const leaveDialog = ref(false)
  const leaveDate = ref('')
  // Defaults to the end of this month, or the end of the stay if that's sooner.
  function openLeave() {
    const t = manilaToday()
    const d = new Date(`${t.slice(0, 7)}-01T00:00:00`)
    d.setMonth(d.getMonth() + 1)
    d.setDate(0)
    const monthEnd = d.toLocaleDateString('en-CA')
    leaveDate.value = lease.value?.endDate && lease.value.endDate < monthEnd ? lease.value.endDate : monthEnd
    leaveDialog.value = true
  }
  const leaving = ref(false)

  const payOpen = ref(false)
  // A transfer sent back, opened again with the same items and the reason in view.
  const resubmit = ref<Resubmit | null>(null)
  function openPay(r: Resubmit | null) {
    resubmit.value = r
    payOpen.value = true
  }
  function startResubmit(p: Payment) {
    const batch = currentLeasePayments.value.filter((x) => (p.batchId ? x.batchId === p.batchId : x.id === p.id))
    openPay({
      reason: p.rejectionReason,
      method: p.method,
      reference: p.txnReference,
      pick: {
        months: batch.filter((x) => x.kind === 'rent').length,
        billIds: batch.filter((x) => x.kind === 'bill' && x.billId).map((x) => x.billId as string),
        deposit: batch.some((x) => x.kind === 'deposit'),
      },
    })
  }

  async function requestLeave() {
    if (!(await confirmAction({ title: 'Request to leave?', message: `Your ${myLandlord.value} will be asked to approve it.` }))) return
    if (leaving.value || !lease.value) return
    leaving.value = true
    try {
      const { data: authData } = await authUser()
      const user = authData?.user
      if (!user) throw new Error('Not logged in.')

      const { error: updateError } = await supabase
        .from('leases')
        .update({ status: 'leave_requested', leave_requested_at: new Date().toISOString(), leave_date: leaveDate.value })
        .eq('id', lease.value.id)
        .eq('student_id', user.id)
      if (updateError) throw updateError

      lease.value = { ...lease.value, status: 'leave_requested', leaveDate: leaveDate.value }
      leaveDialog.value = false
      notify.success('Leave request sent.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not send your leave request.'))
    } finally {
      leaving.value = false
    }
  }

  const withdrawing = ref(false)
  async function withdrawPayment(p: Payment) {
    if (withdrawing.value) return
    if (!(await confirmAction({ title: 'Withdraw this payment?', message: `It is taken back before your ${myLandlord.value} reviews it. You can submit a new one.` }))) return
    withdrawing.value = true
    try {
      const { error: rpcError } = await supabase.rpc('review_payment', { p_payment: p.id, p_action: 'withdraw' })
      if (rpcError) throw rpcError
      paymentDetailOpen.value = false
      notify.success('Payment withdrawn.')
      void load(true)
    } catch (e) {
      notify.error(errorMessage(e, 'Could not withdraw this payment.'))
    } finally {
      withdrawing.value = false
    }
  }

  return {
    leaveDialog,
    leaveDate,
    openLeave,
    leaving,
    payOpen,
    resubmit,
    openPay,
    startResubmit,
    requestLeave,
    withdrawing,
    withdrawPayment,
  }
}
