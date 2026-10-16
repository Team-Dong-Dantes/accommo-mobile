<template>
  <!-- Desktop (`split`): the two halves of a card — the person and the default
       slot on the left, the `right` slot on the right. Otherwise both slots go
       in the one tabbed panel and the caller shows whichever tab is picked; with a
       single tab the right slot stacks under the default one.
       .col-left is display: contents off the desktop, so nothing moves there. -->
  <div :class="split ? 'desk-card' : 'm-tabbed'">
    <div :class="split ? 'desk-col' : 'col-left'">
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
        <span v-if="chip || role" class="head-chips">
          <span v-if="role" class="head-chip head-chip--idle">
            <IconifyIcon :icon="role.icon" width="12" />{{ role.label }}
          </span>
          <span v-if="chip" class="head-chip" :class="`head-chip--${chipTone}`">
            <IconifyIcon v-if="CHIP_ICON[chipTone ?? 'idle']" :icon="CHIP_ICON[chipTone ?? 'idle']!" width="12" />{{ chip }}
          </span>
        </span>
        <span v-if="subtitle" class="head-sub">{{ subtitle }}</span>
      </div>
    </div>

    <div v-if="!split && tabs.length > 1" class="tabs">
      <button
        v-for="t in tabs"
        :key="t.key"
        type="button"
        class="m-tab"
        :class="{ 'm-tab--on': modelValue === t.key }"
        @click="emit('update:modelValue', t.key)"
      >
        {{ t.label }}
      </button>
    </div>

    <div class="panel" :class="{ 'panel--solo': !split && tabs.length < 2 }">
      <q-tab-panels
        v-if="!split"
        :model-value="modelValue"
        animated
        swipeable
        keep-alive
        class="m-panels"
        @update:model-value="emit('update:modelValue', String($event))"
      >
        <q-tab-panel :name="tabs[0]!.key"><slot /><slot v-if="!tabs[1]" name="right" /></q-tab-panel>
        <q-tab-panel v-if="tabs[1]" :name="tabs[1].key"><slot name="right" /></q-tab-panel>
      </q-tab-panels>
      <slot v-else />
    </div>
    </div>

    <div v-if="split && $slots.right" class="desk-col">
      <slot name="right" />
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
  /** Student or landlord/landlady, as a neutral capsule beside the chip. */
  role?: { label: string; icon: string }
  /** Show the message button on the cover. */
  messageTo?: boolean
  /** Desktop: lay the two slots out as the halves of a card instead of tabs. */
  split?: boolean
}>()

const emit = defineEmits<{ 'update:modelValue': [string]; message: [] }>()

// Verified and not-verified chips carry a shield; a plain role label does not.
const CHIP_ICON: Record<string, string | undefined> = {
  good: 'lucide:shield-check',
  warn: 'lucide:shield-alert',
  bad: 'lucide:shield-x',
}

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
  /* The hero sits in a column flex container, so height is the main axis and
     flex-shrink defaults to 1 — a tight column squashed this 84px circle into
     an oval. Every other avatar in the app already pins itself this way. */
  flex: none;
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
.head-chips {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 6px;
  margin-top: 4px;
}
.head-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.head-chip--good { background: var(--m-success-soft); color: var(--m-success); }
.head-chip--warn { background: var(--m-warning-soft); color: var(--m-warning); }
.head-chip--bad { background: var(--m-danger-soft); color: var(--m-danger); }
.head-chip--idle { background: var(--m-bg); color: var(--m-text); }
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
/* No tab strip to sit under, so the panel keeps the same distance from the card. */
.panel--solo { margin-top: 14px; }
/* ---- Desktop: halves of a card (.desk-card / .desk-col, app.scss) ---- */
.col-left {
  display: contents;
}
.desk-card .hero {
  margin: -14px -18px 0;
}
.desk-card .desk-col:first-child {
  gap: 0;
}
/* The overview is content in its half, not a second card. */
.desk-card .panel {
  flex: none;
  margin-top: 14px;
  padding: 0;
  border: 0;
  border-radius: 0;
  background: transparent;
}
</style>
