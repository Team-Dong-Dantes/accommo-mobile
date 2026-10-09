<template>
  <q-dialog
    :model-value="modelValue"
    :position="isWide ? 'standard' : 'bottom'"
    :persistent="persistent"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <div
      class="app-modal"
      :class="[`app-modal--${size}`, { 'app-modal--float': isWide, 'app-modal--tall': tall }]"
    >
      <span v-if="!isWide" class="app-modal-grip" aria-hidden="true" />

      <div v-if="hasHead" class="app-modal-head">
        <div class="app-modal-heading">
          <slot name="header">
            <span v-if="icon" class="app-modal-icon" :class="`app-modal-icon--${tone}`">
              <IconifyIcon :icon="icon" width="18" />
            </span>
            <h2 v-if="title" class="app-modal-title">{{ title }}</h2>
          </slot>
        </div>
        <slot name="actions" />
        <button v-if="closable" type="button" class="app-modal-close" aria-label="Close" @click="emit('update:modelValue', false)">
          <IconifyIcon icon="lucide:x" width="20" />
        </button>
      </div>

      <div class="app-modal-body">
        <slot />
      </div>

      <div v-if="$slots.footer" class="app-modal-foot">
        <slot name="footer" />
      </div>
    </div>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, useSlots } from 'vue'
import { isWide } from '@/utils/useTabletMode'

// Every modal in the app, so they all look alike: a bottom sheet with a grip on
// a phone, a centred card with a close button on anything wider (isWide). The
// header (icon chip + title), the scrolling body and the pinned footer are
// drawn here; callers only supply what goes inside them.
//
// This replaced ~40 hand-rolled q-dialog cards, each with its own copy of the
// sheet's width, radius, padding and grip, and a global !important override in
// app.scss that floated them on the desktop shell only.
//
// Attributes fall through to the q-dialog (@hide, @show).
const props = withDefaults(
  defineProps<{
    modelValue: boolean
    title?: string | undefined
    /** lucide icon in a round chip before the title. */
    icon?: string
    tone?: 'primary' | 'danger'
    /** Floating width: sm 420, md 560, lg 720. Phones are always full width. */
    size?: 'sm' | 'md' | 'lg'
    /**
     * One fixed height, for multi-step sheets that must not resize between
     * steps. The body scrolls and the footer stays put.
     */
    tall?: boolean
    /** No backdrop dismiss and no close button: the content decides. */
    persistent?: boolean
  }>(),
  { title: '', icon: '', tone: 'primary', size: 'md', tall: false, persistent: false },
)

const emit = defineEmits<{ 'update:modelValue': [open: boolean] }>()
const slots = useSlots()

const closable = computed(() => isWide.value && !props.persistent)
const hasHead = computed(() => !!(props.title || props.icon || slots.header || slots.actions) || closable.value)
</script>

<style scoped>
/* Phone: the sheet. */
.app-modal {
  display: flex;
  width: 100%;
  max-width: 480px;
  max-height: 85vh;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 10px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  overflow: hidden;
  border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0;
  background: var(--m-surface);
  color: var(--m-text);
}
.app-modal--tall {
  height: min(660px, 85vh);
}

/* Wider screens: the floating card. */
.app-modal--float {
  max-height: calc(100vh - 64px);
  padding: 18px 24px 22px;
  border-radius: var(--m-radius-lg);
  box-shadow: 0 18px 48px rgba(15, 23, 42, 0.22);
}
.app-modal--float.app-modal--sm {
  width: 420px;
  max-width: 100%;
}
.app-modal--float.app-modal--md {
  width: 560px;
  max-width: 100%;
}
.app-modal--float.app-modal--lg {
  width: 720px;
  max-width: 100%;
}
.app-modal--float.app-modal--tall {
  height: min(660px, calc(100vh - 64px));
}

.app-modal-grip {
  display: block;
  width: 40px;
  height: 4px;
  flex: 0 0 auto;
  margin: 0 auto 2px;
  border-radius: 999px;
  background: var(--m-border);
}

.app-modal-head {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 10px;
}
.app-modal-heading {
  display: flex;
  min-width: 0;
  flex: 1;
  align-items: center;
  gap: 10px;
}
.app-modal-icon {
  display: grid;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  place-items: center;
  border-radius: 999px;
}
.app-modal-icon--primary {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.app-modal-icon--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.app-modal-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
  line-height: 1.3;
}
.app-modal-close {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 auto;
  place-items: center;
  margin: -6px -10px -6px 0;
  border: 0;
  border-radius: 999px;
  background: none;
  color: var(--m-muted);
  cursor: pointer;
}
.app-modal-close:hover {
  background: var(--m-bg);
  color: var(--m-ink);
}

.app-modal-body {
  display: flex;
  min-height: 0;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 12px;
  overflow-y: auto;
}

.app-modal-foot {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
}
/* Only where the body scrolls under a fixed height does the footer need a
   rule to show where the scroll ends. */
.app-modal--tall > .app-modal-foot {
  padding-top: 12px;
  border-top: 1px solid var(--m-border);
}
</style>
