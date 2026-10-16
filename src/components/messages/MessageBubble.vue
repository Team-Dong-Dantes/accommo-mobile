<template>
  <div
    :id="`msg-${msg.id}`"
    class="msg"
    :class="{ 'msg--mine': msg.mine, 'msg--pending': msg.pending, 'msg--lifted': lifted }"
  >
    <!-- The message being answered, as a faded bubble tucked behind this one
         (Messenger-style). Tapping it scrolls to the original. -->
    <button v-if="reply" type="button" class="msg-quote" @click="msg.replyToId && emit('jump', msg.replyToId)">
      <span class="msg-quote-cap">
        <IconifyIcon icon="lucide:reply" width="12" />
        {{ reply.caption }}
      </span>
      <span class="msg-quote-text">{{ reply.text }}</span>
    </button>

    <span v-if="msg.deletedAt" class="msg-bubble msg-bubble--removed">
      <IconifyIcon icon="lucide:ban" width="13" />
      Message removed
    </span>

    <span v-else class="msg-row">
      <!-- Holds the bubble and its reactions, so the chips can sit on the
           bubble's own bottom-end corner rather than under the whole column. -->
      <span class="msg-bubble-wrap" :class="{ 'msg-bubble-wrap--reacted': chips.length }">
      <span
        ref="bubbleRef"
        class="msg-bubble"
        :class="{ 'msg-bubble--media': isPhoto, 'msg-bubble--card': msg.accommodationId }"
        v-on="msg.pending ? {} : press.on(msg.id)"
      >
        <button
          v-if="msg.accommodationId"
          type="button"
          class="msg-card"
          :disabled="!listing"
          @click="tap(() => emit('listing', msg.accommodationId!))"
        >
          <img v-if="listing?.cover" :src="listing.cover" alt="" class="msg-card-img" />
          <span v-else class="msg-card-img msg-card-img--none"><IconifyIcon icon="lucide:house" width="22" /></span>
          <span class="msg-card-body">
            <span class="msg-card-name">{{ listing === null ? 'Listing no longer available' : listing?.name ?? 'Loading…' }}</span>
            <span v-if="listing?.place" class="msg-card-place">{{ listing.place }}</span>
          </span>
        </button>
        <button
          v-else-if="msg.file"
          type="button"
          class="msg-file"
          @click="tap(() => msg.attachmentUrl && emit('file', msg.attachmentUrl))"
        >
          <IconifyIcon icon="lucide:file-text" width="22" />
          <span class="msg-file-text">
            <span class="msg-file-name">PDF document</span>
            <span class="msg-file-hint">{{ msg.pending ? 'Uploading…' : 'Tap to open' }}</span>
          </span>
        </button>
        <button
          v-else-if="msg.attachmentUrl"
          type="button"
          class="msg-img-btn"
          aria-label="View photo"
          @click="tap(() => emit('photo', msg.attachmentUrl!))"
        >
          <img :src="msg.attachmentUrl" alt="Photo" class="msg-img" />
        </button>
        <template v-if="msg.body"><template v-for="(s, i) in segments" :key="i"><a v-if="s.href" :href="s.href" class="msg-link" @click="onLink($event, s)">{{ s.text }}</a><template v-else>{{ s.text }}</template></template></template>
      </span>
      <span v-if="chips.length" class="msg-reacts">
        <button
          v-for="c in chips"
          :key="c.emoji"
          type="button"
          class="msg-react"
          :class="{ 'msg-react--mine': c.mine }"
          :aria-label="c.mine ? `Remove ${c.emoji}` : `React ${c.emoji}`"
          @click="emit('react', c.mine ? '' : c.emoji)"
        >
          {{ c.emoji }}<span v-if="c.count > 1" class="msg-react-n">{{ c.count }}</span>
        </button>
      </span>
      </span>
      <!-- Long-press is a touch gesture; with a mouse the same menu hangs off
           this, shown on hover only where the device can hover. -->
      <button
        v-if="!msg.pending"
        type="button"
        class="msg-more"
        aria-label="Message actions"
        @click="bubbleRef && emit('menu', bubbleRef)"
      >
        <IconifyIcon icon="lucide:ellipsis" width="16" />
      </button>
    </span>

    <!-- Only on the last message of a same-sender, same-minute run — see
         `showMeta` in ChatThread's grouped computed. A still-sending bubble
         always shows its own clock so the pending state stays visible, and an
         edited one always says so. -->
    <span v-if="msg.showMeta || msg.pending || (msg.editedAt && !msg.deletedAt)" class="msg-meta">
      <template v-if="msg.editedAt && !msg.deletedAt">Edited ·</template>
      {{ msg.time }}
      <IconifyIcon
        v-if="msg.mine"
        :icon="msg.pending ? 'lucide:clock' : msg.read || msg.delivered ? 'lucide:check-check' : 'lucide:check'"
        width="13"
        :class="{ 'tick-read': msg.read }"
      />
    </span>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { linkify, longPress, reactionChips, type ChatMsg, type ListingCard, type Segment } from '@/utils/chat'
