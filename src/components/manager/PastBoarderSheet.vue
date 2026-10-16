<template>
  <AppModal :model-value="modelValue" size="sm" @update:model-value="emit('update:modelValue', $event)">
    <template v-if="lease" #header>
      <CollectionAvatar :lease="lease" class="pbs-avatar" />
      <span class="pbs-who">
        <span class="pbs-line">
          <h2 class="pbs-name">{{ lease.studentName }}</h2>
          <span class="pbs-chip">{{ lease.status === 'terminated' ? 'Terminated' : 'Moved out' }}</span>
        </span>
        <span class="pbs-sub">{{ lease.roomLabel }} · {{ lease.accommodationName }}</span>
      </span>
    </template>

    <div v-if="lease" class="pbs">
      <div class="pbs-dates">
        <div><span>Moved in</span><b>{{ fmt(lease.startDate) }}</b></div>
        <div><span>Moved out</span><b>{{ fmt(lease.endDate) }}</b></div>
      </div>

      <dl class="pbs-list">
        <div><dt>Stayed</dt><dd>{{ monthsText(stayMonths(lease.startDate, lease.endDate)) }}</dd></div>
        <div><dt>Rent</dt><dd>{{ formatPeso(lease.monthlyRent) }}/mo</dd></div>
        <div v-if="reason"><dt>Why it ended</dt><dd>{{ reason }}</dd></div>
      </dl>

      <button v-if="rent.totalMonths" type="button" class="pbs-rent" :class="{ 'pbs-rent--owing': rent.unpaidAmount > 0 }" @click="goHistory">
        <span class="pbs-rent-text">
          <b>Rent · {{ rent.paidMonths }} of {{ rent.totalMonths }} months paid</b>
          <span v-if="rent.unpaidAmount > 0" class="pbs-owing">{{ formatPeso(rent.unpaidAmount) }} unpaid · {{ unpaidMonths }}</span>
        </span>
        <span class="pbs-link">Rent history</span>
        <IconifyIcon icon="lucide:chevron-right" width="16" class="pbs-link" />
      </button>

      <div class="pbs-rating">
        <template v-if="review">
          <span class="pbs-rating-top">
            <span class="pbs-eyebrow">Your rating</span>
            <StarRating :model-value="review.rating" :size="15" class="pbs-stars" />
          </span>
          <span v-if="review.comment" class="pbs-comment">{{ review.comment }}</span>
        </template>
        <span v-else class="pbs-rating-top">
          <span class="pbs-eyebrow">Not rated yet</span>
          <button type="button" class="pbs-rate" @click="rate">Rate</button>
        </span>
      </div>
    </div>

    <template #footer>
      <button type="button" class="pbs-btn" @click="message">
        <IconifyIcon icon="lucide:message-circle" width="16" />
        Message
      </button>
      <button type="button" class="pbs-btn pbs-btn--primary" @click="emit('update:modelValue', false)">Close</button>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import AppModal from '@/components/shared/AppModal.vue'
import StarRating from '@/components/shared/StarRating.vue'
import CollectionAvatar from '@/components/manager/CollectionAvatar.vue'
import { formatPeso } from '@/utils/format'
import { stayRent } from '@/utils/rentGrid'
import { manilaToday, type LedgerRow } from '@/utils/payments'
import type { MoneyLease } from '@/api/landlordMoney'
import { END_LABEL, stayMonths, monthsText } from './managerHistory'

// BH-LDetail: one past boarder. The rent line comes from stayRent over the
// stay's own ledger rows; Rate hands off to the tenant profile, which owns the
// rating flow (the rate modal), rather than duplicating it here.
const props = defineProps<{
  modelValue: boolean
  lease: MoneyLease | null
  rows: LedgerRow[]
  review: { rating: number; comment: string } | null
}>()
const emit = defineEmits<{ 'update:modelValue': [open: boolean] }>()
const router = useRouter()

const fmt = (d: string) =>
  new Date(`${d}T00:00:00`).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' })
const rent = computed(() => stayRent(props.rows, manilaToday()))
const unpaidMonths = computed(() => {
  const u = rent.value.unpaid
  const m = (r: LedgerRow) => new Date(`${(r.month ?? '').slice(0, 10)}T00:00:00`)
  if (u.length === 1 && u[0]) return m(u[0]).toLocaleDateString('en-PH', { month: 'long', year: 'numeric' })
  return `${u.length} months`
})
const reason = computed(() => {
  const r = props.lease?.endedReason
  if (!r) return ''
  return END_LABEL[r] ?? r.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
})

function go(path: string) {
  emit('update:modelValue', false)
  void router.push(path)
}
const goHistory = () => go('/manager/tenants?tab=history')
const message = () => props.lease && go(`/manager/messages?to=${props.lease.studentId}`)
const rate = () => props.lease && go(`/manager/tenant/${props.lease.id}`)
</script>

<style scoped>
.pbs-avatar {
  width: 48px;
  height: 48px;
  flex: 0 0 48px;
  margin-right: 12px;
}
.pbs-who {
  display: flex;
  min-width: 0;
  flex-direction: column;
}
.pbs-line {
  display: flex;
  align-items: center;
  gap: 8px;
}
.pbs-name {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
}
.pbs-chip {
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  font-size: 10.5px;
  font-weight: 800;
}
.pbs-sub {
  color: var(--m-muted);
  font-size: 12.5px;
}
.pbs {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.pbs-dates {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}
.pbs-dates > div {
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding: 10px 12px;
  border-radius: 12px;
  background: var(--m-bg);
}
.pbs-dates span {
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
}
.pbs-dates b {
  color: var(--m-ink);
  font-size: 14px;
}
.pbs-list {
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: 12px;
}
.pbs-list > div {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 0;
  border-top: 1px solid var(--m-border);
}
.pbs-list > div:first-child {
  border-top: 0;
}
.pbs-list dt {
  color: var(--m-muted);
  font-size: 13px;
}
.pbs-list dd {
  margin: 0;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 600;
  text-align: right;
}
.pbs-rent {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: 12px;
  background: var(--m-bg);
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.pbs-rent--owing {
  border-color: var(--m-danger);
  background: var(--m-danger-soft);
}
.pbs-rent-text {
  display: flex;
  flex: 1;
  flex-direction: column;
}
.pbs-rent-text b {
  color: var(--m-ink);
  font-size: 13.5px;
}
.pbs-owing {
  color: var(--m-danger);
  font-size: 12px;
  font-weight: 600;
}
.pbs-link {
  color: var(--m-primary-dark);
  font-size: 12.5px;
  font-weight: 700;
}
.pbs-rating {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: 12px;
}
.pbs-rating-top {
  display: flex;
  align-items: center;
  gap: 8px;
}
.pbs-eyebrow {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.pbs-stars,
.pbs-rate {
  margin-left: auto;
}
.pbs-rate {
  padding: 3px 12px;
  border: 0;
  border-radius: 999px;
  background: var(--m-warning-soft);
  color: var(--m-warning);
  font: inherit;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
}
.pbs-comment {
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.45;
}
.pbs-btn {
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
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  cursor: pointer;
}
.pbs-btn--primary {
  border-color: transparent;
  background: var(--m-primary);
  color: #fff;
}
</style>
