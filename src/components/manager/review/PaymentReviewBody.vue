<template>
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
        <span class="rv-by">{{ cash ? (props.student ? 'handed over in cash' : 'no receipt for cash, so only you can tell') : `by ${methodLabel}` }}</span>
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
      <h3 class="rv-h">{{ pending && !cash && !props.student ? `Check against your ${methodLabel}` : 'Details' }}</h3>
      <div class="mx-list">
        <div v-if="first.txn_reference" class="mx-kv"><span class="mx-kv-key">Reference no.</span><span class="mx-kv-val rv-mono">{{ formatReference(first.method, first.txn_reference) }}</span></div>
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
</template>

<script setup lang="ts">
// The sheet's body: the transfer and what it paid, or the reason it is being
// sent back.
import { Icon as IconifyIcon } from '@iconify/vue'
import { PAYMENT_STATUS, formatDate, formatPesoExact, statusColor } from '@/utils/format'
import { REASONS } from './model'
import { formatReference } from '@/utils/payments'
import { usePaymentReview } from './paymentReview'

const {
  props,
  loading,
  rows,
  mode,
  reason,
  detail,
  viewer,
  first,
  status,
  pending,
  cash,
  methodLabel,
  total,
  proof,
  firstName,
  reviewer,
  headline,
  items,
  whatList,
  capitalize,
  partial,
} = usePaymentReview()
</script>

<style scoped>
.rv-center {
  align-items: center;
  justify-content: center;
}
.rv-kicker,
.rv-h {
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  line-height: 1.25;
}
.rv-status--blue {
  color: var(--m-info);
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
