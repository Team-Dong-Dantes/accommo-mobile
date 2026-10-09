<template>
  <!-- Beside its list rather than over it on a landscape tablet; see
       `.page-split` in app.scss. -->
  <!-- Desktop: requirements (left) and support tickets (right) are the two halves
       of a card; tablet keeps list-beside-thread. -->
  <q-page class="op" :class="{ 'page-split': isTablet && !isDesktop, 'page-wide': isDesktop }">
    <q-pull-to-refresh @refresh="onPull">
      <!-- Desktop: the loaded card's two halves, not the phone's tabs. -->
      <div v-if="loading && isDesktop" class="stack">
        <div class="desk-card">
          <div class="desk-col">
            <h2 class="desk-col-title">Requirements</h2>
            <q-skeleton type="rect" height="34px" class="sk-card" />
            <q-skeleton type="rect" height="84px" class="sk-card" />
            <q-skeleton type="rect" height="180px" class="sk-card" />
          </div>
          <div class="desk-col">
            <h2 class="desk-col-title">Support tickets</h2>
            <q-skeleton v-for="n in 2" :key="n" type="rect" height="84px" class="sk-card" />
          </div>
        </div>
      </div>

      <div v-else-if="loading" class="stack">
        <div class="tabs">
          <q-skeleton type="rect" width="72px" height="38px" class="m-sk-tab" />
          <q-skeleton type="rect" width="72px" height="38px" class="m-sk-tab" />
          <q-skeleton type="rect" width="60px" height="38px" class="m-sk-tab" />
        </div>
        <q-skeleton type="rect" height="84px" class="sk-card" />
        <div class="sk-grid">
          <q-skeleton v-for="n in 4" :key="n" type="rect" height="180px" class="sk-card" />
        </div>
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load OSAS" :detail="error" :retry="load" inset />
      </div>

      <div v-else class="stack">
        <div class="m-tabbed">
          <div v-if="!isDesktop" class="tabs">
            <button v-for="t in TABS" :key="t.key" type="button" class="m-tab" :class="{ 'm-tab--on': tab === t.key }" @click="tab = t.key">
              {{ t.label }}
            </button>
          </div>

          <div :class="isDesktop ? 'desk-card osas-card' : 'panel'">
            <component :is="panelsIs" v-bind="panelsProps" :class="isDesktop ? 'desk-contents' : 'm-panels'">
              <!-- Desktop: property and personal requirements share the left half,
                   switched here; tickets have the right half to themselves. -->
              <div v-if="isDesktop" class="osas-left-head">
                <h2 class="desk-col-title">Requirements</h2>
                <div class="seg" role="tablist" aria-label="Requirements">
                  <button
                    v-for="o in LEFT_TABS"
                    :key="o.key"
                    type="button"
                    role="tab"
                    class="seg-btn"
                    :class="{ 'seg-btn--on': leftTab === o.key }"
                    :aria-selected="leftTab === o.key"
                    @click="leftTab = o.key"
                  >
                    {{ o.label }}
                  </button>
                </div>
              </div>
              <!-- PROPERTY DOCUMENTS -->
              <component :is="panelIs" v-show="!isDesktop || leftTab === 'property'" name="property" :class="isDesktop ? 'desk-col osas-left' : 'tab-panel'">
                <EmptyState
                  v-if="!accommodations.length"
                  variant="compact"
                  icon="lucide:building-2"
                  title="No accommodations yet"
                  :message="auth.isVerifiedLandlord
                    ? 'Add an accommodation first — its permits and clearances will be tracked here.'
                    : 'Once OSAS verifies your account, add an accommodation and its permits will be tracked here.'"
                >
                  <template #actions>
                    <q-btn unelevated rounded no-caps color="primary" label="Add accommodation" :disable="!auth.isVerifiedLandlord" @click="router.push('/manager/properties/new')" />
                  </template>
                </EmptyState>

                <template v-else>
                  <!-- Which accommodation's permits are on screen; a menu
                       switches when there is more than one. -->
                  <button type="button" class="prop-head" :disabled="accommodations.length < 2">
                    <span class="prop-icon"><IconifyIcon icon="lucide:building-2" width="18" /></span>
                    <span class="prop-body">
                      <span class="prop-name">{{ selected?.name }}</span>
                      <span v-if="selected?.place" class="prop-place">{{ selected.place }}</span>
                    </span>
                    <span v-if="selected" class="ticket-chip" :class="`ticket-chip--${ACCOMMODATION_STATUS_TONE[selected.status] ?? 'grey'}`">
                      {{ ACCOMMODATION_STATUS_LABEL[selected.status] ?? selected.status }}
                    </span>
                    <IconifyIcon v-if="accommodations.length > 1" icon="lucide:chevrons-up-down" width="16" class="prop-caret" />
                    <q-menu v-if="accommodations.length > 1" fit anchor="bottom left" self="top left">
                      <q-list>
                        <q-item v-for="a in accommodations" :key="a.id" v-close-popup clickable :active="a.id === selectedId" @click="selectedId = a.id">
                          <q-item-section>
                            <q-item-label>{{ a.name }}</q-item-label>
                            <q-item-label v-if="a.place" caption>{{ a.place }}</q-item-label>
                          </q-item-section>
                          <q-item-section side>
                            <span class="ticket-chip" :class="`ticket-chip--${ACCOMMODATION_STATUS_TONE[a.status] ?? 'grey'}`">
                              {{ ACCOMMODATION_STATUS_LABEL[a.status] ?? a.status }}
                            </span>
                          </q-item-section>
                        </q-item>
                      </q-list>
                    </q-menu>
                  </button>

                  <RequirementCards :items="docs" noun="permits" done-word="valid" :busy="uploadingDoc" @upload="openUploadDialog($event)" />
                </template>
              </component>

              <!-- MY REQUIREMENTS (landlord/landlady identity, reviewed by OSAS at registration) -->
              <component :is="panelIs" v-show="!isDesktop || leftTab === 'mine'" name="mine" :class="isDesktop ? 'desk-col osas-left' : 'tab-panel'">
                <!-- 'reviewing' is a soft reject: OSAS wants a better document and
                     the account can still be verified once it arrives. -->
                <div v-if="myStatus === 'rejected' || myStatus === 'needs_resubmission' || myStatus === 'reviewing'" class="reject-banner">
                  <IconifyIcon icon="lucide:triangle-alert" width="16" />
                  <div>
                    <p class="reject-title">{{ myStatus === 'reviewing' ? 'More information needed' : myStatus === 'needs_resubmission' ? 'OSAS asked for new requirements' : 'Verification rejected' }}</p>
                    <p class="reject-text">{{ rejectionReason || 'OSAS needs a clearer copy — please re-upload below.' }}</p>
                  </div>
                </div>
                <RequirementCards :items="myDocs" noun="requirements" done-word="approved" replace-label="Resubmit" :busy="uploadingMyDoc" @upload="openUploadDialog($event, 'account')" />
              </component>

              <!-- TICKETS -->
              <!-- On desktop this is the right half: the list, or — in its
                   place, with their own way back — the open ticket or the
                   new-ticket form. -->
              <component
                :is="panelIs"
                name="tickets"
                :class="isDesktop ? ['desk-col', 'osas-right', { 'desk-col--fill': openTicket || newTicketOpen }] : 'tab-panel'"
              >
                <TicketCompose
                  v-if="isDesktop && newTicketOpen"
                  class="desk-inpanel"
                  :categories="TICKET_CATEGORIES"
                  :submitting="submittingTicket"
                  @close="newTicketOpen = false"
                  @submit="submitTicket"
                />
                <TicketThread
                  v-else-if="isDesktop && openTicket"
                  :key="openTicket.id"
                  class="desk-inpanel"
                  :ticket="openTicket"
                  @close="closeTicket"
                />
                <template v-else>
                  <h2 v-if="isDesktop" class="desk-col-title">Support tickets</h2>
                  <div class="sec-head">
                    <p class="sec-hint">Raise a ticket for anything OSAS needs to look into.</p>
                    <button v-if="!isDesktop" type="button" class="sec-link" @click="openNewTicket">New ticket</button>
                  </div>

                  <EmptyState
                    v-if="!tickets.length"
                    variant="compact"
                    icon="lucide:life-buoy"
                    title="No tickets yet"
                    message="Accreditation or technical issues you raise with OSAS will show up here."
                  />
                  <div v-else class="group">
                    <button v-for="t in tickets" :key="t.id" type="button" class="ticket-row" @click="showTicket(t)">
                      <span class="ticket-body">
                        <span class="ticket-subject">{{ t.subject }}</span>
                        <span class="ticket-when">{{ since(t.reportedAt) }}</span>
                      </span>
                      <span class="ticket-chip" :class="`ticket-chip--${statusColor(TICKET_STATUS, t.status)}`">{{ statusText(TICKET_STATUS, t.status) }}</span>
                    </button>
                  </div>

                  <!-- Desktop: the tickets half's footer. -->
                  <div v-if="isDesktop" class="desk-foot">
                    <button type="button" class="desk-foot-btn" @click="openNewTicket">
                      <IconifyIcon icon="lucide:plus" width="17" />
                      New ticket
                    </button>
                  </div>
                </template>
              </component>
            </component>
          </div>
        </div>
      </div>
    </q-pull-to-refresh>

    <!-- PERMIT UPLOAD FORM — a document already on file is never edited in
         place; replacing it always goes through this fresh form. -->
    <AppModal v-model="uploadDialogOpen" :title="DOC_TYPE_LABEL[uploadDocType]">
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
        <DateTimeField v-model="uploadForm.expiresAt" mode="date" placeholder="Pick an expiry date" />
      </label>
      <template #footer>
        <q-btn unelevated rounded no-caps color="primary" class="new-submit" :loading="uploadingDoc || uploadingMyDoc" label="Upload" @click="submitDocUpload" />
      </template>
    </AppModal>

    <!-- Phone and tablet: the thread covers the list (phone) or sits beside it
         (tablet). Desktop shows it inside the tickets half above. -->
    <TicketThread v-if="openTicket && !isDesktop" :key="openTicket.id" :ticket="openTicket" @close="closeTicket" />

    <div v-else-if="isTablet && !isDesktop" class="page-split-empty">
      <IconifyIcon icon="lucide:ticket" width="26" />
      <p>Pick a ticket to read the thread</p>
    </div>

    <TicketCompose
      v-if="newTicketOpen && !isDesktop"
      :categories="TICKET_CATEGORIES"
      :submitting="submittingTicket"
      @close="newTicketOpen = false"
      @submit="submitTicket"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { since } from '@/utils/notifications'
