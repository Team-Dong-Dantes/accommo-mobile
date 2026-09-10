<template>
  <div class="tabbed">
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
.tabbed { display: flex; flex-direction: column; }

.hero {
  position: relative;
  height: 170px;
  background: linear-gradient(135deg, var(--m-primary-soft), var(--m-info-soft));
}
.hero-img { width: 100%; height: 100%; object-fit: cover; }
.hero-scrim {
  position: absolute;
  inset: 0;
  background: linear-gradient(180deg, transparent 40%, rgb(0 0 0 / 22%));
}
.hero-msg {
  position: absolute;
  right: 12px;
  bottom: 12px;
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary);
  box-shadow: 0 4px 14px rgb(0 0 0 / 18%);
  cursor: pointer;
}

.body-card {
  position: relative;
  margin-top: -18px;
  padding: 0 14px 10px;
  border-radius: 18px 18px 0 0;
  background: var(--m-bg);
}
.head { display: flex; flex-direction: column; align-items: center; gap: 4px; }
.head-avatar {
  display: grid;
  overflow: hidden;
  width: 84px;
  height: 84px;
  margin-top: -42px;
  place-items: center;
  border: 3px solid var(--m-bg);
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary);
  font-size: 26px;
  font-weight: 700;
}
.head-avatar-img { width: 100%; height: 100%; object-fit: cover; }
.head-name { color: var(--m-ink); font-size: 17px; font-weight: 750; }
.head-chip {
  padding: 3px 10px;
  border-radius: 999px;
  background: var(--m-bg);
  font-size: 11px;
  font-weight: 700;
}
.head-chip--good { background: var(--m-success-soft); color: var(--m-success); }
.head-chip--warn { background: var(--m-warning-soft); color: var(--m-warning); }
.head-chip--bad { background: var(--m-danger-soft); color: var(--m-danger); }
.head-chip--idle { background: var(--m-bg); color: var(--m-muted); }
.head-sub { color: var(--m-muted); font-size: 12px; font-weight: 600; text-align: center; }

.tabs {
  display: flex;
  gap: 6px;
  padding: 8px 12px 0;
  background: var(--m-bg);
}
.tab {
  flex: 1 1 0;
  padding: 9px 6px;
  border: 1px solid var(--m-border);
  border-bottom: 0;
  border-radius: 12px 12px 0 0;
  background: var(--m-bg);
  color: var(--m-muted);
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  cursor: pointer;
}
.tab--on {
  border-color: var(--m-border);
  background: var(--m-surface);
  color: var(--m-ink);
}
.panel {
  padding: 14px 12px 24px;
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
</style>
