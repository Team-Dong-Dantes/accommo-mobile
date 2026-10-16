<template>
  <div class="bh">
    <template v-if="shown.length">
      <p class="bh-sum">
        {{ stays.length }} stay{{ stays.length === 1 ? '' : 's' }}<template v-if="total"> · {{ total }} boarding</template>
        <template v-if="toRate"> · <b class="bh-warn">{{ toRate }} to rate</b></template>
      </p>
      <ol class="bh-list" aria-label="Your stays, newest first">
        <li v-for="(s, i) in shown" :key="s.id" class="bh-item">
          <span class="bh-rail" aria-hidden="true">
            <span class="bh-dot" :class="{ 'bh-dot--now': s.state === 'now' || s.state === 'leaving', 'bh-dot--rate': s.toRate }" />
            <span class="bh-line" :class="{ 'bh-line--dashed': s.state === 'now', 'bh-line--last': i === shown.length - 1 }" />
          </span>
          <div class="bh-body">
            <button type="button" class="bh-main" @click="open(s)">
              <span class="bh-top">
                <span class="bh-name">{{ s.name }}</span>
                <span class="bh-state" :class="{ 'bh-state--on': s.state === 'now' }">{{ STATE_TEXT[s.state] }}</span>
              </span>
              <span class="bh-when">{{ formatDate(s.from) }} – {{ s.state === 'now' ? 'now' : formatDate(s.to) }} · {{ stayLength(s.from, s.state === 'now' ? today : s.to) }}</span>
              <span class="bh-room">{{ s.room }}</span>
            </button>
            <button v-if="s.state === 'now' || s.state === 'leaving'" type="button" class="bh-link" @click="router.push('/student/stay')">
              Open My Stay
              <IconifyIcon icon="lucide:chevron-right" width="15" />
            </button>
            <button v-if="s.toRate" type="button" class="bh-rate" @click="open(s)">
              <IconifyIcon icon="lucide:star" width="15" />
              Rate this stay
            </button>
            <span v-else-if="s.rating" class="bh-rated">
              You rated it
              <StarRating :model-value="s.rating" :size="13" />
            </span>
          </div>
        </li>
      </ol>
    </template>
    <EmptyState v-else-if="stays.length" variant="compact" icon="lucide:search-x" title="Nothing matches" message="Try a different search." />
    <EmptyState v-else variant="compact" icon="lucide:history" title="No stays yet" message="Once you move in, your stays land here and you can rate them when they end." />

    <StayDetailSheet v-model="sheetOpen" :stay="picked" @rate="(s, n) => ((sheetOpen = false), emit('rate', s, n))" @payments="(s) => ((sheetOpen = false), emit('payments', s))" />
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import StarRating from '@/components/shared/StarRating.vue'
import StayDetailSheet, { daysLabel, stayLength, type Stay } from '@/components/student/StayDetailSheet.vue'
import { formatDate } from '@/utils/format'
import { manilaToday } from '@/utils/payments'

// Boarding history (BH-Student): the student's stays as a timeline, newest first.
const props = defineProps<{ stays: Stay[]; query: string }>()
const emit = defineEmits<{ rate: [stay: Stay, stars: number]; payments: [stay: Stay] }>()
const router = useRouter()

const STATE_TEXT = { now: 'Staying now', leaving: 'Leaving soon', ended: 'Moved out', terminated: 'Ended by landlord' } as const
const today = manilaToday()

const shown = computed(() => {
  const q = props.query.trim().toLowerCase()
  return q ? props.stays.filter((s) => `${s.name} ${s.room}`.toLowerCase().includes(q)) : props.stays
})
const toRate = computed(() => props.stays.filter((s) => s.toRate).length)
// Total time boarded, summed per stay (the open one counts up to today).
const total = computed(() => {
  const days = props.stays.reduce((n, s) => {
    const end = s.state === 'now' || s.state === 'leaving' ? today : s.to
    return n + Math.max(0, (new Date(end).getTime() - new Date(s.from).getTime()) / 86400000)
  }, 0)
  return days ? daysLabel(days) : ''
})

const sheetOpen = ref(false)
const picked = ref<Stay | null>(null)
function open(s: Stay) {
  picked.value = s
  sheetOpen.value = true
}
</script>

<style scoped>
.bh {
  display: flex;
  flex-direction: column;
  gap: 18px;
}
.bh-sum {
  margin: 0;
  color: var(--m-muted);
  font-size: 13px;
}
.bh-warn {
  color: var(--m-warning);
}
.bh-list {
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 0;
  list-style: none;
}
.bh-item {
  display: grid;
  grid-template-columns: 16px minmax(0, 1fr);
  column-gap: 14px;
}
.bh-rail {
  display: flex;
  flex-direction: column;
  align-items: center;
}
.bh-dot {
  flex: 0 0 16px;
  width: 16px;
  height: 16px;
  margin-top: 3px;
  box-sizing: border-box;
  border: 3px solid var(--m-text);
  border-radius: 50%;
  background: var(--m-text);
}
.bh-dot--now {
  border-color: var(--m-primary);
  background: var(--m-surface);
}
.bh-dot--rate {
  border-color: var(--m-warning);
  background: var(--m-warning);
}
.bh-line {
  flex: 1;
  width: 0;
  border-left: 2px solid var(--m-border);
}
.bh-line--dashed {
  border-left-style: dashed;
}
.bh-line--last {
  border-color: transparent;
}
.bh-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 3px;
  padding-bottom: 26px;
}
.bh-main {
  display: flex;
  flex-direction: column;
  gap: 3px;
  padding: 0;
  border: 0;
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.bh-top {
  display: flex;
  align-items: baseline;
  gap: 8px;
}
.bh-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.bh-state {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
}
.bh-state--on {
  color: var(--m-primary-dark);
}
.bh-when {
  color: var(--m-text);
  font-size: 13px;
  font-weight: 600;
}
.bh-room {
  color: var(--m-muted);
  font-size: 12.5px;
}
.bh-link {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  align-self: flex-start;
  min-height: 36px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.bh-rate {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  align-self: flex-start;
  min-height: 36px;
  margin-top: 4px;
  padding: 0 14px;
  border: 1px solid var(--m-warning);
  border-radius: 999px;
  background: var(--m-warning-soft);
  color: var(--m-warning);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.bh-rated {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  margin-top: 4px;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
</style>
