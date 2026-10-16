<template>
  <AppModal :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <template #header>
      <span class="sd-icon"><IconifyIcon icon="lucide:building-2" width="22" /></span>
      <span class="sd-head">
        <h2 class="sd-name">{{ stay?.name }}</h2>
        <span class="sd-addr">{{ stay?.address }}</span>
      </span>
    </template>
    <template v-if="stay">
      <div class="sd-dates">
        <div class="sd-date"><span>Moved in</span><b>{{ formatDate(stay.from) }}</b></div>
        <div class="sd-date">
          <span>{{ stay.state === 'now' || stay.state === 'leaving' ? 'Lease ends' : 'Moved out' }}</span>
          <b>{{ formatDate(stay.to) }}</b>
        </div>
      </div>
      <dl class="sd-rows">
        <div v-for="r in rows" :key="r.k" class="sd-row">
          <dt>{{ r.k }}</dt>
          <dd>{{ r.v }}</dd>
        </div>
      </dl>

      <button v-if="stay.leaseId && stay.paid !== null" type="button" class="sd-pay" @click="emit('payments', stay)">
        <span class="sd-pay-text">
          <b>Payments for this stay</b>
          <span :class="stay.owed > 0.009 ? 'sd-bad' : 'sd-ok'">{{ payLine }}</span>
        </span>
        <IconifyIcon icon="lucide:chevron-right" width="16" class="sd-chev" />
      </button>

      <div v-if="stay.toRate" class="sd-rate">
        <b>How was your stay?</b>
        <div class="sd-stars" role="radiogroup" aria-label="Your rating">
          <button
            v-for="n in 5"
            :key="n"
            type="button"
            role="radio"
            :aria-checked="pick === n"
            :aria-label="`${n} star${n === 1 ? '' : 's'}`"
            class="sd-star"
            :class="{ 'sd-star--on': n <= pick }"
            @click="pick = n"
          >
            <IconifyIcon icon="lucide:star" width="28" />
          </button>
        </div>
        <span class="sd-hint">Your name stays hidden from the landlord.</span>
      </div>
      <div v-else-if="stay.rating" class="sd-rated">
        You rated it <StarRating :model-value="stay.rating" :size="15" />
      </div>
    </template>
    <template v-if="stay?.toRate" #footer>
      <button type="button" class="sd-cta" @click="emit('rate', stay, pick)">Rate this stay</button>
    </template>
  </AppModal>
</template>

<script lang="ts">
// One place the student has stayed, from a lease (or, for old stays that have no
// lease row any more, a boarding_history row: leaseId null, nothing to rate).
export interface Stay {
  id: string
  leaseId: string | null
  accommodationId: string | null
  managerId: string | null
  name: string
  address: string
  room: string
  from: string
  to: string
  /** now = active; leaving = leave requested; ended; terminated. */
  state: 'now' | 'leaving' | 'ended' | 'terminated'
  rent: number | null
  endedReason: string
  landlord: string
  /** "Landlord" / "Landlady" from their recorded sex. */
  landlordRole: string
  /** Rounded average of the two ratings the student gave; null while unrated. */
  rating: number | null
  /** Left to pay on a finished stay (lease_ledger); 0 = settled. */
  owed: number
  /** Confirmed payments on this stay, in pesos; null = no lease to look up. */
  paid: number | null
  toRate: boolean
}

/** "2 months", "1 year 1 month", "9 days": whole months, days under one. */
export function stayLength(from: string, to: string): string {
  const a = new Date(from)
  const b = new Date(to)
  if (Number.isNaN(a.getTime()) || Number.isNaN(b.getTime())) return ''
  return daysLabel((b.getTime() - a.getTime()) / 86400000)
}

