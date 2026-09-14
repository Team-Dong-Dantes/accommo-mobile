<template>
  <div class="m-tabbed">
    <div class="hero">
      <img v-if="coverUrl" :src="coverUrl" alt="" class="hero-img" />
      <div class="hero-scrim" />
      <button v-if="messageTo" type="button" class="hero-msg" aria-label="Send a message" @click="emit('message')">
        <IconifyIcon icon="lucide:message-circle" width="16" />
      </button>
    </div>

    <div class="body-card">
      <div class="head">
        <span class="head-avatar">
          <img v-if="avatarUrl && !avatarFailed" :src="avatarUrl" alt="" class="head-avatar-img" @error="avatarFailed = true" />
          <template v-else>{{ initials }}</template>
        </span>
        <span class="head-name">{{ name }}</span>
        <span v-if="chip" class="head-chip" :class="`head-chip--${chipTone}`">{{ chip }}</span>
        <span v-if="subtitle" class="head-sub">{{ subtitle }}</span>
      </div>
    </div>

    <div class="tabs">
      <button
        v-for="t in tabs"
        :key="t.key"
        type="button"
        class="tab"
        :class="{ 'tab--on': modelValue === t.key }"
        @click="emit('update:modelValue', t.key)"
      >
        {{ t.label }}
      </button>
    </div>

    <div class="panel">
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'

// The tenancy screen's profile design, lifted into something the QR result and
// the conversation detail can reuse: cover, overlapping avatar card, pill tab
// strip, then whatever panels the caller passes. No payments tab — that data
// belongs to a lease, and two of the three callers have no lease in hand.

defineProps<{
  modelValue: string
  tabs: readonly { key: string; label: string }[]
  name: string
  initials: string
  avatarUrl?: string | null
  coverUrl?: string | null
  chip?: string
  chipTone?: 'good' | 'warn' | 'bad' | 'idle'
  subtitle?: string
  /** Show the message button on the cover. */
  messageTo?: boolean
}>()

const emit = defineEmits<{ 'update:modelValue': [string]; message: [] }>()

const avatarFailed = ref(false)
watch(() => avatarFailed.value, () => {})
</script>

<style scoped>
/* Deliberately the same shape as components/manager/TenantProfile.vue: hero,
   a floating profile card that overlaps it, then pill tabs fused into a
   bordered panel. Both screens show "a person" and must not look like two
   different products. Keep them in step. */
.hero {
  position: relative;
  flex: 0 0 auto;
  height: 170px;
  overflow: hidden;
  background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%);
}
.hero-img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.hero-scrim {
  position: absolute;
  inset: 0;
  background: linear-gradient(to bottom, rgba(0, 0, 0, 0.18) 0%, rgba(0, 0, 0, 0) 70%);
}
.hero-msg {
  position: absolute;
  top: 10px;
  right: var(--m-page-gutter);
  z-index: 2;
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.55);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.body-card {
  position: relative;
  margin: -85px var(--m-page-gutter) 0;
  padding: 0 var(--m-page-gutter) 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  box-shadow: var(--m-shadow);
}
.head {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding-top: 8px;
  text-align: center;
}
.head-avatar {
  display: grid;
  width: 84px;
  height: 84px;
  place-items: center;
  overflow: hidden;
  margin-top: -42px;
  margin-bottom: 4px;
  border: 4px solid var(--m-surface);
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 24px;
  font-weight: 800;
  box-shadow: 0 2px 6px rgba(15, 23, 42, 0.12);
}
.head-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.head-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
/* No background here — the tone class below supplies it. */
.head-chip {
  margin-top: 4px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.head-chip--good { background: var(--m-success-soft); color: var(--m-success); }
.head-chip--warn { background: var(--m-warning-soft); color: var(--m-warning); }
.head-chip--bad { background: var(--m-danger-soft); color: var(--m-danger); }
.head-chip--idle { background: var(--m-bg); color: var(--m-muted); }
.head-sub {
  margin-top: 4px;
  color: var(--m-muted);
  font-size: 12.5px;
}
.tabs {
  position: relative;
  z-index: 2;
  display: flex;
  gap: 4px;
  /* -2px, not -1px: an exact 1px overlap can round the wrong way on real
     (non-@1x) device pixel ratios and leave a hairline gap under the active
     tab. Same value as TenantProfile and ManagerTenantsPage. */
  margin: 14px var(--m-page-gutter) -2px;
}
.tab {
  min-height: 38px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-bottom: none;
  border-radius: 10px 10px 0 0;
  background: var(--m-bg);
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  transition: background-color 0.15s ease, color 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
.tab--on {
  background: var(--m-surface);
  color: var(--m-primary-dark);
}
.panel {
  display: flex;
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  padding: 14px var(--m-page-gutter);
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
</style>
