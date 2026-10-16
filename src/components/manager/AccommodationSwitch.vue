<template>
  <button type="button" class="prop-head" :disabled="accommodations.length < 2">
    <span class="prop-icon"><IconifyIcon icon="lucide:building-2" width="18" /></span>
    <span class="prop-body">
      <span class="prop-name">{{ selected?.name }}</span>
      <span v-if="selected?.place" class="prop-place">{{ selected.place }}</span>
    </span>
    <span v-if="selected" class="prop-chip" :class="`prop-chip--${ACCOMMODATION_STATUS_TONE[selected.status] ?? 'grey'}`">
      {{ ACCOMMODATION_STATUS_LABEL[selected.status] ?? selected.status }}
    </span>
    <IconifyIcon v-if="accommodations.length > 1" icon="lucide:chevrons-up-down" width="16" class="prop-caret" />
    <q-menu v-if="accommodations.length > 1" fit anchor="bottom left" self="top left">
      <q-list>
        <q-item v-for="a in accommodations" :key="a.id" v-close-popup clickable :active="a.id === modelValue" @click="emit('update:modelValue', a.id)">
          <q-item-section>
            <q-item-label>{{ a.name }}</q-item-label>
            <q-item-label v-if="a.place" caption>{{ a.place }}</q-item-label>
          </q-item-section>
          <q-item-section side>
            <span class="prop-chip" :class="`prop-chip--${ACCOMMODATION_STATUS_TONE[a.status] ?? 'grey'}`">
              {{ ACCOMMODATION_STATUS_LABEL[a.status] ?? a.status }}
            </span>
          </q-item-section>
        </q-item>
      </q-list>
    </q-menu>
  </button>
</template>

<script setup lang="ts">
// Which accommodation's permits the OSAS page shows; a menu switches when
// there is more than one.
import { computed } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { ACCOMMODATION_STATUS_LABEL, ACCOMMODATION_STATUS_TONE } from '@/utils/listings'
import type { Accommodation } from '@/utils/useOsasPermits'

const props = defineProps<{ modelValue: string; accommodations: Accommodation[] }>()
const emit = defineEmits<{ 'update:modelValue': [id: string] }>()

const selected = computed(() => props.accommodations.find((a) => a.id === props.modelValue))
</script>

<style scoped>
/* The accommodation whose permits are listed below — a menu switches it. */
.prop-head {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  color: inherit;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.prop-head:disabled {
  cursor: default;
}
.prop-icon {
  display: grid;
  width: 38px;
  height: 38px;
  flex: 0 0 38px;
  place-items: center;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.prop-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.prop-name {
  overflow: hidden;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.prop-place {
  color: var(--m-muted);
  font-size: 12px;
}
.prop-caret {
  flex: 0 0 auto;
  color: var(--m-muted);
}

.prop-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.prop-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.prop-chip--amber,
.prop-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.prop-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.prop-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
</style>
