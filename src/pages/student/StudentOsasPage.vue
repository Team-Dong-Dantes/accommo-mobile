<template>
  <q-page class="op" :style="{ '--sticky-top': stickyTop + 'px' }">
    <div v-if="loading" class="stack">
      <div class="tabs">
        <q-skeleton type="rect" width="88px" height="38px" class="sk-tab" />
        <q-skeleton type="rect" width="70px" height="38px" class="sk-tab" />
      </div>
      <div class="group">
        <div v-for="n in 2" :key="n" class="doc-row">
          <q-skeleton type="circle" size="30px" />
          <span class="doc-body">
            <q-skeleton type="text" width="55%" height="13px" />
            <q-skeleton type="text" width="35%" height="11px" />
          </span>
          <q-skeleton type="text" width="46px" height="18px" />
        </div>
      </div>
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load OSAS</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <div v-else class="stack">
      <div class="tabbed">
        <div class="tabs">
          <button v-for="t in TABS" :key="t.key" type="button" class="tab" :class="{ 'tab--on': tab === t.key }" @click="tab = t.key">
            {{ t.label }}
          </button>
        </div>

        <div class="panel">
          <q-tab-panels v-model="tab" animated swipeable class="panels">
            <!-- DOCUMENTS -->
            <q-tab-panel name="docs" class="tab-panel">
              <div v-if="myStatus === 'rejected'" class="reject-banner">
                <IconifyIcon icon="lucide:triangle-alert" width="16" />
                <div>
                  <p class="reject-title">Verification rejected</p>
                  <p class="reject-text">{{ rejectionReason || 'OSAS rejected your submission — please resubmit below.' }}</p>
                </div>
              </div>
              <p class="sec-hint">OSAS reviews these before your account is verified. Tap one to view or resubmit.</p>
              <div class="group">
                <div v-for="d in docs" :key="d.type" class="doc-item">
                  <button
                    type="button"
                    class="doc-row"
                    :aria-expanded="expandedDoc === d.type"
                    @click="expandedDoc = expandedDoc === d.type ? '' : d.type"
                  >
                    <span class="doc-icon" :class="`doc-icon--${d.tone}`">
                      <IconifyIcon :icon="d.icon" width="16" />
                    </span>
                    <span class="doc-body">
                      <span class="doc-name">{{ DOC_LABEL[d.type] || d.type }}</span>
                      <span class="doc-when">{{ d.when }}</span>
                    </span>
                    <span class="doc-tag" :class="`doc-tag--${d.tone}`">{{ d.statusLabel }}</span>
                    <IconifyIcon icon="lucide:chevron-down" width="16" class="doc-chevron" :class="{ 'doc-chevron--on': expandedDoc === d.type }" />
                  </button>

                  <q-slide-transition>
                    <div v-if="expandedDoc === d.type" class="doc-detail">
                      <div class="doc-preview">
                        <img v-if="d.fileUrl && !isPdf(d.fileUrl)" :src="resolveAsset(d.fileUrl)" alt="" class="doc-preview-img" @click="openFile(d.fileUrl)" />
                        <button v-else-if="d.fileUrl" type="button" class="doc-preview-file" @click="openFile(d.fileUrl)">
                          <IconifyIcon icon="lucide:file-text" width="26" />
                          <span>View file</span>
                        </button>
                        <div v-else class="doc-preview-empty">
                          <IconifyIcon icon="lucide:image-off" width="20" />
                          <span>Nothing uploaded yet</span>
                        </div>
                      </div>
                      <p v-if="d.verified" class="doc-locked">
                        <IconifyIcon icon="lucide:lock" width="13" /> Verified — can't be replaced.
                      </p>
                      <div class="doc-actions">
                        <label v-if="!d.verified" class="doc-action doc-action--primary">
                          <IconifyIcon icon="lucide:upload" width="14" />
                          {{ d.fileUrl ? 'Resubmit' : 'Upload' }}
                          <input type="file" accept="image/*,application/pdf" class="doc-file-input" @change="onDocSelected($event, d.type)" />
                        </label>
                        <button v-if="d.fileUrl" type="button" class="doc-action" @click="openFile(d.fileUrl)">
                          <IconifyIcon icon="lucide:external-link" width="14" /> Open
                        </button>
                      </div>
                    </div>
                  </q-slide-transition>
                </div>
              </div>
              <span v-if="uploadingDoc" class="sec-hint">Uploading…</span>
            </q-tab-panel>

            <!-- TICKETS -->
            <q-tab-panel name="tickets" class="tab-panel">
              <div class="sec-head">
                <p class="sec-hint">Raise a ticket for anything OSAS needs to look into.</p>
                <button type="button" class="sec-link" @click="openNewTicket">New ticket</button>
              </div>

              <EmptyState
                v-if="!tickets.length"
                variant="compact"
                icon="lucide:life-buoy"
                title="No tickets yet"
                message="Account, verification or technical issues you raise with OSAS will show up here."
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
            </q-tab-panel>
          </q-tab-panels>
        </div>
      </div>
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
            <option value="verification">Verification</option>
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
        <label class="field">
          <span class="field-label">Screenshot (optional)</span>
          <input type="file" accept="image/*" class="submit-file" @change="onTicketPhotoSelected" />
          <span v-if="uploadingPhoto" class="sec-hint">Uploading…</span>
        </label>
        <q-btn unelevated rounded no-caps color="primary" class="new-submit" :loading="submittingTicket" label="Submit" @click="submitTicket" />
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { DOC_LABEL, docPresentation } from '@/utils/profile'
import { since } from '@/utils/notifications'
import { useNotify } from '@/utils/notify'
import { uploadDocument } from '@/utils/upload'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import EmptyState from '@/components/shared/EmptyState.vue'

