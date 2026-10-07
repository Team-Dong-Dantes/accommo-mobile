<template>
  <div class="acr">
    <h2 class="acr-title">Accreditation</h2>

    <!-- Waiting on OSAS: a new listing, a resubmission or an appeal. -->
    <div v-if="status === 'pending' || status === 'reviewing'" class="box">
      <span class="box-head">
        <IconifyIcon :icon="status === 'reviewing' ? 'lucide:eye' : 'lucide:hourglass'" width="16" />
        {{ status === 'reviewing' ? 'OSAS is reviewing it now' : 'Waiting for OSAS' }}
      </span>
      <p class="box-text">
        {{ openRound ? `${KIND_LABEL[openRound.kind]} sent ${since(openRound.submitted_at)} ago.` : 'Sent to OSAS.' }}
        {{ waitLine }}
      </p>
      <p class="box-text">The location is locked until OSAS decides.</p>
    </div>

    <!-- Sent back: exactly what to fix, and the way back in. -->
    <div v-else-if="status === 'needs_revision'" class="box box--warn">
      <span class="box-head"><IconifyIcon icon="lucide:file-pen" width="16" /> What OSAS needs</span>
      <p v-if="lastReturned?.note" class="quote">“{{ lastReturned.note }}”</p>
      <p v-if="lastReturned?.tags?.length" class="box-text">{{ lastReturned.tags.join(' · ') }}</p>
      <div v-if="flagged.length" class="flag-list">
        <div v-for="f in flagged" :key="f.type" class="flag-row">
          <span class="flag-icon" :class="f.replaced ? 'flag-icon--done' : 'flag-icon--todo'">
            <IconifyIcon :icon="f.replaced ? 'lucide:check' : 'lucide:file-warning'" width="15" />
          </span>
          <span class="flag-body">
            <span class="flag-name">{{ permitLabel(f.type) }}</span>
            <span class="flag-when">{{ f.replaced ? 'Replaced' : 'Needs a new file' }}</span>
          </span>
          <button type="button" class="pill-btn" @click="openReplace(f.type)">
            {{ f.replaced ? 'Change' : 'Replace' }}
          </button>
        </div>
      </div>
      <p v-else class="box-text">Make the changes OSAS asked for, then resubmit.</p>
      <textarea v-model="message" class="note-input" rows="2" maxlength="1000" placeholder="Note for OSAS (optional)" />
      <button type="button" class="main-btn" :disabled="!allReplaced || busy" @click="resubmit">
        {{ busy ? 'Sending…' : allReplaced ? 'Resubmit to OSAS' : `Replace ${unreplacedCount} more permit${unreplacedCount === 1 ? '' : 's'} first` }}
      </button>
    </div>

    <!-- Refused: one appeal, then it is final. -->
    <div v-else-if="status === 'rejected'" class="box box--danger">
      <span class="box-head"><IconifyIcon icon="lucide:circle-x" width="16" /> OSAS refused this listing</span>
      <p v-if="lastDecided?.note" class="quote">“{{ lastDecided.note }}”</p>
      <template v-if="canAppeal">
        <p class="box-text">If you think OSAS got it wrong, you can appeal once. Say what OSAS should look at again.</p>
        <textarea v-model="message" class="note-input" rows="3" maxlength="1000" placeholder="Why should OSAS reconsider?" />
        <button type="button" class="main-btn" :disabled="!message.trim() || busy" @click="appeal">
          {{ busy ? 'Sending…' : 'Appeal this decision' }}
        </button>
      </template>
      <p v-else class="box-text">OSAS upheld its decision on appeal. This is final; it is hidden from students.</p>
      <button type="button" class="pill-btn pill-btn--danger" @click="emit('delete')">Delete this accommodation</button>
    </div>

    <!-- Live. -->
    <div v-else-if="status === 'accredited' || status === 'delisted'" class="box">
      <span class="box-head"><IconifyIcon icon="lucide:shield-check" width="16" /> Accredited{{ expiresAt ? ` until ${longDate(expiresAt)}` : '' }}</span>
      <p v-if="daysLeft !== null && daysLeft <= RENEW_WINDOW_DAYS" class="box-text">
        {{ daysLeft <= 0 ? 'The term ends today.' : `The term ends in ${daysLeft} day${daysLeft === 1 ? '' : 's'}.` }}
        Renew now so it stays visible to students.
      </p>
      <template v-if="openRound">
        <p class="box-text box-text--strong">
          OSAS is reviewing your {{ KIND_LABEL[openRound.kind].toLowerCase() }}{{ status === 'accredited' ? ' — the listing stays visible meanwhile' : '' }}.
        </p>
        <div v-if="openRound.kind === 'change' && changeRows.length" class="change-list">
          <div v-for="row in changeRows" :key="row.label" class="change-row">
            <span class="change-label">{{ row.label }}</span>
            <span class="change-value">{{ row.to }}</span>
          </div>
          <button type="button" class="pill-btn" :disabled="busy" @click="withdrawChange">Withdraw change</button>
        </div>
      </template>
      <button
        v-else-if="daysLeft !== null && daysLeft <= RENEW_WINDOW_DAYS"
        type="button"
        class="main-btn"
        :disabled="busy"
        @click="renew"
      >
        {{ busy ? 'Sending…' : 'Renew accreditation' }}
      </button>
    </div>

    <div v-else-if="status === 'expired'" class="box box--danger">
      <span class="box-head"><IconifyIcon icon="lucide:calendar-x" width="16" /> Accreditation ended</span>
      <p class="box-text">
        {{ expiresAt && new Date(expiresAt) < new Date() ? `The term ended ${longDate(expiresAt)}.` : 'A permit expired.' }}
        It is hidden from students until OSAS renews it. Make sure every permit is current first.
      </p>
      <p v-if="openRound" class="box-text box-text--strong">Renewal sent — OSAS is reviewing it.</p>
      <button v-else type="button" class="main-btn" :disabled="busy" @click="renew">
        {{ busy ? 'Sending…' : 'Renew accreditation' }}
      </button>
    </div>

    <div v-else-if="status === 'suspended'" class="box box--danger">
      <span class="box-head"><IconifyIcon icon="lucide:ban" width="16" /> Suspended by OSAS</span>
      <p class="box-text">It is hidden from students. Your tenants were told. Contact OSAS to find out what to fix.</p>
      <button type="button" class="pill-btn" @click="router.push('/manager/osas')">Contact OSAS</button>
    </div>

    <!-- Every past decision, newest first: what was asked, what OSAS said. -->
    <div v-if="history.length" class="hist">
      <button type="button" class="hist-toggle" @click="showHistory = !showHistory">
        <IconifyIcon :icon="showHistory ? 'lucide:chevron-down' : 'lucide:chevron-right'" width="15" />
        Review history ({{ history.length }})
      </button>
      <ol v-if="showHistory" class="hist-list">
        <li v-for="r in history" :key="r.id" class="hist-item">
          <span class="hist-dot" :class="`hist-dot--${r.decision}`" />
          <span class="hist-body">
            <span class="hist-head">
              {{ KIND_LABEL[r.kind] }} · <b>{{ DECISION_LABEL[r.decision ?? ''] }}</b>
            </span>
            <span class="hist-when">{{ r.decided_at ? longDate(r.decided_at) : '' }}</span>
            <span v-if="r.flagged_docs?.length" class="hist-line">Flagged: {{ r.flagged_docs.map(permitLabel).join(', ') }}</span>
            <span v-if="r.note" class="hist-line">“{{ r.note }}”</span>
            <span v-if="r.message" class="hist-line">You wrote: “{{ r.message }}”</span>
          </span>
        </li>
      </ol>
    </div>

    <PermitUploadSheet
      v-model="replaceOpen"
      :accommodation-id="accommodationId"
      :doc-type="replaceType"
      replacing
      :osas-note="lastReturned?.note ?? null"
      @saved="onPermitSaved"
    />

    <!-- Replacing the last flagged permit is the moment to send it back, so ask then. -->
    <q-dialog v-model="resubmitPromptOpen" position="bottom">
      <q-card class="rsp">
        <span class="rsp-grip" aria-hidden="true" />
        <span class="box-head"><IconifyIcon icon="lucide:send" width="16" /> Send it back to OSAS?</span>
        <p class="box-text">
          {{ flagged.length
            ? 'Every permit OSAS flagged is replaced. OSAS won’t see it until you resubmit.'
            : 'Permit saved. When you’ve made the changes OSAS asked for, resubmit so OSAS reviews it again.' }}
        </p>
        <textarea v-model="message" class="note-input" rows="2" maxlength="1000" placeholder="Note for OSAS (optional)" />
        <div class="rsp-actions">
          <button type="button" class="pill-btn" :disabled="busy" @click="resubmitPromptOpen = false">Not yet</button>
          <button type="button" class="main-btn" :disabled="busy" @click="resubmitFromPrompt">
            {{ busy ? 'Sending…' : 'Resubmit to OSAS' }}
          </button>
        </div>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup lang="ts">