import { useNotify } from '@/utils/notify'
import { uploadSecureDocument, secureDocUrl, signRows } from '@/utils/upload'
import { expiryProblem, permitDate, permitReplaceOpen, savePermitVersion, uploadPermitFile } from '@/utils/permits'
import { ACCOMMODATION_STATUS_LABEL, ACCOMMODATION_STATUS_TONE } from '@/utils/listings'
import { DOC_LABEL, docPresentation } from '@/utils/profile'
import { parseServerTime, statusText, statusColor, TICKET_STATUS } from '@/utils/format'
import { chatFullscreen } from '@/utils/chatFullscreen'
import { isTablet, isDesktop } from '@/utils/useTabletMode'
import { useDeskPanels } from '@/utils/useDeskPanels'
import EmptyState from '@/components/shared/EmptyState.vue'
import TicketThread from '@/components/shared/TicketThread.vue'
import TicketCompose, { type TicketDraft } from '@/components/shared/TicketCompose.vue'
import DateTimeField from '@/components/shared/DateTimeField.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import RequirementCards, { type RequirementItem } from '@/components/shared/RequirementCards.vue'
import AppModal from '@/components/shared/AppModal.vue'

// `compliance` is the stored DB value — legacy rows and the admin client both
// read it, so only the label follows the app's "accreditation" wording.
const TICKET_CATEGORIES = [
  { value: 'compliance', label: 'Accreditation' },
  { value: 'accommodation', label: 'Accommodation' },
  { value: 'technical', label: 'Technical / app issue' },
  { value: 'other', label: 'Other' },
]

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

