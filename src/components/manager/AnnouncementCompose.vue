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
      <!-- 1. WRITE -->
      <section class="card">
        <div class="row row--wrap">
          <span class="row-label">To</span>
          <span class="m-chips">
            <button
              v-for="a in accommodations"
              :key="a.id"
              type="button"
              class="m-chip"
              :class="{ 'm-chip--on': form.accommodationIds.includes(a.id) }"
              @click="toggleHouse(a.id)"
            >
              <IconifyIcon v-if="form.accommodationIds.includes(a.id)" icon="lucide:check" width="13" />
              {{ a.name }}
            </button>
          </span>
        </div>
        <p class="reach">{{ reachText }}</p>

        <label class="field">
          <span class="field-head">
            <span class="row-label">Title</span>
            <span class="count" :class="{ 'count--near': form.title.length > 100 }">{{ form.title.length }}/120</span>
          </span>
          <input v-model="form.title" type="text" class="row-input" maxlength="120" placeholder="Water interruption Tuesday" />
        </label>

        <label class="field">
          <span class="field-head">
            <span class="row-label">Banner line</span>
            <span class="count" :class="{ 'count--near': form.summary.length > 120 }">{{ form.summary.length }}/140</span>
          </span>
          <input v-model="form.summary" type="text" class="row-input" maxlength="140" placeholder="Optional — the one line tenants see first" />
        </label>

        <textarea v-model="form.body" class="body" placeholder="The full notice: what is happening, when, and what your tenants need to do." />

        <!-- A photo of the posted advisory or schedule says more than the body
             usually can, and the reader already renders it as a poster. -->
        <div v-if="form.imageUrl" class="photo">
          <img :src="resolveAsset(form.imageUrl, CARD)" alt="" class="photo-img" />
          <button type="button" class="photo-drop" aria-label="Remove photo" @click="form.imageUrl = ''">
            <IconifyIcon icon="lucide:trash-2" width="15" />
          </button>
        </div>
        <div v-else class="photo-add">
          <button type="button" class="ghost-btn" :disabled="uploading" @click="fromCamera">
            <IconifyIcon icon="lucide:camera" width="15" />
            {{ uploading ? 'Uploading…' : 'Take photo' }}
          </button>
          <button type="button" class="ghost-btn" :disabled="uploading" @click="pickFile">
            <IconifyIcon icon="lucide:image-plus" width="15" />
            Upload
          </button>
          <input ref="fileInput" type="file" accept="image/*" class="hidden-input" @change="onFilePicked" />
        </div>
      </section>

      <!-- 2. DETAILS -->
      <section class="card">
        <button type="button" class="fold" @click="detailsOpen = !detailsOpen">
          <span class="fold-title">Details</span>
          <span class="fold-note">{{ detailsSummary }}</span>
          <IconifyIcon :icon="detailsOpen ? 'lucide:chevron-up' : 'lucide:chevron-down'" width="16" />
        </button>

        <template v-if="detailsOpen">
          <div class="row">
            <span class="row-label">Happens</span>
            <DateTimeField v-model="form.eventAt" placeholder="Pick a date and time" />
          </div>

          <div v-if="form.eventAt" class="row">
            <span class="row-label">Until</span>
            <DateTimeField v-model="form.eventEnd" placeholder="Pick a date and time" />
          </div>

          <div class="row">
            <span class="row-label">Where</span>
            <input v-model="form.location" type="text" class="row-input" maxlength="120" placeholder="Ground floor · Zone 3" />
          </div>

          <div class="row">
            <span class="row-label">Respond by</span>
            <DateTimeField v-model="form.deadlineAt" placeholder="Pick a date and time" />
          </div>
        </template>
      </section>

      <!-- 3. DELIVERY -->
      <section class="card">
        <span class="fold-title">Delivery</span>

        <div class="row">
          <span class="row-label">Send</span>
          <span class="seg">
            <button type="button" class="seg-btn" :class="{ 'seg-btn--on': !form.publishAt }" @click="form.publishAt = ''">Now</button>
            <button type="button" class="seg-btn" :class="{ 'seg-btn--on': !!form.publishAt }" @click="scheduleSoon">Later</button>
          </span>
        </div>
        <div v-if="form.publishAt" class="row">
          <span class="row-label">At</span>
          <DateTimeField v-model="form.publishAt" :min="today" placeholder="Pick a date and time" />
        </div>

        <div class="row">
          <span class="row-label">Hide after</span>
          <DateTimeField v-model="form.expiresAt" mode="date" :min="today" placeholder="Never" />
        </div>
      </section>

      <p v-for="problem in problems" :key="problem" class="problem">
        <IconifyIcon icon="lucide:alert-circle" width="14" />
        {{ problem }}
      </p>

      <!-- 4. PREVIEW — the notice as a tenant meets it, so the banner line is
           written for the banner rather than guessed at. -->
      <section class="preview">
        <span class="preview-cap">What your tenants will see</span>
        <div class="pv-banner">
          <IconifyIcon icon="lucide:megaphone" width="14" />
          <span class="pv-banner-text">{{ form.summary.trim() || form.title.trim() || 'Your announcement' }}</span>
        </div>
        <article class="pv-card">
          <img v-if="form.imageUrl" :src="resolveAsset(form.imageUrl, CARD)" alt="" class="pv-poster" />
          <h4 class="pv-title">{{ form.title.trim() || 'Untitled notice' }}</h4>
          <p v-if="factLine" class="pv-facts">{{ factLine }}</p>
          <p class="pv-body">{{ form.body.trim() || 'The body of your notice appears here.' }}</p>
          <p v-if="form.deadlineAt" class="pv-deadline">Respond by {{ readable(form.deadlineAt) }}</p>
        </article>
      </section>
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
    <q-dialog v-model="confirmDiscard">
      <q-card class="ask">
        <h3 class="ask-title">Discard this announcement?</h3>
        <p class="ask-text">What you have written will not be kept.</p>
        <div class="ask-actions">
          <button type="button" class="ghost-btn" @click="confirmDiscard = false">Keep writing</button>
          <button type="button" class="danger-btn" @click="emit('close')">Discard</button>
        </div>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { capturePhoto } from '@/utils/camera'
