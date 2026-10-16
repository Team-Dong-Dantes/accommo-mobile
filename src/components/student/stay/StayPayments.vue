<template>
<h2 v-if="isTablet" class="split-head">Payments</h2>
<!-- Moved out, still owing: it blocks applying for a new room. -->
<div v-for="o in pastOwed" :key="o.leaseId" class="past-owed">
  <span class="past-owed-label">Left to settle · {{ o.place }}</span>
  <span class="past-owed-amt">{{ formatPesoExact(o.balance) }}</span>
  <span class="past-owed-sub">From a stay you've left. You can't apply for a new room until it's settled.</span>
  <button type="button" class="past-owed-btn" @click="pastPay = o">Settle {{ formatPesoExact(o.balance) }}</button>
</div>
<PaymentStatement
  v-if="lease && canPay"
  :ledger="ledger"
  :payments="currentLeasePayments"
  :start-date="lease.startDate"
  role="student"
  :closed="leaseClosed"
  can-pay
  :bill-utility="billUtility"
  :metered="metered"
  :who="myLandlord"
  :deposit-held="depositHeld"
  @pay="openPay(null)"
  @open-payment="openPaymentDetail"
  @resubmit="startResubmit"
  @withdraw="withdrawPayment"
  @message="router.push(`/student/messages?to=${lease.managerId}`)"
/>
<p v-else-if="lease" class="pay-head-note">You'll be able to pay once your application is accepted.</p>
<p v-if="leaseClosed" class="pay-head-note">This stay has ended. Settle what's left to be able to apply for a new room.</p>
<p v-if="!lease && !payments.length" class="none">No payments yet.</p>
<button v-if="payments.length" type="button" class="all-pay" @click="router.push('/student/profile/history?tab=payments')">
  <IconifyIcon icon="lucide:receipt" width="16" />
  All my payments
  <IconifyIcon icon="lucide:chevron-right" width="16" class="all-pay-chev" />
</button>
</template>

<script setup lang="ts">
// The Payments tab: anything still owed on a past stay, then this stay's
// statement.
import { Icon as IconifyIcon } from '@iconify/vue'
import PaymentStatement from '@/components/shared/PaymentStatement.vue'
import { formatPesoExact } from '@/utils/format'
import { isTablet } from '@/utils/useTabletMode'
import { useStay } from './stay'

const {
  router,
  myLandlord,
  lease,
  payments,
  billUtility,
  metered,
  currentLeasePayments,
  depositHeld,
  pastOwed,
  pastPay,
  ledger,
  leaseClosed,
  openPaymentDetail,
  canPay,
  openPay,
  startResubmit,
  withdrawPayment,
} = useStay()
</script>

<style scoped>
.pay-head-note {
  margin: 10px 0 0;
  color: var(--m-muted);
  font-size: 12.5px;
}
.past-owed {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 14px;
  padding: 16px;
  border: 1px solid color-mix(in srgb, var(--m-danger) 30%, transparent);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.past-owed-label {
  color: var(--m-danger);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.past-owed-amt {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 28px;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1.1;
}
.past-owed-sub {
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.45;
}
.past-owed-btn {
  min-height: 46px;
  margin-top: 4px;
  border: 0;
  border-radius: 999px;
  background: var(--m-danger);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14.5px;
  font-weight: 700;
}
.all-pay {
  display: flex;
  width: 100%;
  min-height: 48px;
  align-items: center;
  gap: 10px;
  margin-top: 14px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
.all-pay-chev {
  margin-left: auto;
  color: var(--m-muted);
}
.none {
  padding: 14px 12px;
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}
.split-head {
  margin: 0 0 2px;
  line-height: 1.3;
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.01em;
}
</style>