const TABS = [
  { key: 'docs', label: 'Documents' },
  { key: 'tickets', label: 'Tickets' },
] as const

const REQUIRED_DOCS = ['school_id', 'assessment_of_fees']

const TICKET_TONE: Record<string, string> = {
  open: 'amber',
  pending: 'amber',
  assigned: 'orange',
  in_progress: 'orange',
  under_review: 'orange',
  resolved: 'green',
  closed: 'grey',
}

interface DocRow {
  type: string
  statusLabel: string
  tone: string
  icon: string
  when: string
  fileUrl: string
  /** OSAS has approved this one — locked from replacement. */
  verified: boolean
}
interface Ticket {
  id: string
  subject: string
  description: string
  category: string
  status: string
  reportedAt: string
}

const notify = useNotify()

const loading = ref(true)
const error = ref('')
const tab = ref<(typeof TABS)[number]['key']>('docs')

const myId = ref('')
// OSAS approves/rejects identity documents by flipping the account's own
// users.status, not each verification_documents row (the admin review flow
// never writes doc_status past its initial 'pending') — so "verified" has to
// be read from here, not from the per-document status.
const myStatus = ref('')
// There's no rejection-reason column anywhere (users, verification_documents) —
// the admin's decision only ever survives as the notification it sends, so
// that's the one place a reason can be read back from.
const rejectionReason = ref('')
const docRows = ref<{ id: string; doc_type: string; file_url: string; status: string; uploaded_at: string; verified_at: string | null }[]>([])
const expandedDoc = ref('')
const uploadingDoc = ref(false)
const tickets = ref<Ticket[]>([])

const docs = computed<DocRow[]>(() =>
  REQUIRED_DOCS.map((type) => {
    const row = docRows.value.find((d) => d.doc_type === type)
    if (!row) {
      return { type, statusLabel: 'Not submitted', tone: 'idle', icon: 'lucide:circle-dashed', when: '', fileUrl: '', verified: false }
    }
    // The account is the unit OSAS actually reviews — once it's verified (or
    // rejected), that decision overrides this row's own stale 'pending'.
    const effectiveStatus = myStatus.value === 'verified' ? 'approved' : myStatus.value === 'rejected' ? 'rejected' : row.status
    const presentation = docPresentation(effectiveStatus)
    const when = row.verified_at ? `Reviewed ${since(row.verified_at)}` : `Sent ${since(row.uploaded_at)}`
    return { type, statusLabel: presentation.label, tone: presentation.tone, icon: presentation.icon, when, fileUrl: row.file_url, verified: effectiveStatus === 'approved' }
  }),
)

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

