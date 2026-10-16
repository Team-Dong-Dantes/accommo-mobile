<template>
  <AppModal :model-value="modelValue" title="Payment receipt" @update:model-value="emit('update:modelValue', $event)">
    <div v-if="loading || !pay" class="rc-loading"><q-spinner color="primary" size="28px" /></div>
    <template v-else>
      <div class="rc-card">
        <div class="rc-top">
          <span class="rc-chip" :class="`rc-chip--${tone}`">
            <IconifyIcon :icon="tone === 'danger' ? 'lucide:circle-x' : 'lucide:circle-check'" width="14" />
            {{ statusLabel }}
          </span>
          <span class="rc-amount" :class="{ 'rc-amount--void': pay.status === 'rejected' }">{{ formatPesoExact(pay.amount) }}</span>
          <span class="rc-title">{{ title }}</span>
        </div>
        <div class="rc-tear" aria-hidden="true" />
        <dl class="rc-rows">
          <div v-for="r in rows" :key="r.k" class="rc-row">
            <dt>{{ r.k }}</dt>
            <dd :class="{ 'rc-mono': r.mono }">{{ r.v }}</dd>
          </div>
        </dl>
      </div>

      <p v-if="pay.status === 'rejected' && pay.rejection_reason" class="rc-reason"><b>Why it was sent back:</b> {{ pay.rejection_reason }}</p>

      <button v-if="pay.proof_url" type="button" class="rc-proof" @click="viewer = pay.proof_url">
        <span class="rc-thumb"><IconifyIcon icon="lucide:image" width="20" /></span>
        <span class="rc-proof-text">
          <b>Proof of payment</b>
          <span>Open it next to the reference no.</span>
        </span>
        <IconifyIcon icon="lucide:chevron-right" width="16" class="rc-chev" />
      </button>
    </template>

    <template v-if="pay" #footer>
      <button type="button" class="rc-btn" :disabled="busy" @click="share">
        <IconifyIcon icon="lucide:share-2" width="16" />
        Share
      </button>
      <button type="button" class="rc-btn rc-btn--primary" :disabled="busy" @click="savePdf">
        <IconifyIcon icon="lucide:file-down" width="16" />
        Save as PDF
      </button>
    </template>
  </AppModal>
  <PhotoViewer v-model="viewer" caption="Proof of payment" :compare="compare" />
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import AppModal from '@/components/shared/AppModal.vue'
import PhotoViewer from '@/components/shared/PhotoViewer.vue'
import { supabase } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'
import { errorMessage } from '@/utils/errors'
import { signRows } from '@/utils/upload'
import { printHtml, shareHtml } from '@/utils/print'
import { formatMonth, formatPesoExact, parseServerTime, PAYMENT_METHOD_LABEL, PAYMENT_STATUS } from '@/utils/format'
import { paymentTitle } from '@/utils/payments'

// One finished payment as a receipt. Shared by both roles (the student's History
// and the landlord's): RLS lets each read only their own side, the screen is the
// same. Save as PDF goes through the print dialog (printHtml), Share sends the
// same document as a file (shareHtml).
const props = defineProps<{ modelValue: boolean; paymentId: string | null }>()
const emit = defineEmits<{ 'update:modelValue': [open: boolean] }>()
const notify = useNotify()

interface Pay {
  id: string
  kind: string
  month: string
  amount: number
  method: string
  status: string
  description: string | null
  txn_reference: string | null
  proof_url: string | null
  created_at: string
  paid_at: string | null
  rejection_reason: string | null
  receipt_no: string | null
  verified_by_user: { full_name: string | null } | null
  leases: {
    users: { full_name: string | null } | null
    rooms: { room_number: string | null; label: string | null; accommodations: { name: string | null } | null } | null
  } | null
}

const pay = ref<Pay | null>(null)
const loading = ref(false)
const busy = ref(false)
const viewer = ref('')

const COLS =
  'id,kind,month,amount,method,status,description,txn_reference,proof_url,created_at,paid_at,rejection_reason,receipt_no,verified_by_user:users!payments_verified_by_fkey(full_name),leases(users!leases_student_id_fkey(full_name),rooms(room_number,label,accommodations(name)))'

watch(
  () => [props.modelValue, props.paymentId] as const,
  async ([open, id]) => {
    if (!open || !id) return
    pay.value = null
    loading.value = true
    try {
      const { data, error } = await supabase.from('payments').select(COLS).eq('id', id).single()
      if (error) throw error
      const row = data as unknown as Pay
      await signRows('payments', [row], 'proof_url')
      pay.value = row
    } catch (e) {
      notify.error(errorMessage(e, 'Could not load this receipt.'))
      emit('update:modelValue', false)
    } finally {
      loading.value = false
    }
  },
  { immediate: true },
)