import { uploadDocument } from '@/utils/upload'
import { resolveAsset, CARD } from '@/utils/cloudinaryUrl'
import { useNotify } from '@/utils/notify'
import { errorMessage } from '@/utils/errors'
import DateTimeField from '@/components/shared/DateTimeField.vue'

export interface AnnouncementDraft {
  /** One notice per house: the same text, addressed to each set of tenants. */
  accommodationIds: string[]
  title: string
  summary: string
  body: string
  /** What the notice is about — shown as facts, not buried in the sentence. */
  eventAt: string
  eventEnd: string
  location: string
  /** When a reply or action is needed by. */
  deadlineAt: string
  imageUrl: string
  publishAt: string
  expiresAt: string
}

const props = defineProps<{
  /** The landlord/landlady's houses; the first is the default target. */
  accommodations: { id: string; name: string }[]
  /** Parent owns the insert, so it owns the in-flight flag too. */
  submitting?: boolean
}>()

const emit = defineEmits<{ close: []; submit: [AnnouncementDraft] }>()

const notify = useNotify()

const form = reactive<AnnouncementDraft>({
  accommodationIds: props.accommodations[0]?.id ? [props.accommodations[0].id] : [],
  title: '',
  summary: '',
  body: '',
  eventAt: '',
  eventEnd: '',
  location: '',
  deadlineAt: '',
  imageUrl: '',
  publishAt: '',
  expiresAt: '',
})

/** Nothing can be scheduled into the past; the picker greys out earlier days. */
const today = new Date().toISOString().slice(0, 10)

const detailsOpen = ref(false)
const uploading = ref(false)
const confirmDiscard = ref(false)
const fileInput = ref<HTMLInputElement | null>(null)
const tenantCount = ref<number | null>(null)