// Where a listing stands with OSAS, and the one thing to do next. Reads the
// accreditation rounds (migration 20261002120000); every action is one of the
// database's own functions, which re-check everything shown here.
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { since } from '@/utils/notifications'
import { parseServerTime } from '@/utils/format'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { permitLabel } from '@/utils/permits'
import { BUILDING_TYPE_LABEL, GENDER_POLICY_LABEL } from '@/utils/listings'
import PermitUploadSheet from '@/components/manager/PermitUploadSheet.vue'

const props = defineProps<{
  accommodationId: string
  status: string
  appealUsed: boolean
  accreditationExpiresAt: string | null
  /** Latest version of each permit, as the parent loaded them. */
  docs: { doc_type: string; uploaded_at: string }[]
}>()
const emit = defineEmits<{
  /** The listing's status or details changed; reload it. */
  changed: []
  /** A permit was uploaded; reload the permits. */
  'docs-changed': []
  delete: []
}>()

interface Round {
  id: string
  round: number
  kind: 'new' | 'resubmission' | 'appeal' | 'renewal' | 'change' | 'permit_update'
  submitted_at: string
  message: string | null
  proposed_changes: Record<string, unknown> | null
  decided_at: string | null
  decision: 'approved' | 'returned' | 'rejected' | null
  flagged_docs: string[] | null
  tags: string[] | null
  note: string | null
}