import { openExternal } from '@/utils/openExternal'

export type BubbleMsg = ChatMsg & { mine: boolean; read: boolean; delivered: boolean; time: string; showMeta: boolean }

const props = defineProps<{
  msg: BubbleMsg
  me: string
  reply: { caption: string; text: string } | null
  /** undefined while loading, null when RLS no longer shows it. */
  listing?: ListingCard | null | undefined
  /** The menu is open on this one: drawn above the dim backdrop. */
  lifted?: boolean
}>()

const emit = defineEmits<{
  menu: [el: HTMLElement]
  photo: [url: string]
  file: [url: string]
  listing: [id: string]
  jump: [id: string]
  react: [emoji: string]
}>()

const press = longPress<string>((_, el) => emit('menu', el))
const bubbleRef = ref<HTMLElement | null>(null)

const isPhoto = computed(() => !!props.msg.attachmentUrl && !props.msg.file)
const segments = computed(() => linkify(props.msg.body))
const chips = computed(() => reactionChips(props.msg.reactions, props.me))

/** A tap, unless it is the release that ended a long press. */
function tap(fn: () => void) {
  if (!press.swallow()) fn()
}

function onLink(e: MouseEvent, s: Segment) {
  if (press.swallow()) {
    e.preventDefault()
    return
  }
  // tel: is left to the WebView, which hands it to the dialer.
  if (s.external && s.href) {
    e.preventDefault()
    openExternal(s.href)
  }
}
</script>

<style scoped>
.msg {
  display: flex;
  max-width: 82%;
  flex-direction: column;
  align-items: flex-start;
  align-self: flex-start;
  gap: 2px;
}
.msg--mine {
  align-items: flex-end;
  align-self: flex-end;
}
.msg--pending {
  opacity: 0.65;
}
/* Above MessageMenu's dim backdrop (20), below its panels (22). */
.msg--lifted {
  position: relative;
  z-index: 21;
}
/* Bubble plus its ⋯ button; mine mirror so the button stays on the inside. */
.msg-row {
  display: flex;
  max-width: 100%;
  align-items: center;
  gap: 4px;
}
.msg--mine .msg-row {
  flex-direction: row-reverse;
}
.msg-more {
  display: none;
  width: 28px;
  height: 28px;
  flex: 0 0 28px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
}
.msg-more:hover {
  background: var(--m-border);
}
@media (hover: hover) and (pointer: fine) {
  .msg-more {
    display: grid;
    opacity: 0;
  }
  .msg:hover .msg-more,
  .msg--lifted .msg-more,
  .msg-more:focus-visible {
    opacity: 1;
  }
}
.msg-bubble {
  min-width: 0;
  padding: 8px 12px;
  border: 1px solid var(--m-border);
  border-radius: 16px 16px 16px 4px;
  background: var(--m-surface);
  color: var(--m-ink);
  font-size: 13.5px;
  line-height: 1.4;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  /* The long-press is the menu; the OS's own text-selection callout would fight it. */
  -webkit-touch-callout: none;
  user-select: none;
}
/* A photo is its own bubble — no frame, no padding, no fill behind it. The
   `.msg--mine` selector has to be repeated here or its border-colour and
   primary background win on specificity and put a coloured edge back. */
