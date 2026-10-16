<template>
  <q-page class="sp" :class="{ 'page-wide': isDesktop }">
    <q-pull-to-refresh @refresh="onPull">
      <!-- Desktop: the loaded card's two halves, stay left and payments right. -->
      <div v-if="loading && isDesktop" class="stack">
        <div class="desk-card">
          <div v-for="title in ['My Stay', 'Payments']" :key="title" class="desk-col">
            <h2 class="split-head">{{ title }}</h2>
            <q-skeleton type="rect" height="120px" class="sk" />
            <q-skeleton type="rect" height="90px" class="sk" />
          </div>
        </div>
      </div>

      <div v-else-if="loading" class="stack">
        <q-skeleton type="rect" height="200px" square class="sk-hero" />
        <q-skeleton type="rect" height="120px" class="sk" />
        <q-skeleton type="rect" height="90px" class="sk" />
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your stay" :detail="error" :retry="load" />
      </div>

      <EmptyState
        v-else-if="!lease && !payments.length"
        icon="lucide:home"
        title="No active stay"
        message="Once a landlord/landlady accepts your application, your tenancy details, rent and landlord/landlady contact will show up here."
      >
        <template #actions>
          <q-btn unelevated rounded no-caps color="primary" label="Browse rooms" @click="router.push('/student/discover')" />
        </template>
      </EmptyState>

      <div v-else class="stack">
        <div class="m-tabbed" :class="{ 'stay-both': isTablet, 'm-tabbed--hero': lease && !isDesktop }">
          <StayHero
            v-if="lease && !isDesktop"
            :name="lease.accommodationName"
            :room="lease.roomLabel"
            :address="lease.address"
            :status="lease.status"
            :photo-url="lease.photoUrl"
          />
          <!-- A phone shows one panel at a time and needs the strip to choose.
               On a tablet both are up, so there is nothing left to pick. -->
          <div v-if="!isTablet" class="tabs">
            <button type="button" class="m-tab" :class="{ 'm-tab--on': activeTab === 'stay' }" @click="activeTab = 'stay'">
              My Stay
            </button>
            <button type="button" class="m-tab" :class="{ 'm-tab--on': activeTab === 'payments' }" @click="activeTab = 'payments'">
              Payments
            </button>
          </div>

          <div :class="isDesktop ? 'desk-card' : 'panel'">
            <!-- Sliding QTabPanels on a phone; on a tablet, where both halves are
                 up side by side, plain divs (useDeskPanels keyed on isTablet). -->
            <component :is="panelsIs" v-bind="panelsProps" :class="isDesktop ? 'desk-contents' : 'm-panels'">
              <component :is="panelIs" name="stay" :class="isDesktop ? 'desk-col' : 'tab-panel'">
                <h2 v-if="isTablet" class="split-head">My Stay</h2>
                <template v-if="lease">
                  <StayHero
                    v-if="isDesktop"
                    :name="lease.accommodationName"
                    :room="lease.roomLabel"
                    :address="lease.address"
                    :status="lease.status"
                    :photo-url="lease.photoUrl"
                  />

                  <div class="mgr">
                    <span class="mgr-avatar">
                      <img v-if="lease.managerAvatarUrl" :src="lease.managerAvatarUrl" alt="" class="mgr-avatar-img" @error="lease.managerAvatarUrl = null" />
                      <template v-else>{{ lease.managerInitials }}</template>
                    </span>
                    <span class="mgr-body">
                      <span class="mgr-name">{{ lease.managerName }}</span>
                      <span class="mgr-sub">
                        Your {{ myLandlord }}<template v-if="lease.replyMinutes">{{ ` · replies in ~${lease.replyMinutes} min` }}</template>
                      </span>
                    </span>
                    <button
                      type="button"
                      class="mgr-msg"
                      :aria-label="`Message your ${myLandlord}`"
                      @click="router.push(`/student/messages?to=${lease.managerId}`)"
                    >
                      <IconifyIcon icon="lucide:message-circle" width="17" />
                    </button>
                  </div>
                  <p v-if="lease.status === 'pending'" class="note">Application pending — awaiting your {{ myLandlord }}'s decision.</p>
                  <p v-else-if="lease.status === 'leave_requested'" class="note">
                    You asked to move out on {{ formatDate(lease.leaveDate) }} — awaiting your {{ myLandlord }}'s decision. Rent stays due until then.
                  </p>
                  <p v-else-if="lease.leaveDate" class="note">Moving out {{ formatDate(lease.leaveDate) }} — approved by your {{ myLandlord }}.</p>

                  <!-- The four things a boarder actually checks, as tiles; the
                       rest is reference, one hairline list below. -->
                  <div class="facts">
                    <div class="fact">
                      <span class="fact-label">Monthly rent</span>
                      <span class="fact-value">{{ formatPeso(lease.monthlyRent) }}</span>
                      <span class="fact-sub">per month</span>
                    </div>
                    <div class="fact">
                      <span class="fact-label">Lease ends</span>
                      <span class="fact-value">{{ formatDate(lease.endDate) }}</span>
                      <span class="fact-sub">Started {{ formatDate(lease.startDate) }}</span>
                    </div>
                    <div class="fact">
                      <span class="fact-label">Room type</span>
                      <span class="fact-value">{{ lease.roomType || '—' }}</span>
                    </div>
                    <div class="fact">
                      <span class="fact-label">Capacity</span>
                      <span class="fact-value">{{ lease.capacity ? `${lease.capacity} ${lease.capacity === 1 ? 'person' : 'people'}` : '—' }}</span>
                      <span v-if="lease.roommateCount !== null" class="fact-sub">
                        {{ lease.roommateCount > 0 ? `${lease.roommateCount} roommate${lease.roommateCount === 1 ? '' : 's'}` : 'Just you so far' }}
                      </span>
                    </div>
                  </div>

                  <section class="sec">
                    <h2 class="sec-title">Utilities</h2>
                    <div v-for="u in UTILITIES" :key="u.key" class="line">
                      <span class="line-label">{{ u.label }}</span>
                      <span class="line-value">{{ utilityTermsLabel(lease.utilities[u.key]) }}</span>
                    </div>
                  </section>

                  <section v-if="lease.rules.length" class="sec">
                    <h2 class="sec-title">House rules</h2>
                    <div v-for="rule in lease.rules" :key="rule.label" class="line">
                      <span class="line-label">{{ rule.label }}</span>
                      <span class="line-value">{{ rule.value }}</span>
                    </div>
                  </section>

                  <section v-if="lease.amenities.length" class="sec">
                    <h2 class="sec-title">Amenities</h2>
                    <div class="amenities">
                      <span v-for="a in lease.amenities" :key="a" class="amenity">
                        <IconifyIcon :icon="AMENITY_META[a]?.icon || 'lucide:dot'" width="15" />
                        {{ AMENITY_META[a]?.label || a }}
                      </span>
                    </div>
                  </section>

                  <section class="sec">
                    <button type="button" class="line line-link" @click="router.push('/student/concerns')">
                      <IconifyIcon icon="lucide:message-square-warning" width="16" />
                      <span>Concerns</span>
                      <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
                    </button>
                    <button type="button" class="line line-link" @click="router.push('/student/profile/history')">
                      <IconifyIcon icon="lucide:history" width="16" />
                      <span>History</span>
                      <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
                    </button>
                  </section>

                  <button v-if="lease.status === 'active' && !lease.leaveDate" type="button" class="leave-link" @click="openLeave">
                    Request to leave
                  </button>
                </template>

                <EmptyState
                  v-else
                  variant="compact"
                  icon="lucide:home"
                  title="No active stay"
                  message="Once a landlord/landlady accepts your application, your tenancy details, rent and landlord/landlady contact will show up here."
                >
                  <template #actions>
                    <q-btn unelevated rounded no-caps color="primary" label="Browse rooms" @click="router.push('/student/discover')" />
                  </template>
                </EmptyState>
              </component>

              <component :is="panelIs" name="payments" :class="isDesktop ? 'desk-col' : 'tab-panel'">
                <h2 v-if="isTablet" class="split-head">Payments</h2>
                <!-- Moved out, still owing: it blocks applying for a new room. -->
                <div v-for="o in pastOwed" :key="o.leaseId" class="past-owed">
                  <span class="past-owed-label">Left to settle · {{ o.place }}</span>
                  <span class="past-owed-amt">{{ formatPesoExact(o.balance) }}</span>
                  <span class="past-owed-sub">From a stay you've left. You can't apply for a new room until it's settled.</span>
                  <button type="button" class="past-owed-btn" @click="pastPay = o">Settle {{ formatPesoExact(o.balance) }}</button>
                </div>
                <PaymentStatement
                  v-if="lease && canPay"
                  :ledger="ledger"
                  :payments="currentLeasePayments"
                  :start-date="lease.startDate"
                  role="student"
                  :closed="leaseClosed"
                  can-pay
                  :bill-utility="billUtility"
                  :metered="metered"
                  :who="myLandlord"
                  :deposit-held="depositHeld"
                  @pay="openPay(null)"
                  @open-payment="openPaymentDetail"
                  @resubmit="startResubmit"
                  @withdraw="withdrawPayment"
                  @message="router.push(`/student/messages?to=${lease.managerId}`)"
                />
                <p v-else-if="lease" class="pay-head-note">You'll be able to pay once your application is accepted.</p>
                <p v-if="leaseClosed" class="pay-head-note">This stay has ended. Settle what's left to be able to apply for a new room.</p>
                <p v-if="!lease && !payments.length" class="none">No payments yet.</p>
                <button v-if="payments.length" type="button" class="all-pay" @click="router.push('/student/profile/history?tab=payments')">
                  <IconifyIcon icon="lucide:receipt" width="16" />
                  All my payments
                  <IconifyIcon icon="lucide:chevron-right" width="16" class="all-pay-chev" />
                </button>
              </component>
            </component>
          </div>
        </div>
      </div>
    </q-pull-to-refresh>
    <AppModal v-model="leaveDialog" title="Request to leave?" size="sm">
      <p class="leave-body">
        Your {{ myLandlord }} approves or declines it. Your stay runs until the day you move out, and rent is owed until then.
      </p>
      <label class="mx-field leave-date">
        <span class="mx-label">When will you move out?</span>
        <DateTimeField v-model="leaveDate" mode="date" :min="manilaToday()" :max="lease?.endDate || ''" placeholder="Pick your move-out date" class="mx-input" />
      </label>
      <template #footer>
        <button type="button" class="leave-btn leave-btn--ghost" :disabled="leaving" @click="leaveDialog = false">
          Cancel
        </button>
        <button type="button" class="leave-btn" :disabled="leaving || !leaveDate" @click="requestLeave">
          {{ leaving ? 'Sending…' : 'Request to leave' }}
        </button>
      </template>
    </AppModal>

    <PaySheet
      v-if="lease"
      v-model="payOpen"
      :lease-id="lease.id"
      :resubmit="resubmit"
      :landlord-id="lease.managerId"
      :allow-partial="lease.allowPartial"
      :partial-min-pct="lease.partialMinPct"
      :settle-only="leaseClosed"
      :start-date="lease.startDate"
      @submitted="load(true)"
    />
    <PaySheet
      v-if="pastPay"
      :model-value="true"
      :lease-id="pastPay.leaseId"
      settle-only
      :landlord-id="pastPay.landlordId"
      :allow-partial="pastPay.allowPartial"
      :partial-min-pct="pastPay.partialMinPct"
      :subtitle="pastPay.place"
      @update:model-value="(v) => { if (!v) pastPay = null }"
      @submitted="load(true)"
    />

    <AppModal v-model="paymentDetailOpen" :title="selectedPayment ? paymentTitle(selectedPayment) : ''">
      <template v-if="selectedPayment">
        <span class="detail-chip" :class="`detail-chip--${statusColor(PAYMENT_STATUS, selectedPayment.status)}`">
          {{ statusText(PAYMENT_STATUS, selectedPayment.status) }}
        </span>

        <div class="group">
          <div class="rule">
            <span class="rule-label">Amount</span>
            <span class="rule-value">{{ formatPesoExact(selectedPayment.amount) }}</span>
          </div>
          <div v-if="selectedPayment.receiptNo" class="rule">
            <span class="rule-label">Receipt no.</span>
            <span class="rule-value">{{ selectedPayment.receiptNo }}</span>
          </div>
          <div v-if="selectedPayment.promiseDate" class="rule">
            <span class="rule-label">Rest promised by</span>
            <span class="rule-value">{{ formatDate(selectedPayment.promiseDate) }}</span>
          </div>
          <div class="rule">
            <span class="rule-label">Method</span>
            <span class="rule-value">{{ PAYMENT_METHOD_LABEL[selectedPayment.method] || selectedPayment.method }}</span>
          </div>
          <div class="rule">
            <span class="rule-label">Stay</span>
            <span class="rule-value">{{ selectedPayment.roomLabel }} · {{ selectedPayment.accommodationName }}</span>
          </div>
          <div v-if="selectedPayment.txnReference" class="rule">
            <span class="rule-label">Reference number</span>
            <span class="rule-value">{{ selectedPayment.txnReference }}</span>
          </div>
          <div v-if="selectedPayment.verifiedByName" class="rule">
            <span class="rule-label">Reviewed by</span>
            <span class="rule-value">
              {{ selectedPayment.verifiedByName }}{{ selectedPayment.paidAt ? ` · ${formatDate(selectedPayment.paidAt)}` : '' }}
            </span>
          </div>
        </div>

        <template v-if="selectedPayment.status === 'rejected' && selectedPayment.rejectionReason">
          <p class="detail-label detail-label--danger">Why it was sent back</p>
          <p class="detail-text">{{ selectedPayment.rejectionReason.replace('\n', ' — ') }}</p>
        </template>

        <template v-if="selectedPayment.note">
          <p class="detail-label">{{ selectedPayment.status === 'waived' ? 'Why it was forgiven' : 'Note' }}</p>
          <p class="detail-text">{{ selectedPayment.note }}</p>
        </template>

        <template v-if="selectedPayment.proofUrl">
          <p class="detail-label">Proof of payment</p>
          <img :src="resolveAsset(selectedPayment.proofUrl)" alt="Proof of payment" class="proof-img" />
        </template>

        <button
          v-if="selectedPayment.status === 'pending_verification'"
          type="button"
          class="detail-withdraw"
          :disabled="withdrawing"
          @click="withdrawPayment(selectedPayment)"
        >
          {{ withdrawing ? 'Taking it back…' : 'Take it back' }}
        </button>
        <button
          v-if="selectedPayment.status === 'rejected' && selectedPayment.leaseId === lease?.id"
          type="button"
          class="detail-fix"
          @click="paymentDetailOpen = false; startResubmit(selectedPayment)"
        >
          Fix and send again
        </button>
      </template>
    </AppModal>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { isTablet, isDesktop } from '@/utils/useTabletMode'
