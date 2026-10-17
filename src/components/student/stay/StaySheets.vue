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

  <!-- The landlord/landlady's payment sheet, turned round: the proof is a
       thumbnail beside the amount, so it never pushes the details off screen. -->
  <PaymentReviewSheet
    v-model="paymentDetailOpen"
    :payment-id="selectedPayment?.id ?? null"
    student
    :resend="selectedPayment?.leaseId === lease?.id"
    @withdraw="selectedPayment && withdrawPayment(selectedPayment)"
    @resubmit="paymentDetailOpen = false; selectedPayment && startResubmit(selectedPayment)"
  />
</template>

<script setup lang="ts">
// My Stay's sheets: the leave request, paying, settling a past stay, and a
// payment's details.
import AppModal from '@/components/shared/AppModal.vue'
import DateTimeField from '@/components/shared/DateTimeField.vue'
import PaySheet from '@/components/shared/PaySheet.vue'
import PaymentReviewSheet from '@/components/manager/PaymentReviewSheet.vue'
import { manilaToday } from '@/utils/payments'
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
  withdrawPayment,
} = useStay()
</script>

<style scoped>
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
</style>