// Fixed set uploaded once at landlord/landlady registration (stores/auth.ts,
// submitManagerVerificationDocuments) — OSAS reviews these per-document via
// doc_status, independent of any accommodation.
const MY_DOC_TYPES = ['government_id', 'business_permit'] as const

interface Accommodation {
  id: string
  name: string
  /** "Barangay, City" — how listings show an address. */
  place: string
  status: string
}
interface Ticket {
  id: string
  subject: string
  description: string
  category: string
  status: string
  reportedAt: string
  photoUrls: string[]
  ticketNo: number | null
}

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const tab = ref<(typeof TABS)[number]['key']>('property')
// Desktop: all three tabs at once — property and personal requirements share
// the left half (switched by leftTab), tickets take the right.
const { panelsIs, panelIs, panelsProps } = useDeskPanels(tab)
const LEFT_TABS = [
  { key: 'property', label: 'Property' },
  { key: 'mine', label: 'My requirements' },
] as const
const leftTab = ref<(typeof LEFT_TABS)[number]['key']>('property')

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
const permitRows = ref<{ id: string; accommodation_id: string; doc_type: string; file_url: string; expires_at: string | null; uploaded_at: string; version: number }[]>([])
const uploadingDoc = ref(false)
/** Per sent-back accommodation: the permits OSAS flagged, and when it decided. */
const sentBack = ref<Record<string, { docs: string[]; decidedAt: number }>>({})

