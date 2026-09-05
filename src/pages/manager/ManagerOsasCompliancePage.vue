<template>
  <q-page class="op">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="90px" class="sk" />
      <q-skeleton type="rect" height="70px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load OSAS compliance</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <EmptyState
      v-else-if="!accommodations.length"
      icon="lucide:building-2"
      title="No accommodations yet"
      message="Add an accommodation first — its permits and clearances will be tracked here."
    >
      <template #actions>
        <q-btn unelevated rounded no-caps color="primary" label="Add accommodation" @click="router.push('/manager/properties/new')" />
      </template>
    </EmptyState>

    <div v-else class="stack">
      <div v-if="accommodations.length > 1" class="chips">
        <button
          v-for="a in accommodations"
          :key="a.id"
          type="button"
          class="chip"
          :class="{ 'chip--on': selectedId === a.id }"
          @click="selectedId = a.id"
        >
          {{ a.name }}
        </button>
      </div>

      <div class="tabs">
        <button v-for="t in TABS" :key="t.key" type="button" class="tab" :class="{ 'tab--on': tab === t.key }" @click="tab = t.key">
          {{ t.label }}
        </button>
      </div>

      <!-- DOCUMENTS -->
      <section v-if="tab === 'docs'" class="sec">
        <p class="sec-hint">Accreditation depends on these staying current.</p>
        <div class="group">
          <div v-for="d in docs" :key="d.type" class="doc-row">
            <span class="doc-icon" :class="`doc-icon--${d.tone}`">
              <IconifyIcon :icon="d.icon" width="16" />
            </span>
            <span class="doc-body">
              <span class="doc-name">{{ DOC_TYPE_LABEL[d.type] }}</span>
              <span class="doc-when">{{ d.when }}</span>
            </span>
            <span class="doc-tag" :class="`doc-tag--${d.tone}`">{{ d.statusLabel }}</span>
            <label class="doc-upload">
              <IconifyIcon icon="lucide:upload" width="15" />
              <input type="file" accept="image/*,application/pdf" class="doc-file" @change="onDocSelected($event, d.type)" />
            </label>
          </div>
        </div>
        <span v-if="uploadingDoc" class="sec-hint">Uploading…</span>
      </section>

      <!-- TICKETS -->
      <section v-else class="sec">
        <div class="sec-head">
          <p class="sec-hint">Raise a ticket for anything OSAS needs to look into.</p>
          <button type="button" class="sec-link" @click="openNewTicket">New ticket</button>
        </div>

        <EmptyState
          v-if="!tickets.length"
          variant="compact"
          icon="lucide:life-buoy"
          title="No tickets yet"
          message="Compliance, accreditation or technical issues you raise with OSAS will show up here."
        />
        <div v-else class="group">
          <button v-for="t in tickets" :key="t.id" type="button" class="ticket-row" @click="openTicket(t)">
            <span class="ticket-body">
              <span class="ticket-subject">{{ t.subject }}</span>
              <span class="ticket-when">{{ since(t.reportedAt) }}</span>
            </span>
            <span class="ticket-chip" :class="`ticket-chip--${TICKET_TONE[t.status] || 'grey'}`">{{ titleCase(t.status) }}</span>
          </button>
        </div>
      </section>

      <div class="tail" />
    </div>

    <q-dialog v-model="ticketOpen" position="bottom">
      <q-card v-if="selectedTicket" class="detail-sheet">
        <h3 class="detail-title">{{ selectedTicket.subject }}</h3>
        <span class="ticket-chip" :class="`ticket-chip--${TICKET_TONE[selectedTicket.status] || 'grey'}`">{{ titleCase(selectedTicket.status) }}</span>
        <p class="detail-label">{{ titleCase(selectedTicket.category) }} · {{ since(selectedTicket.reportedAt) }}</p>
        <p class="detail-text">{{ selectedTicket.description || 'No description given.' }}</p>
        <q-btn unelevated rounded no-caps color="primary" class="detail-close" label="Close" @click="ticketOpen = false" />
      </q-card>
    </q-dialog>

    <q-dialog v-model="newTicketOpen" position="bottom">
      <q-card class="new-sheet">
        <h3 class="new-title">Raise a ticket</h3>
        <label class="field">
          <span class="field-label">Category</span>
          <select v-model="ticketForm.category" class="field-input">
            <option value="compliance">Compliance / accreditation</option>
            <option value="accommodation">Accommodation</option>
            <option value="technical">Technical / app issue</option>
            <option value="other">Other</option>
          </select>
        </label>
        <label class="field">
          <span class="field-label">Subject</span>
          <input v-model="ticketForm.subject" type="text" class="field-input" placeholder="Short summary" />
        </label>
        <label class="field">
          <span class="field-label">Description</span>
          <textarea v-model="ticketForm.description" class="field-input field-textarea" rows="4" placeholder="What happened?" />
        </label>
        <q-btn unelevated rounded no-caps color="primary" class="new-submit" :loading="submittingTicket" label="Submit" @click="submitTicket" />
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { since } from '@/utils/notifications'
import { useNotify } from '@/utils/notify'
import { uploadDocument } from '@/utils/upload'
import EmptyState from '@/components/shared/EmptyState.vue'