import { useDeskPanels } from '@/utils/useDeskPanels'
import { useRouter, useRoute } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import {
  formatPeso,
  formatPesoExact,
  formatDate,
  initialsOf,
  landlordTitle,
  PAYMENT_STATUS,
  PAYMENT_METHOD_LABEL,
  statusText,
  statusColor,
} from '@/utils/format'
import { useNotify } from '@/utils/notify'
import { confirmAction } from '@/utils/confirmAction'
import { signRows } from '@/utils/upload'
import { resolveAsset, COVER } from '@/utils/cloudinaryUrl'
import { AMENITY_META, UTILITIES, UTILITY_SELECT, isBilledMonthly, roomTypeLabel, utilitiesFromRow, utilityTermsLabel, type UtilityKey, type UtilityTerms } from '@/utils/listings'
import {
  isBillSettled,
  manilaToday,
  paymentTitle,
  toLedger,
  type LedgerRow,
} from '@/utils/payments'
import type { Resubmit } from '@/components/shared/PaySheet.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import StayHero from '@/components/student/StayHero.vue'
import PaySheet from '@/components/shared/PaySheet.vue'
import PaymentStatement from '@/components/shared/PaymentStatement.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import { POLICY_FULL } from '@/api/selects'
import AppModal from '@/components/shared/AppModal.vue'
import DateTimeField from '@/components/shared/DateTimeField.vue'

