<template>
  <section class="card">
    <button type="button" class="fold" @click="detailsOpen = !detailsOpen">
      <span class="fold-title">Details</span>
      <span class="fold-note">{{ detailsSummary }}</span>
      <IconifyIcon :icon="detailsOpen ? 'lucide:chevron-up' : 'lucide:chevron-down'" width="16" />
    </button>

    <template v-if="detailsOpen">
      <div class="row">
        <span class="row-label">Happens</span>
        <DateTimeField v-model="form.eventAt" placeholder="Pick a date and time" />
      </div>

      <div v-if="form.eventAt" class="row">
        <span class="row-label">Until</span>
        <DateTimeField v-model="form.eventEnd" placeholder="Pick a date and time" />
      </div>

      <div class="row">
        <span class="row-label">Where</span>
        <input v-model="form.location" type="text" class="row-input" maxlength="120" placeholder="Ground floor · Zone 3" />
      </div>

      <div class="row">
        <span class="row-label">Respond by</span>
        <DateTimeField v-model="form.deadlineAt" placeholder="Pick a date and time" />
      </div>
    </template>
  </section>

  <!-- 3. DELIVERY -->
  <section class="card">
    <span class="fold-title">Delivery</span>

    <div class="row">
      <span class="row-label">Send</span>
      <span class="seg">
        <button type="button" class="seg-btn" :class="{ 'seg-btn--on': !form.publishAt }" @click="form.publishAt = ''">Now</button>
        <button type="button" class="seg-btn" :class="{ 'seg-btn--on': !!form.publishAt }" @click="scheduleSoon">Later</button>
      </span>
    </div>
    <div v-if="form.publishAt" class="row">
      <span class="row-label">At</span>
      <DateTimeField v-model="form.publishAt" :min="today" placeholder="Pick a date and time" />
    </div>

    <div class="row">
      <span class="row-label">Hide after</span>
      <DateTimeField v-model="form.expiresAt" mode="date" :min="today" placeholder="Never" />
    </div>
  </section>
</template>

<script setup lang="ts">
// 2–3. Details (when, where, reply by) and delivery (publish and expiry).
import DateTimeField from '@/components/shared/DateTimeField.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useAnnouncementCompose } from './announcementCompose'

const {
  form,
  today,
  detailsOpen,
  detailsSummary,
  scheduleSoon,
} = useAnnouncementCompose()
</script>

<style scoped>
.card {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.row {
  display: flex;
  align-items: center;
  gap: 10px;
}
.row-label {
  flex: 0 0 84px;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.row-input {
  min-width: 0;
  flex: 1 1 auto;
  padding: 8px 10px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-text);
  font: inherit;
  font-size: 13.5px;
}
/* The collapsed half names what is already set, so folding it away never hides
   a value the writer forgot about. */
.fold {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 8px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  text-align: left;
}
.fold-title {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 13.5px;
  font-weight: 700;
}
.fold-note {
  flex: 1 1 auto;
  overflow: hidden;
  color: var(--m-muted);
  font-size: 11.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.seg {
  display: flex;
  flex: 1 1 auto;
  gap: 4px;
}
.seg-btn {
  padding: 7px 16px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
}
.seg-btn--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
</style>
