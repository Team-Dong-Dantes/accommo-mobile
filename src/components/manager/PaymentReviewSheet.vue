<template>
  <AppModal :model-value="modelValue" tall @update:model-value="emit('update:modelValue', $event)">
    <template #header>
      <button v-if="mode === 'reject'" type="button" class="rv-back" aria-label="Back to the payment" @click="mode = ''">
        <IconifyIcon icon="lucide:chevron-left" width="20" />
      </button>
      <template v-if="mode === 'reject'">
        <span class="mx-head">
          <h3 class="mx-head-title">Why reject it?</h3>
          <span class="mx-head-sub">{{ who.name }} · {{ formatPesoExact(total) }} by {{ methodLabel }}</span>
        </span>
      </template>
      <template v-else>
        <span class="rv-avatar" :class="who.color ? [`bg-${who.color}`, 'text-white'] : []">
          <img v-if="who.avatar" :src="who.avatar" alt="" />
          <template v-else>{{ initialsOf(who.name) }}</template>
        </span>
        <span class="mx-head">
          <span class="rv-name">{{ who.name }}</span>
          <span class="mx-head-sub">{{ who.place }}<template v-if="sentAt"> · sent {{ formatDate(sentAt) }}</template></span>
        </span>
        <span v-if="pending && waitDays >= 1" class="rv-wait" :class="{ 'rv-wait--long': waitDays >= 3 }">
          Waiting {{ waitDays }} day{{ waitDays === 1 ? '' : 's' }}
        </span>
      </template>
    </template>

    <div v-if="loading" class="mx-body rv-center"><q-spinner size="24px" color="primary" /></div>

    <!-- Reject: a reason the student reads, then they fix it and send again. -->
    <div v-else-if="mode === 'reject'" class="mx-body">
      <div class="mx-radio-list" role="radiogroup" aria-label="Reason">
        <button
          v-for="r in REASONS"
          :key="r"
          type="button"
          role="radio"
          class="mx-radio"
          :class="{ 'mx-radio--on': reason === r }"
          :aria-checked="reason === r"
          @click="reason = r"
        >
          <span class="mx-radio-dot" />{{ r }}
        </button>
      </div>
      <label class="mx-field">
        <span class="mx-label">Tell {{ firstName }} more</span>
        <textarea v-model="detail" rows="3" maxlength="300" class="mx-input" />
      </label>
      <div class="mx-banner mx-banner--danger">
        <IconifyIcon icon="lucide:circle-alert" width="18" class="mx-banner-icon" />
        <span>{{ firstName }} sees this reason in Payments, with a button to send it again. {{ capitalize(whatList) }} stay <b>unpaid</b> until a corrected payment comes in.</span>
      </div>
    </div>

    <div v-else-if="rows.length" class="mx-body">
      <div class="rv-top">
        <div class="rv-amount">
          <span class="rv-kicker" :class="pending ? 'rv-status--blue' : `rv-status--${statusColor(PAYMENT_STATUS, status)}`">{{ headline }}</span>
          <span class="rv-big">{{ formatPesoExact(total) }}</span>
          <span class="rv-by">{{ cash ? 'no receipt for cash, so only you can tell' : `by ${methodLabel}` }}</span>
        </div>
        <button v-if="proof" type="button" class="rv-proof" aria-label="Open receipt screenshot" @click="viewer = proof">
          <img :src="proof" alt="" />
          <span class="rv-proof-zoom"><IconifyIcon icon="lucide:maximize-2" width="12" /></span>
        </button>
      </div>

      <!-- Part of one item: what came now, what is left, and the promise. -->
      <div v-if="partial" class="mx-field">
        <h3 class="rv-h">Part of {{ items[0]?.name.toLowerCase() }}</h3>
        <div class="mx-list">
          <div class="rv-bar-wrap">
            <div class="rv-bar" aria-hidden="true">
              <span :style="{ flex: total }" class="rv-bar-now" />
              <span :style="{ flex: partial.left }" class="rv-bar-left" />
            </div>
            <div class="rv-bar-legend">
              <span><b>{{ formatPesoExact(total) }}</b> now</span>
              <span><b>{{ formatPesoExact(partial.left) }}</b> left of {{ formatPesoExact(partial.due) }}</span>
            </div>
          </div>
          <div v-if="first.promise_date" class="mx-kv"><span class="mx-kv-key">Rest promised by</span><span class="mx-kv-val">{{ formatDate(first.promise_date) }}</span></div>
          <div v-if="first.note" class="mx-kv"><span class="mx-kv-key">Note</span><span class="mx-kv-val rv-light">{{ first.note }}</span></div>
        </div>
      </div>

      <div v-else class="mx-field">
        <h3 class="rv-h">It pays for</h3>
        <div class="mx-list">
          <div v-for="it in items" :key="it.id" class="mx-kv"><span>{{ it.name }}</span><span class="mx-kv-val">{{ formatPesoExact(it.amount) }}</span></div>
        </div>
      </div>

      <div v-if="!partial && (first.txn_reference || first.note || first.receipt_no)" class="mx-field">
        <h3 class="rv-h">{{ pending && !cash ? `Check against your ${methodLabel}` : 'Details' }}</h3>
        <div class="mx-list">
          <div v-if="first.txn_reference" class="mx-kv"><span class="mx-kv-key">Reference no.</span><span class="mx-kv-val rv-mono">{{ first.txn_reference }}</span></div>
          <div v-if="first.receipt_no" class="mx-kv"><span class="mx-kv-key">Receipt no.</span><span class="mx-kv-val">{{ first.receipt_no }}</span></div>
          <div v-if="first.note" class="mx-kv"><span class="mx-kv-key">{{ status === 'waived' ? 'Why forgiven' : 'Note' }}</span><span class="mx-kv-val rv-light">{{ first.note }}</span></div>
        </div>
      </div>

      <div v-if="status === 'rejected' && first.rejection_reason" class="mx-banner mx-banner--danger">
        <IconifyIcon icon="lucide:undo-2" width="18" class="mx-banner-icon" />
        <span><b>Sent back</b> · {{ first.rejection_reason.replace('\n', ' — ') }}</span>
      </div>
      <p v-if="reviewer" class="mx-hint">{{ status === 'paid' ? 'Confirmed' : 'Reviewed' }} by {{ reviewer }}<template v-if="first.paid_at"> · {{ formatDate(first.paid_at) }}</template></p>
    </div>

    <template v-if="!loading && rows.length && (pending || mode === 'reject')" #footer>
      <div v-if="mode === 'reject'" class="mx-foot">
        <button type="button" class="mx-btn mx-btn--danger" :disabled="busy || !reasonText" @click="reject">
          {{ busy ? 'Rejecting…' : 'Reject and ask to resend' }}
        </button>
      </div>
      <div v-else class="mx-foot">
        <!-- Reject sends it back for the student to fix and resend (the reject
             screen says so); the amount to check is already on the sheet. -->
        <div class="mx-foot-row">
          <button type="button" class="mx-btn mx-btn--reject rv-reject" :disabled="busy" @click="startReject">Reject</button>
          <button type="button" class="mx-btn rv-ok" :disabled="busy" @click="confirm">
            {{ busy ? 'Confirming…' : 'Confirm payment' }}
          </button>
        </div>
      </div>
    </template>
  </AppModal>
  <!-- Opened from a pending payment, the viewer carries the figures the
       receipt in the photo should show, so the check needs no switching back. -->
  <PhotoViewer v-model="viewer" :caption="proofCaption" v-bind="proofCompare ? { compare: proofCompare } : {}" />
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { confirmMoney } from '@/utils/confirmAction'
import { resolveAsset, AVATAR } from '@/utils/cloudinaryUrl'
import { signRows } from '@/utils/upload'
import { formatDate, formatMonth, formatPesoExact, initialsOf, PAYMENT_METHOD_LABEL, PAYMENT_STATUS, statusColor } from '@/utils/format'
import { BILL_TAG, toLedger, type LedgerRow } from '@/utils/payments'
import type { UtilityKey } from '@/utils/listings'
import AppModal from '@/components/shared/AppModal.vue'
import PhotoViewer from '@/components/shared/PhotoViewer.vue'

