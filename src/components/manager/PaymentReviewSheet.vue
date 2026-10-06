<template>
  <q-dialog :model-value="modelValue" position="bottom" @update:model-value="emit('update:modelValue', $event)">
    <q-card v-if="payment" class="pay-detail-sheet">
      <div class="pay-detail-head">
        <span class="pay-detail-head-body">
          <h3 class="pay-detail-title">{{ paymentTitle(payment) }}</h3>
          <span class="pay-detail-amount">{{ formatPesoExact(payment.amount) }}</span>
        </span>
        <span class="pay-detail-chip" :class="`pay-detail-chip--${statusColor(PAYMENT_STATUS, payment.status)}`">
          {{ statusText(PAYMENT_STATUS, payment.status) }}
        </span>
        <button type="button" class="sheet-x" aria-label="Close" @click="emit('update:modelValue', false)">
          <IconifyIcon icon="lucide:x" width="20" />
        </button>
      </div>

      <div class="group">
        <div v-if="payment.claimedAmount" class="pay-detail-rule">
          <span class="pay-detail-rule-label">Student submitted</span>
          <span class="pay-detail-rule-value">{{ formatPesoExact(payment.claimedAmount) }}</span>
        </div>
        <div v-if="payment.receiptNo" class="pay-detail-rule">
          <span class="pay-detail-rule-label">Receipt no.</span>
          <span class="pay-detail-rule-value">{{ payment.receiptNo }}</span>
        </div>
        <div class="pay-detail-rule">
          <span class="pay-detail-rule-label">Method</span>
          <span class="pay-detail-rule-value">{{ PAYMENT_METHOD_LABEL[payment.method] || payment.method }}</span>
        </div>
        <div v-if="payment.studentName" class="pay-detail-rule">
          <span class="pay-detail-rule-label">Tenant</span>
          <span class="pay-detail-rule-value">{{ payment.studentName }}</span>
        </div>
        <div v-if="payment.roomLabel" class="pay-detail-rule">
          <span class="pay-detail-rule-label">Stay</span>
          <span class="pay-detail-rule-value">{{ payment.roomLabel }}{{ payment.accommodationName ? ` · ${payment.accommodationName}` : '' }}</span>
        </div>
        <div v-if="payment.txnReference" class="pay-detail-rule">
          <span class="pay-detail-rule-label">Reference number</span>
          <span class="pay-detail-rule-value">{{ payment.txnReference }}</span>
        </div>
        <div v-if="payment.promiseDate" class="pay-detail-rule">
          <span class="pay-detail-rule-label">Rest promised by</span>
          <span class="pay-detail-rule-value">{{ formatDate(payment.promiseDate) }}</span>
        </div>
        <div v-if="payment.verifiedByName" class="pay-detail-rule">
          <span class="pay-detail-rule-label">Reviewed by</span>
          <span class="pay-detail-rule-value">
            {{ payment.verifiedByName }}{{ payment.paidAt ? ` · ${formatDate(payment.paidAt)}` : '' }}
          </span>
        </div>
      </div>

      <template v-if="payment.status === 'rejected' && payment.rejectionReason">
        <p class="pay-detail-label">Rejection reason</p>
        <p class="pay-detail-text">{{ payment.rejectionReason }}</p>
      </template>
      <template v-if="payment.undoReason && payment.status === 'pending_verification'">
        <p class="pay-detail-label">Confirmation undone</p>
        <p class="pay-detail-text">{{ payment.undoReason }}</p>
      </template>
      <template v-if="payment.note">
        <p class="pay-detail-label">{{ payment.status === 'waived' ? 'Why it was forgiven' : 'Note from the student' }}</p>
        <p class="pay-detail-text">{{ payment.note }}</p>
      </template>
      <template v-if="payment.proofUrl">
        <p class="pay-detail-label">Proof of payment</p>
        <img :src="resolveAsset(payment.proofUrl)" alt="Proof of payment" class="pay-detail-proof-img" />
      </template>

      <!-- Awaiting confirmation: confirm it as submitted, or reject it with a reason. -->
      <template v-if="payment.status === 'pending_verification'">
        <div v-if="mode === 'reject'" class="pay-reject-form">
          <label class="pay-detail-label">
            Reason
            <textarea v-model="reason" class="pay-reject-textarea" rows="2" placeholder="Why is this being rejected?" />
          </label>
          <div class="pay-reject-actions">
            <button type="button" class="pay-reject-cancel" @click="mode = ''">Cancel</button>
            <button type="button" class="pay-reject-confirm" :disabled="busy || !reason.trim()" @click="act('reject')">
              {{ busy ? 'Rejecting…' : 'Confirm reject' }}
            </button>
          </div>
        </div>
        <div v-else class="pay-detail-actions">
          <button type="button" class="pay-verify-btn" :disabled="busy" @click="act('confirm')">
            {{ busy ? 'Confirming…' : 'Confirm received' }}
          </button>
          <button type="button" class="pay-reject-btn" @click="mode = 'reject'; reason = ''">Reject</button>
        </div>
      </template>

      <!-- Confirmed in the last 7 days: can be undone (a mis-tap, a bounced transfer). -->
      <template v-if="canUndo">
        <div v-if="mode === 'undo'" class="pay-reject-form">
          <label class="pay-detail-label">
            Why undo it?
            <textarea v-model="reason" class="pay-reject-textarea" rows="2" placeholder="e.g. The transfer was reversed by the bank" />
          </label>
          <div class="pay-reject-actions">
            <button type="button" class="pay-reject-cancel" @click="mode = ''">Cancel</button>
            <button type="button" class="pay-reject-confirm" :disabled="busy || !reason.trim()" @click="act('undo')">
              {{ busy ? 'Undoing…' : 'Undo confirmation' }}
            </button>
          </div>
        </div>
        <button v-else type="button" class="pay-detail-link" @click="mode = 'undo'; reason = ''">Undo this confirmation</button>
      </template>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { requirePin } from '@/utils/requirePin'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { formatDate, formatPesoExact, PAYMENT_STATUS, PAYMENT_METHOD_LABEL, statusText, statusColor } from '@/utils/format'
