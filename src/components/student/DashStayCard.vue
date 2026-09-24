<template>
  <div class="room-card">
    <!-- The cover is the door to My Stay, which holds the full detail: rules,
         amenities, room type, roommates, lease term. -->
    <button type="button" class="cover" @click="emit('go', '/student/stay')">
      <img v-if="stay.photoUrl" :src="stay.photoUrl" alt="" class="cover-img" />
      <span v-else class="cover-mono" aria-hidden="true">{{ monogram }}</span>

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
            Your landlord/landlady<template v-if="manager.replyMinutes"> · replies in ~{{ manager.replyMinutes }} min</template>
          </span>
        </span>
        <span class="person-actions">
          <button type="button" class="icon-btn" aria-label="Message landlord/landlady" @click.stop="emit('message')">
            <IconifyIcon icon="lucide:message-circle" width="17" />
          </button>
        </span>
      </div>

      <button v-if="directionsUrl" type="button" class="room-map-link" @click="openDirections">
        <IconifyIcon icon="lucide:navigation" width="13" />
        Directions
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { reactive, computed } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { formatDate, initialsOf } from '@/utils/format'
import { campusDistanceLabel } from '@/utils/geo'
import { openExternal } from '@/utils/openExternal'
import type { Manager, Stay } from './dashboard'

const props = defineProps<{ stay: Stay; manager: Manager | null }>()
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

const monogram = computed(() => initialsOf(props.stay.accommodationName))

const roomLabel = computed(() => {
  const { roomNumber, roomLabel: label } = props.stay
  if (roomNumber && label) return `Room ${roomNumber} · ${label}`
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
.room-card { border-radius: var(--m-radius); background: var(--m-surface); border: 1px solid var(--m-border); overflow: hidden; }

/* Cover */
.cover {
  position: relative;
  display: block;
  width: 100%;
  height: 140px;
  padding: 0;
  border: 0;
  background: var(--m-primary-soft);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.cover-img { width: 100%; height: 100%; object-fit: cover; display: block; }
.cover-mono {
  display: grid;
  width: 100%;
  height: 100%;
  place-items: center;
  background: linear-gradient(160deg, var(--m-primary) 0%, var(--m-primary-dark) 100%);
  color: rgba(255, 255, 255, 0.55);
  font-family: var(--m-font-display);
  font-size: 44px;
  font-weight: 800;
  letter-spacing: 0.02em;
}
.cover-scrim {
  position: absolute;
  inset: 0;
  background: linear-gradient(to top, rgba(12, 18, 26, 0.82) 0%, rgba(12, 18, 26, 0.34) 44%, rgba(12, 18, 26, 0) 72%);
}
.cover-tag {
  position: absolute;
  top: 9px;
  right: 9px;
  padding: 3px 10px;
  border-radius: 999px;
  background: rgba(12, 18, 26, 0.68);
  color: #fff;
  font-size: 10.5px;
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
  padding: 11px 12px 12px;
}
.cover-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 2px; }
.cover-name {
  color: #fff;
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.15;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cover-room {
  color: rgba(255, 255, 255, 0.82);
  font-size: 12px;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cover-chev { flex: 0 0 auto; color: rgba(255, 255, 255, 0.85); margin-bottom: 2px; }

.room-body { display: flex; flex-direction: column; gap: 8px; padding: 11px 13px 13px; }
.room-meta { margin: 0; color: var(--m-text); font-size: 12px; font-weight: 600; text-wrap: pretty; }
.room-map-link {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 5px;
  min-height: 32px;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

.person { display: flex; align-items: center; gap: 10px; padding: 9px 0 0; border-top: 1px solid var(--m-border); }
.person-avatar {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font-size: 12.5px;
  font-weight: 800;
}
.person-avatar-img { width: 100%; height: 100%; object-fit: cover; }
.person-body { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.person-name { color: var(--m-ink); font-size: 14px; font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.person-role { color: var(--m-muted); font-size: 11.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.person-actions { display: flex; flex: 0 0 auto; gap: 6px; }
.icon-btn {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  text-decoration: none;
  -webkit-tap-highlight-color: transparent;
}
</style>
