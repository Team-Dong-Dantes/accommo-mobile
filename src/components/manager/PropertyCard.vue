<template>
  <button v-if="property" type="button" class="pcard" @click="emit('open', property.id)">
    <span class="pcard-photo" :class="{ 'pcard-photo--empty': !property.image }">
      <img v-if="property.image" :src="property.image" :alt="property.name" loading="lazy" />
      <span v-else class="pcard-photo-empty">
        <IconifyIcon icon="lucide:image-off" width="24" />
        <span class="pcard-photo-empty-label">No photo</span>
      </span>
      <span class="pcard-status" :class="`pcard-status--${STATUS_TONE[property.status] || 'grey'}`">
        <IconifyIcon :icon="STATUS_ICON[property.status] || 'lucide:circle'" width="10" />
        {{ STATUS_LABEL[property.status] || property.status }}
      </span>
      <span class="pcard-health-dot" :class="`pcard-health-dot--${healthTone(property)}`" />
    </span>

    <span class="pcard-body">
      <span class="pcard-head">
        <span class="pcard-name">{{ property.name }}</span>
        <span v-if="property.type" class="pcard-type">{{ property.type }}</span>
      </span>
      <span v-if="property.address" class="pcard-addr">
        <IconifyIcon icon="lucide:map-pin" width="12" />
        {{ property.address }}
      </span>

      <span class="facts">
        <span class="fact">
          <span class="fact-value">{{ property.roomCount ?? '—' }}</span>
          <span class="fact-label">{{ property.roomCount === 1 ? 'Room' : 'Rooms' }}</span>
        </span>
        <span class="fact-div" />
        <span class="fact">
          <span class="fact-value">{{ property.filled }}/{{ property.capacity }}</span>
          <span class="fact-label">Beds filled</span>
        </span>
      </span>

      <span class="pcard-docs">
        <span v-if="property.expired > 0" class="doc-expired">
          <IconifyIcon icon="lucide:file-warning" width="14" />
          {{ property.expired }} expired {{ property.expired === 1 ? 'permit' : 'permits' }}
        </span>
        <span v-else-if="property.expiringSoon > 0" class="doc-expiring">
          <IconifyIcon icon="lucide:clock" width="14" />
          {{ property.expiringSoon }} expiring soon
        </span>
        <span v-else class="doc-ok">
          <IconifyIcon icon="lucide:check-circle" width="14" />
          All permits up to date
        </span>
      </span>
    </span>
  </button>

  <!-- No property: the dashed "add" tile, which shares this card's frame. -->
  <button v-else type="button" class="pcard pcard--add" @click="emit('add')">
    <span class="pcard-add-icon"><IconifyIcon icon="lucide:plus" width="22" /></span>
    <span class="pcard-add-label">{{ addLabel }}</span>
  </button>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'
import { healthTone, type Property } from './property'

withDefaults(defineProps<{ property?: Property | null; addLabel?: string }>(), {
  property: null,
  addLabel: 'Add another',
})
const emit = defineEmits<{ open: [id: string]; add: [] }>()

const STATUS_LABEL: Record<string, string> = {
  pending: 'Pending review',
  reviewing: 'Reviewing',
  accredited: 'Accredited',
  rejected: 'Rejected',
  delisted: 'Delisted',
}
const STATUS_TONE: Record<string, string> = {
  pending: 'warn',
  reviewing: 'warn',
  accredited: 'ok',
  rejected: 'danger',
  delisted: 'grey',
}
const STATUS_ICON: Record<string, string> = {
  pending: 'lucide:hourglass',
  reviewing: 'lucide:search',
  accredited: 'lucide:badge-check',
  rejected: 'lucide:x-circle',
  delisted: 'lucide:archive',
}
</script>

<style scoped>
.pcard {
  position: relative;
  display: flex;
  width: 100%;
  flex-direction: column;
  padding: 0 0 11px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02);
  cursor: pointer;
  font: inherit;
  overflow: hidden;
  text-align: left;
  transition: box-shadow 0.15s, transform 0.12s ease;
}
.pcard:hover { box-shadow: 0 4px 12px rgba(0, 0, 0, 0.06); }
.pcard:active { transform: scale(0.985); }

.pcard-photo {
  position: relative;
  display: grid;
  width: 100%;
  aspect-ratio: 16 / 9;
  place-items: center;
  overflow: hidden;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.pcard-photo img { width: 100%; height: 100%; object-fit: cover; }
.pcard-photo--empty { background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%); }
.pcard-photo-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
}
.pcard-photo-empty-label { font-size: 10.5px; font-weight: 700; letter-spacing: 0.02em; }

.pcard-status {
  position: absolute;
  top: 8px;
  left: 8px;
  display: flex;
  align-items: center;
  gap: 3px;
  padding: 3px 9px 3px 7px;
  border-radius: 999px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.15);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.01em;
}
.pcard-status--ok { background: var(--m-success); }
.pcard-status--warn { background: var(--m-warning); }
.pcard-status--danger { background: var(--m-danger); }
.pcard-status--grey { background: rgba(23, 32, 42, 0.75); }

.pcard-health-dot {
  position: absolute;
  top: 10px;
  right: 10px;
  width: 10px;
  height: 10px;
  border: 2px solid rgba(255, 255, 255, 0.9);
  border-radius: 999px;
  box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.15);
}
.pcard-health-dot--good { background: var(--m-success); }
.pcard-health-dot--warn { background: var(--m-warning); }
.pcard-health-dot--danger { background: var(--m-danger); }

.pcard-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 4px;
  padding: 10px 12px 0;
}
.pcard-head { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; }
.pcard-name {
  min-width: 0;
  overflow: hidden;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
  letter-spacing: -0.01em;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pcard-type {
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  font-size: 10px;
  font-weight: 700;
}
.pcard-addr {
  display: flex;
  align-items: center;
  gap: 4px;
  overflow: hidden;
  color: var(--m-muted);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.facts {
  display: flex;
  align-items: stretch;
  margin-top: 4px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
}
.fact {
  display: flex;
  min-width: 0;
  flex: 1 1 0;
  flex-direction: column;
  align-items: center;
  padding: 6px 4px;
  text-align: center;
}
.fact-div { width: 1px; background: var(--m-border); }
.fact-value {
  max-width: 100%;
  overflow: hidden;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 13px;
  font-weight: 700;
  letter-spacing: -0.01em;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.fact-label { color: var(--m-muted); font-size: 10px; font-weight: 600; }

.pcard-docs {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-top: 6px;
  font-size: 12px;
  font-weight: 600;
}
.doc-expired { color: var(--m-danger); }
.doc-expiring { color: var(--m-warning); }
.doc-ok { color: var(--m-success); }

.pcard--add {
  flex-direction: row;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 18px 12px;
  border-style: dashed;
  background: transparent;
  box-shadow: none;
}
.pcard--add:hover { background: var(--m-surface); box-shadow: 0 1px 4px rgba(0, 0, 0, 0.05); }
.pcard-add-icon {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.pcard-add-label { color: var(--m-muted); font-size: 13px; font-weight: 700; line-height: 1.3; }

@media (prefers-reduced-motion: reduce) {
  .pcard { transition: none; }
}
</style>
