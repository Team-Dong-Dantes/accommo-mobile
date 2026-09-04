<template>
  <section
    class="empty-state"
    :class="[variant, { 'is-animated': animated }]"
    :aria-live="live"
    :role="role"
  >
    <div class="empty-state__inner">
      <!-- Icon with circular background -->
      <div v-if="icon" class="empty-state__icon-wrapper" aria-hidden="true">
        <IconifyIcon :icon="icon" :width="iconSize" />
      </div>

      <!-- Semantic title -->
      <h3 class="empty-state__title">
        {{ title }}
      </h3>

      <!-- Secondary description -->
      <p v-if="message" class="empty-state__message">
        {{ message }}
      </p>

      <!-- Dedicated slot for buttons/CTAs -->
      <div v-if="$slots.actions" class="empty-state__actions">
        <slot name="actions" />
      </div>

      <!-- Custom slot for search bars, filters, etc. -->
      <slot />
    </div>
  </section>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'
import { computed } from 'vue'

const props = withDefaults(defineProps<{
  icon?: string
  title: string
  message?: string
  variant?: 'compact' | 'default' | 'expanded'
  animated?: boolean
  live?: 'off' | 'polite' | 'assertive'
  role?: string
}>(), {
  icon: 'lucide:inbox',
  message: '',
  variant: 'default',
  animated: true,
  live: 'polite',
  role: 'status',
})

const iconSize = computed(() => {
  switch (props.variant) {
    case 'compact': return 20
    case 'expanded': return 48
    default: return 32
  }
})
</script>

<style scoped>
/* --- Base Layout --- */
.empty-state {
  display: grid;
  place-items: center;
  width: 100%;
}

.empty-state__inner {
  display: grid;
  justify-items: center;
  align-content: center;
  gap: var(--m-space-3, 12px);
  width: 100%;
  max-width: 480px;
  padding: var(--m-space-8, 48px);
  text-align: center;
  border-radius: var(--m-radius-xl, 12px);
  background: var(--m-surface, #ffffff);
  border: 1.5px dashed var(--m-border, #d1d5db);
  transition: background 0.2s ease;
}

/* --- Icon --- */
.empty-state__icon-wrapper {
  display: grid;
  place-items: center;
  border-radius: 9999px;
  background: var(--m-surface-subtle, #f3f4f6);
  padding: var(--m-space-3, 12px);
  color: var(--m-muted, #6b7280);
  margin-bottom: var(--m-space-1, 4px);
}

/* --- Typography --- */
.empty-state__title {
  margin: 0;
  color: var(--m-ink, #111827);
  font-family: var(--m-font-display, inherit);
  font-size: 18px;
  font-weight: 700;
  line-height: 1.3;
  letter-spacing: -0.01em;
}

.empty-state__message {
  margin: 0;
  max-width: 34ch;
  color: var(--m-muted, #6b7280);
  font-size: 14px;
  line-height: 1.6;
}

/* --- Actions (CTAs) --- */
.empty-state__actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: var(--m-space-2, 8px);
  margin-top: var(--m-space-2, 8px);
  width: 100%;
}

/* --- Variants --- */
/* Compact (for tables or inline drawers) */
.empty-state--compact .empty-state__inner {
  padding: var(--m-space-4, 16px);
  border: 0;
  background: transparent;
  gap: var(--m-space-2, 8px);
}
.empty-state--compact .empty-state__title {
  font-size: 15px;
}
.empty-state--compact .empty-state__message {
  font-size: 13px;
}
.empty-state--compact .empty-state__icon-wrapper {
  padding: var(--m-space-2, 8px);
}

/* Expanded (for full-page welcome / onboarding) */
.empty-state--expanded .empty-state__inner {
  padding: var(--m-space-12, 64px);
  max-width: 560px;
  border: 2px dashed var(--m-border, #d1d5db);
}
.empty-state--expanded .empty-state__title {
  font-size: 24px;
}
.empty-state--expanded .empty-state__message {
  font-size: 16px;
  max-width: 40ch;
}
.empty-state--expanded .empty-state__icon-wrapper {
  padding: var(--m-space-4, 16px);
}

/* --- Animation --- */
@keyframes empty-state-fade-up {
  0% {
    opacity: 0;
    transform: translateY(12px);
  }
  100% {
    opacity: 1;
    transform: translateY(0);
  }
}

.empty-state.is-animated .empty-state__inner {
  animation: empty-state-fade-up 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
}

/* --- Dark mode readiness (uses CSS vars) --- */
@media (prefers-color-scheme: dark) {
  .empty-state__icon-wrapper {
    background: var(--m-surface-subtle, #1f2937);
  }
  .empty-state__inner {
    background: var(--m-surface, #1f2937);
    border-color: var(--m-border, #374151);
  }
}
</style>