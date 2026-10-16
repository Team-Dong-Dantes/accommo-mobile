<template>
<div class="sec-body">
<PaymentStatement
  v-if="lease.status !== 'pending'"
  :ledger="ledger"
  :payments="payments"
  :start-date="lease.startDate"
  role="landlord"
  :closed="lease.status === 'ended' || lease.status === 'terminated'"
  can-pay
  :bill-utility="billUtility"
  :metered="canPostBill ? monthlyUtilities : []"
  :deposit-held="depositHeld"
  :deposit-usable="depositUsable"
  @pay="logOpen = true"
  @open-payment="openPaymentDetail"
  @forgive="forgiveRow"
  @fix-bill="openFixBill"
  @post-bill="postBillOpen = true"
  @message="router.push(`/manager/messages?to=${lease.studentId}`)"
  @use-deposit="depositOpen = true"
/>

<!-- Below the statement: the terms it runs on, and posting a bill any time. -->
<button v-if="lease.status === 'active' || lease.status === 'leave_requested'" type="button" class="terms-row terms-row--after" @click="termsOpen = true">
  <span class="terms-body">
    <span class="terms-main">Rent due every {{ ordinal(lease.rentDueDay ?? moveInDay) }}</span>
    <span class="terms-sub">{{ termsLine }}</span>
  </span>
  <span class="sec-link">Edit</span>
</button>
<button v-if="canPostBill" type="button" class="terms-row" @click="postBillOpen = true">
  <span class="terms-body">
    <span class="terms-main">Post a utility bill</span>
    <span class="terms-sub">{{ monthlyUtilities.map((u) => u.label).join(' and ') }}, billed monthly</span>
  </span>
  <span class="sec-link">Post</span>
</button>
<EmptyState
  v-if="lease.status === 'pending'"
  variant="compact"
  icon="lucide:receipt"
  title="No payments yet"
  message="Payments start once you accept this application."
/>
</div>
</template>

<script setup lang="ts">
// The Payments tab: the statement and the payment terms it runs on. On
// desktop the page teleports it into the card's right half.
import EmptyState from '@/components/shared/EmptyState.vue'
import PaymentStatement from '@/components/shared/PaymentStatement.vue'
import { useTenant } from './tenant'

const {
  router,
  lease,
  ledger,
  depositOpen,
  depositHeld,
  depositUsable,
  payments,
  monthlyUtilities,
  canPostBill,
  billUtility,
  postBillOpen,
  moveInDay,
  ordinal,
  termsOpen,
  termsLine,
  logOpen,
  forgiveRow,
  openFixBill,
  openPaymentDetail,
} = useTenant()
</script>

<style scoped>
/* ---- Desktop: two columns ----
   Off the desktop these wrappers are transparent: .col-left and .sec-body are
   display: contents, so the phone layout is exactly the tabbed one it was. */
.col-left,
.sec-body {
  display: contents;
}
.col-right .sec-body {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.sec-link {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
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
/* The statement opens the tab; give it the room a heading used to. */
.sec-body > .st:first-child {
  margin-top: 16px;
}
.terms-row--after {
  margin-top: 18px;
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
</style>
