<template>
  <!-- The dashboard's short form of PropertyCard: one hairline row per
       accommodation. Rooms, address and photos stay on the Properties page. -->
  <button type="button" class="prow" @click="emit('open', property.id)">
    <span class="prow-thumb">
      <img v-if="property.image" :src="property.image" alt="" loading="lazy" />
      <IconifyIcon v-else icon="lucide:house" width="18" />
    </span>

    <span class="prow-text">
      <span class="prow-name">{{ property.name }}</span>
      <span class="prow-meta">
        <span class="prow-status" :class="`prow-status--${STATUS_TONE[property.status] || 'grey'}`">
          {{ ACCOMMODATION_STATUS_LABEL[property.status] || property.status }}
        </span>
        <template v-if="permitLine">
          <span class="prow-sep">·</span>
          <span :class="`prow-permit--${healthTone(property)}`">{{ permitLine }}</span>
        </template>
      </span>
    </span>

    <span class="prow-beds">
      <span class="prow-beds-value">{{ property.filled }}/{{ property.capacity }}</span>
      <span class="prow-beds-label">beds</span>
    </span>
    <IconifyIcon icon="lucide:chevron-right" width="18" class="prow-chev" />
  </button>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { healthTone, STATUS_TONE, type Property } from './property'
import { ACCOMMODATION_STATUS_LABEL } from '@/utils/listings'

const props = defineProps<{ property: Property }>()
const emit = defineEmits<{ open: [id: string] }>()

// Only permit trouble is worth a word here; "all up to date" is the silent default.
const permitLine = computed(() => {
  const { expired, expiringSoon } = props.property
  if (expired > 0) return `${expired} expired ${expired === 1 ? 'permit' : 'permits'}`
  if (expiringSoon > 0) return `${expiringSoon} expiring soon`
  return ''
})
</script>

<style scoped>
.prow {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 12px;
  min-height: 64px;
  padding: 10px 12px 10px 14px;
  border: 0;
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.prow + .prow { border-top: 1px solid var(--m-border); }
.prow:active { background: var(--m-bg); }

.prow-thumb {
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  overflow: hidden;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.prow-thumb img { width: 100%; height: 100%; object-fit: cover; }

.prow-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 2px; }
.prow-name {
  overflow: hidden;
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.prow-meta { display: flex; min-width: 0; align-items: center; gap: 4px; overflow: hidden; font-size: 12px; font-weight: 600; white-space: nowrap; }
.prow-sep { color: var(--m-muted); }
.prow-status--ok { color: var(--m-success); }
.prow-status--warn { color: var(--m-warning); }
.prow-status--danger { color: var(--m-danger); }
.prow-status--grey { color: var(--m-muted); }
.prow-permit--danger { color: var(--m-danger); }
.prow-permit--warn { color: var(--m-warning); }

.prow-beds { display: flex; flex: 0 0 auto; flex-direction: column; align-items: flex-end; }
.prow-beds-value { color: var(--m-ink); font-family: var(--m-font-display); font-size: 15px; font-weight: 700; letter-spacing: -0.01em; }
.prow-beds-label { color: var(--m-muted); font-size: 11px; font-weight: 600; }
.prow-chev { flex: 0 0 auto; color: var(--m-muted); }
</style>