function yesNo(value: boolean | null | undefined): string {
  if (value === null || value === undefined) return ''
  return value ? 'Allowed' : 'Not allowed'
}

// Advance/deposit have no dedicated column on `payments` (only `month`,
// which rent needs and these don't) — tagged via `description` instead of a
// schema change, and excluded from the rent month-sequence by that tag.
// Rules live in utils/payments.ts so they can be tested without mounting this
// 1600-line page. The tags are re-exported names, not new constants.

interface Lease {
  id: string
  managerId: string
  managerName: string
  managerTitle: string
  managerInitials: string
  managerAvatarUrl: string | null
  replyMinutes: number | null
  accommodationName: string
  roomLabel: string
  /** The accommodation's cover photo, or empty for the monogram. */
  photoUrl: string
  status: 'active' | 'pending' | 'leave_requested' | 'ended' | 'terminated'
  monthlyRent: number
  /** The landlord/landlady's partial-payment terms for this stay. */
  allowPartial: boolean
  partialMinPct: number
  startDate: string
  endDate: string
  /** The move-out day asked for (waiting) or approved (still active). */
  leaveDate: string | null
  roomType: string
  capacity: number | null
  address: string
  amenities: string[]
  utilities: Record<UtilityKey, UtilityTerms>
  rules: { label: string; value: string }[]
  roommateCount: number | null
}
/** A water/electric bill the landlord/landlady posted (utility_bills). */
interface Bill {
  id: string
  leaseId: string
  utility: UtilityKey
  month: string
  amount: number
  note: string
  dueDate: string
  /** Unpaid past its due date (Manila time). */
  overdue: boolean
  settled: boolean
}
interface Payment {
  id: string
  leaseId: string
  month: string
  kind: string
  billId: string | null
  amount: number
  status: string
  method: string
  roomLabel: string
  accommodationName: string
  description: string
  txnReference: string
  proofUrl: string
  paidAt: string | null
  verifiedByName: string
  rejectionReason: string
  note: string
  promiseDate: string | null
  receiptNo: string
  createdAt: string
  batchId: string | null
}

