<template>
  <section class="empty" :class="{ 'empty--compact': variant === 'compact' }" aria-live="polite" role="status">
    <span v-if="icon" class="empty-icon" aria-hidden="true">
      <IconifyIcon :icon="icon" :width="variant === 'compact' ? 22 : 26" />
    </span>

    <p class="empty-title">{{ title }}</p>
    <p v-if="message" class="empty-text">{{ message }}</p>

    <div v-if="$slots.actions" class="empty-actions">
      <slot name="actions" />
    </div>

    <slot />
  </section>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

// One empty state for the whole app, matching the messages list it was taken
// from: a grey disc, a short title, one line of explanation. `compact` is the
// same thing without the 60vh centring, for a state that sits inside a tab
// panel or a card rather than owning the screen.
withDefaults(
  defineProps<{
    icon?: string
    title: string
    message?: string
    variant?: 'compact' | 'default'
  }>(),
  {
    icon: 'lucide:inbox',
    message: '',
    variant: 'default',
  },
)
</script>

<style scoped>
.empty {
  display: flex;
  min-height: 60vh;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  padding: 24px var(--m-page-gutter);
  text-align: center;
}

/* Deliberately grey rather than the brand tint: an empty list is a neutral
   state, not something to draw the eye. */
.empty-icon {
  display: grid;
  width: 54px;
  height: 54px;
  place-items: center;
  margin-bottom: 6px;
  border-radius: 999px;
  background: var(--m-border);
  color: var(--m-muted);
}
.empty-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
}
.empty-text {
  margin: 0;
  max-width: 280px;
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.45;
}
.empty-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 8px;
  margin-top: 12px;
}

.empty--compact {
  min-height: 0;
  padding: 28px var(--m-page-gutter);
}
.empty--compact .empty-icon {
  width: 44px;
  height: 44px;
  margin-bottom: 4px;
}
.empty--compact .empty-title {
  font-size: 14.5px;
}
.empty--compact .empty-text {
  font-size: 12.5px;
}
</style>
