<template>
  <q-page class="sp" :class="{ 'page-wide': isDesktop }">
    <q-pull-to-refresh @refresh="onPull">
      <div v-if="loading" class="stack">
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
        <div class="m-tabbed" :class="{ 'stay-both': isTablet }">
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
            <!-- Not QTabPanels: it mounts only the active panel, which is exactly
                 what has to stop happening here. v-show keeps both in the DOM and
                 lets CSS decide, and v-touch-swipe puts back the one thing the
                 component was giving us that the phone actually used. -->
            <div v-touch-swipe.mouse.horizontal="onTabSwipe" :class="isDesktop ? 'desk-contents' : 'm-panels'">
              <div v-show="isTablet || activeTab === 'stay'" :class="isDesktop ? 'desk-col' : 'tab-panel'">
                <h2 v-if="isTablet" class="split-head">My Stay</h2>
                <template v-if="lease">
                  <div class="head">
                    <div class="head-top">
                      <span class="head-name">{{ lease.accommodationName }}</span>
                      <button type="button" class="head-history-link" @click="router.push('/student/profile/history')">View history</button>
                    </div>
                    <span v-if="lease.roomLabel" class="head-room">{{ lease.roomLabel }}</span>
                    <span class="head-chip" :class="`head-chip--${statusColor(LEASE_STATUS, lease.status)}`">{{ statusText(LEASE_STATUS, lease.status) }}</span>
                    <p v-if="lease.status === 'pending'" class="head-note">Application pending — awaiting your landlord/landlady's decision.</p>
                    <p v-else-if="lease.status === 'leave_requested'" class="head-note">Leave requested — awaiting your landlord/landlady's decision.</p>
                  </div>

                  <!-- Manager contact -->
                  <section class="sec">
                    <h2 class="sec-title">Your {{ lease.managerTitle.toLowerCase() }}</h2>
                    <div class="mgr">
                      <span class="mgr-avatar">
                        <img v-if="lease.managerAvatarUrl" :src="lease.managerAvatarUrl" alt="" class="mgr-avatar-img" @error="lease.managerAvatarUrl = null" />
                        <template v-else>{{ lease.managerInitials }}</template>
                      </span>
                      <span class="mgr-body">
                        <span class="mgr-name">{{ lease.managerName }}</span>
                        <span class="mgr-sub">{{ lease.replyMinutes ? `Replies in ~${lease.replyMinutes} min` : lease.managerTitle }}</span>
                      </span>
                      <button type="button" class="mgr-msg" @click="router.push(`/student/messages?to=${lease.managerId}`)">
                        <IconifyIcon icon="lucide:message-circle" width="15" />
                        Message
                      </button>
                    </div>
                  </section>

                  <!-- Money at a glance -->
                  <section class="sec">
                    <h2 class="sec-title">Money at a glance</h2>
                    <div class="group">
                      <div class="rule">
                        <span class="rule-label">Monthly rent</span>
                        <span class="rule-value">{{ formatPeso(lease.monthlyRent) }}</span>
                      </div>
                      <div v-if="lease.advancePaid" class="rule">
                        <span class="rule-label">Advance paid</span>
                        <span class="rule-value">{{ formatPeso(lease.advancePaid) }}</span>
                      </div>
                      <div v-if="lease.depositPaid" class="rule">
                        <span class="rule-label">Deposit paid</span>
                        <span class="rule-value">{{ formatPeso(lease.depositPaid) }}</span>
                      </div>
                      <div v-for="u in UTILITIES" :key="u.key" class="rule">
                        <span class="rule-label">{{ u.label }}</span>
                        <span class="rule-value">{{ utilityTermsLabel(lease.utilities[u.key]) }}</span>
                      </div>
                      <div class="rule">
                        <span class="rule-label">Lease term</span>
                        <span class="rule-value">{{ formatDate(lease.startDate) }} – {{ formatDate(lease.endDate) }}</span>
                      </div>
                    </div>
                  </section>

                  <!-- Room & boarding house -->
                  <section class="sec">
                    <h2 class="sec-title">About your room</h2>
                    <div class="group">
                      <div class="rule">
                        <span class="rule-label">Room type</span>
                        <span class="rule-value">{{ lease.roomType || '—' }}</span>
                      </div>
                      <div v-if="lease.capacity" class="rule">
                        <span class="rule-label">Capacity</span>
                        <span class="rule-value">{{ lease.capacity }} {{ lease.capacity === 1 ? 'person' : 'people' }}</span>
                      </div>
                      <div v-if="lease.roommateCount !== null" class="rule">
                        <span class="rule-label">Roommates</span>
                        <span class="rule-value">
                          {{ lease.roommateCount > 0 ? `${lease.roommateCount} other${lease.roommateCount === 1 ? '' : 's'} in this room` : 'None — you have it to yourself' }}
                        </span>
                      </div>
                      <div v-if="lease.address" class="rule">
                        <span class="rule-label">Address</span>
                        <span class="rule-value">{{ lease.address }}</span>
                      </div>
                    </div>
                  </section>

                  <section v-if="lease.amenities.length" class="sec">
                    <h2 class="sec-title">Amenities</h2>
                    <div class="icon-grid">
                      <span v-for="a in lease.amenities" :key="a" class="icon-item">
                        <span class="icon-circle"><IconifyIcon :icon="AMENITY_META[a]?.icon || 'lucide:dot'" width="19" /></span>
                        <small>{{ AMENITY_META[a]?.label || a }}</small>
                      </span>
                    </div>
                  </section>

                  <section v-if="lease.rules.length" class="sec">
                    <h2 class="sec-title">House rules</h2>
                    <div class="group">
                      <div v-for="rule in lease.rules" :key="rule.label" class="rule">
                        <span class="rule-label">{{ rule.label }}</span>
                        <span class="rule-value">{{ rule.value }}</span>
                      </div>
                    </div>
                  </section>

                  <!-- Quick links -->
                  <section class="sec">
                    <div class="group">
                      <button type="button" class="row-link" @click="router.push('/student/concerns')">
                        <IconifyIcon icon="lucide:message-square-warning" width="16" />
                        <span>Concerns</span>
                        <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
                      </button>
                    </div>
                  </section>

                  <button v-if="lease.status === 'active'" type="button" class="leave-link" @click="leaveDialog = true">
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
              </div>

              <div v-show="isTablet || activeTab === 'payments'" :class="isDesktop ? 'desk-col' : 'tab-panel'">
                <h2 v-if="isTablet" class="split-head">Payments</h2>
                <div v-for="o in pastOwed" :key="o.leaseId" class="past-owed">
                  <span class="past-owed-body">
                    <span class="past-owed-title">{{ formatPesoExact(o.balance) }} owed on a past stay</span>
                    <span class="past-owed-sub">{{ o.place }} · settle it to be able to apply for rooms again</span>
                  </span>
                  <button type="button" class="past-owed-btn" @click="pastPay = o">Pay</button>
                </div>
                <div v-if="lease" class="pay-head">
                  <span class="pay-head-label">Expected rent</span>
                  <span class="pay-head-rent">{{ formatPeso(lease.monthlyRent) }}<span class="pay-head-per">/mo</span></span>
                  <span class="pay-head-sub">{{ lease.roomLabel || 'Your room' }} · {{ lease.accommodationName }}</span>
                  <p v-if="owedNow > 0.009" class="pay-head-owed" :class="{ 'pay-head-owed--overdue': hasOverdue }">
                    {{ formatPesoExact(owedNow) }} owed now{{ hasOverdue ? ' · overdue' : '' }}
                  </p>
                  <p v-if="leaseClosed" class="pay-head-note">This stay has ended. Settle what's left to be able to apply for a new room.</p>
                  <div v-if="canPay && (canPayAdvance || canPayDeposit || unpaidBills.length)" class="pay-dues">
                    <div v-for="b in unpaidBills" :key="b.id" class="pay-due">
                      <span class="pay-due-body">
                        <span class="pay-due-label">{{ BILL_TAG[b.utility] }} · {{ formatMonth(b.month) }}</span>
                        <span class="pay-due-note" :class="{ 'pay-due-note--overdue': b.overdue }">
                          {{ billNote(b) }} · {{ b.overdue ? 'overdue since' : 'due' }} {{ formatDate(b.dueDate) }}{{ b.note ? ` · ${b.note}` : '' }}
                        </span>
                      </span>
                    </div>
                    <div v-if="canPayAdvance && !leaseClosed" class="pay-due">
                      <span class="pay-due-body">
                        <span class="pay-due-label">Advance</span>
                        <span class="pay-due-note">{{ itemNote('advance') }}</span>
                      </span>
                    </div>
                    <div v-if="canPayDeposit && !leaseClosed" class="pay-due">
                      <span class="pay-due-body">
                        <span class="pay-due-label">Deposit</span>
                        <span class="pay-due-note">{{ itemNote('deposit') }}</span>
                      </span>
                    </div>
                  </div>
                  <button v-if="canPay && (!leaseClosed || owedNow > 0.009)" type="button" class="pay-head-btn" @click="payOpen = true">
                    <IconifyIcon icon="lucide:wallet" width="16" />
                    Pay
                  </button>
                  <p v-else-if="!canPay" class="pay-head-note">You'll be able to pay once your application is accepted.</p>
                </div>

                <section class="sec">
                  <div class="sec-head">
                    <h2 class="sec-title">{{ showAllPayments ? 'All payments' : 'History' }}</h2>
                    <button v-if="hasOtherLeasePayments" type="button" class="sec-link" @click="showAllPayments = !showAllPayments">
                      {{ showAllPayments ? 'Current room only' : 'View all payments' }}
                    </button>
                  </div>
                  <p v-if="!showAllPayments && lease" class="pay-head-note">Payments for {{ lease.roomLabel || 'your current room' }}.</p>
                  <div v-if="visibleHistoryPayments.length" class="group">
                    <button
                      v-for="p in visibleHistoryPayments"
                      :key="p.id"
                      type="button"
                      class="pay-row"
                      @click="openPaymentDetail(p)"
                    >
                      <span class="pay-icon"><IconifyIcon icon="lucide:receipt" width="16" /></span>
                      <span class="pay-body">
                        <span class="pay-month">{{ paymentTitle(p) }}</span>
                        <span class="pay-method">{{ PAYMENT_METHOD_LABEL[p.method] || p.method }} · {{ p.accommodationName }}</span>
                      </span>
                      <span class="pay-side">
                        <span class="pay-amount">{{ formatPesoExact(p.amount) }}</span>
                        <span class="pay-chip" :class="`pay-chip--${statusColor(PAYMENT_STATUS, p.status)}`">
                          {{ statusText(PAYMENT_STATUS, p.status) }}
                        </span>
                      </span>
                      <IconifyIcon icon="lucide:chevron-right" width="16" class="pay-chevron" />
                    </button>
                  </div>
                  <p v-else class="none">No payments {{ showAllPayments ? 'submitted yet' : 'for this room yet' }}.</p>
                </section>
              </div>
            </div>
          </div>
        </div>
      </div>

    </q-pull-to-refresh>
    <q-dialog v-model="leaveDialog" position="bottom">
      <q-card class="leave-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <h3 class="leave-title">Request to leave?</h3>
        <p class="leave-body">
          Your landlord/landlady will be notified and needs to approve this before your stay ends. You'll stay on your
          current lease until then.
        </p>
        <div class="leave-actions">
          <button type="button" class="leave-btn leave-btn--ghost" :disabled="leaving" @click="leaveDialog = false">
            Cancel
          </button>
          <button type="button" class="leave-btn" :disabled="leaving" @click="requestLeave">
            {{ leaving ? 'Sending…' : 'Request to leave' }}
          </button>
        </div>
      </q-card>
    </q-dialog>

    <PaySheet
      v-if="lease"
      v-model="payOpen"
      :lease-id="lease.id"
      role="student"
      :landlord-id="lease.managerId"
      :allow-partial="lease.allowPartial"
      :partial-min-pct="lease.partialMinPct"
      :settle-only="leaseClosed"
      @submitted="load(true)"
    />
    <PaySheet
      v-if="pastPay"
      :model-value="true"
      :lease-id="pastPay.leaseId"
      role="student"
      settle-only
      :landlord-id="pastPay.landlordId"
      :allow-partial="pastPay.allowPartial"
      :partial-min-pct="pastPay.partialMinPct"
      :subtitle="pastPay.place"
      @update:model-value="(v) => { if (!v) pastPay = null }"
      @submitted="load(true)"
    />

    <q-dialog v-model="paymentDetailOpen" position="bottom">
      <q-card v-if="selectedPayment" class="detail-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="detail-head">
          <h3 class="detail-title">{{ paymentTitle(selectedPayment) }}</h3>
          <button type="button" class="sheet-x" aria-label="Close" @click="paymentDetailOpen = false">
            <IconifyIcon icon="lucide:x" width="20" />
          </button>
        </div>
        <span class="detail-chip" :class="`detail-chip--${statusColor(PAYMENT_STATUS, selectedPayment.status)}`">
          {{ statusText(PAYMENT_STATUS, selectedPayment.status) }}
        </span>

        <div class="group">
          <div class="rule">
            <span class="rule-label">Amount</span>
            <span class="rule-value">{{ formatPesoExact(selectedPayment.amount) }}</span>
          </div>
          <div v-if="selectedPayment.claimedAmount" class="rule">
            <span class="rule-label">You submitted</span>
            <span class="rule-value">{{ formatPesoExact(selectedPayment.claimedAmount) }} — only {{ formatPesoExact(selectedPayment.amount) }} arrived</span>
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
          <p class="detail-label detail-label--danger">Rejection reason</p>
          <p class="detail-text">{{ selectedPayment.rejectionReason }}</p>
        </template>

        <template v-if="selectedPayment.undoReason && selectedPayment.status === 'pending_verification'">
          <p class="detail-label detail-label--danger">Confirmation undone</p>
          <p class="detail-text">{{ selectedPayment.undoReason }}</p>
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
          {{ withdrawing ? 'Withdrawing…' : 'Withdraw this payment' }}
        </button>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { isTablet, isDesktop } from '@/utils/useTabletMode'