const router = useRouter()
const route = useRoute()
const notify = useNotify()
// The student's landlord/landlady, titled by their sex, for running text.
const myLandlord = computed(() => (lease.value?.managerTitle ?? landlordTitle(null)).toLowerCase())

const loading = ref(true)
const error = ref('')
const lease = ref<Lease | null>(null)
const payments = ref<Payment[]>([])
const bills = ref<Bill[]>([])
// Which utility each bill is, for the statement's labels.
const billUtility = computed(() => Object.fromEntries(bills.value.map((b) => [b.id, b.utility])))
// Utilities this stay bills monthly (own meter or split), for "not posted yet".
const metered = computed(() =>
  lease.value ? UTILITIES.filter((u) => isBilledMonthly(lease.value!.utilities[u.key].billing)).map((u) => ({ key: u.key, label: u.label })) : [],
)
// The statement covers the current room; the rest is in History.
const currentLeasePayments = computed(() =>
  lease.value ? payments.value.filter((p) => p.leaseId === lease.value!.id) : payments.value,
)
// The deposit still held on this stay (paid in, less what it has paid for).
const depositReturned = ref(false)
const depositHeld = computed(() => {
  if (depositReturned.value) return 0
  const rows = currentLeasePayments.value.filter((p) => p.status === 'paid')
  return Math.max(rows.filter((p) => p.kind === 'deposit').reduce((s, p) => s + p.amount, 0) - rows.filter((p) => p.method === 'deposit').reduce((s, p) => s + p.amount, 0), 0)
})
// Deep links to the old /student/payments path (quick actions, settings,
// stored notification link_urls from before this merge) land straight on the
// Payments tab instead of needing a separate page.
const activeTab = ref<'stay' | 'payments'>(route.path === '/student/payments' ? 'payments' : 'stay')