const KIND_LABEL: Record<Round['kind'], string> = {
  new: 'Submission',
  resubmission: 'Resubmission',
  appeal: 'Appeal',
  renewal: 'Renewal',
  change: 'Change request',
  permit_update: 'Permit update',
}
const DECISION_LABEL: Record<string, string> = {
  approved: 'approved',
  returned: 'sent back for changes',
  rejected: 'refused',
}
/** Renewal opens this many days before the term ends (request_renewal). */
const RENEW_WINDOW_DAYS = 60

const router = useRouter()
const notify = useNotify()
const rounds = ref<Round[]>([])
const waitDays = ref<number | null>(null)
const message = ref('')
const busy = ref(false)
const showHistory = ref(false)
const replaceOpen = ref(false)
const replaceType = ref('')

const expiresAt = computed(() => props.accreditationExpiresAt)
const daysLeft = computed(() => {
  if (!expiresAt.value) return null
  return Math.ceil((new Date(expiresAt.value).getTime() - Date.now()) / 86_400_000)
})
const openRound = computed(() => rounds.value.find((r) => !r.decided_at) ?? null)
const history = computed(() => rounds.value.filter((r) => r.decided_at))
const lastDecided = computed(() => history.value[0] ?? null)
const lastReturned = computed(() => history.value.find((r) => r.decision === 'returned') ?? null)
const canAppeal = computed(() => !props.appealUsed && lastDecided.value?.kind !== 'appeal')

const flagged = computed(() => {
  const r = lastReturned.value
  if (!r?.decided_at) return []
  const decidedAt = parseServerTime(r.decided_at).getTime()
  return (r.flagged_docs ?? []).map((type) => {
    const doc = props.docs.find((d) => d.doc_type === type)
    return { type, replaced: Boolean(doc && parseServerTime(doc.uploaded_at).getTime() > decidedAt) }
  })
})
const unreplacedCount = computed(() => flagged.value.filter((f) => !f.replaced).length)
const allReplaced = computed(() => unreplacedCount.value === 0)

const waitLine = computed(() =>
  waitDays.value === null ? '' : `OSAS usually replies within ${Math.max(1, Math.ceil(waitDays.value))} day${Math.ceil(waitDays.value) <= 1 ? '' : 's'}.`,
)