import { useRouter, useRoute } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import {
  formatPeso,
  formatPesoExact,
  formatDate,
  formatMonth,
  initialsOf,
  landlordTitle,
  LEASE_STATUS,
  PAYMENT_STATUS,
  PAYMENT_METHOD_LABEL,
  statusText,
  statusColor,
} from '@/utils/format'
import { useNotify } from '@/utils/notify'
import { requirePin } from '@/utils/requirePin'
import { signRows } from '@/utils/upload'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { AMENITY_META, UTILITIES, UTILITY_SELECT, roomTypeLabel, utilitiesFromRow, utilityTermsLabel, type UtilityKey, type UtilityTerms } from '@/utils/listings'
import {
  BILL_TAG,
  isBillSettled,
  manilaToday,
  paymentTitle,
  toLedger,
  type LedgerRow,
} from '@/utils/payments'
import EmptyState from '@/components/shared/EmptyState.vue'
import PaySheet from '@/components/shared/PaySheet.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import { POLICY_FULL } from '@/api/selects'

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
  status: 'active' | 'pending' | 'leave_requested' | 'ended' | 'terminated'
  monthlyRent: number
  advancePaid: number
  /** The landlord/landlady's partial-payment terms for this stay. */
  allowPartial: boolean
  partialMinPct: number
  depositPaid: number
  startDate: string
  endDate: string
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
  /** What the student said they sent, when less arrived. */
  claimedAmount: number | null
  undoReason: string
  receiptNo: string
}

