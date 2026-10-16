<template>
<AppModal v-model="leaveDialog" title="Request to leave?" size="sm">
  <p class="leave-body">
    Your {{ myLandlord }} approves or declines it. Your stay runs until the day you move out, and rent is owed until then.
  </p>
  <label class="mx-field leave-date">
    <span class="mx-label">When will you move out?</span>
    <DateTimeField v-model="leaveDate" mode="date" :min="manilaToday()" :max="lease?.endDate || ''" placeholder="Pick your move-out date" class="mx-input" />
  </label>
  <template #footer>
    <button type="button" class="leave-btn leave-btn--ghost" :disabled="leaving" @click="leaveDialog = false">
      Cancel
    </button>
    <button type="button" class="leave-btn" :disabled="leaving || !leaveDate" @click="requestLeave">
      {{ leaving ? 'Sending…' : 'Request to leave' }}
    </button>
  </template>
</AppModal>

<PaySheet
  v-if="lease"
  v-model="payOpen"
  :lease-id="lease.id"
  :resubmit="resubmit"
  :landlord-id="lease.managerId"
  :allow-partial="lease.allowPartial"
  :partial-min-pct="lease.partialMinPct"
  :settle-only="leaseClosed"
  :start-date="lease.startDate"
  @submitted="load(true)"
/>
<PaySheet
  v-if="pastPay"
  :model-value="true"
  :lease-id="pastPay.leaseId"
  settle-only
  :landlord-id="pastPay.landlordId"
  :allow-partial="pastPay.allowPartial"
  :partial-min-pct="pastPay.partialMinPct"
  :subtitle="pastPay.place"
  @update:model-value="(v) => { if (!v) pastPay = null }"
  @submitted="load(true)"
/>

<AppModal v-model="paymentDetailOpen" :title="selectedPayment ? paymentTitle(selectedPayment) : ''">
  <template v-if="selectedPayment">
    <span class="detail-chip" :class="`detail-chip--${statusColor(PAYMENT_STATUS, selectedPayment.status)}`">
      {{ statusText(PAYMENT_STATUS, selectedPayment.status) }}
    </span>

    <div class="group">
      <div class="rule">
        <span class="rule-label">Amount</span>
        <span class="rule-value">{{ formatPesoExact(selectedPayment.amount) }}</span>
      </div>
      <div v-if="selectedPayment.receiptNo" class="rule">
        <span class="rule-label">Receipt no.</span>
        <span class="rule-value">{{ selectedPayment.receiptNo }}</span>
      </div>
      <div v-if="selectedPayment.promiseDate" class="rule">
        <span class="rule-label">Rest promised by</span>
        <span class="rule-value">{{ formatDate(selectedPayment.promiseDate) }}</span>
      </div>
      <div class="rule">
        <span class="rule-label">Method</span>
        <span class="rule-value">{{ PAYMENT_METHOD_LABEL[selectedPayment.method] || selectedPayment.method }}</span>
      </div>
      <div class="rule">
        <span class="rule-label">Stay</span>
        <span class="rule-value">{{ selectedPayment.roomLabel }} · {{ selectedPayment.accommodationName }}</span>
      </div>
      <div v-if="selectedPayment.txnReference" class="rule">
        <span class="rule-label">Reference number</span>
        <span class="rule-value">{{ selectedPayment.txnReference }}</span>
      </div>
      <div v-if="selectedPayment.verifiedByName" class="rule">
        <span class="rule-label">Reviewed by</span>
        <span class="rule-value">
          {{ selectedPayment.verifiedByName }}{{ selectedPayment.paidAt ? ` · ${formatDate(selectedPayment.paidAt)}` : '' }}
        </span>
      </div>
    </div>

    <template v-if="selectedPayment.status === 'rejected' && selectedPayment.rejectionReason">
      <p class="detail-label detail-label--danger">Why it was sent back</p>
      <p class="detail-text">{{ selectedPayment.rejectionReason.replace('\n', ' — ') }}</p>
    </template>

    <template v-if="selectedPayment.note">
      <p class="detail-label">{{ selectedPayment.status === 'waived' ? 'Why it was forgiven' : 'Note' }}</p>
      <p class="detail-text">{{ selectedPayment.note }}</p>
    </template>

    <template v-if="selectedPayment.proofUrl">
      <p class="detail-label">Proof of payment</p>
      <img :src="resolveAsset(selectedPayment.proofUrl)" alt="Proof of payment" class="proof-img" />
    </template>

    <button
      v-if="selectedPayment.status === 'pending_verification'"
      type="button"
      class="detail-withdraw"
      :disabled="withdrawing"
      @click="withdrawPayment(selectedPayment)"
    >
      {{ withdrawing ? 'Taking it back…' : 'Take it back' }}
    </button>
    <button
      v-if="selectedPayment.status === 'rejected' && selectedPayment.leaseId === lease?.id"
      type="button"
      class="detail-fix"
      @click="paymentDetailOpen = false; startResubmit(selectedPayment)"
    >
      Fix and send again
    </button>
  </template>
</AppModal>
</template>

<script setup lang="ts">
// My Stay's sheets: the leave request, paying, settling a past stay, and a
// payment's details.
import AppModal from '@/components/shared/AppModal.vue'
import DateTimeField from '@/components/shared/DateTimeField.vue'
import { PAYMENT_METHOD_LABEL, PAYMENT_STATUS, formatDate, formatPesoExact, statusColor, statusText } from '@/utils/format'
import PaySheet from '@/components/shared/PaySheet.vue'
import { manilaToday, paymentTitle } from '@/utils/payments'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { useStay } from './stay'

const {
  myLandlord,
  lease,
  pastPay,
  leaseClosed,
  paymentDetailOpen,
  selectedPayment,
  load,
  leaveDialog,
  leaveDate,
  leaving,
  payOpen,
  resubmit,
  startResubmit,
  requestLeave,
  withdrawing,
  withdrawPayment,
} = useStay()
</script>

<style scoped>
.group {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.rule {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .rule:first-child {
  border-top: 0;
}
.rule-label {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.rule-value {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
  text-align: right;
}
.note {
  margin: -4px 0 0;
  padding: 9px 12px;
  border-radius: var(--m-radius-sm);
  background: var(--m-warning-soft);
  color: var(--m-warning);
  font-size: 12.5px;
  font-weight: 600;
}
.detail-chip {
  align-self: flex-start;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.detail-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.detail-chip--amber,
.detail-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.detail-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.detail-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.detail-label {
  margin: 4px 0 0;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.detail-label--danger {
  color: var(--m-danger);
}
.detail-text {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
}
.proof-img {
  width: 100%;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
}
.leave-date {
  margin-top: 14px;
}
.leave-body {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
}
.leave-btn {
  flex: 1;
  min-height: 46px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.leave-btn:disabled {
  opacity: 0.6;
}
.leave-btn--ghost {
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}
.detail-fix {
  min-height: 48px;
  border: 0;
  border-radius: 999px;
  background: var(--m-danger);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14.5px;
  font-weight: 700;
}
.detail-withdraw {
  min-height: 44px;
  border: 0;
  background: none;
  color: var(--m-danger);
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
</style>