const CHANGE_LABEL: Record<string, string> = {
  name: 'Name',
  accommodation_type: 'Type',
  gender_policy: 'Accepts',
  purok: 'Purok',
  barangay: 'Barangay',
  city: 'City',
  lat: 'Map pin',
  lng: 'Map pin',
}
const changeRows = computed(() => {
  const changes = openRound.value?.proposed_changes ?? {}
  const rows: { label: string; to: string }[] = []
  for (const [key, value] of Object.entries(changes)) {
    if (key === 'lng' && 'lat' in changes) continue
    const to =
      key === 'accommodation_type' ? BUILDING_TYPE_LABEL[String(value) as keyof typeof BUILDING_TYPE_LABEL] ?? String(value)
        : key === 'gender_policy' ? GENDER_POLICY_LABEL[String(value) as keyof typeof GENDER_POLICY_LABEL] ?? String(value)
          : key === 'lat' || key === 'lng' ? 'Moved'
            : String(value)
    rows.push({ label: CHANGE_LABEL[key] ?? key, to })
  }
  return rows
})

function longDate(iso: string) {
  return parseServerTime(iso).toLocaleDateString('en-PH', { month: 'long', day: 'numeric', year: 'numeric' })
}

async function load() {
  const [{ data, error }, { data: wait }] = await Promise.all([
    supabase
      .from('accreditation_rounds')
      .select('id, round, kind, submitted_at, message, proposed_changes, decided_at, decision, flagged_docs, tags, note')
      .eq('accommodation_id', props.accommodationId)
      .order('round', { ascending: false }),
    supabase.rpc('accreditation_wait_estimate'),
  ])
  if (error) {
    notify.error(errorMessage(error, 'Could not load the review history.'))
    return
  }
  rounds.value = (data ?? []) as Round[]
  waitDays.value = typeof wait === 'number' ? wait : null
}

/** Runs one of the database's accreditation functions, then reloads. */
async function run(fn: () => PromiseLike<{ error: unknown }>, done: string): Promise<boolean> {
  if (busy.value) return false
  busy.value = true
  try {
    const { error } = await fn()
    if (error) throw error
    message.value = ''
    notify.success(done)
    await load()
    emit('changed')
    return true
  } catch (e) {
    notify.error(errorMessage(e, 'That did not go through.'))
    return false
  } finally {
    busy.value = false
  }
}

function resubmit() {
  return run(
    () => supabase.rpc('resubmit_accommodation', {
      p_id: props.accommodationId,
      ...(message.value.trim() ? { p_message: message.value.trim() } : {}),
    }),
    'Resubmitted — OSAS will review it again.',
  )
}
function appeal() {
  return run(
    () => supabase.rpc('appeal_accommodation', { p_id: props.accommodationId, p_message: message.value.trim() }),
    'Appeal sent to OSAS.',
  )
}
function renew() {
  return run(
    () => supabase.rpc('request_renewal', { p_id: props.accommodationId }),
    'Renewal sent to OSAS.',
  )
}
function withdrawChange() {
  return run(
    () => supabase.rpc('withdraw_details_change', { p_id: props.accommodationId }),
    'Change withdrawn.',
  )
}

function openReplace(type: string) {
  replaceType.value = type
  replaceOpen.value = true
}
function onPermitSaved() {
  permitReplaced()
  emit('docs-changed')
}

// A permit saved while sent back — from this card or the parent's Permits list.
// `docs` only catches up once the parent reloads them, so the check waits for that.
const resubmitPromptOpen = ref(false)
let checkAfterDocs = false
function permitReplaced() {
  if (props.status === 'needs_revision') checkAfterDocs = true
}
watch(() => props.docs, () => {
  if (!checkAfterDocs) return
  checkAfterDocs = false
  if (props.status === 'needs_revision' && allReplaced.value) resubmitPromptOpen.value = true
})
async function resubmitFromPrompt() {
  if (await resubmit()) resubmitPromptOpen.value = false
}

onMounted(load)
// The status moves under this card (resubmit, renew, OSAS deciding), and with
// it the rounds; a change request is submitted from the parent's editor.
watch(() => props.status, () => void load())
defineExpose({ reload: load, flagged, permitReplaced })
</script>