export function daysLabel(span: number): string {
  const days = Math.max(0, Math.round(span))
  const months = Math.round(days / 30.44)
  if (months < 1) return `${days} day${days === 1 ? '' : 's'}`
  const y = Math.floor(months / 12)
  const m = months % 12
  return [y && `${y} year${y === 1 ? '' : 's'}`, m && `${m} month${m === 1 ? '' : 's'}`].filter(Boolean).join(' ')
}
</script>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import AppModal from '@/components/shared/AppModal.vue'
import StarRating from '@/components/shared/StarRating.vue'
import { formatDate, formatPeso } from '@/utils/format'

// A stay in full (BH-Detail). Rating is only picked here; the two-part form
// (place + landlord, with comments) is the page's, opened by `rate`.
const props = defineProps<{ modelValue: boolean; stay: Stay | null }>()
const emit = defineEmits<{
  'update:modelValue': [open: boolean]
  rate: [stay: Stay, stars: number]
  payments: [stay: Stay]
}>()

const pick = ref(0)
watch(() => props.stay?.id, () => (pick.value = 0))

const rows = computed(() => {
  const s = props.stay
  if (!s) return []
  const list: { k: string; v: string }[] = [{ k: 'Room', v: s.room }]
  if (s.rent) list.push({ k: 'Rent', v: `${formatPeso(s.rent)}/mo` })
  list.push({ k: 'Stayed', v: stayLength(s.from, s.to) })
  if (s.endedReason) list.push({ k: 'Why it ended', v: s.endedReason })
  if (s.landlord) list.push({ k: s.landlordRole, v: s.landlord })
  return list.filter((r) => r.v)
})
const payLine = computed(() => {
  const s = props.stay
  if (!s) return ''
  if (s.state === 'now' || s.state === 'leaving') return `${formatPeso(s.paid ?? 0)} paid so far`
  return s.owed > 0.009 ? `${formatPeso(s.paid ?? 0)} paid · ${formatPeso(s.owed)} unpaid` : `${formatPeso(s.paid ?? 0)} paid · settled`
})
</script>

<style scoped>
.sd-icon {
  display: grid;
  flex: 0 0 48px;
  width: 48px;
  height: 48px;
  place-items: center;
  border: 2px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.sd-head {
  display: flex;
  min-width: 0;
  flex-direction: column;
}
.sd-name {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
}
.sd-addr {
  color: var(--m-muted);
  font-size: 12.5px;
}
.sd-dates {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}
.sd-date {
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding: 10px 12px;
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
}
.sd-date span {
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
}
.sd-date b {
  color: var(--m-ink);
  font-size: 14px;
}
.sd-rows {
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
}
.sd-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 0;
  border-top: 1px solid var(--m-border);
}
.sd-row:first-child {
  border-top: 0;
}
.sd-row dt {
  color: var(--m-muted);
  font-size: 13px;
}
.sd-row dd {
  margin: 0;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 600;
  text-align: right;
}
.sd-pay {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
}
.sd-pay-text {
  display: flex;
  flex: 1;
  flex-direction: column;
  font-size: 12px;
  font-weight: 600;
}
.sd-pay-text b {
  color: var(--m-ink);
  font-size: 13.5px;
}
.sd-ok {
  color: var(--m-success);
}
.sd-bad {
  color: var(--m-danger);
}
.sd-chev {
  color: var(--m-muted);
}
.sd-rate {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 14px;
  border: 1px solid var(--m-warning);
  border-radius: var(--m-radius);
  background: var(--m-warning-soft);
  color: var(--m-ink);
  font-size: 14px;
}
.sd-stars {
  display: flex;
  gap: 6px;
}
.sd-star {
  display: grid;
  width: 44px;
  height: 44px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-border);
  cursor: pointer;
}
.sd-star--on {
  color: #f5a623;
}
.sd-star--on :deep(path) {
  fill: currentColor;
}
.sd-hint {
  color: var(--m-muted);
  font-size: 12px;
}
.sd-rated {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.sd-cta {
  flex: 1;
  min-height: 46px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
</style>