function toggleHouse(id: string) {
  const at = form.accommodationIds.indexOf(id)
  if (at === -1) form.accommodationIds.push(id)
  else form.accommodationIds.splice(at, 1)
}

/** The honest version of "who am I about to interrupt". */
async function countTenants() {
  if (!form.accommodationIds.length) {
    tenantCount.value = 0
    return
  }
  tenantCount.value = null
  // head + exact count: the number is all that is wanted, so no rows cross the
  // wire to be counted client-side.
  const { count } = await supabase
    .from('leases')
    .select('id, rooms!inner(accommodation_id)', { count: 'exact', head: true })
    .eq('status', 'active')
    .in('rooms.accommodation_id', form.accommodationIds)
  tenantCount.value = count ?? 0
}

watch(() => [...form.accommodationIds], countTenants, { immediate: true })

const reachText = computed(() => {
  if (!form.accommodationIds.length) return 'Pick at least one house.'
  if (tenantCount.value === null) return 'Counting tenants…'
  const who = `${tenantCount.value} ${tenantCount.value === 1 ? 'tenant' : 'tenants'}`
  return form.accommodationIds.length === 1
    ? `${who} will get this`
    : `${who} across ${form.accommodationIds.length} houses will get this`
})

const detailsSummary = computed(() => {
  const set = [
    form.eventAt && 'when',
    form.location && 'where',
    form.deadlineAt && 'respond by',
  ].filter(Boolean)
  return set.length ? set.join(' · ') : 'When, where, respond by'
})

