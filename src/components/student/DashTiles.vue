<template>
  <!-- D-S5: a tall stay card with two cards beside it, then two tiles. The row
       heights are capped so the whole dashboard fits one phone screen. -->
  <div class="grid">
    <button v-if="stay" type="button" class="stay" @click="emit('go', '/student/stay')">
      <span class="stay-photo">
        <img v-if="stay.photoUrl && !photoBroken" :src="stay.photoUrl" alt="" @error="photoBroken = true" />
        <PhotoEmpty v-else :size="28" />
        <span class="stay-chip">{{ chip }}</span>
      </span>
      <span class="stay-body">
        <span class="stay-name">{{ stay.accommodationName }}</span>
        <span class="stay-room">{{ roomLine }}</span>
      </span>
    </button>
    <div v-else class="stay stay--empty">
      <span class="ico ico--muted"><IconifyIcon icon="lucide:bed-double" width="20" /></span>
      <span class="stay-body">
        <span class="stay-name">No stay yet</span>
        <span class="stay-room">{{ emptyHint }}</span>
      </span>
    </div>

    <!-- ?to= lets Messages find or create the thread with this landlord/landlady. -->
    <button type="button" class="card card--row" @click="emit('go', manager ? `/student/messages?to=${manager.id}` : '/student/messages')">
      <span class="ico" :class="manager ? 'ico--primary' : 'ico--muted'">
        <template v-if="manager">
          <img v-if="manager.avatarUrl && !avatarBroken" :src="manager.avatarUrl" alt="" class="avatar" @error="avatarBroken = true" />
          <template v-else>{{ manager.initials }}</template>
        </template>
        <IconifyIcon v-else icon="lucide:message-circle" width="20" />
        <i v-if="unread > 0" class="dot" />
      </span>
      <span class="txt">
        <span class="t">{{ manager ? firstWord(manager.name) : 'Messages' }}</span>
        <span class="s">{{ messageLine }}</span>
      </span>
    </button>

    <button v-if="stay" type="button" class="card card--col" @click="emit('go', '/student/stay')">
      <span class="lease-top">
        <span class="t">Lease</span>
        <span class="s">{{ lease.left }}</span>
      </span>
      <span class="track"><span class="fill" :style="{ width: `${lease.pct}%` }" /></span>
      <span class="s">{{ lease.ends }}</span>
    </button>
    <button v-else type="button" class="card card--row" @click="emit('go', '/student/discover')">
      <span class="ico ico--primary"><IconifyIcon icon="lucide:search" width="20" /></span>
      <span class="txt">
        <span class="t">Browse rooms</span>
        <span class="s">{{ browseHint }}</span>
      </span>
    </button>
  </div>

  <div class="tiles">
    <button v-for="t in tiles" :key="t.title" type="button" class="card card--tile" @click="emit('go', t.route)">
      <span class="ico" :class="t.tone === 'muted' ? 'ico--muted' : ''" :style="t.tone === 'muted' ? undefined : { background: `var(--m-${t.tone}-soft)`, color: `var(--m-${t.tone})` }">
        <IconifyIcon :icon="t.icon" width="18" />
      </span>
      <span class="txt">
        <span class="t">{{ t.title }}</span>
        <span class="s">{{ t.sub }}</span>
      </span>
    </button>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import PhotoEmpty from '@/components/shared/PhotoEmpty.vue'
import { formatDate, formatPeso, stayProgress } from '@/utils/format'
import { manilaToday } from '@/utils/payments'
import type { DashTile, Manager, Stay } from './dashboard'

const props = defineProps<{
  stay: Stay | null
  manager: Manager | null
  /** Unread messages: from this landlord/landlady with a stay, from anyone without. */
  unread: number
  emptyHint: string
  browseHint: string
  tiles: DashTile[]
}>()
const emit = defineEmits<{ go: [route: string] }>()

const photoBroken = ref(false)
const avatarBroken = ref(false)

const firstWord = (s: string) => s.split(' ')[0]

const CHIP: Record<string, string> = { active: 'Staying now', pending: 'Applied', leave_requested: 'Leaving' }
const chip = computed(() => CHIP[props.stay?.status ?? ''] ?? 'Your stay')

// A label that only restates the number ("Room 303" for room 303) is not shown twice.
const roomLine = computed(() => {
  const s = props.stay
  if (!s) return ''
  const n = s.roomNumber
  const label = s.roomLabel && s.roomLabel.trim().replace(/^room\s*/i, '') !== String(n) ? s.roomLabel : null
  const room = n ? `Room ${n}${label ? ` · ${label}` : ''}` : label || 'Room'
  return `${room} · ${formatPeso(s.monthlyRent)}/mo`
})

