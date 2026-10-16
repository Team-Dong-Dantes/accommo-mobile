<template>
  <button type="button" class="dpc" @click="emit('open', property.id)">
    <span class="dpc-photo">
      <img v-if="property.image" :src="property.image" :alt="property.name" loading="lazy" />
      <IconifyIcon v-else icon="lucide:building-2" width="26" class="dpc-ph" />
      <span class="dpc-name">{{ property.name }}</span>
      <span v-if="dot" class="dpc-dot" role="img" aria-label="Needs attention" />
    </span>
    <span class="dpc-body">
      <span class="dpc-beds">
        <span class="dpc-bars" aria-hidden="true">
          <i v-for="(on, i) in bars" :key="i" :class="{ on }" />
        </span>
        <b>{{ property.filled }}/{{ property.capacity }}</b>
      </span>
      <span class="dpc-rent"><b>{{ formatPeso(paid) }}</b> / {{ formatPeso(due) }}</span>
    </span>
  </button>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { formatPeso } from '@/utils/format'
import type { Property } from '@/components/manager/property'

// One "My properties" tile on the landlord dashboard (D-L5): photo, a bar per
// bed, and this month's rent paid / due. `dot` = something late, to confirm or
// an expired permit.
const props = defineProps<{ property: Property; paid: number; due: number; dot: boolean }>()
const emit = defineEmits<{ open: [id: string] }>()

// ponytail: more than 12 beds are drawn as 12 proportional bars; the 3/20 text stays exact.
const MAX_BARS = 12
const bars = computed(() => {
  const { capacity, filled } = props.property
  const n = Math.min(Math.max(capacity, 0), MAX_BARS)
  const on = capacity > MAX_BARS ? Math.round((filled / capacity) * MAX_BARS) : Math.min(filled, n)
  return Array.from({ length: n }, (_, i) => i < on)
})
</script>

<style scoped>
.dpc {
  display: flex;
  min-width: 0;
  min-height: 0;
  height: 100%;
  flex-direction: column;
  padding: 0;
  overflow: hidden;
  border: 0;
  border-radius: 20px;
  background: var(--m-surface);
  color: inherit;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.dpc-photo {
  position: relative;
  display: flex;
  /* Fills what the dashboard has left; never shrinks past the name pill. */
  flex: 1 1 76px;
  min-height: 40px;
  max-height: 150px;
  align-items: flex-end;
  box-sizing: border-box;
  padding: 8px;
  background: var(--m-primary-soft);
}
.dpc-photo img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
.dpc-ph { position: absolute; top: 50%; left: 50%; color: var(--m-primary-dark); transform: translate(-50%, -50%); }
.dpc-name {
  position: relative;
  max-width: 100%;
  overflow: hidden;
  padding: 3px 10px;
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dpc-dot {
  position: absolute;
  top: 8px;
  right: 8px;
  width: 12px;
  height: 12px;
  border: 2px solid var(--m-surface);
  border-radius: 50%;
  background: var(--m-danger);
}
.dpc-body { display: flex; flex-direction: column; gap: 6px; padding: 10px 12px 12px; }
.dpc-beds { display: flex; align-items: center; gap: 8px; color: var(--m-ink); font-size: 13px; }
.dpc-bars { display: flex; flex: 1; gap: 3px; }
.dpc-bars i { flex: 1; height: 8px; border-radius: 4px; background: var(--m-border); }
.dpc-bars i.on { background: var(--m-primary); }
.dpc-rent { color: var(--m-muted); font-size: 12.5px; }
.dpc-rent b { color: var(--m-ink); }
</style>
