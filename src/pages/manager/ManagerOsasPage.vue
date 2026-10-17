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

                  <!-- View only: permits are uploaded, and accreditation is
                       submitted, renewed or appealed, from the listing's Settings. -->
                  <RequirementCards :items="docs" noun="permits" done-word="valid" readonly />
                  <q-btn
                    outline
                    rounded
                    no-caps
                    color="primary"
                    :label="selected?.status === 'draft' ? 'Finish and submit in Settings' : 'Manage permits in Settings'"
                    @click="router.push({ path: `/manager/properties/${selectedId}`, query: { tab: 'settings' } })"
                  >
                    <IconifyIcon icon="lucide:arrow-right" width="16" class="q-ml-sm" />
                  </q-btn>
                  <ReviewHistory :items="history" />
                </template>
              </component>

              <!-- MY REQUIREMENTS (landlord/landlady identity, reviewed by OSAS at registration) -->
              <component :is="panelIs" v-show="!isDesktop || leftTab === 'mine'" name="mine" :class="isDesktop ? 'desk-col osas-left' : 'tab-panel'">
                <RequirementCards :items="myDocs" noun="requirements" done-word="approved" replace-label="Resubmit" :busy="uploadingMyDoc" @upload="openUploadDialog" />
                <AccountReviewStatus
                  :status="myStatus"
                  :decision="myDecisions[0] ?? null"
                  :sent-at="MY_DOC_TYPES.map((t) => myDocRows.find((d) => d.doc_type === t)?.uploaded_at ?? null)"
                  unlocks="You can add accommodations and rooms once it is approved."
                  :busy="resubmitting || uploadingMyDoc"
                  @resubmit="resubmitMine"
                />
                <ReviewHistory :items="myHistory" />
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

    <!-- ACCOUNT DOCUMENT UPLOAD FORM — a document already on file is never
         edited in place; replacing it always goes through this fresh form. -->
    <DocUploadModal v-model="uploadDialogOpen" :title="DOC_LABEL[uploadDocType] ?? uploadDocType" :loading="uploadingMyDoc" @submit="submitDocUpload" />

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
import { computed, onActivated, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { useOsasTickets, toTickets, TICKET_SELECT } from '@/utils/useOsasTickets'
import { useOsasPermits } from '@/utils/useOsasPermits'
import { DOC_LABEL, accountHistory, loadAccountDecisions, resubmitVerification, type AccountDecision } from '@/utils/profile'
import { MY_DOC_TYPES, useOsasUploads } from '@/utils/useOsasUploads'
import { useNotify } from '@/utils/notify'
import { isTablet, isDesktop } from '@/utils/useTabletMode'
import { useDeskPanels } from '@/utils/useDeskPanels'
import EmptyState from '@/components/shared/EmptyState.vue'
import TicketThread from '@/components/shared/TicketThread.vue'
import TicketCompose from '@/components/shared/TicketCompose.vue'
import TicketList from '@/components/shared/TicketList.vue'
import AccountReviewStatus from '@/components/shared/AccountReviewStatus.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import RequirementCards from '@/components/shared/RequirementCards.vue'
import ReviewHistory from '@/components/shared/ReviewHistory.vue'
import AccommodationSwitch from '@/components/manager/AccommodationSwitch.vue'
import DocUploadModal from '@/components/manager/DocUploadModal.vue'

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

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

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
// ?tab=mine opens on the account's own requirements — where the "OSAS needs
// changes" banner and verification notifications lead. The page is kept alive,
// so it is applied on every visit, not only the first.
function applyTabQuery() {
  if (route.query.tab !== 'mine') return
  tab.value = 'mine'
  leftTab.value = 'mine'
}
watch(() => route.query.tab, applyTabQuery, { immediate: true })
onActivated(applyTabQuery)

const myId = ref('')
// OSAS approves/rejects identity documents by flipping the account's own
// users.status, not each verification_documents row (the admin review flow
// never writes doc_status past its initial 'pending') — so "verified" has to
// be read from here, not from the per-document status.
const myStatus = ref('')
const { accommodations, selectedId, selected, docs, history, loadPermits, signPermits } = useOsasPermits()
const { uploadDialogOpen, uploadDocType, uploadingMyDoc, myDocRows, myDocs, loadMyDocs, openUploadDialog, submitDocUpload } = useOsasUploads({
  myId,
  myStatus,
  decidedAt: computed(() => myDecisions.value[0]?.reviewed_at ?? null),
})
// OSAS's decisions on the account, newest first (verification_requests): the
// reason it sent the account back, and the review history.
const myDecisions = ref<AccountDecision[]>([])
const myHistory = computed(() => accountHistory(myDecisions.value, myDocRows.value))

const notify = useNotify()
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

const { tickets, openTicket, showTicket, closeTicket, newTicketOpen, submittingTicket, openNewTicket, submitTicket } = useOsasTickets(
  (_draft, userId) => ({ landlord_id: userId, accommodation_id: selectedId.value || null }),
)

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

    accommodations.value = (accData ?? []).map((a) => ({
      id: a.id,
      name: a.name?.trim() || 'Unnamed accommodation',
      place: [a.barangay, a.city].filter(Boolean).join(', '),
      status: a.status,
    }))
    // ?accommodation= picks which listing's permits open first.
    const asked = accommodations.value.find((a) => a.id === route.query.accommodation)
    selectedId.value = asked?.id || accommodations.value[0]?.id || ''
    await loadPermits()
    if (selectedId.value) void signPermits(selectedId.value)
    await loadMyDocs(user.id)
    myDecisions.value = await loadAccountDecisions(user.id)

    tickets.value = ticketList
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
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
