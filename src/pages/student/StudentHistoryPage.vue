<template>
  <q-page class="history-page" :class="{ 'page-wide': split }">
    <q-pull-to-refresh @refresh="onPull">
      <!-- Desktop: the loaded shape — the way back live already above a card
           showing one tab at a time, with its own search. -->
      <div v-if="loading && split" class="stack">
        <div class="desk-back-row">
          <button type="button" class="desk-panel-back" :aria-label="backLabel" @click="goBack">
            <IconifyIcon icon="lucide:arrow-left" width="20" />
          </button>
          <span class="desk-panel-title">{{ backLabel }}</span>
        </div>
        <div class="desk-card desk-card--tabbed">
          <div class="desk-col">
            <q-skeleton type="rect" height="40px" class="sk sk-search" />
            <q-skeleton type="rect" height="90px" class="sk" />
            <q-skeleton type="rect" height="90px" class="sk" />
          </div>
        </div>
      </div>

      <div v-else-if="loading" class="stack">
        <q-skeleton type="rect" height="40px" class="sk" />
        <q-skeleton type="rect" height="90px" class="sk" />
        <q-skeleton type="rect" height="90px" class="sk" />
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your history" :detail="error" :retry="load" />
      </div>

      <div v-else class="stack">
        <!-- Desktop: the way back sits just above the card, as on an
             accommodation; the app header stays the plain one (see OWN_BACK
             in MainLayout). -->
        <div v-if="split" class="desk-back-row">
          <button type="button" class="desk-panel-back" :aria-label="backLabel" @click="goBack">
            <IconifyIcon icon="lucide:arrow-left" width="20" />
          </button>
          <span class="desk-panel-title">{{ backLabel }}</span>
        </div>
        <div class="m-tabbed">
          <div class="tabs" role="tablist" aria-label="History">
            <button
              v-for="t in TABS"
              :key="t.key"
              type="button"
              role="tab"
              :aria-selected="tab === t.key"
              class="m-tab"
              :class="{ 'm-tab--on': tab === t.key }"
              @click="tab = t.key"
            >
              {{ t.label }}
            </button>
          </div>

          <!-- Desktop: still tabs, not halves side by side (ratings used to be
               moved in below payments). -->
          <div :class="split ? 'desk-card desk-card--tabbed' : 'panel'">
            <component :is="panelsIs" v-bind="panelsProps" :class="split ? 'desk-contents' : 'm-panels'">
              <component :is="panelIs" v-show="!split || tab === 'history'" name="history" :class="split ? 'desk-col' : 'tab-panel'">
                <!-- Desktop: each tab searches only itself. -->
                <SearchDock v-if="split" v-model="queries.history" inline no-filters class="desk-search" :filter-count="0" placeholder="Search boarding history" search-label="Search" />
                <BoardingHistoryTab :stays="stays" :query="queries.history" @rate="openReview" @payments="showPayments" />
              </component>

              <component :is="panelIs" v-show="!split || tab === 'reviews'" name="reviews" :class="split ? 'desk-col' : 'tab-panel'">
                <SearchDock v-if="split" v-model="queries.reviews" inline no-filters class="desk-search" :filter-count="0" placeholder="Search ratings" search-label="Search" />
                <StudentRatingsTab :reviews="reviewsFromManagers" :query="queries.reviews" />
              </component>

              <component :is="panelIs" v-show="!split || tab === 'payments'" name="payments" :class="split ? 'desk-col' : 'tab-panel'">
                <SearchDock v-if="split" v-model="queries.payments" inline no-filters class="desk-search" :filter-count="0" placeholder="Search month or method" search-label="Search" />
                <StudentPaymentsTab :payments="payments" :owed="owed" :query="queries.payments" :expand="expandLease" />
              </component>
            </component>
          </div>
        </div>
      </div>
    </q-pull-to-refresh>

    <!-- Search sits on the FAB's baseline so the two read as one control band
         on a tab-shell page — but History is a subpage (no FAB, no bottom
         nav), so it just spans the full width instead of reserving FAB room.
         Outside the pull-to-refresh wrapper on purpose: it transforms its
         content while you pull, which would drag this fixed dock along.
         None of the three tabs has a filter button: their filters are pills
         inside the tab. -->
    <SearchDock
      v-if="!loading && !error && !split"
      v-model="queries[tab]"
      no-filters
      :filter-count="0"
      :placeholder="tab === 'payments' ? 'Search month or method' : tab === 'reviews' ? 'Search ratings' : 'Search boarding history'"
      search-label="Search"
    />

    <!-- Rate stay -->
    <AppModal v-model="reviewOpen" :title="reviewTarget ? `Rate your stay at ${reviewTarget.name}` : ''">
      <template v-if="reviewTarget">
        <div class="review-field">
          <span class="review-field-label">The place</span>
          <StarRating v-model="reviewForm.accRating" interactive :size="26" />
          <textarea v-model="reviewForm.accComment" class="review-textarea" rows="2" placeholder="What was it like? (optional)" />
        </div>

        <div class="review-field">
          <span class="review-field-label">The landlord/landlady</span>
          <StarRating v-model="reviewForm.managerRating" interactive :size="26" />
          <textarea v-model="reviewForm.managerComment" class="review-textarea" rows="2" placeholder="How were they to deal with? (optional)" />
        </div>
      </template>
      <template #footer>
        <q-btn unelevated rounded no-caps color="primary" class="review-submit" :loading="submittingReview" label="Submit" @click="submitReview" />
      </template>
    </AppModal>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onActivated } from 'vue'