const TABS = [
  { key: 'docs', label: 'Documents' },
  { key: 'tickets', label: 'Tickets' },
] as const

const DOC_TYPES = ['sanitary_permit', 'fire_safety', 'business_permit', 'building_permit'] as const
const DOC_TYPE_LABEL: Record<string, string> = {
  sanitary_permit: 'Sanitary permit',
  fire_safety: 'Fire safety certificate',
  business_permit: 'Business permit',
  building_permit: 'Building permit',
}

const TICKET_TONE: Record<string, string> = {
  open: 'amber',
  pending: 'amber',
  assigned: 'orange',
  in_progress: 'orange',
  under_review: 'orange',
  resolved: 'green',
  closed: 'grey',
}

interface Accommodation {
  id: string
  name: string
}
interface DocRow {
  type: string
  statusLabel: string
  tone: string
  icon: string
  when: string
}
interface Ticket {
  id: string
  subject: string
  description: string
  category: string
  status: string
  reportedAt: string
}

const router = useRouter()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const tab = ref<(typeof TABS)[number]['key']>('docs')

const accommodations = ref<Accommodation[]>([])
const selectedId = ref('')
const docRows = ref<{ doc_type: string; expires_at: string | null; uploaded_at: string; version: number }[]>([])
const tickets = ref<Ticket[]>([])
const uploadingDoc = ref(false)

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

const docs = computed<DocRow[]>(() =>
  DOC_TYPES.map((type) => {
    const row = docRows.value.find((d) => d.doc_type === type)
    if (!row) {
      return { type, statusLabel: 'Not submitted', tone: 'idle', icon: 'lucide:circle-dashed', when: '' }
    }
    if (!row.expires_at) {
      return { type, statusLabel: 'On file', tone: 'good', icon: 'lucide:check', when: `Uploaded ${since(row.uploaded_at)}` }
    }
    const now = Date.now()
    const soon = now + 30 * 24 * 60 * 60 * 1000
    const t = new Date(row.expires_at).getTime()
    if (t < now) return { type, statusLabel: 'Expired', tone: 'danger', icon: 'lucide:file-warning', when: `Expired ${since(row.expires_at)}` }
    if (t < soon) return { type, statusLabel: 'Expiring soon', tone: 'warn', icon: 'lucide:calendar-clock', when: `Expires ${since(row.expires_at)}` }
    return { type, statusLabel: 'Valid', tone: 'good', icon: 'lucide:check', when: `Expires ${since(row.expires_at)}` }
  }),
)

async function loadDocsFor(accommodationId: string) {
  const { data, error: docError } = await supabase
    .from('accommodation_documents')
    .select('doc_type, expires_at, uploaded_at, version')
    .eq('accommodation_id', accommodationId)
    .order('version', { ascending: false })
  if (docError) throw docError

  const seen = new Set<string>()
  docRows.value = (data ?? []).filter((d) => {
    if (seen.has(d.doc_type)) return false
    seen.add(d.doc_type)
    return true
  })
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: authData } = await supabase.auth.getUser()
    const user = authData?.user
    if (!user) {
      error.value = 'Not signed in.'
      return
    }

    const [{ data: accData, error: accError }, { data: ticketData, error: ticketError }] = await Promise.all([
      supabase.from('accommodations').select('id, name').eq('accommodation_manager_id', user.id).order('name'),
      supabase
        .from('tickets')
        .select('id, subject, description, category, status, reported_at')
        .eq('accommodation_manager_id', user.id)
        .order('reported_at', { ascending: false }),
    ])
    if (accError) throw accError
    if (ticketError) throw ticketError

    accommodations.value = (accData ?? []).map((a) => ({ id: a.id, name: a.name?.trim() || 'Unnamed accommodation' }))
    selectedId.value = accommodations.value[0]?.id || ''
    if (selectedId.value) await loadDocsFor(selectedId.value)

    tickets.value = (ticketData ?? []).map((t) => ({
      id: t.id,
      subject: t.subject || 'Untitled',
      description: t.description || '',
      category: t.category || 'other',
      status: t.status,
      reportedAt: t.reported_at,
    }))
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

watch(selectedId, (id) => {
  if (id) void loadDocsFor(id)
})