const when = (iso: string) =>
  parseServerTime(iso).toLocaleString('en-PH', { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' })

const tone = computed(() => (pay.value?.status === 'rejected' ? 'danger' : 'success'))
const statusLabel = computed(() => PAYMENT_STATUS[pay.value?.status ?? '']?.text ?? '')
const method = computed(() => PAYMENT_METHOD_LABEL[pay.value?.method ?? ''] ?? pay.value?.method ?? '')
const title = computed(() => {
  const p = pay.value
  if (!p) return ''
  return p.kind === 'rent' ? `${formatMonth(p.month)} rent` : paymentTitle(p)
})
const rows = computed(() => {
  const p = pay.value
  if (!p) return []
  const room = p.leases?.rooms
  const place = [p.leases?.rooms?.accommodations?.name, room?.label || (room?.room_number ? `Room ${room.room_number}` : '')].filter(Boolean).join(' · ')
  const by = p.verified_by_user?.full_name
  const label = p.status === 'rejected' ? 'Reviewed' : p.status === 'waived' ? 'Forgiven' : 'Confirmed'
  const list: { k: string; v: string; mono?: boolean }[] = [
    { k: 'Paid by', v: p.leases?.users?.full_name || 'Student' },
    { k: 'Paid to', v: place || 'Your accommodation' },
    { k: 'Method', v: method.value },
  ]
  if (p.txn_reference) list.push({ k: 'Reference no.', v: p.txn_reference, mono: true })
  list.push({ k: 'Sent', v: when(p.created_at) })
  if (p.paid_at || by) list.push({ k: label, v: `${p.paid_at ? when(p.paid_at) : ''}${by ? `${p.paid_at ? ' by ' : 'By '}${by}` : ''}` })
  if (p.receipt_no) list.push({ k: 'Receipt no.', v: p.receipt_no, mono: true })
  return list
})
// What the proof photo should say, for the viewer's compare panel.
const compare = computed(() => ({
  reference: pay.value?.txn_reference ?? '',
  amount: formatPesoExact(pay.value?.amount ?? 0),
  method: method.value,
  sent: pay.value ? when(pay.value.created_at) : '',
}))

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`)

function receiptHtml(): string {
  const p = pay.value!
  const body = rows.value.map((r) => `<tr><th>${esc(r.k)}</th><td>${esc(r.v)}</td></tr>`).join('')
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Payment receipt</title><style>
body{font-family:Arial,sans-serif;color:#17202a;margin:32px auto;max-width:480px}
h1{font-size:13px;letter-spacing:.06em;text-transform:uppercase;color:#6b7280;margin:0 0 16px}
.amt{font-size:32px;font-weight:700;margin:4px 0}.st{font-size:12px;font-weight:700;text-transform:uppercase}
table{width:100%;border-collapse:collapse;margin-top:16px;border-top:2px dashed #d1d5db}
th,td{padding:8px 0;border-bottom:1px solid #eef0f2;font-size:14px;vertical-align:top}
th{text-align:left;color:#6b7280;font-weight:400;width:40%}td{text-align:right;font-weight:600}
</style></head><body><h1>Payment receipt</h1><div class="st">${esc(statusLabel.value)}</div>
<div class="amt">${esc(formatPesoExact(p.amount))}</div><div>${esc(title.value)}</div>
<table>${body}</table>${p.rejection_reason ? `<p>Why it was sent back: ${esc(p.rejection_reason)}</p>` : ''}</body></html>`
}

const fileName = () => `receipt-${pay.value?.receipt_no || pay.value?.id.slice(0, 8)}`

async function run(task: () => Promise<void>, fallback: string) {
  busy.value = true
  try {
    await task()
  } catch (e) {
    // Closing the share sheet rejects too; that is not an error.
    const msg = errorMessage(e, fallback)
    if (!/cancel|abort/i.test(msg)) notify.error(msg)
  } finally {
    busy.value = false
  }
}
const savePdf = () => run(() => printHtml(receiptHtml(), { name: fileName() }), 'Could not open the print dialog.')
const share = () => run(() => shareHtml(receiptHtml(), { name: fileName(), title: 'Payment receipt' }), 'Could not share this receipt.')
</script>

<style scoped>
.rc-loading {
  display: grid;
  min-height: 160px;
  place-items: center;
}
.rc-card {
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
}
.rc-top {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 18px 16px 16px;
  background: var(--m-bg);
}
.rc-chip {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 800;
}
.rc-chip--success {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.rc-chip--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.rc-amount {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 34px;
  font-weight: 700;
  letter-spacing: -0.03em;
}
.rc-amount--void {
  color: var(--m-muted);
  text-decoration: line-through;
}
.rc-title {
  color: var(--m-text);
  font-size: 14px;
  font-weight: 600;
}
.rc-tear {
  border-top: 2px dashed var(--m-border);
}
.rc-rows {
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 4px 14px;
}
.rc-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 0;
  border-top: 1px solid var(--m-border);
}
.rc-row:first-child {
  border-top: 0;
}
.rc-row dt {
  flex: 0 0 auto;
  color: var(--m-muted);
  font-size: 13px;
}
.rc-row dd {
  margin: 0;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 600;
  text-align: right;
  overflow-wrap: anywhere;
}
.rc-mono {
  font-family: var(--m-font-mono);
}
.rc-reason {
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--m-radius-sm);
  background: var(--m-danger-soft);
  color: var(--m-danger);
  font-size: 12.5px;
}
.rc-proof {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 10px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
}
.rc-thumb {
  display: grid;
  flex: 0 0 48px;
  width: 48px;
  height: 60px;
  place-items: center;
  border: 1px dashed var(--m-border);
  border-radius: 8px;
  background: var(--m-bg);
  color: var(--m-muted);
}
.rc-proof-text {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: column;
  color: var(--m-muted);
  font-size: 12px;
}
.rc-proof-text b {
  color: var(--m-ink);
  font-size: 14px;
}
.rc-chev {
  color: var(--m-muted);
}
.rc-btn {
  display: flex;
  flex: 1;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-height: 46px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
.rc-btn--primary {
  border-color: transparent;
  background: var(--m-primary);
  color: #fff;
}
.rc-btn:disabled {
  opacity: 0.6;
}
</style>
