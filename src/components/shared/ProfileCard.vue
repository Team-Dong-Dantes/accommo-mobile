<template>
  <section class="profile-card">
    <slot name="always" />

    <button type="button" class="card-toggle" @click="expanded = !expanded">
      <span>{{ expanded ? 'Show less' : 'Show all details' }}</span>
      <IconifyIcon icon="lucide:chevron-down" width="16" class="card-toggle-icon" :class="{ 'card-toggle-icon--open': expanded }" />
    </button>

    <template v-if="expanded">
      <slot name="more" />
    </template>

    <p v-if="$slots.footer" class="profile-card-footer">
      <slot name="footer" />
    </p>
  </section>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'

const expanded = ref(false)
</script>

<style scoped>
.profile-card {
  background: var(--m-surface);
  border-radius: var(--m-radius);
  border: 1px solid var(--m-border);
  overflow: hidden;
}
.card-toggle {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  width: 100%;
  padding: 10px 14px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  color: var(--m-primary-dark);
  font: inherit;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
}
.card-toggle:hover {
  background: var(--m-bg);
}
.card-toggle-icon {
  transition: transform 0.15s;
}
.card-toggle-icon--open {
  transform: rotate(180deg);
}
.profile-card-footer {
  margin: 0;
  padding: 10px 14px;
  border-top: 1px solid var(--m-border);
  color: var(--m-muted);
  font-size: 12px;
  text-align: center;
}
</style>