const router = useRouter()
const route = useRoute()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const lease = ref<Lease | null>(null)
const payments = ref<Payment[]>([])
const bills = ref<Bill[]>([])
// Bills still owed on the current stay, soonest due first.
const unpaidBills = computed(() =>
  bills.value.filter((b) => !b.settled && b.leaseId === lease.value?.id).sort((a, b) => a.dueDate.localeCompare(b.dueDate)),
)
const showAllPayments = ref(false)

// Payment history defaults to the current room only — a student who's moved
// between rooms shouldn't see an unlabeled mix of past and present dues.
const currentLeasePayments = computed(() =>
  lease.value ? payments.value.filter((p) => p.leaseId === lease.value!.id) : payments.value,
)
const hasOtherLeasePayments = computed(() => Boolean(lease.value) && payments.value.length > currentLeasePayments.value.length)
const visibleHistoryPayments = computed(() => (showAllPayments.value || !lease.value ? payments.value : currentLeasePayments.value))
// Deep links to the old /student/payments path (quick actions, settings,
// stored notification link_urls from before this merge) land straight on the
// Payments tab instead of needing a separate page.
const activeTab = ref<'stay' | 'payments'>(route.path === '/student/payments' ? 'payments' : 'stay')

// Replaces QTabPanels' `swipeable`. Inert on a tablet, where both panels are
// already on screen and activeTab is not driving anything.
function onTabSwipe({ direction }: { direction: string }) {
  if (isTablet.value) return
  activeTab.value = direction === 'left' ? 'payments' : 'stay'
}

