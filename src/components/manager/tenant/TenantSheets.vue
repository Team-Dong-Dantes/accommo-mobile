<template>
<PostBillDialog
  v-model="postBillOpen"
  :lease-id="leaseId"
  :student-id="lease.studentId"
  :student-name="lease.studentName"
  :utilities="monthlyUtilities"
  @posted="load(true)"
/>

<AppModal v-model="reviewOpen" :title="`Rate ${lease.studentName}`">
  <StarRating v-model="reviewForm.rating" interactive :size="26" />
  <label class="pay-field">
    <span class="pay-label">Notes (optional)</span>
    <textarea v-model="reviewForm.comment" class="pay-input review-textarea" rows="3" placeholder="How was this boarder to have?" />
  </label>
  <template #footer>
    <q-btn
      unelevated
      rounded
      no-caps
      color="primary"
      class="pay-submit"
      :loading="submittingReview"
      label="Submit"
      @click="submitTenantReview"
    />
  </template>
</AppModal>

<!-- Payment review — verifying only ever happens from here, never
     straight off the row, so a proof/reference actually gets looked at. -->
<PaymentReviewSheet v-model="paymentDetailOpen" :payment-id="selectedPayment?.id ?? null" @changed="load(true)" />
<LogPaymentSheet
  v-model="logOpen"
  :lease-id="leaseId"
  :subtitle="`From ${lease.studentName} · ${lease.roomLabel}`"
  :settle-only="lease.status === 'ended' || lease.status === 'terminated'"
  :start-date="lease.startDate"
  @submitted="load(true)"
/>
<ForgiveSheet v-model="forgiveOpen" :lease-id="leaseId" :student-name="lease.studentName" :target="forgiveTarget" @done="load(true)" />
<BillFixSheet v-model="fixOpen" :student-name="lease.studentName" :bill="fixBill" @done="load(true)" />
<UseDepositSheet
  v-model="depositOpen"
  :lease-id="leaseId"
  :student-name="lease.studentName"
  :end-date="lease.endDate || null"
  :held="depositHeld"
  :ledger="ledger"
  @done="load(true)"
/>

<!-- When rent falls due, the grace before it's late, and part payments. -->
<AppModal v-model="termsOpen" title="Payment terms" size="sm">
  <div class="terms-form">
    <label class="mx-field">
      <span class="mx-label">Rent is due</span>
      <AppSelect
        class="mx-input"
        placeholder="Rent is due"
        :model-value="lease.rentDueDay ?? 0"
        :options="dueDayOptions"
        :disable="savingTerms"
        @update:model-value="(d) => setDueTerms(d || null, lease.graceDays)"
      />
    </label>
    <label class="mx-field">
      <span class="mx-label">Late after</span>
      <AppSelect
        class="mx-input"
        placeholder="Late after"
        :model-value="lease.graceDays"
        :options="[0, 3, 5, 7, 15].map((g) => ({ label: g ? `${g} days of grace` : 'no grace — late the next day', value: g }))"
        :disable="savingTerms"
        @update:model-value="(g) => setDueTerms(lease.rentDueDay, g)"
      />
    </label>
    <div class="terms-toggle">
      <span class="terms-body">
        <span class="terms-main">Partial payments</span>
        <span class="terms-sub">Let {{ lease.studentName.split(' ')[0] }} pay part of an item at a time.</span>
      </span>
      <q-toggle :model-value="lease.allowPartial" :disable="savingPartial" color="primary" aria-label="Allow partial payments" @update:model-value="(v) => setPartial(v)" />
    </div>
    <label v-if="lease.allowPartial" class="mx-field">
      <span class="mx-label">At least</span>
      <AppSelect
        class="mx-input"
        placeholder="At least"
        :model-value="lease.partialMinPct"
        :options="[10, 25, 50, 75].map((p) => ({ label: `${p}% of the item`, value: p }))"
        :disable="savingPartial"
        @update:model-value="(p) => setPartial(true, p)"
      />
    </label>
  </div>
</AppModal>
</template>

<script setup lang="ts">
// The profile's sheets: posting a bill, rating the boarder, reviewing,
// logging, forgiving or fixing a payment, the deposit, and payment terms.
import AppModal from '@/components/shared/AppModal.vue'
import AppSelect from '@/components/shared/AppSelect.vue'
import BillFixSheet from '@/components/manager/BillFixSheet.vue'
import ForgiveSheet from '@/components/manager/ForgiveSheet.vue'
import LogPaymentSheet from '@/components/manager/LogPaymentSheet.vue'
import PaymentReviewSheet from '@/components/manager/PaymentReviewSheet.vue'
import PostBillDialog from '@/components/manager/PostBillDialog.vue'
import StarRating from '@/components/shared/StarRating.vue'
import UseDepositSheet from '@/components/manager/UseDepositSheet.vue'
import { useTenant } from './tenant'

const {
  lease,
  ledger,
  depositOpen,
  depositHeld,
  monthlyUtilities,
  postBillOpen,
  leaseId,
  load,
  savingPartial,
  setPartial,
  dueDayOptions,
  savingTerms,
  setDueTerms,
  termsOpen,
  logOpen,
  forgiveOpen,
  forgiveTarget,
  fixOpen,
  fixBill,
  paymentDetailOpen,
  selectedPayment,
  reviewOpen,
  submittingReview,
  reviewForm,
  submitTenantReview,
} = useTenant()
</script>

<style scoped>
.terms-row,
.terms-toggle {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 12px;
  margin-bottom: 14px;
  padding: 12px 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: inherit;
  cursor: pointer;
  font: inherit;
  text-align: left;
}
.terms-toggle {
  margin: 0;
  cursor: default;
}
.terms-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.terms-main {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.terms-sub {
  color: var(--m-muted);
  font-size: 12.5px;
}
.terms-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.pay-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.pay-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.pay-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.pay-submit {
  flex: 1;
  min-height: 48px;
  font-weight: 700;
}
.review-textarea {
  min-height: 70px;
  padding: 10px 12px;
  resize: vertical;
}
</style>