const { panelsIs, panelIs, panelsProps } = useDeskPanels(activeTab, isTablet)

const leaveDialog = ref(false)
const leaveDate = ref('')
// Defaults to the end of this month, or the end of the stay if that's sooner.
function openLeave() {
  const t = manilaToday()
  const d = new Date(`${t.slice(0, 7)}-01T00:00:00`)
  d.setMonth(d.getMonth() + 1)
  d.setDate(0)
  const monthEnd = d.toLocaleDateString('en-CA')
  leaveDate.value = lease.value?.endDate && lease.value.endDate < monthEnd ? lease.value.endDate : monthEnd
  leaveDialog.value = true
}
const leaving = ref(false)

const payOpen = ref(false)
// A transfer sent back, opened again with the same items and the reason in view.
const resubmit = ref<Resubmit | null>(null)
function openPay(r: Resubmit | null) {
  resubmit.value = r
  payOpen.value = true
}
function startResubmit(p: Payment) {
  const batch = currentLeasePayments.value.filter((x) => (p.batchId ? x.batchId === p.batchId : x.id === p.id))
  openPay({
    reason: p.rejectionReason,
    method: p.method,
    reference: p.txnReference,
    pick: {
      months: batch.filter((x) => x.kind === 'rent').length,
      billIds: batch.filter((x) => x.kind === 'bill' && x.billId).map((x) => x.billId as string),
      deposit: batch.some((x) => x.kind === 'deposit'),
    },
  })
}
// Balances on ended stays other than the one shown (student_past_balance).
interface PastOwed { leaseId: string; landlordId: string; place: string; balance: number; allowPartial: boolean; partialMinPct: number }
const pastOwed = ref<PastOwed[]>([])
const pastPay = ref<PastOwed | null>(null)
// What is owed, from the database (lease_ledger). It refuses anything that
// breaks its rules; the form only says so first. Empty until loaded, when the
// older payment-list rules below stand in.
const ledger = ref<LedgerRow[]>([])
async function loadLedger() {
  if (!lease.value || lease.value.status === 'pending') { ledger.value = []; return }
  const { data } = await supabase.rpc('lease_ledger', { p_lease: lease.value.id })
  ledger.value = toLedger(data)
}
// A stay that ended with something still owed: shown so it can be settled.
const leaseClosed = computed(() => lease.value?.status === 'ended' || lease.value?.status === 'terminated')
const paymentDetailOpen = ref(false)
const selectedPayment = ref<Payment | null>(null)
function openPaymentDetail(p: Payment) {
  selectedPayment.value = p
  paymentDetailOpen.value = true
}

// A pending application isn't an accepted lease yet, so there's nothing to pay.
const canPay = computed(() => lease.value?.status !== 'pending')

