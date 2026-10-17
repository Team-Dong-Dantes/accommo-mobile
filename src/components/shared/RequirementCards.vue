<template>
  <!-- One requirement or permit set: a one-line progress summary over a
       two-column grid of short cards. Shared by the student and
       landlord/landlady OSAS pages. Sized so a set of four, with what sits
       under it, fits a phone screen; every file is visible at once, nothing
       hides behind an accordion, and each thumbnail opens its file. -->
  <div class="rq">
    <div class="rq-sum">
      <p class="rq-sum-title">
        <strong>{{ done }} of {{ items.length }}</strong> {{ noun }} {{ doneWord }}
        <span v-if="rest" class="rq-sum-rest">· {{ rest }}</span>
      </p>
      <div class="rq-bar" aria-hidden="true">
        <span v-for="d in items" :key="d.type" class="rq-bar-seg" :class="`rq--${d.tone}`" />
      </div>
    </div>

    <div class="rq-grid">
      <article v-for="d in items" :key="d.type" class="rq-card">
        <button
          type="button"
          class="rq-thumb"
          :class="{ 'rq-thumb--empty': !d.fileUrl && !d.fileLoading }"
          :disabled="d.fileLoading || (!d.fileUrl && (readonly || d.verified || busy))"
          :aria-label="d.fileUrl ? `Open ${d.label}` : readonly ? `${d.label}: not submitted` : `Upload ${d.label}`"
          @click="d.fileUrl ? openFile(d.fileUrl) : emit('upload', d.type)"
        >
          <img v-if="d.fileUrl && !isPdf(d.fileUrl)" :src="resolveAsset(d.fileUrl)" alt="" />
          <IconifyIcon v-else-if="d.fileUrl" icon="lucide:file-text" width="22" />
          <q-spinner v-else-if="d.fileLoading" size="20px" />
          <IconifyIcon v-else :icon="readonly ? 'lucide:file-x' : 'lucide:plus'" width="20" />
          <!-- The status rides on the thumbnail, so it costs the card no line. -->
          <span class="rq-pill" :class="`rq-status--${d.tone}`">
            <span class="rq-dot" :class="`rq--${d.tone}`" />{{ d.statusLabel }}
          </span>
        </button>

        <div class="rq-body">
          <h3 class="rq-name">{{ d.label }}</h3>
          <p v-if="d.when" class="rq-when">{{ d.when }}</p>
        </div>

        <span v-if="d.verified" class="rq-locked">
          <IconifyIcon icon="lucide:lock" width="12" /> Verified
        </span>
        <button v-else-if="!readonly" type="button" class="rq-action" :class="{ 'rq-action--primary': !d.fileUrl && !d.fileLoading }" :disabled="busy" @click="emit('upload', d.type)">
          {{ d.fileUrl || d.fileLoading ? replaceLabel : 'Upload' }}
        </button>
      </article>
    </div>
    <p v-if="busy" class="rq-busy">Uploading…</p>

    <PhotoViewer v-model="viewerUrl" />
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { resolveAsset, isPdf } from '@/utils/cloudinaryUrl'
import { openExternal } from '@/utils/openExternal'
import PhotoViewer from './PhotoViewer.vue'

export interface RequirementItem {
  type: string
  label: string
  statusLabel: string
  /** good | warn | danger | idle */
  tone: string
  when: string
  fileUrl: string
  /** A file is on record but its signed link has not arrived yet. */
  fileLoading?: boolean
  /** OSAS has approved this one — locked from replacement. */
  verified: boolean
}

const props = withDefaults(
  defineProps<{
    items: RequirementItem[]
    noun: string
    doneWord: string
    replaceLabel?: string
    busy?: boolean
    /** Files open but nothing uploads; another screen manages them. */
    readonly?: boolean
  }>(),
  { replaceLabel: 'Replace', busy: false, readonly: false },
)
const emit = defineEmits<{ upload: [type: string] }>()

/** Photos open in the in-app viewer; a PDF can only be handed to the system. */
const viewerUrl = ref('')
function openFile(url: string) {
  if (isPdf(url)) openExternal(resolveAsset(url))
  else viewerUrl.value = resolveAsset(url)
}

const done = computed(() => props.items.filter((d) => d.tone === 'good').length)

/** "1 expiring soon · 1 not submitted" — everything that is not yet good. */
const rest = computed(() => {
  const counts = new Map<string, number>()
  for (const d of props.items) if (d.tone !== 'good') counts.set(d.statusLabel, (counts.get(d.statusLabel) ?? 0) + 1)
  return [...counts].map(([label, n]) => `${n} ${label.toLowerCase()}`).join(' · ')
})
</script>

<style scoped>
.rq {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.rq-sum {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.rq-sum-title {
  margin: 0;
  color: var(--m-text);
  font-size: 13px;
}
.rq-sum-title strong {
  color: var(--m-ink);
  font-weight: 800;
}
.rq-sum-rest {
  color: var(--m-muted);
  font-size: 12px;
}
.rq-bar {
  display: flex;
  gap: 4px;
}
.rq-bar-seg {
  flex: 1;
  height: 5px;
  border-radius: 999px;
}

/* Two columns at every width a phone has; wider screens fit more. */
.rq-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 8px;
}
.rq-card {
  display: flex;
  min-width: 0;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  overflow: hidden;
}

/* A short strip, not a 4:3 picture: enough to recognise the document, and
   tapping it opens the whole file. */
.rq-thumb {
  position: relative;
  display: grid;
  width: 100%;
  height: 60px;
  place-items: center;
  padding: 0;
  border: 0;
  border-bottom: 1px solid var(--m-border);
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  overflow: hidden;
  font: inherit;
  -webkit-tap-highlight-color: transparent;
}
.rq-thumb img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.rq-thumb--empty {
  color: var(--m-muted);
}
.rq-thumb:disabled {
  cursor: default;
}
.rq-pill {
  position: absolute;
  top: 6px;
  left: 6px;
  display: inline-flex;
  max-width: calc(100% - 12px);
  align-items: center;
  gap: 5px;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-surface);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.18);
  font-size: 10.5px;
  font-weight: 700;
  line-height: 1.4;
  white-space: nowrap;
}

.rq-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
  padding: 7px 9px 6px;
}
.rq-name {
  display: -webkit-box;
  margin: 0;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  line-height: 1.25;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  line-clamp: 2;
}
.rq-dot {
  width: 7px;
  height: 7px;
  flex: 0 0 7px;
  border-radius: 999px;
}
.rq-when {
  margin: 0;
  color: var(--m-muted);
  font-size: 11px;
}

.rq--good { background: var(--m-success); }
.rq--warn { background: var(--m-warning); }
.rq--danger { background: var(--m-danger); }
.rq--idle { background: var(--m-border); }
.rq-status--good { color: var(--m-success); }
.rq-status--warn { color: var(--m-warning); }
.rq-status--danger { color: var(--m-danger); }
.rq-status--idle { color: var(--m-muted); }

/* The card's foot: its one action, or the lock once OSAS has approved it. */
.rq-action,
.rq-locked {
  display: flex;
  min-height: 32px;
  align-items: center;
  justify-content: center;
  gap: 5px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
}
.rq-action {
  color: var(--m-primary-dark);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.rq-action--primary {
  background: var(--m-primary-soft);
}
.rq-action:disabled {
  opacity: 0.6;
}
.rq-locked {
  color: var(--m-muted);
}

.rq-busy {
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
}
</style>