.msg-bubble--media,
.msg--mine .msg-bubble--media {
  padding: 0;
  border: 0;
  background: none;
  overflow: hidden;
}
.msg-img-btn {
  display: block;
  padding: 0;
  border: 0;
  background: none;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
/* Keeps the bubble silhouette now that the wrapper no longer draws it. */
.msg-img {
  display: block;
  max-width: 100%;
  max-height: 260px;
  border-radius: 16px 16px 16px 4px;
  object-fit: cover;
}
.msg--mine .msg-img {
  border-radius: 16px 16px 4px 16px;
}
.msg--mine .msg-bubble {
  border-color: transparent;
  border-radius: 16px 16px 4px 16px;
  background: var(--m-primary);
  color: #fff;
}
.msg-bubble--removed,
.msg--mine .msg-bubble--removed {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  border: 1px dashed var(--m-border);
  background: transparent;
  color: var(--m-muted);
  font-style: italic;
}
.msg-link {
  color: inherit;
  text-decoration: underline;
}

/* A listing keeps a light card on both sides, so its photo and text read the same. */
.msg-bubble--card,
.msg--mine .msg-bubble--card {
  padding: 0;
  overflow: hidden;
  border-color: var(--m-border);
  background: var(--m-surface);
  color: var(--m-ink);
}
.msg-card {
  display: flex;
  width: 240px;
  max-width: 100%;
  flex-direction: column;
  padding: 0;
  border: 0;
  background: none;
  color: inherit;
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.msg-card-img {
  display: block;
  width: 100%;
  height: 120px;
  object-fit: cover;
}
.msg-card-img--none {
  display: grid;
  place-items: center;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.msg-card-body {
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding: 8px 12px 10px;
}
.msg-card-name {
  font-weight: 700;
}
.msg-card-place {
  color: var(--m-muted);
  font-size: 12px;
}

.msg-file {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 2px 0;
  border: 0;
  background: none;
  color: inherit;
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.msg-file-text {
  display: flex;
  flex-direction: column;
}
.msg-file-name {
  font-weight: 700;
}
.msg-file-hint {
  font-size: 11.5px;
  opacity: 0.8;
}

.msg-quote {
  display: flex;
  max-width: 100%;
  flex-direction: column;
  align-items: inherit;
  gap: 3px;
  /* The reply's own bubble overlaps the ghost's bottom edge. */
  margin-bottom: -12px;
  padding: 0;
  border: 0;
  background: none;
  color: var(--m-muted);
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.msg-quote-cap {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 0 4px;
  font-size: 11px;
  font-weight: 600;
}
.msg-quote-text {
  display: -webkit-box;
  max-width: 100%;
  overflow: hidden;
  /* The room the reply overlaps is a transparent border, not padding: the
     clamp clips at the padding edge, so a third line can't peek into it. */
  padding: 7px 12px 0;
  border-bottom: 19px solid transparent;
  border-radius: 16px;
  background: color-mix(in srgb, var(--m-border) 70%, transparent);
  color: var(--m-muted);
  font-size: 12.5px;
  line-height: 1.35;
  overflow-wrap: anywhere;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
/* Mine sit right, so the ghost's inset goes left (and the other way round). */
.msg .msg-quote-text {
  margin-left: 10px;
}
.msg--mine .msg-quote-text {
  margin-right: 10px;
  margin-left: 0;
}
/* Drawn over the ghost it overlaps. */
.msg-quote ~ .msg-row,
.msg-quote ~ .msg-bubble--removed {
  position: relative;
  z-index: 1;
}

.msg-bubble-wrap {
  position: relative;
  display: flex;
  min-width: 0;
  flex-direction: column;
}
/* Room under the bubble for the chips hanging off its corner. */
.msg-bubble-wrap--reacted {
  margin-bottom: 14px;
}
/* Overlapping the bubble's bottom corner on the side facing the middle of the
   screen: right for theirs, left for mine. Pinned by the edge facing into the
   bubble, 22px in, so it straddles that corner even when the chip is wider
   than a one-word bubble (a plain right/left inset slid it to the far side). */
.msg-reacts {
  position: absolute;
  left: calc(100% - 22px);
  bottom: -16px;
  z-index: 1;
  display: flex;
  gap: 3px;
}
.msg--mine .msg-reacts {
  right: calc(100% - 22px);
  left: auto;
}
.msg-react {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  height: 22px;
  padding: 0 6px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  font-size: 13px;
  cursor: pointer;
}
.msg-react--mine {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
}
.msg-react-n {
  color: var(--m-text);
  font-size: 11px;
  font-weight: 700;
}

.msg-meta {
  display: flex;
  align-items: center;
  gap: 3px;
  padding: 0 3px;
  color: var(--m-muted);
  font-size: 10.5px;
  font-weight: 600;
}
.tick-read {
  color: var(--m-info);
}
</style>
