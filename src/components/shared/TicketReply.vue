<template>
  <form class="reply" @submit.prevent="emit('send')">
    <p v-if="resolved" class="reply-note">
      This ticket is resolved. Replying will reopen it.
    </p>
    <textarea
      v-model="draft"
      class="reply-input"
      rows="2"
      placeholder="Reply to OSAS…"
      :disabled="sending"
    />
    <div class="reply-actions">
      <button type="submit" class="reply-send" :disabled="!draft.trim() || sending">
        <IconifyIcon icon="lucide:send-horizontal" width="15" />
        {{ sending ? 'Sending…' : 'Send' }}
      </button>
    </div>
  </form>
</template>

<script setup lang="ts">
// A ticket thread's reply box, docked to the bottom of the screen so it's
// reachable without scrolling the thread to its end. TicketThread owns the
// draft and the send.
import { Icon as IconifyIcon } from '@iconify/vue'

defineProps<{ resolved: boolean; sending: boolean }>()
const draft = defineModel<string>('draft', { required: true })
const emit = defineEmits<{ send: [] }>()
</script>

<style scoped>
.reply-note {
  margin: 0 0 8px;
  color: var(--m-muted);
  font-size: 12.5px;
}
.reply {
  flex: 0 0 auto;
  padding: 10px var(--m-page-gutter) calc(10px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.reply-input {
  display: block;
  width: 100%;
  max-height: 40vh;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  line-height: 1.45;
  resize: vertical;
}
.reply-input:focus {
  border-color: var(--m-primary);
  outline: none;
}
.reply-actions {
  display: flex;
  justify-content: flex-end;
  padding-top: 8px;
}
.reply-send {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.reply-send:disabled {
  opacity: 0.45;
}
</style>
