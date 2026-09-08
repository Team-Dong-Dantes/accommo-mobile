<template>
  <q-page class="op" :style="{ '--sticky-top': stickyTop + 'px' }">
    <div v-if="loading" class="stack">
      <div class="tabs">
        <q-skeleton type="rect" width="72px" height="38px" class="sk-tab" />
        <q-skeleton type="rect" width="72px" height="38px" class="sk-tab" />
        <q-skeleton type="rect" width="60px" height="38px" class="sk-tab" />
      </div>
      <div class="group">
        <div v-for="n in 4" :key="n" class="doc-row">
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
        <p class="err-title">Couldn't load OSAS compliance</p>
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
            <!-- PROPERTY DOCUMENTS -->
            <q-tab-panel name="property" class="tab-panel">
              <EmptyState
                v-if="!accommodations.length"
                variant="compact"
                icon="lucide:building-2"
                title="No accommodations yet"
                message="Add an accommodation first — its permits and clearances will be tracked here."
              >
                <template #actions>
                  <q-btn unelevated rounded no-caps color="primary" label="Add accommodation" @click="router.push('/manager/properties/new')" />
                </template>
              </EmptyState>

              <template v-else>
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

                <p class="sec-hint">Accreditation depends on these staying current. Tap a document to view or upload.</p>
                <div class="group">
                  <div v-for="d in docs" :key="d.type" class="doc-item">
                    <button
                      type="button"
                      class="doc-row"
                      :aria-expanded="expandedProperty === d.type"
                      @click="toggleProperty(d.type)"
                    >
                      <span class="doc-icon" :class="`doc-icon--${d.tone}`">
                        <IconifyIcon :icon="d.icon" width="16" />
                      </span>
                      <span class="doc-body">
                        <span class="doc-name">{{ DOC_TYPE_LABEL[d.type] }}</span>
                        <span class="doc-when">{{ d.when }}</span>
                      </span>
                      <span class="doc-tag" :class="`doc-tag--${d.tone}`">{{ d.statusLabel }}</span>
                      <IconifyIcon icon="lucide:chevron-down" width="16" class="doc-chevron" :class="{ 'doc-chevron--on': expandedProperty === d.type }" />
                    </button>

                    <q-slide-transition>
                      <div v-if="expandedProperty === d.type" class="doc-detail">
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
                        <div class="doc-actions">
                          <button type="button" class="doc-action doc-action--primary" @click="openUploadDialog(d.type)">
                            <IconifyIcon icon="lucide:upload" width="14" />
                            {{ d.fileUrl ? 'Replace' : 'Upload' }}
                          </button>
                          <button v-if="d.fileUrl" type="button" class="doc-action" @click="openFile(d.fileUrl)">
                            <IconifyIcon icon="lucide:external-link" width="14" /> Open
                          </button>
                        </div>
                      </div>
                    </q-slide-transition>
                  </div>
                </div>
                <span v-if="uploadingDoc" class="sec-hint">Uploading…</span>
              </template>
            </q-tab-panel>

            <!-- MY DOCUMENTS (manager identity, reviewed by OSAS at registration) -->
            <q-tab-panel name="mine" class="tab-panel">
              <!-- 'reviewing' is a soft reject: OSAS wants a better document and
                   the account can still be verified once it arrives. -->
              <div v-if="myStatus === 'rejected' || myStatus === 'reviewing'" class="reject-banner">
                <IconifyIcon icon="lucide:triangle-alert" width="16" />
                <div>
                  <p class="reject-title">{{ myStatus === 'reviewing' ? 'More information needed' : 'Verification rejected' }}</p>
                  <p class="reject-text">{{ rejectionReason || 'OSAS needs a clearer copy — please re-upload below.' }}</p>
                </div>
              </div>
              <p class="sec-hint">Your own identity documents. Tap one to view or resubmit.</p>
              <div class="group">
                <div v-for="d in myDocs" :key="d.type" class="doc-item">
                  <button
                    type="button"
                    class="doc-row"
                    :aria-expanded="expandedMine === d.type"
                    @click="expandedMine = expandedMine === d.type ? '' : d.type"
                  >
                    <span class="doc-icon" :class="`doc-icon--${d.tone}`">
                      <IconifyIcon :icon="d.icon" width="16" />
                    </span>
                    <span class="doc-body">
                      <span class="doc-name">{{ DOC_LABEL[d.type] || d.type }}</span>
                      <span class="doc-when">{{ d.when }}</span>
                    </span>
                    <span class="doc-tag" :class="`doc-tag--${d.tone}`">{{ d.statusLabel }}</span>
                    <IconifyIcon icon="lucide:chevron-down" width="16" class="doc-chevron" :class="{ 'doc-chevron--on': expandedMine === d.type }" />
                  </button>

                  <q-slide-transition>
                    <div v-if="expandedMine === d.type" class="doc-detail">
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
                          <input type="file" accept="image/*,application/pdf" class="doc-file-input" @change="onMyDocSelected($event, d.type)" />
                        </label>
                        <button v-if="d.fileUrl" type="button" class="doc-action" @click="openFile(d.fileUrl)">
                          <IconifyIcon icon="lucide:external-link" width="14" /> Open
                        </button>
                      </div>
                    </div>
                  </q-slide-transition>
                </div>
              </div>
              <span v-if="uploadingMyDoc" class="sec-hint">Uploading…</span>
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
            </q-tab-panel>
          </q-tab-panels>
        </div>
      </div>
    </div>

    <!-- PERMIT UPLOAD FORM — a document already on file is never edited in
         place; replacing it always goes through this fresh form. -->
    <q-dialog v-model="uploadDialogOpen" position="bottom">
      <q-card class="new-sheet">
        <h3 class="new-title">{{ DOC_TYPE_LABEL[uploadDocType] }}</h3>
        <label class="field">
          <span class="field-label">File</span>
          <span class="file-picker" :class="{ 'file-picker--chosen': uploadForm.file }">
            <IconifyIcon :icon="uploadForm.file ? 'lucide:file-check' : 'lucide:upload'" width="16" />
            <span class="file-picker-text">{{ uploadForm.file ? uploadForm.file.name : 'Choose file' }}</span>
            <input type="file" accept="image/*,application/pdf" class="file-picker-input" @change="onUploadFileSelected" />
          </span>
        </label>
        <label class="field">
          <span class="field-label">Expiration date</span>
          <input v-model="uploadForm.expiresAt" type="date" class="field-input" />
        </label>
        <q-btn unelevated rounded no-caps color="primary" class="new-submit" :loading="uploadingDoc" label="Upload" @click="submitDocUpload" />
      </q-card>
    </q-dialog>

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
import { ref, reactive, computed, watch, onMounted, onUnmounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { since } from '@/utils/notifications'
import { useNotify } from '@/utils/notify'
import { uploadSecureDocument, secureDocUrl } from '@/utils/upload'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { DOC_LABEL, docPresentation } from '@/utils/profile'
import EmptyState from '@/components/shared/EmptyState.vue'

const TABS = [
  { key: 'property', label: 'Property' },
  { key: 'mine', label: 'My Docs' },
  { key: 'tickets', label: 'Tickets' },
] as const

const DOC_TYPES = ['sanitary_permit', 'fire_safety', 'business_permit', 'building_permit'] as const
const DOC_TYPE_LABEL: Record<string, string> = {
  sanitary_permit: 'Sanitary permit',
  fire_safety: 'Fire safety certificate',
  business_permit: 'Business permit',
  building_permit: 'Building permit',
}

// Fixed set uploaded once at manager registration (stores/auth.ts,
// submitManagerVerificationDocuments) — OSAS reviews these per-document via
// doc_status, independent of any accommodation.
const MY_DOC_TYPES = ['government_id', 'business_permit'] as const

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

const router = useRouter()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const tab = ref<(typeof TABS)[number]['key']>('property')

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
const accommodations = ref<Accommodation[]>([])
const selectedId = ref('')
const docRows = ref<{ doc_type: string; file_url: string; expires_at: string | null; uploaded_at: string; version: number }[]>([])
const expandedProperty = ref('')
const uploadingDoc = ref(false)

// A permit already on file is view-only — replacing it goes through this
// dialog's own blank form, never an inline field on the (read-only) row.
const uploadDialogOpen = ref(false)
const uploadDocType = ref('')
const uploadForm = reactive({ file: null as File | null, expiresAt: '' })

const myDocRows = ref<{ id: string; doc_type: string; file_url: string; filename: string | null; status: string; uploaded_at: string; verified_at: string | null }[]>([])
const expandedMine = ref('')
const uploadingMyDoc = ref(false)

const tickets = ref<Ticket[]>([])

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

// Property permits have no admin-reviewed status column yet (see the OSAS
// compliance brainstorm) — every tone here is expiry-derived, never a real
// OSAS approval, so replacement is never locked.
const docs = computed<DocRow[]>(() =>
  DOC_TYPES.map((type) => {
    const row = docRows.value.find((d) => d.doc_type === type)
    if (!row) {
      return { type, statusLabel: 'Not submitted', tone: 'idle', icon: 'lucide:circle-dashed', when: '', fileUrl: '', verified: false }
    }
    if (!row.expires_at) {
      // Expiry is required on upload now, so a null one only happens on a
      // legacy row from before that — flag it rather than reading as settled.
      return { type, statusLabel: 'No expiration set', tone: 'warn', icon: 'lucide:calendar-x', when: `Uploaded ${since(row.uploaded_at)}`, fileUrl: row.file_url, verified: false }
    }
    const now = Date.now()
    const soon = now + 30 * 24 * 60 * 60 * 1000
    const t = new Date(row.expires_at).getTime()
    if (t < now) return { type, statusLabel: 'Expired', tone: 'danger', icon: 'lucide:file-warning', when: `Expired ${since(row.expires_at)}`, fileUrl: row.file_url, verified: false }
    if (t < soon) return { type, statusLabel: 'Expiring soon', tone: 'warn', icon: 'lucide:calendar-clock', when: `Expires ${since(row.expires_at)}`, fileUrl: row.file_url, verified: false }
    return { type, statusLabel: 'Valid', tone: 'good', icon: 'lucide:check', when: `Expires ${since(row.expires_at)}`, fileUrl: row.file_url, verified: false }
  }),
)

const myDocs = computed<DocRow[]>(() =>
  MY_DOC_TYPES.map((type) => {
    const row = myDocRows.value.find((d) => d.doc_type === type)
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

async function loadDocsFor(accommodationId: string) {
  const { data, error: docError } = await supabase
    .from('accommodation_documents')
    .select('id, doc_type, file_url, expires_at, uploaded_at, version')
    .eq('accommodation_id', accommodationId)
    .order('version', { ascending: false })
  if (docError) throw docError

  const seen = new Set<string>()
  const latest = (data ?? []).filter((d) => {
    if (seen.has(d.doc_type)) return false
    seen.add(d.doc_type)
    return true
  })
  // Permits use Cloudinary authenticated delivery: file_url holds a ref, so each
  // one is signed for this viewer.
  docRows.value = await Promise.all(
    latest.map(async (d) => ({ ...d, file_url: await secureDocUrl('accommodation_documents', d.id) })),
  )
}

async function loadMyDocs(userId: string) {
  const { data, error: docError } = await supabase
    .from('verification_documents')
    .select('id, doc_type, file_url, filename, status, uploaded_at, verified_at')
    .eq('user_id', userId)
    .order('uploaded_at', { ascending: false })
  if (docError) throw docError

  const seen = new Set<string>()
  const latest = (data ?? []).filter((d) => {
    if (!d.doc_type || seen.has(d.doc_type)) return false
    seen.add(d.doc_type)
    return true
  })
  myDocRows.value = (await Promise.all(
    latest.map(async (d) => ({ ...d, file_url: await secureDocUrl('verification_documents', d.id) })),
  )) as typeof myDocRows.value
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

    const [{ data: accData, error: accError }, { data: ticketData, error: ticketError }, { data: userData, error: userError }] = await Promise.all([
      supabase.from('accommodations').select('id, name').eq('accommodation_manager_id', user.id).order('name'),
      supabase
        .from('tickets')
        .select('id, subject, description, category, status, reported_at')
        .eq('accommodation_manager_id', user.id)
        .order('reported_at', { ascending: false }),
      supabase.from('users').select('status').eq('id', user.id).maybeSingle(),
    ])
    if (accError) throw accError
    if (ticketError) throw ticketError
    if (userError) throw userError
    myStatus.value = userData?.status || ''
    if (myStatus.value === 'rejected' || myStatus.value === 'reviewing') {
      // verification_requests is the decision trail. This used to string-match a
      // notification *title*, so renaming that copy silently lost every reason.
      const { data: decision } = await supabase
        .from('verification_requests')
        .select('decision_notes, rejection_reasons')
        .eq('entity_type', 'user')
        .eq('entity_id', user.id)
        .order('reviewed_at', { ascending: false })
        .limit(1)
        .maybeSingle()
      rejectionReason.value =
        decision?.decision_notes || (decision?.rejection_reasons ?? []).join(', ') || ''
    }

    accommodations.value = (accData ?? []).map((a) => ({ id: a.id, name: a.name?.trim() || 'Unnamed accommodation' }))
    selectedId.value = accommodations.value[0]?.id || ''
    if (selectedId.value) await loadDocsFor(selectedId.value)
    await loadMyDocs(user.id)

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

function toggleProperty(type: string) {
  expandedProperty.value = expandedProperty.value === type ? '' : type
}

function openUploadDialog(type: string) {
  uploadDocType.value = type
  uploadForm.file = null
  uploadForm.expiresAt = ''
  uploadDialogOpen.value = true
}

function onUploadFileSelected(event: Event) {
  const input = event.target as HTMLInputElement
  uploadForm.file = input.files?.[0] || null
}

async function submitDocUpload() {
  if (!uploadForm.file) {
    notify.error('Choose a file.')
    return
  }
  if (!uploadForm.expiresAt) {
    notify.error('Pick an expiration date.')
    return
  }
  if (!selectedId.value) return

  uploadingDoc.value = true
  try {
    const docType = uploadDocType.value
    const url = await uploadSecureDocument(uploadForm.file)
    const existing = docRows.value.find((d) => d.doc_type === docType)
    const { error: insertError } = await supabase.from('accommodation_documents').insert({
      accommodation_id: selectedId.value,
      doc_type: docType,
      file_url: url,
      expires_at: uploadForm.expiresAt,
      version: existing ? existing.version + 1 : 1,
    })
    if (insertError) throw insertError

    await loadDocsFor(selectedId.value)
    uploadDialogOpen.value = false
    notify.success('Uploaded.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload this document.'))
  } finally {
    uploadingDoc.value = false
  }
}

async function onMyDocSelected(event: Event, docType: string) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file || !myId.value) return
  uploadingMyDoc.value = true
  try {
    const url = await uploadSecureDocument(file)
    const existing = myDocRows.value.find((d) => d.doc_type === docType)

    // Resubmission updates the same row back to pending rather than inserting
    // a duplicate — verification_documents has no version column to
    // disambiguate "latest" the way accommodation_documents does.
    const { error: writeError } = existing
      ? await supabase
          .from('verification_documents')
          .update({ file_url: url, filename: file.name, status: 'pending', uploaded_at: new Date().toISOString(), verified_at: null })
          .eq('id', existing.id)
      : await supabase.from('verification_documents').insert({
          user_id: myId.value,
          doc_type: docType,
          file_url: url,
          filename: file.name,
          status: 'pending',
        })
    if (writeError) throw writeError

    // A rejected account has to be put back in the queue, or the re-upload is
    // never looked at. No-ops for any other status.
    const { error: resubmitError } = await supabase.rpc('resubmit_verification')
    if (resubmitError) throw resubmitError
    if (myStatus.value === 'rejected') myStatus.value = 'pending'

    await loadMyDocs(myId.value)
    notify.success('Uploaded.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload this document.'))
  } finally {
    uploadingMyDoc.value = false
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
  margin-bottom: 4px;
}
.chip {
  padding: 6px 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
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
.file-picker {
  position: relative;
  display: flex;
  min-height: 44px;
  align-items: center;
  gap: 8px;
  padding: 0 12px;
  border: 1px dashed var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-muted);
  cursor: pointer;
}
.file-picker--chosen {
  border-style: solid;
  border-color: var(--m-primary);
  color: var(--m-primary-dark);
}
.file-picker-text {
  flex: 1;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.file-picker-input {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  cursor: pointer;
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