const LEASE_SELECT = `id, room_id, status, start_date, end_date, leave_date, deposit_returned_at, monthly_rent, allow_partial, partial_min_pct, landlord_id, ${UTILITY_SELECT}, rooms(room_number, label, room_type, custom_room_type, capacity, accommodations(id, name, address, barangay, city, accommodation_amenities(amenity), accommodation_policies(${POLICY_FULL})))`

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data: authData } = await authUser()
    const user = authData?.user
    if (!user) {
      error.value = 'Not logged in.'
      return
    }

    // The current lease (for the Stay tab) and all-time payment history (for
    // the Payments tab) are independent — a student with no active lease can
    // still have real payments on file from a past stay, so the Payments tab
    // must not be gated on there being a lease right now.
    const [
      { data: currentLease, error: leaseError },
      { data: paymentRows, error: paymentsError },
      { data: billRows, error: billsError },
    ] = await Promise.all([
      supabase
        .from('leases')
        .select(LEASE_SELECT)
        .eq('student_id', user.id)
        .in('status', ['active', 'pending', 'leave_requested'])
        .order('start_date', { ascending: false })
        .limit(1)
        .maybeSingle(),
      supabase
        .from('payments')
        .select(
          'id, lease_id, month, amount, status, method, kind, bill_id, description, txn_reference, proof_url, paid_at, rejection_reason, note, promise_date, receipt_no, created_at, batch_id, verified_by_user:users!payments_verified_by_fkey(full_name), leases!inner(student_id, rooms(room_number, label, accommodations(name)))',
        )
        .eq('leases.student_id', user.id)
        .order('month', { ascending: false }),
      supabase
        .from('utility_bills')
        .select('id, lease_id, utility, month, amount, note, due_date, payments(status, amount), leases!inner(student_id)')
        .eq('leases.student_id', user.id),
    ])
    if (leaseError) throw leaseError
    if (paymentsError) throw paymentsError
    if (billsError) throw billsError

    bills.value = (billRows ?? []).map((b) => ({
      id: b.id,
      leaseId: b.lease_id,
      utility: b.utility as UtilityKey,
      month: b.month,
      amount: Number(b.amount),
      note: b.note || '',
      dueDate: b.due_date,
      overdue: b.due_date < manilaToday(),
      settled: isBillSettled(b.payments, Number(b.amount)),
    }))

    await signRows('payments', paymentRows, 'proof_url')
    payments.value = (paymentRows ?? []).map((p) => {
      const payLease = p.leases as unknown as {
        rooms: { room_number: string | null; label: string | null; accommodations: { name: string | null } | null } | null
      }
      const payRoom = payLease.rooms
      const verifier = p.verified_by_user as unknown as { full_name: string | null } | null
      return {
        id: p.id,
        leaseId: p.lease_id,
        month: p.month,
        kind: p.kind,
        billId: p.bill_id,
        amount: Number(p.amount),
        status: p.status,
        method: p.method,
        roomLabel: payRoom?.label || (payRoom?.room_number ? `Room ${payRoom.room_number}` : 'Your room'),
        accommodationName: payRoom?.accommodations?.name || 'Your accommodation',
        description: p.description || '',
        txnReference: p.txn_reference || '',
        proofUrl: p.proof_url || '',
        paidAt: p.paid_at,
        verifiedByName: verifier?.full_name || '',
        rejectionReason: p.rejection_reason || '',
        note: p.note || '',
        promiseDate: p.promise_date,
        receiptNo: p.receipt_no || '',
        createdAt: p.created_at,
        batchId: p.batch_id,
      }
    })

    // Ended stays with something still owed: it blocks applying elsewhere, so
    // it stays on this screen until settled. With no current stay, the latest
    // of them takes the main card; any others get a "Pay" row of their own.
    const { data: owed } = await supabase.rpc('student_past_balance', { p_student: user.id })
    let leaseRow = currentLease
    if (!leaseRow && owed?.[0]) {
      leaseRow = (await supabase.from('leases').select(LEASE_SELECT).eq('id', owed[0].lease_id).maybeSingle()).data
    }
    const others = (owed ?? []).filter((o) => o.lease_id !== leaseRow?.id)
    const { data: otherLeases } = others.length
      ? await supabase.from('leases').select('id, landlord_id, allow_partial, partial_min_pct').in('id', others.map((o) => o.lease_id))
      : { data: [] }
    pastOwed.value = others.map((o) => {
      const l = otherLeases?.find((x) => x.id === o.lease_id)
      return {
        leaseId: o.lease_id,
        landlordId: l?.landlord_id ?? '',
        place: `${o.accommodation} · ${o.room}`,
        balance: Number(o.balance),
        allowPartial: Boolean(l?.allow_partial),
        partialMinPct: Number(l?.partial_min_pct ?? 10),
      }
    })
    if (!leaseRow) {
      lease.value = null
      return
    }

    const room = leaseRow.rooms as unknown as {
      room_number: string | null
      label: string | null
      room_type: string | null
      custom_room_type: string | null
      capacity: number | null
      accommodations: {
        id: string
        name: string | null
        address: string | null
        barangay: string | null
        city: string | null
        accommodation_amenities: { amenity: string }[] | null
        accommodation_policies: Record<string, unknown>[] | Record<string, unknown> | null
      } | null
    } | null

    const acc = room?.accommodations
    const amenities = ((acc?.accommodation_amenities ?? []) as { amenity: string }[]).map((a) => a.amenity).filter((a) => a in AMENITY_META)
    const policyRows = acc?.accommodation_policies
    const policy = (Array.isArray(policyRows) ? policyRows[0] : policyRows) as Record<string, unknown> | null | undefined
    const rules = policy
      ? (
          [
            { label: 'Curfew', value: String(policy.curfew_time ?? '') },
            { label: 'Quiet hours', value: String(policy.quiet_hours ?? '') },
            { label: 'Visitors', value: String(policy.visitor_policy ?? '') },
            { label: 'Cooking', value: yesNo(policy.cooking as boolean | null) },
            { label: 'Laundry', value: yesNo(policy.laundry as boolean | null) },
            { label: 'Pets', value: yesNo(policy.pets as boolean | null) },
            { label: 'Contract type', value: String(policy.contract_type ?? '') },
          ] as { label: string; value: string }[]
        ).filter((r) => r.value)
      : []

    const [{ data: manager }, { data: profile }, roommateResult, { data: cover }] = await Promise.all([
      supabase.from('users').select('full_name, initials, avatar_url, sex').eq('id', leaseRow.landlord_id).maybeSingle(),
      supabase
        .from('landlord_profiles')
        .select('avg_response_minutes')
        .eq('user_id', leaseRow.landlord_id)
        .maybeSingle(),
      leaseRow.room_id
        ? supabase
            .from('leases')
            .select('id', { count: 'exact', head: true })
            .eq('room_id', leaseRow.room_id)
            .eq('status', 'active')
            .neq('student_id', user.id)
        : Promise.resolve({ count: null }),
      acc?.id
        ? supabase.from('accommodation_images').select('url').eq('accommodation_id', acc.id).order('sort_order', { ascending: true }).limit(1).maybeSingle()
        : Promise.resolve({ data: null }),
    ])

    lease.value = {
      id: leaseRow.id,
      managerId: leaseRow.landlord_id,
      managerName: manager?.full_name || landlordTitle(manager?.sex),
      managerTitle: landlordTitle(manager?.sex),
      managerInitials: manager?.initials || initialsOf(manager?.full_name || '?'),
      managerAvatarUrl: manager?.avatar_url ? resolveAsset(manager.avatar_url) : null,
      replyMinutes: profile?.avg_response_minutes ?? null,
      accommodationName: room?.accommodations?.name || 'Your accommodation',
      roomLabel: room?.label || (room?.room_number ? `Room ${room.room_number}` : ''),
      photoUrl: cover?.url ? resolveAsset(cover.url, COVER) : '',
      status: leaseRow.status as Lease['status'],
      monthlyRent: Number(leaseRow.monthly_rent ?? 0),
      allowPartial: Boolean(leaseRow.allow_partial),
      partialMinPct: Number(leaseRow.partial_min_pct ?? 50),
      startDate: leaseRow.start_date,
      endDate: leaseRow.end_date,
      leaveDate: leaseRow.leave_date,
      roomType: roomTypeLabel(room?.custom_room_type || room?.room_type),
      capacity: room?.capacity ?? null,
      address: acc?.address || [acc?.barangay, acc?.city].filter(Boolean).join(', ') || '',
      amenities,
      // The terms this lease was agreed under, copied from the room at move-in
      // (like monthly_rent) — a later change to the room doesn't reach it.
      utilities: utilitiesFromRow(leaseRow),
      rules,
      roommateCount: roommateResult.count,
    }
    depositReturned.value = !!leaseRow.deposit_returned_at
    await loadLedger()
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

