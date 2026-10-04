<template>
  <!-- One requirement or permit set as a progress summary over a grid of
       thumbnail cards. Shared by the student and landlord/landlady OSAS pages:
       every file is visible at once, so nothing hides behind an accordion. -->
  <div class="rq">
    <div class="rq-sum">
      <p class="rq-sum-title">
        <strong>{{ done }} of {{ items.length }}</strong> {{ noun }} {{ doneWord }}
      </p>
      <div class="rq-bar" aria-hidden="true">
        <span v-for="d in items" :key="d.type" class="rq-bar-seg" :class="`rq--${d.tone}`" />
      </div>
      <p v-if="rest" class="rq-sum-rest">{{ rest }}</p>
    </div>

    <div class="rq-grid">
      <article v-for="d in items" :key="d.type" class="rq-card">
        <button
          type="button"
          class="rq-thumb"
          :class="{ 'rq-thumb--empty': !d.fileUrl && !d.fileLoading }"
          :disabled="d.fileLoading || (!d.fileUrl && (d.verified || busy))"
          :aria-label="d.fileUrl ? `Open ${d.label}` : `Upload ${d.label}`"
          @click="d.fileUrl ? openFile(d.fileUrl) : emit('upload', d.type)"
        >
          <img v-if="d.fileUrl && !isPdf(d.fileUrl)" :src="resolveAsset(d.fileUrl)" alt="" />
          <span v-else-if="d.fileUrl" class="rq-thumb-pdf">
            <IconifyIcon icon="lucide:file-text" width="26" />
            PDF
          </span>
          <q-spinner v-else-if="d.fileLoading" size="22px" />
          <IconifyIcon v-else icon="lucide:plus" width="22" />
        </button>

        <div class="rq-body">
          <h3 class="rq-name">{{ d.label }}</h3>
          <p class="rq-status" :class="`rq-status--${d.tone}`">
            <span class="rq-dot" :class="`rq--${d.tone}`" />{{ d.statusLabel }}
          </p>
          <p v-if="d.when" class="rq-when">{{ d.when }}</p>
        </div>

        <p v-if="d.verified" class="rq-locked">
          <IconifyIcon icon="lucide:lock" width="12" /> Verified
        </p>
        <button v-else type="button" class="rq-action" :class="{ 'rq-action--primary': !d.fileUrl && !d.fileLoading }" :disabled="busy" @click="emit('upload', d.type)">
          <IconifyIcon icon="lucide:upload" width="13" />
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
  defineProps<{ items: RequirementItem[]; noun: string; doneWord: string; replaceLabel?: string; busy?: boolean }>(),
  { replaceLabel: 'Replace', busy: false },
)
const emit = defineEmits<{ upload: [type: string] }>()

/** Photos open in the in-app viewer; a PDF can only be handed to the system. */
const viewerUrl = ref('')
function openFile(url: string) {
  if (isPdf(url)) openExternal(resolveAsset(url))
  else viewerUrl.value = resolveAsset(url)
}

const done = computed(() => props.items.filter((d) => d.tone === 'good').length)

/** "1 Expiring soon · 1 Not submitted" — everything that is not yet good. */
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
  gap: 12px;
}

.rq-sum {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
}
.rq-sum-title {
  margin: 0;
  color: var(--m-text);
  font-size: 13px;
}
.rq-sum-title strong {
  color: var(--m-ink);
  font-family: var(--m-font-display, inherit);
  font-size: 20px;
  font-weight: 800;
  margin-right: 2px;
}
.rq-bar {
  display: flex;
  gap: 4px;
}
.rq-bar-seg {
  flex: 1;
  height: 6px;
  border-radius: 999px;
}
.rq-sum-rest {
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
}

.rq-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 10px;
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

.rq-thumb {
  display: grid;
  aspect-ratio: 4 / 3;
  width: 100%;
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
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.rq-thumb-pdf {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.06em;
}
.rq-thumb--empty {
  margin: 8px 8px 0;
  width: calc(100% - 16px);
  border: 1.5px dashed var(--m-border);
  border-radius: var(--m-radius-sm);
  color: var(--m-muted);
}
.rq-thumb:disabled {
  cursor: default;
}

.rq-body {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 3px;
  padding: 10px 10px 8px;
}
.rq-name {
  margin: 0;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
  line-height: 1.25;
}
.rq-status {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: 0;
  font-size: 11.5px;
  font-weight: 700;
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

.rq-action,
.rq-locked {
  display: flex;
  min-height: 36px;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin: 0;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  color: var(--m-text);
  font: inherit;
  font-size: 12px;
  font-weight: 700;
}
.rq-action {
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.rq-action--primary {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
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