function readable(local: string): string {
  const d = new Date(local)
  return Number.isNaN(d.getTime())
    ? ''
    : d.toLocaleString([], { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
}

const factLine = computed(() => {
  const parts: string[] = []
  if (form.eventAt) {
    parts.push(form.eventEnd ? `${readable(form.eventAt)} – ${readable(form.eventEnd)}` : readable(form.eventAt))
  }
  if (form.location.trim()) parts.push(form.location.trim())
  return parts.join(' · ')
})

/**
 * Everything the database would accept but nobody meant: an end before its
 * start, a send time in the past (the cron would fire it on its next pass and
 * "scheduled" would be a lie), an expiry before the notice is even out.
 */
const problems = computed(() => {
  const out: string[] = []
  const at = (v: string) => (v ? new Date(v).getTime() : null)
  const start = at(form.eventAt)
  const end = at(form.eventEnd)
  const send = at(form.publishAt)
  const due = at(form.deadlineAt)
  const now = Date.now()

  if (start && end && end <= start) out.push('“Until” is before it starts.')
  if (send && send <= now) out.push('That send time has already passed.')
  if (due && due <= now) out.push('“Respond by” has already passed.')
  if (form.expiresAt) {
    const hides = new Date(`${form.expiresAt}T23:59:59`).getTime()
    if (hides <= (send ?? now)) out.push('It would be hidden before it is sent.')
    if (due && hides < due) out.push('It hides before the respond-by date.')
  }
  return out
})

/** The one thing still missing, so a greyed-out Send is never a mystery. */
const footNote = computed(() => {
  if (props.submitting) return ""
  if (!form.accommodationIds.length) return "Pick a house"
  if (!form.title.trim()) return "Needs a title"
  if (!form.body.trim()) return "Needs a notice"
  if (problems.value.length) return "Fix the dates above"
  if (form.publishAt) return `Goes out ${readable(form.publishAt)}`
  return tenantCount.value === null ? "" : `Goes out now to ${tenantCount.value}`
})

const canSend = computed(
  () =>
    form.accommodationIds.length > 0 &&
    Boolean(form.title.trim()) &&
    Boolean(form.body.trim()) &&
    problems.value.length === 0 &&
    !uploading.value &&
    !props.submitting,
)

const dirty = computed(() =>
  Boolean(form.title || form.summary || form.body || form.eventAt || form.location || form.imageUrl),
)

function tryClose() {
  if (dirty.value) confirmDiscard.value = true
  else emit('close')
}

/** Default a scheduled send to the next whole hour, not to "now". */
function scheduleSoon() {
  if (form.publishAt) return
  const d = new Date(Date.now() + 60 * 60 * 1000)
  d.setMinutes(0, 0, 0)
  const pad = (n: number) => String(n).padStart(2, '0')
  form.publishAt = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

async function fromCamera() {
  const { file, error } = await capturePhoto()
  if (error) notify.error(error)
  if (file) await upload(file)
}

function pickFile() {
  fileInput.value?.click()
}

async function onFilePicked(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  ;(e.target as HTMLInputElement).value = ''
  if (file) await upload(file)
}

async function upload(file: File) {
  uploading.value = true
  try {
    form.imageUrl = await uploadDocument(file, '', 'announcement')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload that photo.'))
  } finally {
    uploading.value = false
  }
}

function submit() {
  if (!canSend.value) return
  emit('submit', { ...form, accommodationIds: [...form.accommodationIds] })
}
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
.row {
  display: flex;
  align-items: center;
  gap: 10px;
}
.row--wrap {
  align-items: flex-start;
}
.row-label {
  flex: 0 0 84px;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.row-input {
  min-width: 0;
  flex: 1 1 auto;
  padding: 8px 10px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-text);
  font: inherit;
  font-size: 13.5px;
}
/* A label with its own counter sits above its input rather than beside it —
   the counter has nowhere to go on a 320px row. */
.field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.field-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
}
.count {
  color: var(--m-muted);
  font-size: 11px;
  font-variant-numeric: tabular-nums;
}
.count--near {
  color: var(--m-danger);
}
.reach {
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
}
.body {
  min-height: 140px;
  padding: 10px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-text);
  font: inherit;
  font-size: 13.5px;
  line-height: 1.45;
  resize: none;
}
.photo {
  position: relative;
}
.photo-img {
  display: block;
  width: 100%;
  max-height: 180px;
  border-radius: var(--m-radius-sm);
  object-fit: cover;
}
.photo-drop {
  position: absolute;
  top: 8px;
  right: 8px;
  display: grid;
  width: 30px;
  height: 30px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.62);
  color: #fff;
  cursor: pointer;
}
.photo-add {
  display: flex;
  gap: 8px;
}
.hidden-input {
  display: none;
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
/* The collapsed half names what is already set, so folding it away never hides
   a value the writer forgot about. */
.fold {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 8px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  text-align: left;
}
.fold-title {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 13.5px;
  font-weight: 700;
}
.fold-note {
  flex: 1 1 auto;
  overflow: hidden;
  color: var(--m-muted);
  font-size: 11.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.seg {
  display: flex;
  flex: 1 1 auto;
  gap: 4px;
}
.seg-btn {
  padding: 7px 16px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
}
.seg-btn--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
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
.preview-cap {
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.pv-banner {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.pv-banner-text {
  overflow: hidden;
  font-size: 12.5px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pv-card {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
}
.pv-poster {
  display: block;
  width: 100%;
  max-height: 140px;
  border-radius: var(--m-radius-sm);
  object-fit: cover;
}
.pv-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 14px;
  font-weight: 700;
}
.pv-facts {
  margin: 0;
  color: var(--m-primary-dark);
  font-size: 12px;
  font-weight: 600;
}
.pv-body {
  margin: 0;
  color: var(--m-text);
  font-size: 12.5px;
  line-height: 1.45;
  white-space: pre-wrap;
}
.pv-deadline {
  margin: 0;
  color: var(--m-danger);
  font-size: 12px;
  font-weight: 600;
}
.ask {
  display: flex;
  width: 100%;
  max-width: 320px;
  flex-direction: column;
  gap: 8px;
  padding: 18px;
  border-radius: var(--m-radius-lg);
  background: var(--m-surface);
}
.ask-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
}
.ask-text {
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
}
.ask-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 6px;
}
.m-chips {
  flex: 1 1 auto;
}
</style>
