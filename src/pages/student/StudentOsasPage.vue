<template>
  <!-- Beside its list rather than over it on a landscape tablet; see
       `.page-split` in app.scss. -->
  <!-- Desktop: requirements and support tickets are the two halves of a card
       (the tabs, side by side); tablet keeps list-beside-thread. -->
  <q-page class="op" :class="{ 'page-split': isTablet && !isDesktop, 'page-wide': isDesktop }">
    <q-pull-to-refresh @refresh="onPull">
      <!-- Desktop: the loaded card's two halves, not the phone's tabs. -->
      <div v-if="loading && isDesktop" class="stack">
        <div class="desk-card">
          <div class="desk-col">
            <h2 class="desk-col-title">Requirements</h2>
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
          <q-skeleton type="rect" width="88px" height="38px" class="m-sk-tab" />
          <q-skeleton type="rect" width="70px" height="38px" class="m-sk-tab" />
        </div>
        <q-skeleton type="rect" height="84px" class="sk-card" />
        <div class="sk-grid">
          <q-skeleton v-for="n in 2" :key="n" type="rect" height="180px" class="sk-card" />
        </div>
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load OSAS" :detail="error" :retry="load" />
      </div>

      <div v-else class="stack">
        <div class="m-tabbed">
          <div v-if="!isDesktop" class="tabs">
            <button v-for="t in TABS" :key="t.key" type="button" class="m-tab" :class="{ 'm-tab--on': tab === t.key }" @click="tab = t.key">
              {{ t.label }}
            </button>
          </div>

          <div :class="isDesktop ? 'desk-card' : 'panel'">
            <component :is="panelsIs" v-bind="panelsProps" :class="isDesktop ? 'desk-contents' : 'm-panels'">
              <!-- DOCUMENTS (the left half on desktop) -->
              <component :is="panelIs" name="docs" :class="isDesktop ? 'desk-col' : 'tab-panel'">
                <h2 v-if="isDesktop" class="desk-col-title">Requirements</h2>
                <RequirementCards :items="docs" noun="requirements" done-word="approved" replace-label="Resubmit" :busy="uploadingDoc" @upload="pickFile" />
                <AccountReviewStatus
                  :status="myStatus"
                  :decision="decisions[0] ?? null"
                  :sent-at="REQUIRED_DOCS.map((t) => docRows.find((d) => d.doc_type === t)?.uploaded_at ?? null)"
                  :busy="resubmitting || uploadingDoc"
                  @resubmit="resubmitMine"
                />
                <input ref="fileInput" type="file" accept="image/*,application/pdf" hidden @change="onDocSelected" />
                <ReviewHistory :items="history" />
              </component>

              <!-- TICKETS. On desktop this is the right half: the list, or —
                   in its place, with their own way back — the open ticket or
                   the new-ticket form. -->
              <component
                :is="panelIs"
                name="tickets"
                :class="isDesktop ? ['desk-col', { 'desk-col--fill': openTicket || newTicketOpen }] : 'tab-panel'"
              >
                <TicketCompose
                  v-if="isDesktop && newTicketOpen"
                  class="desk-inpanel"
                  attachment
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
                  empty-message="Account, verification or technical issues you raise with OSAS will show up here."
                  @open="showTicket"
                  @new="openNewTicket"
                >
                  For school, account or verification matters, or a problem your {{ myLandlord }} hasn't fixed.
                  Room, rent or house issues go to
                  <router-link to="/student/concerns" class="sec-hint-link">your {{ myLandlord }}</router-link> first.
                </TicketList>
              </component>
            </component>
          </div>
        </div>
      </div>
    </q-pull-to-refresh>

    <!-- Phone and tablet: the thread covers the list (phone) or sits beside it
         (tablet). Desktop shows it inside the tickets half above. -->
    <TicketThread v-if="openTicket && !isDesktop" :key="openTicket.id" :ticket="openTicket" @close="closeTicket" />

    <div v-else-if="isTablet && !isDesktop" class="page-split-empty">
      <IconifyIcon icon="lucide:ticket" width="26" />
      <p>Pick a ticket to read the thread</p>
    </div>

    <TicketCompose
      v-if="newTicketOpen && !isDesktop"
      attachment
      :categories="TICKET_CATEGORIES"
      :submitting="submittingTicket"
      @close="newTicketOpen = false"
      @submit="submitTicket"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useMyLandlordTitle } from '@/utils/myLandlordTitle'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { accountDocItem, accountHistory, isSentBack, latestSignedDocs, loadAccountDecisions, resubmitVerification, type AccountDecision, type AccountDocRow } from '@/utils/profile'