import { useDeskPanels } from '@/utils/useDeskPanels'
import { useLiveData } from '@/utils/useLiveData'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'
import StarRating from '@/components/shared/StarRating.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import AppModal from '@/components/shared/AppModal.vue'
import BoardingHistoryTab from '@/components/student/BoardingHistoryTab.vue'
import StudentRatingsTab, { type ManagerReview } from '@/components/student/StudentRatingsTab.vue'
import StudentPaymentsTab, { type PaymentRow } from '@/components/student/StudentPaymentsTab.vue'
import type { Stay } from '@/components/student/StayDetailSheet.vue'
import { landlordTitle } from '@/utils/format'
import { toLedger } from '@/utils/payments'
import { roomTypeLabel } from '@/utils/listings'

type Tab = 'history' | 'reviews' | 'payments'
const TABS: { key: Tab; label: string }[] = [
  { key: 'history', label: 'Boarding history' },
  { key: 'reviews', label: 'Ratings' },
  { key: 'payments', label: 'Payments' },
]

const router = useRouter()
// Back to wherever History was opened from (Settings, or a View-all link);
// Settings on a fresh load with nothing behind it. Read on every visit, not
// once at setup: the page is kept alive, so where it was opened from changes.
const BACK_LABELS: Record<string, string> = {
  '/student/settings': 'settings',
  '/student/stay': 'my stay',
  '/student/notifications': 'notifications',
}
const backPath = ref<string | null>(null)
function readBack() {
  backPath.value = window.history.state?.back ?? null
}
readBack()
onActivated(readBack)
const backLabel = computed(() => {
  if (!backPath.value) return 'Back to settings'
  const name = BACK_LABELS[backPath.value.split('?')[0] ?? '']
  return name ? `Back to ${name}` : 'Back'
})
function goBack() {
  if (backPath.value) router.back()
  else void router.push('/student/settings')
}
const notify = useNotify()

const loading = ref(true)
const error = ref('')
// `?tab=payments` (the Payments tab's "All my payments" link).
const tab = ref<Tab>(useRoute().query.tab === 'payments' ? 'payments' : 'history')
// Desktop puts the panels in a card, still one tab at a time (useDeskPanels).
const { split, panelsIs, panelIs, panelsProps } = useDeskPanels(tab)

const stays = ref<Stay[]>([])
const reviewsFromManagers = ref<ManagerReview[]>([])
const payments = ref<PaymentRow[]>([])
// Left to pay per finished lease (lease_ledger), for the Settled chips.
const owed = ref<Record<string, number>>({})
// The stay whose payments group the Payments tab should open.
const expandLease = ref<string | null>(null)

// One search per tab — the open tab's on a phone, each half's own on desktop
// (where ratings sit in the payments half and go by its search).
const queries = reactive({ history: '', reviews: '', payments: '' })
watch(tab, () => {
  queries.history = ''
  queries.reviews = ''
  queries.payments = ''
})

function showPayments(stay: Stay) {
  expandLease.value = stay.leaseId
  tab.value = 'payments'
}

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

const reviewOpen = ref(false)
const submittingReview = ref(false)
const reviewTarget = ref<Stay | null>(null)
const reviewForm = reactive({ accRating: 0, accComment: '', managerRating: 0, managerComment: '' })

// `stars` is what the student already tapped in the stay sheet (0 = nothing yet).
function openReview(stay: Stay, stars = 0) {
  reviewTarget.value = stay
  reviewForm.accRating = stars
  reviewForm.accComment = ''
  reviewForm.managerRating = stars
  reviewForm.managerComment = ''
  reviewOpen.value = true
}

