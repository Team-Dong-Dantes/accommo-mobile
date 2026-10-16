<template>
  <p v-if="otherTyping" class="typing-note">{{ other.name }} is typing…</p>

  <div v-if="replyTo || editing" class="compose-ctx">
    <IconifyIcon :icon="editing ? 'lucide:pencil' : 'lucide:reply'" width="16" class="compose-ctx-icon" />
    <span class="compose-ctx-body">
      <span class="compose-ctx-title">
        {{ editing ? 'Editing message' : `Replying to ${replyTo?.senderId === me ? 'yourself' : other.name}` }}
      </span>
      <span class="compose-ctx-text">{{ snippet((editing ?? replyTo)!) }}</span>
    </span>
    <button type="button" class="compose-ctx-x" aria-label="Cancel" @click="cancelCompose">
      <IconifyIcon icon="lucide:x" width="16" />
    </button>
  </div>

  <form class="composer" @submit.prevent="submit">
    <div class="composer-attach-wrap">
      <button
        type="button"
        class="composer-attach"
        :class="{ 'composer-attach--open': attachMenuOpen }"
        aria-label="Attach"
        :disabled="sending || loading || !!editing"
        @click="attachMenuOpen = !attachMenuOpen"
      >
        <IconifyIcon icon="lucide:plus" width="20" />
      </button>
      <template v-if="attachMenuOpen">
        <div class="composer-attach-backdrop" @click="attachMenuOpen = false" />
        <div class="composer-attach-menu" role="menu" aria-label="Attach">
          <button type="button" role="menuitem" @click="onTakePhotoClick">
            <IconifyIcon icon="lucide:camera" width="16" />
            Take photo
          </button>
          <button type="button" role="menuitem" @click="onUploadClick">
            <IconifyIcon icon="lucide:image-plus" width="16" />
            Upload photo
          </button>
          <button type="button" role="menuitem" @click="onFileClick">
            <IconifyIcon icon="lucide:file-text" width="16" />
            Send a PDF
          </button>
          <button type="button" role="menuitem" @click="onListingClick">
            <IconifyIcon icon="lucide:house" width="16" />
            Share a listing
          </button>
        </div>
      </template>
      <input
        ref="fileInputRef"
        type="file"
        accept="image/*"
        class="composer-attach-input-hidden"
        :disabled="sending || loading"
        @change="onAttach"
      />
      <input
        ref="pdfInputRef"
        type="file"
        accept="application/pdf"
        class="composer-attach-input-hidden"
        :disabled="sending || loading"
        @change="onAttach"
      />
    </div>
    <textarea
      ref="inputRef"
      v-model="outgoing"
      class="composer-input"
      rows="1"
      placeholder="Message…"
      :disabled="sending || loading"
      @keydown.enter.exact.prevent="submit"
      @keydown.esc="cancelCompose"
      @input="notifyTyping"
    />
    <button
      type="submit"
      class="composer-send"
      :disabled="!outgoing.trim() || sending || loading"
      :aria-label="editing ? 'Save edit' : 'Send'"
    >
      <IconifyIcon :icon="editing ? 'lucide:check' : 'lucide:send-horizontal'" width="18" />
    </button>
  </form>
</template>

<script setup lang="ts">
// The foot of the thread: who is typing, the reply/edit bar, attachments and
// the message box.
import { Icon as IconifyIcon } from '@iconify/vue'
import { snippet } from '@/utils/chat'
import { useChatThread } from './chatThread'

const {
  loading,
  sending,
  outgoing,
  attachMenuOpen,
  fileInputRef,
  pdfInputRef,
  inputRef,
  me,
  other,
  replyTo,
  editing,
  otherTyping,
  onAttach,
  onTakePhotoClick,
  onUploadClick,
  onFileClick,
  onListingClick,
  cancelCompose,
  submit,
  notifyTyping,
} = useChatThread()
</script>

<style scoped>
.typing-note {
  margin: 0;
  padding: 2px var(--m-page-gutter) 0;
  color: var(--m-muted);
  font-size: 12px;
  font-style: italic;
}
/* What the composer is doing besides a new message: replying, or editing. */
.compose-ctx {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 10px;
  padding: 8px var(--m-page-gutter);
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.compose-ctx-icon {
  flex: 0 0 auto;
  color: var(--m-primary);
}
.compose-ctx-body {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  flex-direction: column;
}
.compose-ctx-title {
  color: var(--m-ink);
  font-size: 12px;
  font-weight: 700;
}
/* The same faded ghost bubble the sent reply shows above itself. */
.compose-ctx-text {
  max-width: 100%;
  align-self: flex-start;
  margin-top: 4px;
  padding: 5px 12px;
  overflow: hidden;
  border-radius: 14px;
  background: color-mix(in srgb, var(--m-border) 70%, transparent);
  color: var(--m-muted);
  font-size: 12.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.compose-ctx-x {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
}
.composer {
  display: flex;
  flex: 0 0 auto;
  align-items: flex-end;
  gap: 8px;
  padding: 8px var(--m-page-gutter) calc(8px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.composer-attach-wrap {
  position: relative;
  flex: 0 0 auto;
}
.composer-attach {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.composer-attach svg {
  transition: transform 200ms cubic-bezier(0.34, 1.56, 0.64, 1);
}
.composer-attach--open svg {
  transform: rotate(45deg);
}
.composer-attach-input-hidden {
  display: none;
}
.composer-attach-backdrop {
  position: fixed;
  inset: 0;
  z-index: 5;
}
.composer-attach-menu {
  position: absolute;
  bottom: calc(100% + 8px);
  left: 0;
  z-index: 6;
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 6px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  box-shadow: 0 4px 12px rgba(15, 23, 42, 0.12);
  animation: composer-attach-menu-in 160ms ease-out both;
}
.composer-attach-menu button {
  display: flex;
  min-height: 40px;
  align-items: center;
  gap: 8px;
  padding: 0 10px;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: transparent;
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  white-space: nowrap;
  text-align: left;
}
.composer-attach-menu button:hover {
  background: var(--m-primary-soft);
}
.composer-input {
  flex: 1 1 auto;
  max-height: 110px;
  min-height: 44px;
  padding: 12px 14px;
  border: 1px solid var(--m-border);
  border-radius: 22px;
  background: var(--m-bg);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  line-height: 1.35;
  resize: none;
}
.composer-input:focus {
  border-color: var(--m-primary);
  outline: none;
}
.composer-send {
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.composer-send:disabled {
  opacity: 0.45;
}
@keyframes composer-attach-menu-in {
  from {
    opacity: 0;
    transform: translateY(6px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>