// The landlord/landlady's view of one payment, and the only place it is
// reviewed. review_payment acts on the whole transfer (every row of its batch),
// so a payment that covered rent and a bill is confirmed or sent back as one.
// Confirming can't be undone, so it ends with the typed CONFIRM step; rejecting
// needs a reason the student reads before they send it again.
const props = defineProps<{ modelValue: boolean; paymentId: string | null }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; changed: [] }>()
const notify = useNotify()

const REASONS = [
  "The amount doesn't match what arrived",
  "I can't find this reference number",
  'The screenshot is unclear',
  'Nothing has arrived yet',
  'Something else',
] as const

interface Row {
  id: string
  lease_id: string
  batch_id: string | null
  kind: string
  month: string
  bill_id: string | null
  amount: number
  method: string
  status: string
  txn_reference: string | null
  proof_url: string | null
  note: string | null
  promise_date: string | null
  created_at: string
  paid_at: string | null
  rejection_reason: string | null
  receipt_no: string | null
  verified_by_user: { full_name: string | null } | null
}

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
  if (pending.value) return cash.value ? 'Cash to confirm' : 'To confirm'
  return status.value === 'paid' ? 'Confirmed' : status.value === 'rejected' ? 'Sent back' : status.value === 'withdrawn' ? 'Taken back' : status.value === 'waived' ? 'Forgiven' : status.value
})