import { isTablet, isDesktop } from '@/utils/useTabletMode'
import { useDeskPanels } from '@/utils/useDeskPanels'
import { useNotify } from '@/utils/notify'
import { uploadSecureDocument, secureDocUrl } from '@/utils/upload'
import { useOsasTickets, toTickets, TICKET_SELECT } from '@/utils/useOsasTickets'
import { useAuthStore } from '@/stores/auth'
import type { DocReadings } from '@/utils/docReading'
import type { Json } from '@/types/database.gen'
import TicketThread from '@/components/shared/TicketThread.vue'
import TicketCompose from '@/components/shared/TicketCompose.vue'
import TicketList from '@/components/shared/TicketList.vue'
import AccountReviewStatus from '@/components/shared/AccountReviewStatus.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import RequirementCards, { type RequirementItem } from '@/components/shared/RequirementCards.vue'
import ReviewHistory from '@/components/shared/ReviewHistory.vue'

const TICKET_CATEGORIES = [
  { value: 'verification', label: 'Verification' },
  { value: 'accommodation', label: 'Accommodation' },
  { value: 'technical', label: 'Technical / app issue' },
  { value: 'other', label: 'Other' },
]

const TABS = [
  { key: 'docs', label: 'Requirements' },
  { key: 'tickets', label: 'Tickets' },
] as const

const REQUIRED_DOCS = ['school_id', 'assessment_of_fees']

const notify = useNotify()
const auth = useAuthStore()
const myLandlord = useMyLandlordTitle()

const loading = ref(true)
const error = ref('')
const tab = ref<(typeof TABS)[number]['key']>('docs')
// Desktop: both tabs at once, as the halves of a card (useDeskPanels).
const { panelsIs, panelIs, panelsProps } = useDeskPanels(tab)

const myId = ref('')
// OSAS approves/rejects identity documents by flipping the account's own
// users.status, not each verification_documents row (the admin review flow
// never writes doc_status past its initial 'pending') — so "verified" has to
// be read from here, not from the per-document status.
const myStatus = ref('')
const docRows = ref<AccountDocRow[]>([])
// OSAS's decisions on the account, newest first (verification_requests): the
// reason it sent the account back, and the review history.
const decisions = ref<AccountDecision[]>([])
const history = computed(() => accountHistory(decisions.value, docRows.value))
const uploadingDoc = ref(false)
const { tickets, openTicket, showTicket, closeTicket, newTicketOpen, submittingTicket, openNewTicket, submitTicket } = useOsasTickets(
  (draft, userId) => ({ student_id: userId, photo_urls: draft.photoUrl ? [draft.photoUrl] : [] }),
)

const docs = computed<RequirementItem[]>(() =>
  REQUIRED_DOCS.map((type) => accountDocItem(type, docRows.value.find((d) => d.doc_type === type), myStatus.value, decisions.value[0]?.reviewed_at ?? null)),
)

