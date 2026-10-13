<template>
  <div class="room-card">
    <!-- The cover is the door to My Stay, which holds the full detail: rules,
         amenities, room type, roommates, lease term. -->
    <button type="button" class="cover" @click="emit('go', '/student/stay')">
      <img v-if="stay.photoUrl" :src="stay.photoUrl" alt="" class="cover-img" />
      <PhotoEmpty v-else :size="28" label />

      <span class="cover-scrim" aria-hidden="true" />
      <span class="cover-tag">{{ statusLabel }}</span>

      <span class="cover-body">
        <span class="cover-text">
          <span class="cover-name">{{ stay.accommodationName }}</span>
          <span class="cover-room">{{ roomLabel }}</span>
        </span>
        <IconifyIcon icon="lucide:chevron-right" width="18" class="cover-chev" />
      </span>
    </button>

    <!-- Rent and what's next — the door into Payments. -->
    <button type="button" class="money" @click="emit('go', '/student/payments')">
      <span class="money-cell">
        <span class="money-cap">Rent</span>
        <span class="money-value">{{ formatPeso(stay.monthlyRent) }}<span class="money-unit">/mo</span></span>
      </span>
      <span class="money-cell">
        <span class="money-cap" :class="{ 'money-cap--due': next?.overdue }">{{ nextCap }}</span>
        <span class="money-value" :class="{ 'money-value--due': next?.overdue, 'money-value--clear': !next }">
          {{ next ? formatPeso(next.amount) : 'All paid up' }}
        </span>
      </span>
      <IconifyIcon icon="lucide:chevron-right" width="18" class="money-chev" />
    </button>

    <div class="room-body">
      <p v-if="metaLine" class="room-meta">{{ metaLine }}</p>

      <div v-if="manager" class="person">
        <span class="person-avatar">
          <img
            v-if="manager.avatarUrl && !broken[manager.id]"
            :src="manager.avatarUrl"
            alt=""
            class="person-avatar-img"
            @error="broken[manager.id] = true"
          />
          <template v-else>{{ manager.initials }}</template>
        </span>
        <span class="person-body">
          <span class="person-name">{{ manager.name }}</span>
          <span class="person-role">
            Your {{ (manager.title ?? LANDLORD_ROLE_LABEL).toLowerCase() }}<template v-if="manager.replyMinutes">{{ ` · replies in ~${manager.replyMinutes} min` }}</template>
          </span>
        </span>
        <span class="person-actions">
          <button type="button" class="icon-btn" :aria-label="`Message ${(manager.title ?? LANDLORD_ROLE_LABEL).toLowerCase()}`" @click.stop="emit('message')">
            <IconifyIcon icon="lucide:message-circle" width="18" />
          </button>
          <button v-if="directionsUrl" type="button" class="icon-btn" aria-label="Directions" @click.stop="openDirections">
            <IconifyIcon icon="lucide:navigation" width="18" />
          </button>
        </span>
      </div>

      <button v-else-if="directionsUrl" type="button" class="room-map-link" @click="openDirections">
        <IconifyIcon icon="lucide:navigation" width="14" />
        Directions
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import PhotoEmpty from '@/components/shared/PhotoEmpty.vue'
import { reactive, computed } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { formatDate, formatPeso, LANDLORD_ROLE_LABEL } from '@/utils/format'
import { campusDistanceLabel } from '@/utils/geo'
import { openExternal } from '@/utils/openExternal'
import type { Manager, NextPayment, Stay } from './dashboard'

const props = defineProps<{ stay: Stay; manager: Manager | null; next: NextPayment | null }>()
const emit = defineEmits<{ go: [route: string]; message: [] }>()

/** Avatars whose image 404s, so the initials fallback takes over without mutating props. */
const broken = reactive<Record<string, boolean>>({})

const STATUS_LABEL: Record<string, string> = {
  active: 'Active',
  pending: 'Pending',
  leave_requested: 'Leaving',
  ended: 'Ended',
  terminated: 'Ended',
}
const statusLabel = computed(() => STATUS_LABEL[props.stay.status] ?? props.stay.status)

const nextCap = computed(() => {
  const n = props.next
  if (!n) return 'Next due'
  // Short month: the strip is half a phone wide and "November 2026" would clip.
  const month = new Date(n.month).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' })
  return `${n.overdue ? 'Overdue' : 'Due'} · ${month}`
})


const roomLabel = computed(() => {
  const { roomNumber, roomLabel: label } = props.stay
  // A label that only restates the number ("Room 303" for room 303) is not shown twice.
  const sameAsNumber = !!label && label.trim().replace(/^room\s*/i, '') === String(roomNumber)
  if (roomNumber && label && !sameAsNumber) return `Room ${roomNumber} · ${label}`
  if (roomNumber) return `Room ${roomNumber}`
  return label || 'Room'
})