// A permit already on file is view-only — replacing it goes through this
// dialog's own blank form, never an inline field on the (read-only) row.
const uploadDialogOpen = ref(false)
const uploadDocType = ref('')
/**
 * The upload sheet serves both document sets. A property permit goes to
 * `accommodation_documents` against the selected accommodation; an account
 * document goes to `verification_documents` against this landlord/landlady. They differ
 * in where the row lands, not in what is collected, so they share one form.
 */
type UploadTarget = 'property' | 'account'
const uploadTarget = ref<UploadTarget>('property')
const uploadForm = reactive({ file: null as File | null, expiresAt: '' })

const myDocRows = ref<{ id: string; doc_type: string; file_url: string; filename: string | null; status: string; uploaded_at: string; verified_at: string | null }[]>([])
const uploadingMyDoc = ref(false)

const tickets = ref<Ticket[]>([])

// Property permits have no per-file approval: a tone is expiry-derived unless
// OSAS flagged the permit when sending the listing back. Replacement locks once
// the listing is accredited (permitReplaceOpen).
const docs = computed<RequirementItem[]>(() =>
  DOC_TYPES.map((type) => {
    const label = DOC_TYPE_LABEL[type] ?? type
    const row = permitRows.value.find((d) => d.accommodation_id === selectedId.value && d.doc_type === type)
    if (!row) return { type, label, statusLabel: 'Not submitted', tone: 'idle', when: '', fileUrl: '', verified: false }
    const link = signed.value[row.id]
    // OSAS's verdict outranks the date: a permit it flagged when sending the
    // listing back needs a new file, however far off its expiry is.
    const flag = sentBack.value[selectedId.value]
    const flagged = Boolean(flag?.docs.includes(type) && parseServerTime(row.uploaded_at).getTime() <= flag.decidedAt)
    // Locked once accredited unless expiring or flagged; shown as "Verified".
    const locked = !permitReplaceOpen(selected.value?.status ?? '', row.expires_at, flagged)
    const base = { type, label, fileUrl: link?.url ?? '', fileLoading: !link, verified: locked }
    if (flagged) {
      return { ...base, statusLabel: 'Needs resubmission', tone: 'danger', when: 'OSAS asked for a new file' }
    }
    // Expiry is required on upload now, so a null one only happens on a
    // legacy row from before that — flag it rather than reading as settled.
    if (!row.expires_at) return { ...base, statusLabel: 'No expiration set', tone: 'warn', when: `Uploaded ${since(row.uploaded_at)}` }
    const now = Date.now()
    const soon = now + 30 * 24 * 60 * 60 * 1000
    const t = new Date(row.expires_at).getTime()
    if (t < now) return { ...base, statusLabel: 'Expired', tone: 'danger', when: `Expired ${permitDate(row.expires_at)}` }
    if (t < soon) return { ...base, statusLabel: 'Expiring soon', tone: 'warn', when: `Expires ${permitDate(row.expires_at)}` }
    return { ...base, statusLabel: 'Valid', tone: 'good', when: `Expires ${permitDate(row.expires_at)}` }
  }),
)