async function submitReview() {
  const row = reviewTarget.value
  if (submittingReview.value || !row?.leaseId || !row.managerId || !row.accommodationId) return
  if (!reviewForm.accRating || !reviewForm.managerRating) {
    notify.error('Rate both the place and the manager.')
    return
  }
  submittingReview.value = true
  try {
    // Both halves in one transaction. As two sequential inserts, a failure on
    // the second left the first committed — and since a stay counts as rated
    // once either row exists, the student could never supply the missing half.
    const { error: reviewError } = await supabase.rpc('submit_student_review', {
      p_lease_id: row.leaseId,
      p_accommodation_id: row.accommodationId,
      p_landlord_id: row.managerId,
      p_acc_rating: reviewForm.accRating,
      p_acc_comment: reviewForm.accComment,
      p_manager_rating: reviewForm.managerRating,
      p_manager_comment: reviewForm.managerComment,
    })
    if (reviewError) throw reviewError

    const target = stays.value.find((s) => s.id === row.id)
    if (target) {
      target.rating = Math.round((reviewForm.accRating + reviewForm.managerRating) / 2)
      target.toRate = false
    }
    reviewOpen.value = false
    notify.success('Thanks for the feedback!')
  } catch (e) {
    notify.error(e instanceof Error ? e.message : 'Could not submit your rating.')
  } finally {
    submittingReview.value = false
  }
}