<style scoped>
.acr { display: flex; flex-direction: column; gap: 10px; }
.acr-title {
  margin: 4px 0 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.box {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
}
.box--warn { border-color: color-mix(in srgb, var(--m-warning) 45%, var(--m-border)); }
.box--danger { border-color: color-mix(in srgb, var(--m-danger) 40%, var(--m-border)); }
.box-head {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.box-head :deep(svg) { color: var(--m-primary-dark); }
.box--warn .box-head :deep(svg) { color: var(--m-warning); }
.box--danger .box-head :deep(svg) { color: var(--m-danger); }
.box-text { margin: 0; color: var(--m-muted); font-size: 12.5px; line-height: 1.45; }
.box-text--strong { color: var(--m-ink); font-weight: 600; }
.quote {
  margin: 0;
  padding: 8px 10px;
  border-left: 3px solid var(--m-warning);
  border-radius: 0 var(--m-radius-sm) var(--m-radius-sm) 0;
  background: var(--m-surface);
  color: var(--m-ink);
  font-size: 13px;
  line-height: 1.45;
}
.box--danger .quote { border-left-color: var(--m-danger); }
.flag-list {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.flag-row { display: flex; align-items: center; gap: 10px; padding: 10px 12px; border-top: 1px solid var(--m-border); }
.flag-row:first-child { border-top: 0; }
.flag-icon {
  display: grid;
  width: 30px;
  height: 30px;
  flex: 0 0 30px;
  place-items: center;
  border-radius: 999px;
}
.flag-icon--todo { background: var(--m-warning-soft); color: var(--m-warning); }
.flag-icon--done { background: var(--m-success-soft); color: var(--m-success); }
.flag-body { display: flex; min-width: 0; flex: 1; flex-direction: column; gap: 1px; }
.flag-name { color: var(--m-ink); font-size: 13px; font-weight: 700; }
.flag-when { color: var(--m-muted); font-size: 11px; }
.note-input {
  box-sizing: border-box;
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
  resize: vertical;
}
.main-btn {
  min-height: 46px;
  padding: 0 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.main-btn:disabled { background: var(--m-border); color: var(--m-muted); cursor: not-allowed; }
.pill-btn {
  align-self: flex-start;
  min-height: 36px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.flag-row .pill-btn { align-self: center; }
.pill-btn--danger { border-color: var(--m-danger); background: var(--m-danger-soft); color: var(--m-danger); }
.pill-btn:disabled { opacity: 0.6; }
.rsp {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.rsp-grip { width: 40px; height: 4px; margin: 0 auto; border-radius: 999px; background: var(--m-border); }
.rsp-actions { display: flex; align-items: center; justify-content: flex-end; gap: 10px; }
.rsp-actions .pill-btn { align-self: center; min-height: 46px; }
.change-list { display: flex; flex-direction: column; gap: 6px; }
.change-row { display: flex; justify-content: space-between; gap: 12px; font-size: 12.5px; }
.change-label { color: var(--m-muted); }
.change-value { color: var(--m-ink); font-weight: 600; text-align: right; overflow-wrap: anywhere; }
.hist { display: flex; flex-direction: column; gap: 6px; }
.hist-toggle {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 4px;
  padding: 4px 2px;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
}
.hist-list { display: flex; flex-direction: column; margin: 0; padding: 0 0 0 6px; list-style: none; }
.hist-item {
  position: relative;
  display: flex;
  gap: 10px;
  padding: 0 0 12px 12px;
  border-left: 2px solid var(--m-border);
}
.hist-item:last-child { border-left-color: transparent; }
.hist-dot {
  position: absolute;
  top: 3px;
  left: -6px;
  width: 10px;
  height: 10px;
  border-radius: 999px;
  background: var(--m-border);
}
.hist-dot--approved { background: var(--m-success); }
.hist-dot--returned { background: var(--m-warning); }
.hist-dot--rejected { background: var(--m-danger); }
.hist-body { display: flex; flex-direction: column; gap: 2px; font-size: 12.5px; }
.hist-head { color: var(--m-ink); }
.hist-when { color: var(--m-muted); font-size: 11px; }
.hist-line { color: var(--m-muted); line-height: 1.4; }
</style>