const myDocs = computed<RequirementItem[]>(() =>
  MY_DOC_TYPES.map((type) => {
    const label = DOC_LABEL[type] ?? type
    const row = myDocRows.value.find((d) => d.doc_type === type)
    if (!row) return { type, label, statusLabel: 'Not submitted', tone: 'idle', when: '', fileUrl: '', verified: false }
    // Once the account is verified that overrides an old row stuck at 'pending'.
    // Otherwise the row speaks for itself: OSAS marks only the documents it
    // wants again, so a sent-back account can still have an approved one.
    const effectiveStatus = myStatus.value === 'verified' ? 'approved' : row.status === 'rejected' && myStatus.value === 'needs_resubmission' ? 'resubmit' : row.status
    const presentation = docPresentation(effectiveStatus)
    const when = row.verified_at ? `Reviewed ${since(row.verified_at)}` : `Sent ${since(row.uploaded_at)}`
    return { type, label, statusLabel: presentation.label, tone: presentation.tone, when, fileUrl: row.file_url, verified: effectiveStatus === 'approved' }
  }),
)

const selected = computed(() => accommodations.value.find((a) => a.id === selectedId.value))

/**
 * Every accommodation's latest permits, fetched in one query, so switching
 * between boarding houses needs no round trip for statuses or dates. Only the
 * file links are fetched per accommodation (signPermits), since each one is a
 * call to the doc-access function.
 */
