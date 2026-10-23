// Reviewing one transfer: loading it with the items it paid, then confirming
// it (typed CONFIRM) or sending it back with a reason.
import { AVATAR, resolveAsset } from '@/utils/cloudinaryUrl'
import { BILL_TAG, formatReference, type LedgerRow, toLedger } from '@/utils/payments'
import { PAYMENT_METHOD_LABEL, formatDate, formatMonth, formatPesoExact } from '@/utils/format'
import { REASONS, type Row } from './model'
import { type Seed } from './model'
import { type UtilityKey } from '@/utils/listings'
import { computed, ref, watch } from 'vue'
import { confirmMoney, requirePin } from '@/utils/requirePin'
import { errorMessage } from '@/utils/errors'
import { signRows } from '@/utils/upload'
import { supabase } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'

export function createPaymentReview(ctx: Seed) {
  const { props, emit } = ctx
  const notify = useNotify()

  const loading = ref(false)
  const rows = ref<Row[]>([])
  const ledger = ref<LedgerRow[]>([])
  const billUtility = ref<Record<string, UtilityKey>>({})
  const who = ref({ name: '', place: '', avatar: '', color: '' as string | null })
  const mode = ref<'' | 'reject'>('')
  const reason = ref<string>(REASONS[1])
  const detail = ref('')
  const busy = ref(false)
  const viewer = ref('')

  const first = computed(() => rows.value[0] as Row)
  const status = computed(() => first.value?.status ?? '')
  const pending = computed(() => status.value === 'pending_verification')
  const cash = computed(() => first.value?.method === 'cash')
  const methodLabel = computed(() => PAYMENT_METHOD_LABEL[first.value?.method ?? ''] ?? 'Other')
  const total = computed(() => rows.value.reduce((s, r) => s + Number(r.amount), 0))
  const proof = computed(() => (first.value?.proof_url ? resolveAsset(first.value.proof_url) : ''))
  const sentAt = computed(() => first.value?.created_at ?? '')
  const waitDays = computed(() => (sentAt.value ? Math.floor((Date.now() - new Date(sentAt.value).getTime()) / 86400000) : 0))
  const firstName = computed(() => who.value.name.split(' ')[0] || 'The student')
  const reviewer = computed(() => (pending.value ? '' : first.value?.verified_by_user?.full_name ?? ''))
  const headline = computed(() => {
    if (pending.value) return props.student ? 'Waiting to be confirmed' : cash.value ? 'Cash to confirm' : 'To confirm'
    return status.value === 'paid' ? 'Confirmed' : status.value === 'rejected' ? 'Sent back' : status.value === 'withdrawn' ? 'Taken back' : status.value === 'waived' ? 'Forgiven' : status.value
  })

  const proofCaption = computed(() => `${props.student ? 'What you sent' : who.value.name} · ${capitalize(whatList.value)}`)
  const proofCompare = computed(() =>
    pending.value
      ? { reference: first.value?.txn_reference ?? '', amount: formatPesoExact(total.value), method: methodLabel.value, sent: formatDate(sentAt.value) }
      : null,
  )

  const items = computed(() => rows.value.map((r) => ({
    id: r.id,
    amount: Number(r.amount),
    name: r.kind === 'bill'
      ? `${BILL_TAG[billUtility.value[r.bill_id ?? ''] ?? 'water'] ?? 'Utility bill'} · ${formatMonth(r.month).split(' ')[0]}`
      : r.kind === 'deposit' ? 'Deposit' : `${formatMonth(r.month).split(' ')[0]} rent`,
  })))
  const whatList = computed(() => {
    // "October rent and the water bill"
    const names = items.value.map((i) => (i.name.includes(' · ') ? `the ${i.name.split(' · ')[0]!.toLowerCase()}` : i.name))
    return names.length > 1 ? `${names.slice(0, -1).join(', ')} and ${names[names.length - 1]}` : names[0] ?? 'it'
  })
  const capitalize = (s: string) => s.charAt(0).toUpperCase() + s.slice(1)
  // One item paid only in part: what is still left on it after this payment.
  const partial = computed(() => {
    if (rows.value.length !== 1 || !pending.value) return null
    const r = first.value
    const row = ledger.value.find((x) => (r.kind === 'bill' ? x.billId === r.bill_id : x.kind === r.kind && (r.kind !== 'rent' || x.month?.slice(0, 7) === r.month.slice(0, 7))))
    return row && row.balance > 0.009 ? { left: row.balance, due: row.due } : null
  })
  const reasonText = computed(() => {
    const more = detail.value.trim()
    if (reason.value === 'Something else') return more
    return more ? `${reason.value}\n${more}` : reason.value
  })

  watch(
    () => [props.modelValue, props.paymentId] as const,
    async ([open, id]) => {
      if (!open || !id) return
      mode.value = ''
      detail.value = ''
      reason.value = REASONS[1]
      loading.value = true
      try {
        const { data: one, error: e1 } = await supabase.from('payments').select('batch_id, lease_id').eq('id', id).single()
        if (e1) throw e1
        const cols = 'id,lease_id,batch_id,kind,month,bill_id,amount,method,status,txn_reference,proof_url,note,promise_date,created_at,paid_at,rejection_reason,receipt_no,verified_by_user:users!payments_verified_by_fkey(full_name)'
        const [{ data: batch, error: e2 }, { data: lease }, { data: led }, { data: bills }] = await Promise.all([
          one.batch_id ? supabase.from('payments').select(cols).eq('batch_id', one.batch_id) : supabase.from('payments').select(cols).eq('id', id),
          supabase
            .from('leases')
            .select('users!leases_student_id_fkey(full_name,avatar_color,avatar_url),landlord:users!leases_landlord_id_fkey(full_name,avatar_color,avatar_url),rooms(label,room_number,accommodations(name))')
            .eq('id', one.lease_id)
            .single(),
          supabase.rpc('lease_ledger', { p_lease: one.lease_id }),
          supabase.from('utility_bills').select('id,utility').eq('lease_id', one.lease_id),
        ])
        if (e2) throw e2
        const list = (batch ?? []) as unknown as Row[]
        await signRows('payments', list, 'proof_url')
        rows.value = list.sort((a, b) => a.kind.localeCompare(b.kind) || a.month.localeCompare(b.month))
        ledger.value = toLedger(led)
        billUtility.value = Object.fromEntries((bills ?? []).map((b) => [b.id, b.utility as UtilityKey]))
        // The other side of the payment: the student for the landlord/landlady, and the reverse.
        type Person = { full_name: string | null; avatar_color: string | null; avatar_url: string | null } | null
        const person = (props.student ? lease?.landlord : lease?.users) as unknown as Person
        const room = lease?.rooms as unknown as { label: string | null; room_number: string | null; accommodations: { name: string | null } | null } | null
        who.value = {
          name: person?.full_name || (props.student ? 'Your landlord/landlady' : 'A student'),
          place: [room?.label || (room?.room_number ? `Room ${room.room_number}` : ''), room?.accommodations?.name].filter(Boolean).join(' · '),
          avatar: person?.avatar_url ? resolveAsset(person.avatar_url, AVATAR) : '',
          color: person?.avatar_color ?? null,
        }
      } catch (e) {
        notify.error(errorMessage(e, 'Could not load this payment.'))
        emit('update:modelValue', false)
      } finally {
        loading.value = false
      }
    },
    { immediate: true },
  )

  function startReject() {
    // A cash payment can't have a reference problem; start on the likelier reason.
    reason.value = cash.value ? REASONS[3] : REASONS[1]
    detail.value = ''
    mode.value = 'reject'
  }

  async function run(action: 'confirm' | 'reject') {
    busy.value = true
    try {
      const { error } = await supabase.rpc('review_payment', {
        p_payment: first.value.id,
        p_action: action,
        ...(action === 'reject' ? { p_reason: reasonText.value } : {}),
      })
      if (error) throw error
      notify.success(action === 'confirm' ? 'Payment confirmed.' : `Sent back to ${firstName.value}.`)
      emit('update:modelValue', false)
      emit('changed')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not update this payment.'))
    } finally {
      busy.value = false
    }
  }

  async function confirm() {
    const checks = cash.value
      ? [`I have ${formatPesoExact(total.value)} in cash from ${firstName.value}`]
      : [`I see ${formatPesoExact(total.value)} in my ${methodLabel.value}`, ...(first.value.txn_reference ? [`The reference matches ${formatReference(first.value.method, first.value.txn_reference)}`] : [])]
    const ok = await confirmMoney(
      `Did ${formatPesoExact(total.value)} really reach you?`,
      `Confirming marks ${whatList.value} as paid for ${firstName.value}. This can't be undone.`,
      checks,
      `Confirm ${formatPesoExact(total.value)}`,
    )
    if (ok) await run('confirm')
  }

  async function reject() {
    if (!reasonText.value) return notify.error('Say why, so they can fix it.')
    if (!(await requirePin({ title: 'Reject this payment?' }))) return
    await run('reject')
  }

  return {
    notify,
    loading,
    rows,
    ledger,
    billUtility,
    who,
    mode,
    reason,
    detail,
    busy,
    viewer,
    first,
    status,
    pending,
    cash,
    methodLabel,
    total,
    proof,
    sentAt,
    waitDays,
    firstName,
    reviewer,
    headline,
    proofCaption,
    proofCompare,
    items,
    whatList,
    capitalize,
    partial,
    reasonText,
    startReject,
    run,
    confirm,
    reject,
  }
}