async function onDocSelected(event: Event, docType: string) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file || !selectedId.value) return
  uploadingDoc.value = true
  try {
    const url = await uploadDocument(file, '', docType)
    const existing = docRows.value.find((d) => d.doc_type === docType)
    const { error: insertError } = await supabase.from('accommodation_documents').insert({
      accommodation_id: selectedId.value,
      doc_type: docType,
      file_url: url,
      version: existing ? existing.version + 1 : 1,
    })
    if (insertError) throw insertError

    await loadDocsFor(selectedId.value)
    notify.success('Uploaded.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload this document.'))
  } finally {
    uploadingDoc.value = false
    input.value = ''
  }
}

const ticketOpen = ref(false)
const selectedTicket = ref<Ticket | null>(null)
function openTicket(t: Ticket) {
  selectedTicket.value = t
  ticketOpen.value = true
}

const newTicketOpen = ref(false)
const submittingTicket = ref(false)
const ticketForm = reactive({ category: 'compliance', subject: '', description: '' })

function openNewTicket() {
  ticketForm.category = 'compliance'
  ticketForm.subject = ''
  ticketForm.description = ''
  newTicketOpen.value = true
}

async function submitTicket() {
  if (submittingTicket.value) return
  if (!ticketForm.subject.trim()) {
    notify.error('Give your ticket a subject.')
    return
  }
  submittingTicket.value = true
  try {
    const { data: authData } = await supabase.auth.getUser()
    const user = authData?.user
    if (!user) throw new Error('Not signed in.')

    const { data: created, error: insertError } = await supabase
      .from('tickets')
      .insert({
        accommodation_manager_id: user.id,
        accommodation_id: selectedId.value || null,
        subject: ticketForm.subject.trim(),
        description: ticketForm.description.trim() || null,
        category: ticketForm.category,
        status: 'open',
        priority: 'medium',
      })
      .select('id, subject, description, category, status, reported_at')
      .single()
    if (insertError) throw insertError

    tickets.value = [
      { id: created.id, subject: created.subject || 'Untitled', description: created.description || '', category: created.category || 'other', status: created.status, reportedAt: created.reported_at },
      ...tickets.value,
    ]

    newTicketOpen.value = false
    notify.success('Ticket submitted.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not submit your ticket.'))
  } finally {
    submittingTicket.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.op {
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 10px var(--m-page-gutter) 24px;
}
.tail {
  height: 12px;
}
.sk {
  border-radius: var(--m-radius);
  margin: 0 var(--m-page-gutter);
}
.card {
  margin: 8px var(--m-page-gutter);
  padding: 18px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}
.err-title {
  margin: 8px 0 0;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.err-sub {
  margin: 2px 0 0;
  color: var(--m-muted);
  font-size: 12px;
}

.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.chip {
  padding: 6px 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 600;
  -webkit-tap-highlight-color: transparent;
}
.chip--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}

.tabs {
  display: flex;
  gap: 6px;
  border-bottom: 1px solid var(--m-border);
}
.tab {
  padding: 8px 4px;
  border: 0;
  border-bottom: 2px solid transparent;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.tab--on {
  border-bottom-color: var(--m-primary);
  color: var(--m-primary-dark);
}

.sec {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.sec-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}
.sec-hint {
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
}
.sec-link {
  flex: 0 0 auto;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

.group {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}

.doc-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .doc-row:first-child {
  border-top: 0;
}
.doc-icon {
  display: grid;
  width: 30px;
  height: 30px;
  flex: 0 0 30px;
  place-items: center;
  border-radius: 999px;
}
.doc-icon--good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.doc-icon--warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.doc-icon--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.doc-icon--idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.doc-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.doc-name {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.doc-when {
  color: var(--m-muted);
  font-size: 11px;
}
.doc-tag {
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}
.doc-tag--good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.doc-tag--warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.doc-tag--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.doc-tag--idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.doc-upload {
  position: relative;
  display: grid;
  width: 30px;
  height: 30px;
  flex: 0 0 30px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  color: var(--m-primary-dark);
  cursor: pointer;
}
.doc-file {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  cursor: pointer;
}

.ticket-row {
  display: flex;
  width: 100%;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 10px 12px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.group > .ticket-row:first-child {
  border-top: 0;
}
.ticket-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
}
.ticket-subject {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.ticket-when {
  color: var(--m-muted);
  font-size: 11px;
}
.ticket-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.ticket-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.ticket-chip--amber,
.ticket-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.ticket-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}

.detail-sheet,
.new-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 10px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.detail-title,
.new-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.detail-label {
  margin: 4px 0 0;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.detail-text {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
}
.detail-close {
  min-height: 46px;
  margin-top: 6px;
  font-weight: 700;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.field-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.field-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.field-textarea {
  min-height: 90px;
  padding: 10px 12px;
  resize: vertical;
}
.new-submit {
  min-height: 48px;
  font-weight: 700;
}
</style>