async function requestLeave() {
  if (!(await confirmAction({ title: 'Request to leave?', message: `Your ${myLandlord.value} will be asked to approve it.` }))) return
  if (leaving.value || !lease.value) return
  leaving.value = true
  try {
    const { data: authData } = await authUser()
    const user = authData?.user
    if (!user) throw new Error('Not logged in.')

    const { error: updateError } = await supabase
      .from('leases')
      .update({ status: 'leave_requested', leave_requested_at: new Date().toISOString(), leave_date: leaveDate.value })
      .eq('id', lease.value.id)
      .eq('student_id', user.id)
    if (updateError) throw updateError

    lease.value = { ...lease.value, status: 'leave_requested', leaveDate: leaveDate.value }
    leaveDialog.value = false
    notify.success('Leave request sent.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not send your leave request.'))
  } finally {
    leaving.value = false
  }
}

const withdrawing = ref(false)
async function withdrawPayment(p: Payment) {
  if (withdrawing.value) return
  if (!(await confirmAction({ title: 'Withdraw this payment?', message: `It is taken back before your ${myLandlord.value} reviews it. You can submit a new one.` }))) return
  withdrawing.value = true
  try {
    const { error: rpcError } = await supabase.rpc('review_payment', { p_payment: p.id, p_action: 'withdraw' })
    if (rpcError) throw rpcError
    paymentDetailOpen.value = false
    notify.success('Payment withdrawn.')
    void load(true)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not withdraw this payment.'))
  } finally {
    withdrawing.value = false
  }
}