// One hidden file input serves every card; the card's type rides along here.
const fileInput = ref<HTMLInputElement | null>(null)
const pickingType = ref('')
function pickFile(type: string) {
  pickingType.value = type
  fileInput.value?.click()
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

    const [{ data: docData, error: docError }, { data: ticketData, error: ticketError }, { data: userData, error: userError }] = await Promise.all([
      supabase
        .from('verification_documents')
        .select('id, doc_type, file_url, status, uploaded_at, verified_at')
        .eq('user_id', user.id)
        .in('doc_type', REQUIRED_DOCS)
        .order('uploaded_at', { ascending: false }),
      supabase
        .from('tickets')
        .select(TICKET_SELECT)
        .eq('student_id', user.id)
        // A concern the landlord/landlady escalated carries this student's id too, but
        // it isn't theirs to answer here — it shows on the concern instead.
        .is('concern_id', null)
        .order('reported_at', { ascending: false }),
      supabase.from('users').select('status').eq('id', user.id).maybeSingle(),
    ])
    decisions.value = await loadAccountDecisions(user.id)
    if (docError) throw docError
    if (ticketError) throw ticketError
    const ticketList = await toTickets(ticketData)
    if (userError) throw userError
    myStatus.value = userData?.status || ''

    // Keep only the most recent row per doc type.
    docRows.value = await latestSignedDocs(
      (docData ?? []).filter((d): d is typeof d & { doc_type: string; file_url: string; uploaded_at: string } => Boolean(d.doc_type && d.file_url && d.uploaded_at)),
    )

    tickets.value = ticketList
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

/**
 * Drop the text registration read off the document just replaced, so OSAS is
 * not shown a check of the old file. The console reads the new one itself.
 */
async function forgetReading(docType: string) {
  if (docType !== 'school_id' && docType !== 'assessment_of_fees') return
  const { data } = await supabase.from('student_profiles').select('document_text').eq('user_id', myId.value!).maybeSingle()
  const readings = (data?.document_text ?? null) as DocReadings | null
  if (!readings?.[docType]) return
  delete readings[docType]
  await supabase
    .from('student_profiles')
    .update({ document_text: Object.keys(readings).length ? (readings as Json) : null })
    .eq('user_id', myId.value!)
}

async function onDocSelected(event: Event) {
  const docType = pickingType.value
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file || !myId.value) return
  uploadingDoc.value = true
  try {
    const url = await uploadSecureDocument(file)
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
      existing.file_url = await secureDocUrl('verification_documents', existing.id)
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
        { id: created.id, doc_type: docType, file_url: await secureDocUrl('verification_documents', created.id), status: 'pending', uploaded_at: created.uploaded_at ?? new Date().toISOString(), verified_at: null },
        ...docRows.value,
      ]
    }
    await forgetReading(docType)
    // A sent-back account goes back to OSAS only when its owner says so (the
    // Resubmit button, AccountReviewStatus), like a sent-back listing. Any
    // other status: puts a first upload in the queue, or no-ops.
    if (isSentBack(myStatus.value)) {
      notify.success('Uploaded. Resubmit when everything OSAS asked for is in.')
    } else {
      await resubmitVerification()
      notify.success('Uploaded — awaiting review.')
    }
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload this document.'))
  } finally {
    uploadingDoc.value = false
    input.value = ''
  }
}

const resubmitting = ref(false)
async function resubmitMine() {
  resubmitting.value = true
  try {
    await resubmitVerification()
    myStatus.value = 'pending'
    auth.accountStatus = 'pending'
    notify.success('Resubmitted — OSAS will review it again.')
  } catch (e) {
    notify.error(errorMessage(e, 'That did not go through.'))
  } finally {
    resubmitting.value = false
  }
}

// This screen is kept alive (see MainLayout's KEEP_ALIVE_PAGES), so without
// this it would fetch once and never again — an OSAS verification decision or
// ticket reply would not surface until the app restarted.
const { refresh } = useLiveData({
  key: 'student-osas',
  load,
  watch: (uid) => [
    { table: 'verification_documents', filter: `user_id=eq.${uid}` },
    { table: 'tickets', filter: `student_id=eq.${uid}` },
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

.sec-hint-link {
  color: var(--m-primary);
  font-weight: 600;
}

.sk-card {
  border-radius: var(--m-radius);
}
.sk-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

</style>
