<template>
  <ol class="bt">
    <li v-for="s in stays" :key="s.id" class="bt-item">
      <span class="bt-dot" :class="{ 'bt-dot--now': s.current, 'bt-dot--bad': isTerminated(s) }" aria-hidden="true" />
      <div class="bt-head">
        <span class="bt-name">{{ s.name }}</span>
        <span v-if="s.current" class="bt-tag bt-tag--now">Current</span>
        <span v-else-if="s.mine" class="bt-tag">Stayed with you</span>
      </div>
      <span class="bt-meta">{{ s.room }} · {{ lengthLabel(days(s)) }}</span>
      <!-- How a stay ended belongs with the date it ended on. -->
      <span class="bt-dates">
        {{ fullDate(s.start) }} – {{ s.end ? fullDate(s.end) : 'present' }}<template v-if="!s.current && endLabel(s)">
          · <span class="bt-why" :class="{ 'bt-why--bad': isTerminated(s) }">{{ endLabel(s) }}</span></template>
      </span>
    </li>
  </ol>
</template>

<script setup lang="ts">

/**
 * One student's stays, newest first, as a vertical timeline. Used by the
 * boarder's Boarding History tab and the profile a QR scan opens.
 */
export interface TimelineStay {
  id: string
  name: string
  /** Room type or room label, already readable. */
  room: string
  start: string
  /** null while the stay is still running. */
  end: string | null
  current?: boolean
  /** leases.ended_reason (boarding_history.end_reason), raw. */
  endReason?: string | null
  /** At one of the viewing landlord/landlady's own accommodations. */
  mine?: boolean
}

defineProps<{ stays: TimelineStay[] }>()

const isTerminated = (s: TimelineStay) => s.endReason === 'terminated'

const END_LABEL: Record<string, string> = {
  terminated: 'Terminated',
  leave_approved: 'Moved out',
  stay_ended: 'Lease ended',
  ended: 'Lease ended',
}
function endLabel(s: TimelineStay) {
  const r = s.endReason
  if (!r) return ''
  return END_LABEL[r] ?? r.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

const DAY = 864e5
function days(s: TimelineStay) {
  const end = s.end ? Date.parse(`${s.end}T00:00:00`) : Date.now()
  return Math.max(0, Math.round((end - Date.parse(`${s.start}T00:00:00`)) / DAY))
}

// Months are 30.44-day steps, as in stayProgress.
function lengthLabel(d: number) {
  const months = Math.round(d / 30.44)
  if (months < 1) return `${d} ${d === 1 ? 'day' : 'days'}`
  if (months < 12) return `${months} ${months === 1 ? 'month' : 'months'}`
  const rest = months % 12
  return `${Math.floor(months / 12)} yr${rest ? ` ${rest} mo` : ''}`
}

// Always with the year: formatDate drops it inside the current year, which
// reads oddly in a range that started the year before.
const fullDate = (d: string) =>
  new Date(`${d}T00:00:00`).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' })
</script>

<style scoped>
.bt {
  display: flex;
  flex-direction: column;
  margin: 10px 0 0;
  padding: 14px 14px 2px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  list-style: none;
}
.bt-item { position: relative; display: flex; flex-direction: column; gap: 2px; padding: 0 0 16px 24px; }
/* The rail runs from this dot down to the next one; the last stay has none. */
.bt-item:not(:last-child)::before {
  content: '';
  position: absolute;
  top: 16px;
  bottom: -2px;
  left: 5px;
  width: 2px;
  border-radius: 1px;
  background: var(--m-border);
}
.bt-dot {
  position: absolute;
  top: 4px;
  left: 0;
  width: 12px;
  height: 12px;
  border: 2px solid var(--m-surface);
  border-radius: 999px;
  background: var(--m-muted);
  box-shadow: 0 0 0 1px var(--m-border);
}
.bt-dot--now { background: var(--m-success); }
.bt-dot--bad { background: var(--m-danger); }
.bt-head { display: flex; flex-wrap: wrap; align-items: center; gap: 4px 8px; }
.bt-name { color: var(--m-ink); font-size: 15px; font-weight: 700; line-height: 1.3; }
.bt-tag {
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 11px;
  font-weight: 700;
}
.bt-tag--now { background: var(--m-success-soft); color: var(--m-success); }
.bt-meta { color: var(--m-text); font-size: 13px; font-weight: 600; }
.bt-dates { color: var(--m-muted); font-size: 12px; line-height: 1.4; }
.bt-why { color: var(--m-text); font-weight: 600; }
.bt-why--bad { color: var(--m-danger); font-weight: 700; }
</style>
