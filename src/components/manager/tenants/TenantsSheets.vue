<template>
<BottomSheet
  v-model="filtersOpen"
  title="Filters"
  @clear="filter = 'all'; selectedAccId = 'all'"
>
  <div v-if="accreditedAccommodations.length > 1" class="sheet-block">
    <span class="sheet-label">Property</span>
    <div class="m-chips">
      <button type="button" class="m-chip" :class="{ 'm-chip--on': selectedAccId === 'all' }" @click="selectedAccId = 'all'">
        All
      </button>
      <button
        v-for="a in accreditedAccommodations"
        :key="a.id"
        type="button"
        class="m-chip"
        :class="{ 'm-chip--on': selectedAccId === a.id }"
        @click="selectedAccId = a.id"
      >
        {{ a.name }}
      </button>
    </div>
  </div>
  <div class="sheet-block">
    <span class="sheet-label">Status</span>
    <div class="m-chips">
      <button
        v-for="f in FILTERS"
        :key="f.key"
        type="button"
        class="m-chip"
        :class="{ 'm-chip--on': filter === f.key }"
        @click="filter = f.key"
      >
        {{ f.label }}
      </button>
    </div>
  </div>
</BottomSheet>

<!-- A decline the student can act on: the reason reaches them in the
     notification and stays on the lease. -->
<BottomSheet
  v-model="declineOpen"
  title="Decline application"
  clear-label=""
  done-label=""
>
  <div class="sheet-block">
    <span class="sheet-label">The student sees this reason</span>
    <textarea v-model="declineReason" class="decline-input" rows="3" placeholder="Why are you declining?" />
  </div>
  <div class="decline-actions">
    <button type="button" class="lease-act lease-act--ghost" @click="declineOpen = false">Cancel</button>
    <button
      type="button"
      class="lease-act"
      :disabled="!declineReason.trim() || Boolean(decidingId)"
      @click="confirmDecline"
    >
      {{ decidingId ? 'Declining…' : 'Decline' }}
    </button>
  </div>
</BottomSheet>

<AddStudentSheet v-model="addOpen" @added="refresh" />
</template>

<script setup lang="ts">
// The list's sheets: filters, declining an application, adding a walk-in.
import AddStudentSheet from '@/components/manager/AddStudentSheet.vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'
import { FILTERS } from './model'
import { useTenants } from './tenants'

const {
  filter,
  filtersOpen,
  selectedAccId,
  accreditedAccommodations,
  refresh,
  decidingId,
  addOpen,
  declineOpen,
  declineReason,
  confirmDecline,
} = useTenants()
</script>

<style scoped>
/* Docked search — same baseline and height as the quick-actions FAB, ending
   where it begins, so the two read as one band. */
/* Filter sheet */
.decline-input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  color: var(--m-text);
  font: inherit;
  font-size: 14px;
  resize: none;
}
.decline-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
.lease-actions .lease-act {
  flex: 1;
  min-height: 36px;
  font-size: 12.5px;
}
.lease-act {
  flex: 0 0 auto;
  padding: 6px 11px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 11.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.lease-act:disabled {
  opacity: 0.6;
}
.lease-act--ghost {
  background: var(--m-surface);
  color: var(--m-text);
  border: 1px solid var(--m-border);
}
</style>