async function loadPermits() {
  const ids = accommodations.value.map((a) => a.id)
  if (!ids.length) {
    permitRows.value = []
    return
  }
  // Sent back for revision, or a permit update sent back on a live listing.
  const returnedIds = accommodations.value
    .filter((a) => ['needs_revision', 'accredited', 'delisted'].includes(a.status))
    .map((a) => a.id)
  const [{ data, error: docError }, { data: rounds, error: roundError }] = await Promise.all([
    supabase
      .from('accommodation_documents')
      .select('id, accommodation_id, doc_type, file_url, expires_at, uploaded_at, version')
      .in('accommodation_id', ids)
      .order('version', { ascending: false }),
    supabase
      .from('accreditation_rounds')
      .select('accommodation_id, flagged_docs, decided_at')
      .in('accommodation_id', returnedIds)
      .eq('decision', 'returned')
      .order('round', { ascending: false }),
  ])
  if (docError) throw docError
  if (roundError) throw roundError

  // Newest send-back per accommodation only; rounds come newest first.
  const flags: typeof sentBack.value = {}
  for (const r of rounds ?? []) {
    if (flags[r.accommodation_id] || !r.decided_at) continue
    flags[r.accommodation_id] = { docs: r.flagged_docs ?? [], decidedAt: parseServerTime(r.decided_at).getTime() }
  }
  sentBack.value = flags

  const seen = new Set<string>()
  permitRows.value = (data ?? []).filter((d) => {
    const key = `${d.accommodation_id}:${d.doc_type}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
}

// doc-access links live 5 minutes; reuse one for 4 so it never expires on screen.
const SIGNED_FOR_MS = 4 * 60 * 1000
const signed = ref<Record<string, { url: string; at: number }>>({})

/** Signs the selected accommodation's files that have no fresh link yet. */
async function signPermits(accommodationId: string) {
  const now = Date.now()
  await Promise.all(
    permitRows.value
      .filter((d) => d.accommodation_id === accommodationId && !(now - (signed.value[d.id]?.at ?? 0) < SIGNED_FOR_MS))
      .map(async (d) => {
        // Permits use Cloudinary authenticated delivery: file_url holds a ref,
        // so each one is signed for this viewer.
        const url = await secureDocUrl('accommodation_documents', d.id)
        signed.value = { ...signed.value, [d.id]: { url, at: Date.now() } }
      }),
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
    const { data: authData } = await authUser()
    const user = authData?.user
    if (!user) {
      error.value = 'Not signed in.'
      return
    }
    myId.value = user.id

    const [{ data: accData, error: accError }, { data: ticketData, error: ticketError }, { data: userData, error: userError }] = await Promise.all([
      supabase.from('accommodations').select('id, name, barangay, city, status').eq('landlord_id', user.id).order('name'),
      supabase
        .from('tickets')
        .select('id, ticket_no, subject, description, category, status, reported_at, photo_urls')
        .eq('landlord_id', user.id)
        .order('reported_at', { ascending: false }),
      supabase.from('users').select('status').eq('id', user.id).maybeSingle(),
    ])
    if (accError) throw accError
    if (ticketError) throw ticketError
    await signRows('tickets', ticketData, 'photo_urls')
    if (userError) throw userError
    myStatus.value = userData?.status || ''
    if (myStatus.value === 'rejected' || myStatus.value === 'needs_resubmission' || myStatus.value === 'reviewing') {
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

    accommodations.value = (accData ?? []).map((a) => ({
      id: a.id,
      name: a.name?.trim() || 'Unnamed accommodation',
      place: [a.barangay, a.city].filter(Boolean).join(', '),
      status: a.status,
    }))
    // ?accommodation= comes from a draft's "Attach permits" in the editor.
    const asked = accommodations.value.find((a) => a.id === route.query.accommodation)
    selectedId.value = asked?.id || accommodations.value[0]?.id || ''
    await loadPermits()
    if (selectedId.value) void signPermits(selectedId.value)
    await loadMyDocs(user.id)

    tickets.value = (ticketData ?? []).map((t) => ({
      id: t.id,
      subject: t.subject || 'Untitled',
      description: t.description || '',
      category: t.category || 'other',
      status: t.status,
      reportedAt: t.reported_at,
      photoUrls: t.photo_urls ?? [],
      ticketNo: t.ticket_no,
    }))
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

watch(selectedId, (id) => {
  if (id) void signPermits(id)
})

function openUploadDialog(type: string, target: UploadTarget = 'property') {
  uploadDocType.value = type
  uploadTarget.value = target
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
  if (uploadTarget.value === 'account') {
    await submitMyDocUpload()
    return
  }
  if (!selectedId.value) return
  const expiryError = expiryProblem(uploadForm.expiresAt)
  if (expiryError) {
    notify.error(expiryError)
    return
  }

  uploadingDoc.value = true
  try {
    // The same path as the wizard and the listing's Replace button: checked
    // for legibility, shrunk, hashed, saved as the next version (utils/permits).
    const uploaded = await uploadPermitFile(uploadForm.file)
    await savePermitVersion(selectedId.value, uploadDocType.value, uploaded, uploadForm.expiresAt)

    await loadPermits()
    await signPermits(selectedId.value)
    uploadDialogOpen.value = false
    notify.success('Uploaded.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload this document.'))
  } finally {
    uploadingDoc.value = false
  }
}

/**
 * An account document — government ID or business permit — now goes through the
 * same sheet as a property permit, so it carries an expiry date. It used to be
 * a bare file input that wrote the row immediately, which meant OSAS could see
 * a landlord/landlady's permit had been approved but not that it had since lapsed.
 */
async function submitMyDocUpload() {
  const file = uploadForm.file
  if (!file || !myId.value) return
  uploadingMyDoc.value = true
  try {
    const docType = uploadDocType.value
    const url = await uploadSecureDocument(file)

    // Resubmission replaces the same row rather than adding a duplicate —
    // verification_documents has no version column to disambiguate "latest"
    // the way accommodation_documents does, and (user_id, doc_type) is unique.
    // The find-then-update-or-insert this replaced only caught a duplicate the
    // page had already loaded; the constraint catches every case.
    const { error: writeError } = await supabase.from('verification_documents').upsert(
      {
        user_id: myId.value,
        doc_type: docType,
        file_url: url,
        filename: file.name,
        status: 'pending' as const,
        expires_at: uploadForm.expiresAt,
        uploaded_at: new Date().toISOString(),
        verified_at: null,
      },
      { onConflict: 'user_id,doc_type' },
    )
    if (writeError) throw writeError

    // A rejected account has to be put back in the queue, or the re-upload is
    // never looked at. No-ops for any other status.
    const { error: resubmitError } = await supabase.rpc('resubmit_verification')
    if (resubmitError) throw resubmitError
    if (myStatus.value === 'rejected' || myStatus.value === 'needs_resubmission') myStatus.value = 'pending'

    await loadMyDocs(myId.value)
    uploadDialogOpen.value = false
    notify.success('Uploaded.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload this document.'))
  } finally {
    uploadingMyDoc.value = false
  }
}

// ?t=<id> opens the ticket thread over this page, so the hardware/browser back
// button closes it — the same arrangement MessagesPage uses for a conversation.
const openTicket = computed(
  () => tickets.value.find((t) => t.id === route.query.t) ?? null,
)
function showTicket(t: Ticket) {
  void router.push({ path: route.path, query: { t: t.id } })
}
function closeTicket() {
  void router.push({ path: route.path })
}

// An open thread covers the screen, so the shell's nav and FAB step aside.
watch(openTicket, (t) => { chatFullscreen.value = Boolean(t) }, { immediate: true })
onUnmounted(() => { chatFullscreen.value = false })

const newTicketOpen = ref(false)
const submittingTicket = ref(false)

function openNewTicket() {
  newTicketOpen.value = true
}

// TicketCompose owns the form and its validation; this only does the insert.
async function submitTicket(draft: TicketDraft) {
  if (submittingTicket.value) return
  submittingTicket.value = true
  try {
    const { data: authData } = await authUser()
    const user = authData?.user
    if (!user) throw new Error('Not signed in.')

    const { data: created, error: insertError } = await supabase
      .from('tickets')
      .insert({
        landlord_id: user.id,
        accommodation_id: selectedId.value || null,
        subject: draft.subject,
        description: draft.description || null,
        category: draft.category,
        status: 'open',
        priority: 'medium',
      })
      .select('id, ticket_no, subject, description, category, status, reported_at, photo_urls')
      .single()
    if (insertError) throw insertError
    await signRows('tickets', [created], 'photo_urls')

    tickets.value = [
      { id: created.id, subject: created.subject || 'Untitled', description: created.description || '', category: created.category || 'other', status: created.status, reportedAt: created.reported_at, photoUrls: created.photo_urls ?? [], ticketNo: created.ticket_no },
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

// This screen is kept alive (see MainLayout's KEEP_ALIVE_PAGES), so without
// this it would fetch once and never again — an OSAS decision or ticket reply
// would not surface until the app restarted. The permit watch follows the
// accommodation currently selected in the chip row, which is the only one
// whose documents are on screen.
const { refresh } = useLiveData({
  key: 'manager-osas',
  load,
  watch: (uid) => [
    ...(selectedId.value
      ? [{ table: 'accommodation_documents', filter: `accommodation_id=eq.${selectedId.value}` }]
      : []),
    { table: 'verification_documents', filter: `user_id=eq.${uid}` },
    { table: 'tickets', filter: `landlord_id=eq.${uid}` },
  ],
})

// Pull-to-refresh goes through useLiveData's refresh rather than load(): it
// loads silently (no skeleton behind the spinner) and resets the freshness
// clock, so returning to the screen does not immediately fetch again.
function onPull(done: () => void) {
  void refresh().finally(done)
}
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

/* Same rounded-top pill tabs fused into a bordered panel used by
   AccommodationDetail.vue / TenantProfile.vue / ManagerTenantsPage.vue —
   the default tabbed-section design for this app. */
/* QPullToRefresh wraps the page body in two plain <div>s of its own, which
   land between the q-page and .stack and break the flex chain the bottom-flush
   panel needs — .stack's flex:1 measures against a block box that just hugs its
   content, so the card stops wherever the content happens to end. Passing the
   chain through them costs nothing: neither div clips or scrolls. */
:deep(.q-pull-to-refresh),
:deep(.q-pull-to-refresh__content) {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
}
.tabs {
  position: relative;
  z-index: 2;
  display: flex;
  gap: 4px;
  margin: 0 calc(var(--m-page-gutter) * -1) -2px;
  padding: 0 var(--m-page-gutter);
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
.tab-panel {
  display: flex;
  flex-direction: column;
  gap: 12px;
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

.sk-card {
  border-radius: var(--m-radius);
}
.sk-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

/* The accommodation whose permits are listed below — a menu switches it. */
.prop-head {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  color: inherit;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.prop-head:disabled {
  cursor: default;
}
.prop-icon {
  display: grid;
  width: 38px;
  height: 38px;
  flex: 0 0 38px;
  place-items: center;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.prop-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.prop-name {
  overflow: hidden;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.prop-place {
  color: var(--m-muted);
  font-size: 12px;
}
.prop-caret {
  flex: 0 0 auto;
  color: var(--m-muted);
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
.ticket-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
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
.new-submit {
  flex: 1;
  min-height: 48px;
  font-weight: 700;
}
/* ---- Desktop: requirements | tickets ----
   The card (.desk-card) is two columns and two rows here: the left column is
   a switch (row 1) over whichever requirements list is picked (row 2, both
   lists share that cell); tickets span both rows on the right. */
.osas-card {
  grid-template-rows: auto minmax(0, 1fr);
}
/* The left half's header: the same title as "Support tickets" opposite, and a
   two-way switch under it — a flat segmented control rather than the phone's
   folder tabs, which only read as tabs when fused into a bordered panel. */
.osas-left-head {
  grid-area: 1 / 1;
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 14px 18px 10px;
}
.seg {
  display: flex;
  gap: 2px;
  padding: 3px;
  border-radius: 999px;
  background: var(--m-bg);
}
.seg-btn {
  flex: 1;
  min-height: 34px;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  transition: background-color 0.15s ease, color 0.15s ease;
}
.seg-btn:hover:not(.seg-btn--on) {
  color: var(--m-ink);
}
.seg-btn--on {
  background: var(--m-surface);
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.12);
  color: var(--m-primary-dark);
}
.desk-card .osas-left.desk-col {
  grid-area: 2 / 1;
  padding-top: 4px;
  border-left: 0;
}
.desk-card .osas-right.desk-col {
  grid-area: 1 / 2 / 3 / 3;
  border-left: 1px solid var(--m-border);
}
</style>