import { paymentTitle } from '@/utils/payments'

// The landlord/landlady's view of one payment, and the only place it is
// reviewed: confirm as submitted, reject, or undo a recent
// confirmation. review_payment acts on the whole submission, so one transfer
// that covered several months is handled as one.
export interface ReviewPayment {
  id: string
  month: string
  amount: number
  method: string
  status: string
  description: string
  txnReference: string
  proofUrl: string
  paidAt: string | null
  verifiedByName: string
  rejectionReason: string
  note: string
  promiseDate: string | null
  claimedAmount: number | null
  undoReason: string
  receiptNo: string
  studentName?: string
  roomLabel?: string
  accommodationName?: string
}

const props = defineProps<{ modelValue: boolean; payment: ReviewPayment | null }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; changed: [] }>()
const notify = useNotify()

const mode = ref<'' | 'reject' | 'undo'>('')
const reason = ref('')
const busy = ref(false)
watch(() => props.payment?.id, () => { mode.value = '' })

const WEEK_MS = 7 * 24 * 60 * 60 * 1000
const canUndo = computed(() => {
  const p = props.payment
  return p?.status === 'paid' && !!p.paidAt && Date.now() - new Date(p.paidAt).getTime() < WEEK_MS
})

const TITLES = { confirm: 'Confirm this payment?', reject: 'Reject this payment?', undo: 'Undo this confirmation?' } as const
const DONE = { confirm: 'Payment confirmed.', reject: 'Payment rejected.', undo: 'Confirmation undone.' } as const

async function act(action: 'confirm' | 'reject' | 'undo') {
  const p = props.payment
  if (!p || busy.value) return
  if (!(await requirePin({ confirm: true, title: TITLES[action] }))) return
  busy.value = true
  try {
    const { error } = await supabase.rpc('review_payment', {
      p_payment: p.id,
      p_action: action,
      ...(action !== 'confirm' ? { p_reason: reason.value.trim() } : {}),
    })
    if (error) throw error
    notify.success(DONE[action])
    mode.value = ''
    emit('update:modelValue', false)
    emit('changed')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update this payment.'))
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.pay-detail-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.pay-detail-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}
.pay-detail-head-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
}
.pay-detail-title {
  margin: 0;
  line-height: 1.3;
  color: var(--m-muted);
  font-size: 13px;
  font-weight: 700;
}
.pay-detail-amount {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 28px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  line-height: 1.15;
}
.pay-detail-chip {
  flex: 0 0 auto;
  margin-top: 2px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.pay-detail-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.pay-detail-chip--amber,
.pay-detail-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.pay-detail-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.pay-detail-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.group {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.pay-detail-rule {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .pay-detail-rule:first-child {
  border-top: 0;
}
.pay-detail-rule-label {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.pay-detail-rule-value {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
  text-align: right;
}
.pay-detail-label {
  margin: 4px 0 0;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.pay-detail-text {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
}
.pay-detail-proof-img {
  width: 100%;
  max-height: 360px;
  object-fit: contain;
  background: var(--m-bg);
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
}
.pay-detail-actions,
.pay-reject-actions {
  display: flex;
  gap: 8px;
}
.pay-verify-btn {
  flex: 1;
  min-height: 48px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
.pay-verify-btn:disabled,
.pay-reject-confirm:disabled {
  opacity: 0.6;
}
.pay-reject-btn {
  flex: 0 0 auto;
  min-height: 48px;
  padding: 0 18px;
  border: 1px solid var(--m-danger);
  border-radius: 999px;
  background: var(--m-danger-soft);
  color: var(--m-danger);
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
.pay-reject-form {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.pay-reject-textarea {
  display: block;
  width: 100%;
  min-height: 60px;
  margin-top: 4px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  resize: vertical;
  text-transform: none;
}
.pay-reject-cancel {
  flex: 0 0 auto;
  min-height: 44px;
  padding: 0 16px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
.pay-reject-confirm {
  flex: 1;
  min-height: 44px;
  border: 0;
  border-radius: 999px;
  background: var(--m-danger);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
.pay-detail-link {
  min-height: 40px;
  border: 0;
  background: none;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.sheet-x {
  display: flex;
  width: 36px;
  height: 36px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  margin: -6px -8px 0 0;
  border: 0;
  border-radius: 999px;
  background: none;
  color: var(--m-muted);
  cursor: pointer;
}
</style>