const proofCaption = computed(() => `${who.value.name} · ${capitalize(whatList.value)}`)
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
          .select('users!leases_student_id_fkey(full_name,avatar_color,avatar_url),rooms(label,room_number,accommodations(name))')
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
      const student = lease?.users as unknown as { full_name: string | null; avatar_color: string | null; avatar_url: string | null } | null
      const room = lease?.rooms as unknown as { label: string | null; room_number: string | null; accommodations: { name: string | null } | null } | null
      who.value = {
        name: student?.full_name || 'A student',
        place: [room?.label || (room?.room_number ? `Room ${room.room_number}` : ''), room?.accommodations?.name].filter(Boolean).join(' · '),
        avatar: student?.avatar_url ? resolveAsset(student.avatar_url, AVATAR) : '',
        color: student?.avatar_color ?? null,
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
    : [`I see ${formatPesoExact(total.value)} in my ${methodLabel.value}`, ...(first.value.txn_reference ? [`The reference matches ${first.value.txn_reference}`] : [])]
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
  await run('reject')
}
</script>

<style scoped>
.rv-center {
  align-items: center;
  justify-content: center;
}
.rv-back {
  display: flex;
  width: 36px;
  height: 36px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  margin-left: -8px;
  border: 0;
  border-radius: 999px;
  background: none;
  color: var(--m-ink);
  cursor: pointer;
}
.rv-avatar {
  display: inline-flex;
  width: 40px;
  height: 40px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  border-radius: 50%;
  background: var(--m-primary-dark);
  color: #fff;
  font-size: 13px;
  font-weight: 800;
}
.rv-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.rv-name {
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
}
.rv-wait {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 5px;
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-info-soft);
  color: var(--m-info);
  font-size: 11px;
  font-weight: 700;
}
/* Three days or more reads as a nudge, not just a count. */
.rv-wait--long {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.rv-kicker,
.rv-h {
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.rv-status--blue {
  color: var(--m-info);
}
.rv-reject {
  flex: 1;
}
.rv-ok {
  flex: 2;
}
.rv-top {
  display: flex;
  align-items: flex-start;
  gap: 14px;
}
.rv-amount {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 4px;
}
.rv-status--orange,
.rv-status--amber {
  color: var(--m-info);
}
.rv-status--green {
  color: var(--m-success);
}
.rv-status--red {
  color: var(--m-danger);
}
.rv-big {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 32px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1;
}
.rv-by {
  color: var(--m-text);
  font-size: 13px;
}
.rv-proof {
  position: relative;
  width: 84px;
  height: 110px;
  flex: 0 0 auto;
  padding: 0;
  overflow: hidden;
  border: 1px dashed var(--m-border);
  border-radius: 12px;
  background: var(--m-bg);
  cursor: zoom-in;
}
.rv-proof img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.rv-proof-zoom {
  position: absolute;
  right: 6px;
  bottom: 6px;
  display: inline-flex;
  width: 26px;
  height: 26px;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: rgba(23, 32, 42, 0.7);
  color: #fff;
}
.rv-bar-wrap {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 14px;
}
.rv-bar {
  display: flex;
  height: 8px;
  gap: 3px;
}
.rv-bar-now {
  border-radius: 6px 2px 2px 6px;
  background: var(--m-info);
}
.rv-bar-left {
  border-radius: 2px 6px 6px 2px;
  background: var(--m-border);
}
.rv-bar-legend {
  display: flex;
  justify-content: space-between;
  color: var(--m-muted);
  font-size: 13px;
}
.rv-bar-legend b {
  color: var(--m-ink);
}
.rv-bar-wrap + .mx-kv {
  border-top: 1px solid var(--m-border);
}
.rv-mono {
  font-family: var(--m-font-mono);
  font-size: 13px;
  font-weight: 500;
}
.rv-light {
  font-weight: 500;
}
</style>
