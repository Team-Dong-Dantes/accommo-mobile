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
                  <AccommodationSwitch v-model="selectedId" :accommodations="accommodations" />

                  <RequirementCards :items="docs" noun="permits" done-word="valid" :busy="uploadingDoc" @upload="openUploadDialog($event)" />
                </template>
              </component>

              <!-- MY REQUIREMENTS (landlord/landlady identity, reviewed by OSAS at registration) -->
              <component :is="panelIs" v-show="!isDesktop || leftTab === 'mine'" name="mine" :class="isDesktop ? 'desk-col osas-left' : 'tab-panel'">
                <RejectBanner :status="myStatus" :reason="rejectionReason" />
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
                <TicketList
                  v-else
                  :tickets="tickets"
                  empty-message="Accreditation or technical issues you raise with OSAS will show up here."
                  @open="showTicket"
                  @new="openNewTicket"
                >
                  Raise a ticket for anything OSAS needs to look into.
                </TicketList>
              </component>
            </component>
          </div>
        </div>
      </div>
    </q-pull-to-refresh>

    <!-- PERMIT UPLOAD FORM — a document already on file is never edited in
         place; replacing it always goes through this fresh form. -->
    <DocUploadModal v-model="uploadDialogOpen" :title="DOC_TYPE_LABEL[uploadDocType]" :loading="uploadingDoc || uploadingMyDoc" @submit="submitDocUpload" />

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
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { uploadSecureDocument } from '@/utils/upload'
import { useOsasTickets, toTickets, TICKET_SELECT } from '@/utils/useOsasTickets'
import { expiryProblem, savePermitVersion, uploadPermitFile } from '@/utils/permits'
import { useOsasPermits, DOC_TYPE_LABEL } from '@/utils/useOsasPermits'
import { accountDocItem, latestSignedDocs, type AccountDocRow } from '@/utils/profile'
import { isTablet, isDesktop } from '@/utils/useTabletMode'
import { useDeskPanels } from '@/utils/useDeskPanels'
import EmptyState from '@/components/shared/EmptyState.vue'
import TicketThread from '@/components/shared/TicketThread.vue'
import TicketCompose from '@/components/shared/TicketCompose.vue'
import TicketList from '@/components/shared/TicketList.vue'
import RejectBanner from '@/components/shared/RejectBanner.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import RequirementCards, { type RequirementItem } from '@/components/shared/RequirementCards.vue'
import AccommodationSwitch from '@/components/manager/AccommodationSwitch.vue'
import DocUploadModal, { type DocUpload } from '@/components/manager/DocUploadModal.vue'

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

// Fixed set uploaded once at landlord/landlady registration (stores/auth.ts,
// submitManagerVerificationDocuments) — OSAS reviews these per-document via
// doc_status, independent of any accommodation.
const MY_DOC_TYPES = ['government_id', 'business_permit'] as const

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
const { accommodations, selectedId, docs, loadPermits, signPermits } = useOsasPermits()
const uploadingDoc = ref(false)

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

const myDocRows = ref<AccountDocRow[]>([])
const uploadingMyDoc = ref(false)

const { tickets, openTicket, showTicket, closeTicket, newTicketOpen, submittingTicket, openNewTicket, submitTicket } = useOsasTickets(
  (_draft, userId) => ({ landlord_id: userId, accommodation_id: selectedId.value || null }),
)

const myDocs = computed<RequirementItem[]>(() =>
  MY_DOC_TYPES.map((type) => accountDocItem(type, myDocRows.value.find((d) => d.doc_type === type), myStatus.value)),
)


async function loadMyDocs(userId: string) {
  const { data, error: docError } = await supabase
    .from('verification_documents')
    .select('id, doc_type, file_url, filename, status, uploaded_at, verified_at')
    .eq('user_id', userId)
    .order('uploaded_at', { ascending: false })
  if (docError) throw docError
  myDocRows.value = (await latestSignedDocs(data)) as AccountDocRow[]
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: authData } = await authUser()
    const user = authData?.user
    if (!user) {
      error.value = 'Not logged in.'
      return
    }
    myId.value = user.id

    const [{ data: accData, error: accError }, { data: ticketData, error: ticketError }, { data: userData, error: userError }] = await Promise.all([
      supabase.from('accommodations').select('id, name, barangay, city, status').eq('landlord_id', user.id).order('name'),
      supabase
        .from('tickets')
        .select(TICKET_SELECT)
        .eq('landlord_id', user.id)
        .order('reported_at', { ascending: false }),
      supabase.from('users').select('status').eq('id', user.id).maybeSingle(),
    ])
    if (accError) throw accError
    if (ticketError) throw ticketError
    const ticketList = await toTickets(ticketData)
    if (userError) throw userError
    myStatus.value = userData?.status || ''
    if (myStatus.value === 'rejected' || myStatus.value === 'needs_resubmission' || myStatus.value === 'reviewing') {
      // verification_requests is the decision trail. This used to string-match a
      // notification *title*, so renaming that copy silently lost every reason.
      rejectionReason.value = await auth.fetchDecisionReason(user.id)
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

    tickets.value = ticketList
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

function openUploadDialog(type: string, target: UploadTarget = 'property') {
  uploadDocType.value = type
  uploadTarget.value = target
  uploadDialogOpen.value = true
}

async function submitDocUpload(uploadForm: DocUpload) {
  if (!uploadForm.file) {
    notify.error('Choose a file.')
    return
  }
  if (!uploadForm.expiresAt) {
    notify.error('Pick an expiration date.')
    return
  }
  if (uploadTarget.value === 'account') {
    await submitMyDocUpload(uploadForm)
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
async function submitMyDocUpload(uploadForm: DocUpload) {
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

.sk-card {
  border-radius: var(--m-radius);
}
.sk-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
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