// Replaces the old progress ring: the date and the countdown say the same thing
// in words, and an application that hasn't been accepted has no lease to count.
const leaseLine = computed(() => {
  if (props.stay.status === 'pending') return ''
  const end = new Date(props.stay.endDate).getTime()
  if (Number.isNaN(end)) return ''
  const days = Math.ceil((end - Date.now()) / 86400000)
  if (days < 0) return `Lease ended ${formatDate(props.stay.endDate)}`
  return `Lease ends ${formatDate(props.stay.endDate)} · ${days} ${days === 1 ? 'day' : 'days'} left`
})

const metaLine = computed(() =>
  [leaseLine.value, campusDistanceLabel(props.stay.lat, props.stay.lng)].filter(Boolean).join(' · '),
)

// A static map image can't be panned or routed from, so hand the coordinates to
// whichever maps app the device actually has.
const directionsUrl = computed(() => {
  const { lat, lng } = props.stay
  if (typeof lat !== 'number' || typeof lng !== 'number') return ''
  return `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`
})

function openDirections() {
  openExternal(directionsUrl.value)
}
</script>

<style scoped>
/* One type scale: 11 / 12 / 13 / 15 / 17 / 20. */
.room-card { overflow: hidden; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }

/* Cover */
.cover {
  position: relative;
  display: block;
  width: 100%;
  height: 152px;
  padding: 0;
  border: 0;
  background: var(--m-primary-soft);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.cover-img { display: block; width: 100%; height: 100%; object-fit: cover; }
.cover-scrim {
  position: absolute;
  inset: 0;
  background: linear-gradient(to top, rgba(12, 18, 26, 0.82) 0%, rgba(12, 18, 26, 0.34) 44%, rgba(12, 18, 26, 0) 72%);
}
.cover-tag {
  position: absolute;
  top: 10px;
  right: 10px;
  padding: 4px 10px;
  border-radius: 999px;
  background: rgba(12, 18, 26, 0.68);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
}
.cover-body {
  position: absolute;
  right: 0;
  bottom: 0;
  left: 0;
  display: flex;
  align-items: flex-end;
  gap: 8px;
  padding: 12px 14px;
}
.cover-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 2px; }
.cover-name {
  overflow: hidden;
  color: #fff;
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cover-room {
  overflow: hidden;
  color: rgba(255, 255, 255, 0.85);
  font-size: 13px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cover-chev { flex: 0 0 auto; margin-bottom: 2px; color: rgba(255, 255, 255, 0.85); }

/* Money strip — two figures side by side, the whole strip opens Payments */
.money {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 12px;
  padding: 12px 12px 12px 14px;
  border: 0;
  border-bottom: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.money-cell { display: flex; min-width: 0; flex: 1 1 0; flex-direction: column; gap: 2px; }
.money-cell + .money-cell { padding-left: 12px; border-left: 1px solid var(--m-border); }
.money-cap { overflow: hidden; color: var(--m-muted); font-size: 11px; font-weight: 700; letter-spacing: 0.04em; text-overflow: ellipsis; text-transform: uppercase; white-space: nowrap; }
.money-cap--due { color: var(--m-danger); }
.money-value {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -0.02em;
  white-space: nowrap;
}
.money-value--due { color: var(--m-danger); }
.money-value--clear { color: var(--m-success); }
.money-unit { color: var(--m-muted); font-size: 12px; font-weight: 600; }
.money-chev { flex: 0 0 auto; color: var(--m-muted); }

.room-body { display: flex; flex-direction: column; gap: 12px; padding: 12px 14px 14px; }
.room-meta { margin: 0; color: var(--m-text); font-size: 13px; font-weight: 600; line-height: 1.4; text-wrap: pretty; }
.room-map-link {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 6px;
  min-height: 36px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

.person { display: flex; align-items: center; gap: 12px; }
.person-avatar {
  display: grid;
  width: 40px;
  height: 40px;
  flex: 0 0 40px;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font-size: 13px;
  font-weight: 800;
}
.person-avatar-img { width: 100%; height: 100%; object-fit: cover; }
.person-body { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 2px; }
.person-name { overflow: hidden; color: var(--m-ink); font-size: 15px; font-weight: 700; text-overflow: ellipsis; white-space: nowrap; }
.person-role { overflow: hidden; color: var(--m-muted); font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
.person-actions { display: flex; flex: 0 0 auto; gap: 8px; }
.icon-btn {
  display: grid;
  width: 44px;
  height: 44px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
</style>