// Kept alive across navigation (see MainLayout's KEEP_ALIVE_PAGES), so the
// database pushes lease changes here instead of the page re-asking on every
// return. utils/useLiveData.ts owns the whole policy — first load, the
// subscription's lifetime, and how stale the data may be on return.
const { refresh } = useLiveData({
  key: 'student-stay',
  load,
  // leases/payments are not in the realtime publication; confirmations and
  // rejections notify the student, so their notifications are the signal.
  watch: (uid) => [
    { table: 'leases', filter: `student_id=eq.${uid}` },
    { table: 'notifications', filter: `user_id=eq.${uid}` },
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
.sp {
  display: flex;
  flex-direction: column;
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  gap: 14px;
  padding: 8px var(--m-page-gutter) 0;
}
.sk {
  border-radius: var(--m-radius);
}

/* Default tabbing design (see AccommodationDetail.vue) — edge-to-edge tabs
   and a panel stretched flush to the true bottom of the page (same
   full-bleed + bottom-flush technique as ManagerTenantsPage.vue): the whole
   flex chain (.sp -> .stack -> .tabbed -> .panel) has to carry flex:1;
   min-height:0 for this to work, not just the panel itself. */
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
  /* -2px, not -1px: an exact 1px overlap can round the wrong way at
     fractional device-pixel ratios (real phones, not desktop @1x) and leave
     a hairline gap of page background under the active tab. */
  margin: 0 calc(var(--m-page-gutter) * -1) -2px;
  padding: 0 var(--m-page-gutter);
}
.panel {
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  margin: 0 calc(var(--m-page-gutter) * -1);
  padding: 14px 14px 20px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
.tab-panel {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.sec {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.sec-title {
  margin: 0;
  padding: 6px 2px 0;
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.04em;
  /* Quasar gives h2 a 3.75rem line-height, which an 11px label inherits. */
  line-height: 1.3;
  text-transform: uppercase;
}
.sec-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
  padding: 0 2px;
}
.sec-head .sec-title {
  padding: 0;
}
.sec-link {
  flex: 0 0 auto;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12px;
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
.rule {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .rule:first-child {
  border-top: 0;
}
.rule-label {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.rule-value {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
  text-align: right;
}

/* The hero runs edge to edge under the app header, and the tab strip is
   pulled up over its bottom edge so the panel rises out of the photo — the
   same recipe as AccommodationDetail.vue. .m-tabbed has no gap, so the two
   negative margins are all that sits between them. */
.sk-hero {
  margin: -8px calc(var(--m-page-gutter) * -1) 0;
  width: auto;
}
.m-tabbed--hero > .stay-hero {
  margin: -8px calc(var(--m-page-gutter) * -1) 0;
}
.m-tabbed--hero > .tabs {
  margin-top: -56px;
}
/* Desktop: the hero heads the stay half instead, as a card of its own. */
.desk-col > .stay-hero {
  height: 180px;
  border-radius: var(--m-radius);
}

.mgr {
  display: flex;
  align-items: center;
  gap: 11px;
}
.mgr-avatar {
  display: grid;
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 800;
}
.mgr-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.mgr-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.mgr-name {
  overflow: hidden;
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.mgr-sub {
  color: var(--m-muted);
  font-size: 12px;
}
.mgr-msg {
  display: grid;
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.note {
  margin: -4px 0 0;
  padding: 9px 12px;
  border-radius: var(--m-radius-sm);
  background: var(--m-warning-soft);
  color: var(--m-warning);
  font-size: 12.5px;
  font-weight: 600;
}

/* Key facts: recessed tiles, so they read as their own surface on the panel. */
.facts {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}
.fact {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
  padding: 12px 13px;
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
}
.fact-label {
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.fact-value {
  overflow: hidden;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
  letter-spacing: -0.01em;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.fact-sub {
  color: var(--m-muted);
  font-size: 12px;
}

/* Reference rows: one hairline column, no boxes. */
.line {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 16px;
  padding: 10px 2px;
  border-top: 1px solid var(--m-border);
}
.line-label {
  flex: 0 0 auto;
  color: var(--m-muted);
  font-size: 13px;
}
.line-value {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
  text-align: right;
  text-wrap: pretty;
}
.line-link {
  width: 100%;
  align-items: center;
  justify-content: flex-start;
  gap: 10px;
  border-right: 0;
  border-bottom: 0;
  border-left: 0;
  background: transparent;
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 600;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.line-link .chevron {
  margin-left: auto;
  color: var(--m-muted);
}

.amenities {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  padding-top: 4px;
}
.amenity {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 11px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 12.5px;
  font-weight: 600;
}

.leave-link {
  align-self: center;
  padding: 8px;
  border: 0;
  background: transparent;
  color: var(--m-danger);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  text-decoration: underline;
  -webkit-tap-highlight-color: transparent;
}

.detail-chip {
  align-self: flex-start;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.detail-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.detail-chip--amber,
.detail-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.detail-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.detail-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.detail-label {
  margin: 4px 0 0;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.detail-label--danger {
  color: var(--m-danger);
}
.detail-text {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
}
.proof-img {
  width: 100%;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
}
.leave-date {
  margin-top: 14px;
}
.leave-body {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
}
.leave-btn {
  flex: 1;
  min-height: 46px;
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
.leave-btn:disabled {
  opacity: 0.6;
}
.leave-btn--ghost {
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}

.pay-head-note {
  margin: 10px 0 0;
  color: var(--m-muted);
  font-size: 12.5px;
}
.past-owed {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 14px;
  padding: 16px;
  border: 1px solid color-mix(in srgb, var(--m-danger) 30%, transparent);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.past-owed-label {
  color: var(--m-danger);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.past-owed-amt {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 28px;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1.1;
}
.past-owed-sub {
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.45;
}
.past-owed-btn {
  min-height: 46px;
  margin-top: 4px;
  border: 0;
  border-radius: 999px;
  background: var(--m-danger);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14.5px;
  font-weight: 700;
}
.all-pay {
  display: flex;
  width: 100%;
  min-height: 48px;
  align-items: center;
  gap: 10px;
  margin-top: 14px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
.all-pay-chev {
  margin-left: auto;
  color: var(--m-muted);
}
.detail-fix {
  min-height: 48px;
  border: 0;
  border-radius: 999px;
  background: var(--m-danger);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14.5px;
  font-weight: 700;
}
.detail-withdraw {
  min-height: 44px;
  border: 0;
  background: none;
  color: var(--m-danger);
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}

.none {
  padding: 14px 12px;
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}

/* Both panels at once on a landscape tablet. The tab strip is gone, so the panel
   squares off the top corners it was using to fuse into it, and each half names
   itself where its tab used to. */
.stay-both .panel {
  border-radius: var(--m-radius);
}
.stay-both .m-panels {
  display: grid;
  gap: 20px;
  grid-template-columns: 1fr 1fr;
  align-items: start;
}
.stay-both .tab-panel + .tab-panel {
  padding-left: 20px;
  border-left: 1px solid var(--m-border);
}
.split-head {
  margin: 0 0 2px;
  line-height: 1.3;
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.01em;
}
</style>