const messageLine = computed(() => {
  const n = props.unread
  if (n > 0) return `${n} new ${n === 1 ? 'message' : 'messages'}`
  return props.manager ? 'No new messages' : 'None yet'
})

// Months are 30.44-day steps, same as stayProgress; under a month it counts days.
const lease = computed(() => {
  const s = props.stay
  if (!s) return { pct: 0, left: '', ends: '' }
  const today = manilaToday()
  const { pct } = stayProgress(s.startDate, s.endDate, today)
  if (s.status === 'pending') return { pct: 0, left: 'Pending', ends: `Starts ${formatDate(s.startDate)}` }
  const days = Math.round((Date.parse(`${s.endDate}T00:00:00`) - Date.parse(`${today}T00:00:00`)) / 864e5)
  const left = days <= 0 ? 'Ended' : days <= 31 ? `${days} ${days === 1 ? 'day' : 'days'} left` : `${Math.round(days / 30.44)} mo left`
  return { pct, left, ends: `Ends ${formatDate(s.endDate)}` }
})
</script>

<style scoped>
button { font: inherit; text-align: left; cursor: pointer; -webkit-tap-highlight-color: transparent; }
.grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  grid-template-rows: repeat(2, minmax(0, 1fr));
  gap: 10px;
  /* Takes whatever the dashboard has left (StudentDashboard fits the page to the screen). */
  flex: 1 1 260px;
  min-height: 160px;
  max-height: 320px;
}
.stay {
  grid-row: span 2;
  display: flex;
  flex-direction: column;
  min-width: 0;
  overflow: hidden;
  padding: 0;
  border: 0;
  border-radius: 20px;
  background: var(--m-surface);
  color: inherit;
}
.stay-photo {
  position: relative;
  display: grid;
  flex: 1;
  min-height: 0;
  place-items: center;
  overflow: hidden;
  background: var(--m-primary-soft);
}
.stay-photo img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
.stay-chip {
  position: absolute;
  top: 8px;
  left: 8px;
  padding: 3px 8px;
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  font-size: 10.5px;
  font-weight: 800;
}
.stay-body { display: flex; flex-direction: column; gap: 1px; padding: 12px 14px; }
.stay-name {
  overflow: hidden;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.stay-room { overflow: hidden; color: var(--m-muted); font-size: 12.5px; text-overflow: ellipsis; white-space: nowrap; }
.stay--empty {
  justify-content: center;
  align-items: flex-start;
  gap: 12px;
  padding: 18px;
  border: 1.5px dashed var(--m-border);
  background: transparent;
}
.stay--empty .stay-body { padding: 0; gap: 2px; }
.stay--empty .stay-name { white-space: normal; }

.card {
  display: flex;
  min-width: 0;
  padding: 16px;
  border: 0;
  border-radius: 20px;
  background: var(--m-surface);
  color: inherit;
}
.card--row { align-items: center; gap: 12px; }
.card--col { flex-direction: column; justify-content: center; gap: 10px; }
.lease-top { display: flex; justify-content: space-between; align-items: baseline; gap: 6px; }
.track { display: block; height: 8px; overflow: hidden; border-radius: 999px; background: var(--m-border); }
.fill { display: block; height: 100%; border-radius: 999px; background: var(--m-primary); }

.ico {
  position: relative;
  display: grid;
  flex: 0 0 44px;
  width: 44px;
  height: 44px;
  place-items: center;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 800;
}
.ico--primary { background: var(--m-primary-soft); color: var(--m-primary-dark); }
.ico--muted { background: var(--m-border); color: var(--m-muted); }
.avatar { width: 100%; height: 100%; border-radius: 999px; object-fit: cover; }
.dot {
  position: absolute;
  top: -2px;
  right: -2px;
  width: 12px;
  height: 12px;
  border: 2px solid var(--m-surface);
  border-radius: 50%;
  background: var(--m-danger);
}
.txt { display: flex; min-width: 0; flex-direction: column; }
.t { display: -webkit-box; overflow: hidden; color: var(--m-ink); font-size: 15px; font-weight: 700; line-height: 1.25; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
.s { display: -webkit-box; overflow: hidden; color: var(--m-muted); font-size: 12.5px; line-height: 1.3; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }

.tiles { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
.card--tile { flex-direction: column; gap: 10px; padding: 14px 16px; }
</style>