/** Cosmetic extension check — good enough to pick "image preview" vs "open file". */
function isPdf(url: string) {
  return /\.pdf(\?|$)/i.test(url)
}

function openFile(url: string) {
  if (url) window.open(resolveAsset(url), '_blank', 'noopener')
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
    myId.value = user.id

    const [{ data: docData, error: docError }, { data: ticketData, error: ticketError }, { data: userData, error: userError }] = await Promise.all([
      supabase
        .from('verification_documents')
        .select('id, doc_type, file_url, status, uploaded_at, verified_at')
        .eq('user_id', user.id)
        .in('doc_type', REQUIRED_DOCS)
        .order('uploaded_at', { ascending: false }),
      supabase
        .from('tickets')
        .select('id, subject, description, category, status, reported_at')
        .eq('student_id', user.id)
        .order('reported_at', { ascending: false }),
      supabase.from('users').select('status').eq('id', user.id).maybeSingle(),
    ])
    if (docError) throw docError
    if (ticketError) throw ticketError
    if (userError) throw userError
    myStatus.value = userData?.status || ''
    if (myStatus.value === 'rejected') {
      const { data: reasonRow } = await supabase
        .from('notifications')
        .select('body')
        .eq('user_id', user.id)
        .eq('title', 'Verification rejected')
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()
      rejectionReason.value = reasonRow?.body || ''
    }

    // Keep only the most recent row per doc type.
    const seen = new Set<string>()
    docRows.value = (docData ?? [])
      .filter((d): d is typeof d & { doc_type: string; file_url: string; uploaded_at: string } => Boolean(d.doc_type && d.file_url && d.uploaded_at))
      .filter((d) => {
        if (seen.has(d.doc_type)) return false
        seen.add(d.doc_type)
        return true
      })

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

async function onDocSelected(event: Event, docType: string) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file || !myId.value) return
  uploadingDoc.value = true
  try {
    const url = await uploadDocument(file, myId.value, docType)
    const existing = docRows.value.find((d) => d.doc_type === docType)

    // Resubmission updates the same row back to pending rather than inserting
    // a duplicate — verification_documents has no version column to
    // disambiguate "latest" the way accommodation_documents does.
    if (existing) {
      const { error: updateError } = await supabase
        .from('verification_documents')
        .update({ file_url: url, filename: file.name, status: 'pending', uploaded_at: new Date().toISOString(), verified_at: null })
        .eq('id', existing.id)
      if (updateError) throw updateError
      existing.file_url = url
      existing.status = 'pending'
      existing.uploaded_at = new Date().toISOString()
      existing.verified_at = null
    } else {
      const { data: created, error: insertError } = await supabase
        .from('verification_documents')
        .insert({ user_id: myId.value, doc_type: docType, filename: file.name, file_url: url, status: 'pending' })
        .select('id, uploaded_at')
        .single()
      if (insertError) throw insertError
      docRows.value = [
        { id: created.id, doc_type: docType, file_url: url, status: 'pending', uploaded_at: created.uploaded_at ?? new Date().toISOString(), verified_at: null },
        ...docRows.value,
      ]
    }
    notify.success('Uploaded — awaiting review.')
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
const uploadingPhoto = ref(false)
const ticketForm = reactive({ category: 'verification', subject: '', description: '', photoUrl: '' })

function openNewTicket() {
  ticketForm.category = 'verification'
  ticketForm.subject = ''
  ticketForm.description = ''
  ticketForm.photoUrl = ''
  newTicketOpen.value = true
}

async function onTicketPhotoSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  uploadingPhoto.value = true
  try {
    ticketForm.photoUrl = await uploadDocument(file, '', 'ticket_photo')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload that screenshot.'))
  } finally {
    uploadingPhoto.value = false
    input.value = ''
  }
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
        student_id: user.id,
        subject: ticketForm.subject.trim(),
        description: ticketForm.description.trim() || null,
        category: ticketForm.category,
        photo_urls: ticketForm.photoUrl ? [ticketForm.photoUrl] : [],
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

// The app header floats over the page at a JS-measured height (Quasar's
// QHeader has no fixed size), so the sticky tab row needs its real bottom
// edge, not a guessed px value, or it would stick underneath the header
// once scrolled instead of just below it.
const stickyTop = ref(64)
function measureStickyTop() {
  const header = document.querySelector('.app-header') as HTMLElement | null
  if (header) stickyTop.value = Math.ceil(header.getBoundingClientRect().bottom)
}

onMounted(() => {
  load()
  void nextTick(measureStickyTop)
  window.addEventListener('resize', measureStickyTop)
})
onUnmounted(() => window.removeEventListener('resize', measureStickyTop))
</script>

<style scoped>
.op {
  display: flex;
  flex-direction: column;
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  gap: 12px;
  padding: 10px var(--m-page-gutter) 0;
}
.sk-tab {
  border-radius: 10px 10px 0 0;
}
.sk {
  border-radius: var(--m-radius);
}
.card {
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

/* Same rounded-top pill tabs fused into a bordered panel used by
   AccommodationDetail.vue / TenantProfile.vue / ManagerTenantsPage.vue —
   the default tabbed-section design for this app. */
.tabbed {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
}
.tabs {
  position: sticky;
  top: var(--sticky-top, 64px);
  z-index: 2;
  display: flex;
  gap: 4px;
  margin: 0 calc(var(--m-page-gutter) * -1) -2px;
  padding: 0 var(--m-page-gutter);
}
.tab {
  min-height: 38px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-bottom: none;
  border-radius: 10px 10px 0 0;
  background: var(--m-bg);
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  transition: background-color 0.15s ease, color 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
.tab--on {
  background: var(--m-surface);
  color: var(--m-primary-dark);
}
.panel {
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  margin: 0 calc(var(--m-page-gutter) * -1);
  padding: 14px 14px 16px;
  border: 1px solid var(--m-border);
  /* Square the bottom corners — the panel is stretched flush to the true
     bottom of the page (above the bottom nav), so a rounded corner would
     have nothing beside it to round away from. */
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
.panels {
  background: transparent;
}
.panels :deep(.q-tab-panel) {
  padding: 0;
}
.tab-panel {
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
.reject-banner {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 10px 12px;
  border: 1px solid var(--m-danger-soft);
  border-radius: var(--m-radius-sm);
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.reject-title {
  margin: 0;
  font-size: 12.5px;
  font-weight: 800;
}
.reject-text {
  margin: 2px 0 0;
  color: var(--m-text);
  font-size: 12px;
  line-height: 1.4;
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
  background: var(--m-bg);
  overflow: hidden;
}

.doc-item {
  border-top: 1px solid var(--m-border);
}
.group > .doc-item:first-child {
  border-top: 0;
}
.doc-row {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 0;
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
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
  background: var(--m-surface);
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
  background: var(--m-surface);
  color: var(--m-muted);
}
.doc-chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
  transition: transform 0.15s ease;
}
.doc-chevron--on {
  transform: rotate(180deg);
}

.doc-detail {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 0 12px 12px;
}
.doc-preview {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 96px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  overflow: hidden;
}
.doc-preview-img {
  width: 100%;
  max-height: 220px;
  object-fit: contain;
  cursor: pointer;
}
.doc-preview-file,
.doc-preview-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  padding: 20px 12px;
  border: 0;
  background: transparent;
  color: var(--m-muted);
  font: inherit;
  font-size: 12px;
  font-weight: 600;
}
.doc-preview-file {
  color: var(--m-primary-dark);
  cursor: pointer;
}
.doc-locked {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}
.doc-actions {
  display: flex;
  gap: 8px;
}
.doc-action {
  display: flex;
  min-height: 36px;
  flex: 1;
  align-items: center;
  justify-content: center;
  gap: 6px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.doc-action--primary {
  position: relative;
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  overflow: hidden;
}
.doc-file-input {
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
.submit-file {
  font-size: 13px;
}
.new-submit {
  min-height: 48px;
  font-weight: 700;
}
</style>