const leaveDialog = ref(false)
const leaving = ref(false)

const payOpen = ref(false)
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
// What is owed today — rent up to this month, bills, advance and deposit.
const owedNow = computed(() => {
  const today = manilaToday()
  return ledger.value
    // Once a stay has ended, everything left on it is owed now — the same sum
    // past_stay_balance() blocks applying on — not only what is past due.
    .filter((r) => r.kind !== 'rent' || leaseClosed.value || (r.dueDate ?? '') <= today || r.state === 'overdue')
    .filter((r) => !leaseClosed.value || r.kind === 'rent' || r.kind === 'bill')
    .reduce((sum, r) => sum + r.balance, 0)
})
const hasOverdue = computed(() => ledger.value.some((r) => r.state === 'overdue'))
function billNote(b: Bill): string {
  const row = ledger.value.find((r) => r.billId === b.id)
  return row && row.balance + 0.009 < row.due ? `${formatPesoExact(row.balance)} of ${formatPesoExact(row.due)} left` : formatPesoExact(b.amount)
}

const ledgerItem = (kind: 'advance' | 'deposit') => ledger.value.find((r) => r.kind === kind)
const canPayItem = (kind: 'advance' | 'deposit', fallback: boolean) => {
  const row = ledgerItem(kind)
  return ledger.value.length ? Boolean(row && row.balance > 0.009) : fallback
}
/** "₱2,500 · not yet paid", "₱1,250 of ₱2,500 left", or "Awaiting confirmation". */
function itemNote(kind: 'advance' | 'deposit'): string {
  const row = ledgerItem(kind)
  if (!row) return 'Not yet paid'
  if (row.pending > 0) return 'Awaiting confirmation'
  return row.balance + 0.009 < row.due ? `${formatPesoExact(row.balance)} of ${formatPesoExact(row.due)} left` : `${formatPesoExact(row.due)} · not yet paid`
}
const canPayAdvance = computed(() => canPayItem('advance', Boolean(lease.value && !lease.value.advancePaid)))
const canPayDeposit = computed(() => canPayItem('deposit', Boolean(lease.value && !lease.value.depositPaid)))



