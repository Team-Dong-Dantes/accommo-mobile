<template>
  <!-- Same shell as components/shared/TicketCompose.vue: a full-screen overlay
       opened from a button, not a form parked on the page. Composing a house
       notice is an occasional, deliberate act — the page behind this is a list
       of what you have already sent.

       Three groups, in the order the work actually happens: what you are
       saying, the facts behind it, and when it goes out. Only the first is
       open to begin with — six optional fields sitting at the same weight as
       the title was the whole problem with the old single wall of inputs. -->
  <div class="compose">
    <header class="bar">
      <button type="button" class="bar-icon" aria-label="Discard" @click="tryClose">
        <IconifyIcon icon="lucide:x" width="20" />
      </button>
      <span class="bar-title">New announcement</span>
    </header>

    <div class="body-scroll">
      <ComposeWrite />

      <ComposeDetails />

      <p v-for="problem in problems" :key="problem" class="problem">
        <IconifyIcon icon="lucide:alert-circle" width="14" />
        {{ problem }}
      </p>

      <ComposePreview />
    </div>

    <!-- The send button sits at the end of the form, where the writing ends,
         rather than in the top bar: it is the last thing you do, and on a phone
         it is also the only corner a thumb reaches without a stretch. -->
    <footer class="foot">
      <span class="foot-note">{{ footNote }}</span>
      <button type="button" class="foot-send" :disabled="!canSend" @click="submit">
        <IconifyIcon :icon="form.publishAt ? 'lucide:clock' : 'lucide:send'" width="16" />
        {{ submitting ? 'Sending…' : form.publishAt ? 'Schedule' : 'Send' }}
      </button>
    </footer>

    <!-- Typing a notice and losing it to a stray tap on X is the one mistake
         this screen can make for you. -->
    <AppModal v-model="confirmDiscard" title="Discard this announcement?" size="sm">
      <p class="ask-text">What you have written will not be kept.</p>
      <template #footer>
        <button type="button" class="ghost-btn" @click="confirmDiscard = false">Keep writing</button>
        <button type="button" class="danger-btn" @click="emit('close')">Discard</button>
      </template>
    </AppModal>
  </div>
</template>

<script setup lang="ts">
import { type AnnouncementDraft } from '@/components/manager/compose/model'
import AppModal from '@/components/shared/AppModal.vue'
import ComposeDetails from './compose/ComposeDetails.vue'
import ComposePreview from './compose/ComposePreview.vue'
import ComposeWrite from './compose/ComposeWrite.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { provideAnnouncementCompose } from './compose/announcementCompose'

// The compose overlay's state lives in ./compose/; this is its frame: the bar,
// the sections, the send footer and the discard check.
const props = defineProps<{
  /** The landlord/landlady's houses; the first is the default target. */
  accommodations: { id: string; name: string }[]
  /** Parent owns the insert, so it owns the in-flight flag too. */
  submitting?: boolean
}>()

const emit = defineEmits<{ close: []; submit: [AnnouncementDraft] }>()

const {
  form,
  confirmDiscard,
  problems,
  footNote,
  canSend,
  tryClose,
  submit,
} = provideAnnouncementCompose({ props, emit })
</script>

<style scoped>
.compose {
  position: fixed;
  inset: 0;
  z-index: 3000;
  display: flex;
  flex-direction: column;
  background: var(--m-bg);
}
.bar {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 10px;
  padding: calc(8px + env(safe-area-inset-top)) var(--m-page-gutter) 8px;
  border-bottom: 1px solid var(--m-border);
  background: var(--m-surface);
}
.bar-icon {
  display: grid;
  width: 40px;
  height: 40px;
  flex: 0 0 40px;
  place-items: center;
  margin-left: -8px;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-ink);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.bar-title {
  flex: 1 1 auto;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
}
.foot {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 10px;
  padding: 10px var(--m-page-gutter) calc(10px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.foot-note {
  flex: 1 1 auto;
  overflow: hidden;
  color: var(--m-muted);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.foot-send {
  display: inline-flex;
  min-height: 44px;
  flex: 0 0 auto;
  align-items: center;
  gap: 7px;
  padding: 0 20px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.foot-send:disabled {
  opacity: 0.5;
}
.body-scroll {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 10px;
  padding: 12px var(--m-page-gutter) calc(24px + env(safe-area-inset-bottom));
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
}
.card {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.ghost-btn,
.danger-btn {
  display: inline-flex;
  min-height: 36px;
  align-items: center;
  gap: 6px;
  padding: 0 14px;
  border-radius: 999px;
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.ghost-btn {
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}
.ghost-btn:disabled {
  opacity: 0.6;
}
.danger-btn {
  border: 0;
  background: var(--m-danger);
  color: #fff;
}
.problem {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: 0;
  color: var(--m-danger);
  font-size: 12px;
}
.preview {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 12px;
  border: 1px dashed var(--m-border);
  border-radius: var(--m-radius);
  background: transparent;
}
.ask-text {
  margin: 0;
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.45;
}
</style>