interface LeaseRow {
  id: string
  status: string
  start_date: string
  end_date: string
  leave_date: string | null
  monthly_rent: number | null
  ended_reason: string | null
  landlord_id: string
  rooms: {
    label: string | null
    room_number: string | null
    room_type: string | null
    custom_room_type: string | null
    accommodation_id: string
    accommodations: { name: string | null; address: string | null; barangay: string | null; city: string | null } | null
  } | null
}
const STATE: Record<string, Stay['state']> = { active: 'now', leave_requested: 'leaving', ended: 'ended', terminated: 'terminated' }

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data: auth } = await authUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }

    const [
      { data: leaseRows, error: leaseErr },
      { data: past },
      { data: written },
      { data: reviewsAboutMe },
      { data: paymentRows },
    ] = await Promise.all([
      supabase
        .from('leases')
        .select(
          'id, status, start_date, end_date, leave_date, monthly_rent, ended_reason, landlord_id, rooms(label, room_number, room_type, custom_room_type, accommodation_id, accommodations(name, address, barangay, city))',
        )
        .eq('student_id', user.id)
        .in('status', ['active', 'leave_requested', 'ended', 'terminated'])
        .order('start_date', { ascending: false }),
      // Stays from before leases were recorded: kept for the record, nothing to rate.
      supabase
        .from('boarding_history')
        .select('id, accommodation_id, accommodation_name, room_type, period_start, period_end, end_reason')
        .eq('student_id', user.id)
        .order('period_start', { ascending: false }),
      // Which stays this student has already rated, and how. One view instead of
      // two table reads, and it is scoped to the caller by the view itself.
      supabase.from('review_written_leases').select('lease_id, rating').in('kind', ['accommodation', 'manager']),
      // Reviews landlords/landladies left about this student — anonymous, so no name join:
      // the landlord/landlady's identity is not exposed by the view at all.
      supabase
        .from('review_inbox')
        .select('id, rating, comment, created_at')
        .eq('kind', 'tenant')
        .order('created_at', { ascending: false }),
      // Finished payments only; anything still pending is on My Stay.
      supabase
        .from('payments')
        .select(
          'id, lease_id, month, amount, status, method, kind, description, paid_at, created_at, leases!inner(student_id, status, start_date, end_date, rooms(room_number, label, accommodations(name)))',
        )
        .eq('leases.student_id', user.id)
        .in('status', ['paid', 'waived', 'rejected'])
        .order('month', { ascending: false }),
    ])
    if (leaseErr) throw leaseErr
    const leases = (leaseRows ?? []) as unknown as LeaseRow[]
    const finished = leases.filter((l) => l.status === 'ended' || l.status === 'terminated')

    const [{ data: landlords }, ledgers] = await Promise.all([
      supabase.from('users').select('id, full_name, sex').in('id', [...new Set(leases.map((l) => l.landlord_id))]),
      Promise.all(finished.map((l) => supabase.rpc('lease_ledger', { p_lease: l.id }))),
    ])
    const landlordById = new Map((Array.isArray(landlords) ? landlords : []).map((u) => [u.id, u]))
    owed.value = Object.fromEntries(
      finished.map((l, i) => [l.id, toLedger(Array.isArray(ledgers[i]?.data) ? (ledgers[i]!.data as unknown[]) : []).reduce((n, r) => n + r.balance, 0)]),
    )

    const ratingsByLease = new Map<string, number[]>()
    for (const w of written ?? []) {
      if (w.lease_id && w.rating) ratingsByLease.set(w.lease_id, [...(ratingsByLease.get(w.lease_id) ?? []), w.rating])
    }
    const paidByLease = new Map<string, number>()
    for (const p of paymentRows ?? []) {
      if (p.status === 'paid') paidByLease.set(p.lease_id, (paidByLease.get(p.lease_id) ?? 0) + Number(p.amount))
    }

    const fromLeases: Stay[] = leases.map((l) => {
      const room = l.rooms
      const acc = room?.accommodations
      const given = ratingsByLease.get(l.id)
      const rating = given ? Math.round(given.reduce((n, r) => n + r, 0) / given.length) : null
      const state = STATE[l.status] ?? 'ended'
      const landlord = landlordById.get(l.landlord_id)
      return {
        id: l.id,
        leaseId: l.id,
        accommodationId: room?.accommodation_id ?? null,
        managerId: l.landlord_id,
        name: acc?.name || 'Accommodation',
        address: [acc?.address, acc?.barangay, acc?.city].filter(Boolean).join(', '),
        room: [room?.label || (room?.room_number ? `Room ${room.room_number}` : ''), roomTypeLabel(room?.custom_room_type || room?.room_type)].filter(Boolean).join(' · '),
        from: l.start_date,
        to: state === 'ended' || state === 'terminated' ? l.leave_date || l.end_date : l.end_date,
        state,
        rent: l.monthly_rent,
        endedReason: titleCase(l.ended_reason),
        landlord: landlord?.full_name || '',
        landlordRole: landlordTitle(landlord?.sex),
        rating,
        owed: owed.value[l.id] ?? 0,
        paid: paidByLease.get(l.id) ?? 0,
        toRate: finished.some((f) => f.id === l.id) && rating === null,
      }
    })
    // boarding_history rows with no lease behind them (same place, same move-in).
    const seen = new Set(leases.map((l) => `${l.rooms?.accommodation_id}:${l.start_date.slice(0, 10)}`))
    const legacy: Stay[] = (past ?? [])
      .filter((h) => !seen.has(`${h.accommodation_id}:${h.period_start.slice(0, 10)}`))
      .map((h) => ({
        id: h.id,
        leaseId: null,
        accommodationId: h.accommodation_id,
        managerId: null,
        name: h.accommodation_name || 'Accommodation',
        address: '',
        room: roomTypeLabel(h.room_type),
        from: h.period_start,
        to: h.period_end,
        state: 'ended',
        rent: null,
        endedReason: titleCase(h.end_reason),
        landlord: '',
        landlordRole: '',
        rating: null,
        owed: 0,
        paid: null,
        toRate: false,
      }))
    stays.value = [...fromLeases, ...legacy].sort((a, b) => b.from.localeCompare(a.from))

    reviewsFromManagers.value = (reviewsAboutMe ?? []).map((r) => ({
      id: r.id ?? '',
      rating: r.rating ?? 0,
      comment: r.comment || '',
      createdAt: r.created_at ?? '',
    }))

    payments.value = (paymentRows ?? []).map((p) => {
      const lease = p.leases as unknown as {
        status: string
        start_date: string
        end_date: string
        rooms: { room_number: string | null; label: string | null; accommodations: { name: string | null } | null } | null
      }
      const room = lease.rooms
      return {
        id: p.id,
        leaseId: p.lease_id,
        month: p.month,
        amount: Number(p.amount),
        status: p.status,
        method: p.method,
        kind: p.kind,
        description: p.description || '',
        paidAt: p.paid_at,
        createdAt: p.created_at,
        name: room?.accommodations?.name || 'Your accommodation',
        room: room?.label || (room?.room_number ? `Room ${room.room_number}` : 'Your room'),
        leaseStatus: lease.status,
        leaseStart: lease.start_date,
        leaseEnd: lease.end_date,
      }
    })
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

// Not kept alive and with no realtime watch behind it, so a pull is the only
// way to see anything that changed since the screen was opened.
function onPull(done: () => void) {
  void refresh().finally(done)
}

// Kept alive across navigation (see MainLayout KEEP_ALIVE_PAGES), so returning
// to this screen no longer refetches the whole history every time. No realtime
// watch on purpose: this is a record of things that already happened, and the
// two-minute TTL plus pull-to-refresh is all the freshness it needs.
const { refresh } = useLiveData({ key: 'student-history', load, ttl: 120_000 })
</script>

<style scoped>
.history-page {
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
}
/* Stands in for a half's own search (.desk-search). */
.sk-search {
  border-radius: 999px;
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
  /* Extra bottom room so the last row isn't hidden under the fixed dock —
     this page has no bottom nav/FAB to clear, just the dock itself. */
  padding: 14px 14px 84px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
.tab-panel {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.review-field {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.review-field-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.review-textarea {
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  resize: vertical;
}
.review-submit {
  flex: 1;
  min-height: 48px;
  font-weight: 700;
}
</style>