const paymentDetailOpen = ref(false)
const selectedPayment = ref<Payment | null>(null)
function openPaymentDetail(p: Payment) {
  selectedPayment.value = p
  paymentDetailOpen.value = true
}

// A pending application isn't an accepted lease yet, so there's nothing to pay.
const canPay = computed(() => lease.value?.status !== 'pending')

const LEASE_SELECT = `id, room_id, status, start_date, end_date, monthly_rent, advance_paid, deposit_paid, allow_partial, partial_min_pct, landlord_id, ${UTILITY_SELECT}, rooms(room_number, label, room_type, custom_room_type, capacity, accommodations(name, address, barangay, city, accommodation_amenities(amenity), accommodation_policies(${POLICY_FULL})))`

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data: authData } = await authUser()
    const user = authData?.user
    if (!user) {
      error.value = 'Not signed in.'
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
          'id, lease_id, month, amount, status, method, description, txn_reference, proof_url, paid_at, rejection_reason, note, promise_date, claimed_amount, undo_reason, receipt_no, verified_by_user:users!payments_verified_by_fkey(full_name), leases!inner(student_id, rooms(room_number, label, accommodations(name)))',
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
        claimedAmount: p.claimed_amount == null ? null : Number(p.claimed_amount),
        undoReason: p.undo_reason || '',
        receiptNo: p.receipt_no || '',
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

    const [{ data: manager }, { data: profile }, roommateResult] = await Promise.all([
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
    ])

    lease.value = {
      id: leaseRow.id,
      managerId: leaseRow.landlord_id,
      managerName: manager?.full_name || 'Landlord/Landlady',
      managerTitle: landlordTitle(manager?.sex),
      managerInitials: manager?.initials || initialsOf(manager?.full_name || '?'),
      managerAvatarUrl: manager?.avatar_url ? resolveAsset(manager.avatar_url) : null,
      replyMinutes: profile?.avg_response_minutes ?? null,
      accommodationName: room?.accommodations?.name || 'Your accommodation',
      roomLabel: room?.label || (room?.room_number ? `Room ${room.room_number}` : ''),
      status: leaseRow.status as Lease['status'],
      monthlyRent: Number(leaseRow.monthly_rent ?? 0),
      advancePaid: Number(leaseRow.advance_paid ?? 0),
      depositPaid: Number(leaseRow.deposit_paid ?? 0),
      allowPartial: Boolean(leaseRow.allow_partial),
      partialMinPct: Number(leaseRow.partial_min_pct ?? 50),
      startDate: leaseRow.start_date,
      endDate: leaseRow.end_date,
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
    await loadLedger()
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

async function requestLeave() {
  if (!(await requirePin({ confirm: true, title: 'Request to leave?', message: 'Your landlord/landlady will be asked to approve it.' }))) return
  if (leaving.value || !lease.value) return
  leaving.value = true
  try {
    const { data: authData } = await authUser()
    const user = authData?.user
    if (!user) throw new Error('Not signed in.')

    const { error: updateError } = await supabase
      .from('leases')
      .update({ status: 'leave_requested', leave_requested_at: new Date().toISOString() })
      .eq('id', lease.value.id)
      .eq('student_id', user.id)
    if (updateError) throw updateError

    lease.value = { ...lease.value, status: 'leave_requested' }
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
  if (!(await requirePin({ confirm: true, title: 'Withdraw this payment?', message: 'It is taken back before your landlord/landlady reviews it. You can submit a new one.' }))) return
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
.card {
  padding: 18px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}

.head {
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.head-top {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
}
.head-history-link {
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
.head-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
}
.head-room {
  color: var(--m-muted);
  font-size: 13px;
}
.head-chip {
  align-self: flex-start;
  margin-top: 4px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.head-chip--teal {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.head-chip--amber,
.head-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.head-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.head-note {
  margin: 6px 0 0;
  color: var(--m-warning);
  font-size: 12.5px;
  font-weight: 600;
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
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
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

.icon-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(68px, 1fr));
  gap: 16px 6px;
}
.icon-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  text-align: center;
}
.icon-circle {
  display: grid;
  width: 46px;
  height: 46px;
  place-items: center;
  border-radius: 50%;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.icon-item small {
  color: var(--m-text);
  font-size: 11px;
  font-weight: 600;
  line-height: 1.2;
}

.mgr {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.mgr-avatar {
  display: grid;
  width: 40px;
  height: 40px;
  flex: 0 0 40px;
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
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.mgr-sub {
  color: var(--m-muted);
  font-size: 11.5px;
}
.mgr-msg {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 6px;
  min-height: 36px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
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

.row-link {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  padding: 11px 12px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  color: var(--m-text);
  font-size: 13.5px;
  font-weight: 600;
  -webkit-tap-highlight-color: transparent;
}
.group > .row-link:first-child {
  border-top: 0;
}
.row-link .chevron {
  margin-left: auto;
  color: var(--m-muted);
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

.sheet-grip {
  display: block;
  width: 40px;
  height: 4px;
  margin: 0 auto;
  border-radius: 999px;
  background: var(--m-border);
}
.leave-sheet,
.detail-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.detail-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 8px;
}
.sheet-x {
  display: flex;
  width: 36px;
  height: 36px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  margin: -6px -8px 0 0;
  border: 0;
  border-radius: 999px;
  background: none;
  color: var(--m-muted);
  cursor: pointer;
}
.detail-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
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
.leave-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.leave-body {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
}
.leave-actions {
  display: flex;
  gap: 8px;
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

.pay-head {
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.pay-head-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.pay-head-rent {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 26px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.pay-head-per {
  font-size: 13px;
  font-weight: 600;
  opacity: 0.7;
}
.pay-head-sub {
  color: var(--m-muted);
  font-size: 12.5px;
}
.pay-head-btn {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 6px;
  margin-top: 10px;
  padding: 9px 16px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.pay-head-note {
  margin: 10px 0 0;
  color: var(--m-muted);
  font-size: 12.5px;
}
.past-owed {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
  padding: 12px 14px;
  border: 1px solid var(--m-danger);
  border-radius: var(--m-radius);
  background: var(--m-danger-soft);
}
.past-owed-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.past-owed-title {
  color: var(--m-danger);
  font-size: 14px;
  font-weight: 700;
}
.past-owed-sub {
  color: var(--m-text);
  font-size: 12.5px;
}
.past-owed-btn {
  flex: 0 0 auto;
  min-height: 40px;
  padding: 0 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-danger);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
.pay-head-owed {
  margin: 8px 0 0;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.pay-head-owed--overdue {
  color: var(--m-danger);
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
.pay-dues {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-top: 10px;
}
.pay-due {
  display: flex;
  min-height: 44px;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.pay-due-body {
  display: flex;
  flex-direction: column;
  gap: 1px;
}
.pay-due-label {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.pay-due-note {
  color: var(--m-muted);
  font-size: 11.5px;
}
.pay-due-note--overdue {
  color: var(--m-danger);
  font-weight: 700;
}
.pay-due-action {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 1px;
  color: var(--m-primary-dark);
  font-size: 12.5px;
  font-weight: 700;
}

.none {
  padding: 14px 12px;
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}
.pay-row {
  display: flex;
  width: 100%;
  align-items: center;
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
.group > .pay-row:first-child {
  border-top: 0;
}
.pay-chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
}
.pay-icon {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.pay-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.pay-month {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.pay-method {
  color: var(--m-muted);
  font-size: 11.5px;
}
.pay-side {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: flex-end;
  gap: 3px;
}
.pay-amount {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 14px;
  font-weight: 700;
}
.pay-chip {
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}
.pay-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.pay-chip--amber,
.pay-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.pay-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.pay-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
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
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.01em;
}
</style>
