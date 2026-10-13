<template>
  <q-page class="tprof" :class="{ 'page-wide': split }">
    <!-- Desktop placeholder in the card's own shape, so the first open does not
         show the phone layout and then snap into two halves. -->
    <div v-if="loading && split" class="stack">
      <div class="desk-card">
        <div class="desk-col">
          <div class="hero" />
          <div class="body-card">
            <div class="head">
              <q-skeleton type="circle" size="84px" style="margin-top: -42px; margin-bottom: 4px;" />
              <q-skeleton type="text" width="130px" height="17px" />
              <q-skeleton type="text" width="160px" height="12px" />
            </div>
          </div>
          <q-skeleton type="rect" height="90px" class="sk" style="margin-top: 14px;" />
        </div>
        <div class="desk-col">
          <q-skeleton type="rect" height="120px" class="sk" />
          <q-skeleton type="rect" height="70px" class="sk" />
        </div>
      </div>
    </div>

    <div v-else-if="loading" class="stack">
      <div class="hero"><q-skeleton type="rect" height="170px" square /></div>
      <div class="body-card">
        <div class="head">
          <q-skeleton type="circle" size="84px" style="margin-top: -42px; margin-bottom: 4px;" />
          <q-skeleton type="text" width="130px" height="17px" />
          <q-skeleton type="text" width="72px" height="18px" />
          <q-skeleton type="text" width="160px" height="12px" />
        </div>
      </div>
      <div class="tabs">
        <q-skeleton type="rect" width="72px" height="38px" class="m-sk-tab" />
        <q-skeleton type="rect" width="72px" height="38px" class="m-sk-tab" />
        <q-skeleton type="rect" width="72px" height="38px" class="m-sk-tab" />
      </div>
      <q-skeleton type="rect" height="90px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <ErrorCard title="Couldn't load this boarder" :detail="error" :retry="load" />
    </div>

    <div v-else class="stack">
      <!-- Desktop: two columns that scroll on their own — the profile and its
           overview on the left, payments and history on the right. On a phone
           .col-left is display: contents and nothing here changes. -->
      <div :class="split ? 'desk-card' : 'tabbed'">
        <div :class="split ? 'desk-col' : 'col-left'">
        <div class="hero">
          <img v-if="coverUrl" :src="coverUrl" alt="" class="hero-img" />
          <div class="hero-scrim" />
          <!-- Desktop only: the app header stays the plain one here (MainLayout),
               so the way back to the tenants list lives on the card itself. -->
          <button v-if="split" type="button" class="hero-msg hero-back" aria-label="Back to my boarders" @click="router.push('/manager/tenants')">
            <IconifyIcon icon="lucide:arrow-left" width="16" />
          </button>
          <button type="button" class="hero-msg" aria-label="Message boarder" @click="router.push(`/manager/messages?to=${lease.studentId}`)">
            <IconifyIcon icon="lucide:message-circle" width="16" />
          </button>
        </div>

        <div class="body-card">
          <div class="head">
            <span class="head-avatar">
              <img v-if="lease.studentAvatarUrl" :src="lease.studentAvatarUrl" alt="" class="head-avatar-img" @error="lease.studentAvatarUrl = null" />
              <template v-else>{{ lease.studentInitials }}</template>
            </span>
            <span class="head-name">{{ lease.studentName }}</span>
            <span class="head-chip" :class="`head-chip--${statusColor(LEASE_STATUS, lease.status)}`">
              {{ statusText(LEASE_STATUS, lease.status) }}
            </span>
            <span class="head-sub">{{ lease.roomLabel }} · {{ lease.accommodationName }}</span>
          </div>
        </div>

        <div v-if="!split" class="tabs">
          <button
            v-for="t in TABS"
            :key="t.key"
            type="button"
            class="m-tab"
            :class="{ 'm-tab--on': tab === t.key }"
            @click="tab = t.key"
          >
            {{ t.label }}
          </button>
        </div>

        <div class="panel">
          <!-- Plain divs on desktop, swipeable QTabPanels elsewhere; the same
               markup either way. -->
          <component :is="panelsIs" v-bind="panelsProps" class="m-panels">
            <component :is="panelIs" name="overview" class="sec">
            <!-- Decisions -->
            <div v-if="lease.status === 'pending'" class="decide-box">
              <div v-if="decisionReasonFor === 'reject'" class="decide-reason">
                <label class="decide-reason-label">
                  Reason for declining
                  <textarea v-model="decisionReason" class="decide-reason-textarea" rows="2" placeholder="Let the student know why…" />
                </label>
                <div class="decide-reason-actions">
                  <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = ''">Cancel</button>
                  <button
                    type="button"
                    class="decide-btn decide-btn--danger"
                    :disabled="deciding || !decisionReason.trim()"
                    @click="decide('rejected')"
                  >
                    {{ deciding ? 'Declining…' : 'Confirm decline' }}
                  </button>
                </div>
              </div>
              <div v-else class="decide">
                <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = 'reject'; decisionReason = ''">
                  Decline
                </button>
                <!-- Added by hand: accepted only by scanning their QR (DB-enforced). -->
                <template v-if="lease.addedByLandlord">
                  <button
                    type="button"
                    class="decide-btn"
                    @click="router.push(`/manager/profile/qr-scanner?accept=${leaseId}`)"
                  >
                    Scan to accept
                  </button>
                </template>
                <button v-else type="button" class="decide-btn" :disabled="deciding" @click="decide('active')">
                  Accept
                </button>
              </div>
            </div>
            <div v-else-if="lease.status === 'leave_requested'" class="decide-box">
              <p class="leave-ask">
                <IconifyIcon icon="lucide:log-out" width="16" />
                <span>Wants to move out on <b>{{ formatDate(lease.leaveDate) }}</b>. If you approve, the stay runs until then.</span>
              </p>
              <div v-if="decisionReasonFor === 'keep'" class="decide-reason">
                <label class="decide-reason-label">
                  Reason for keeping the boarder
                  <textarea v-model="decisionReason" class="decide-reason-textarea" rows="2" placeholder="Let the student know why…" />
                </label>
                <div class="decide-reason-actions">
                  <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = ''">Cancel</button>
                  <button
                    type="button"
                    class="decide-btn decide-btn--danger"
                    :disabled="deciding || !decisionReason.trim()"
                    @click="declineLeave"
                  >
                    {{ deciding ? 'Sending…' : 'Confirm' }}
                  </button>
                </div>
              </div>
              <div v-else class="decide">
                <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = 'keep'; decisionReason = ''">
                  Keep boarder
                </button>
                <button type="button" class="decide-btn" :disabled="deciding" @click="approveLeave">
                  Approve leave
                </button>
              </div>
            </div>
            <!-- Asked of the landlord/landlady once the stay is over. -->
            <div v-else-if="(lease.status === 'ended' || lease.status === 'terminated') && !tenantReview" class="decide-box decide">
              <button type="button" class="decide-btn" @click="openReview">Rate this boarder</button>
            </div>

            <!-- Stay: where today falls between move-in and the lease's end. -->
            <h2 class="sec-title ov-title">Stay</h2>
            <div class="ov-card">
              <div class="tl-ends">
                <span class="tl-end"><span class="tl-k">Move-in</span>{{ formatDate(lease.startDate) }}</span>
                <span class="tl-end tl-end--r"><span class="tl-k">Lease ends</span>{{ formatDate(lease.endDate) }}</span>
              </div>
              <div class="tl-track" role="progressbar" :aria-valuenow="stay.pct" aria-valuemin="0" aria-valuemax="100" :aria-label="stay.label">
                <span class="tl-fill" :style="{ width: `${stay.pct}%` }" />
              </div>
              <p class="tl-label">{{ stay.label }}</p>
              <p v-if="lease.status === 'active' && lease.leaveDate" class="tl-note">
                <IconifyIcon icon="lucide:log-out" width="14" />
                <span>Moving out on <b>{{ formatDate(lease.leaveDate) }}</b> — you approved it.</span>
              </p>
              <div class="ov-rent">
                <span class="ov-rent-amt">{{ formatPeso(lease.monthlyRent) }}</span>
                <span class="ov-rent-per">a month</span>
                <span v-if="tenantReview" class="ov-rated">
                  <StarRating :model-value="tenantReview.rating" :size="13" />
                  <span>your rating</span>
                </span>
              </div>
            </div>

            <template v-if="lease.email || lease.phone">
              <h2 class="sec-title ov-title">Contact</h2>
              <div class="ov-contact">
                <a v-if="lease.email" :href="`mailto:${lease.email}`" class="ov-tile">
                  <span class="ov-tile-ic"><IconifyIcon icon="lucide:mail" width="16" /></span>
                  <span class="ov-tile-k">Email</span>
                  <span class="ov-tile-v">{{ lease.email }}</span>
                </a>
                <a v-if="lease.phone" :href="`tel:${lease.phone}`" class="ov-tile">
                  <span class="ov-tile-ic"><IconifyIcon icon="lucide:phone" width="16" /></span>
                  <span class="ov-tile-k">Call</span>
                  <span class="ov-tile-v">{{ lease.phone }}</span>
                </a>
              </div>
            </template>

            <!-- Ending a stay is rare and final: a quiet link, not a button
                 beside everything else. -->
            <template v-if="lease.status === 'active'">
              <div v-if="decisionReasonFor === 'end'" class="decide-box decide-reason ov-end-form">
                <label class="decide-reason-label">
                  Why is this stay ending?
                  <textarea v-model="decisionReason" class="decide-reason-textarea" rows="2" placeholder="The student sees this…" />
                </label>
                <p class="decide-note" style="margin: 0; text-align: left">End it when the term is over or they moved out. Terminate it only for breaking the house rules.</p>
                <div class="decide-reason-actions">
                  <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = ''">Cancel</button>
                  <button type="button" class="decide-btn decide-btn--danger" :disabled="deciding || !decisionReason.trim()" @click="endStay(true)">Terminate</button>
                  <button type="button" class="decide-btn" :disabled="deciding || !decisionReason.trim()" @click="endStay(false)">
                    {{ deciding ? 'Ending…' : 'End stay' }}
                  </button>
                </div>
              </div>
              <button v-else type="button" class="ov-end" :disabled="deciding" @click="decisionReasonFor = 'end'; decisionReason = ''">
                End this stay<IconifyIcon icon="lucide:chevron-right" width="14" />
              </button>
            </template>
          </component>

          <!-- Payments and history move into the right column on desktop. The
               Teleport sits inside the panel, not around it, so QTabPanels still
               finds a panel named "payments" among its children on a phone. -->
          <component :is="panelIs" name="payments" class="sec" :class="{ 'sec--moved': split }">
            <Teleport :to="rightCol" :disabled="!split || !rightCol">
            <div class="sec-body">
            <PaymentStatement
              v-if="lease.status !== 'pending'"
              :ledger="ledger"
              :payments="payments"
              :start-date="lease.startDate"
              role="landlord"
              :closed="lease.status === 'ended' || lease.status === 'terminated'"
              can-pay
              :bill-utility="billUtility"
              :metered="canPostBill ? monthlyUtilities : []"
              :deposit-held="depositHeld"
              :deposit-usable="depositUsable"
              @pay="logOpen = true"
              @open-payment="openPaymentDetail"
              @forgive="forgiveRow"
              @fix-bill="openFixBill"
              @post-bill="postBillOpen = true"
              @message="router.push(`/manager/messages?to=${lease.studentId}`)"
              @use-deposit="depositOpen = true"
            />

            <!-- Below the statement: the terms it runs on, and posting a bill any time. -->
            <button v-if="lease.status === 'active' || lease.status === 'leave_requested'" type="button" class="terms-row terms-row--after" @click="termsOpen = true">
              <span class="terms-body">
                <span class="terms-main">Rent due every {{ ordinal(lease.rentDueDay ?? moveInDay) }}</span>
                <span class="terms-sub">{{ termsLine }}</span>
              </span>
              <span class="sec-link">Edit</span>
            </button>
            <button v-if="canPostBill" type="button" class="terms-row" @click="postBillOpen = true">
              <span class="terms-body">
                <span class="terms-main">Post a utility bill</span>
                <span class="terms-sub">{{ monthlyUtilities.map((u) => u.label).join(' and ') }}, billed monthly</span>
              </span>
              <span class="sec-link">Post</span>
            </button>
            <EmptyState
              v-if="lease.status === 'pending'"
              variant="compact"
              icon="lucide:receipt"
              title="No payments yet"
              message="Payments start once you accept this application."
            />
            </div>
            </Teleport>
          </component>

          <component :is="panelIs" name="history" class="sec" :class="{ 'sec--moved': split }">
            <Teleport :to="rightCol" :disabled="!split || !rightCol">
            <div class="sec-body">
            <BoardingTimeline v-if="history.length" :stays="history" />
            <EmptyState
              v-else
              variant="compact"
              icon="lucide:history"
              title="No past stays"
              message="This is their first stay through accommo."
            />
            </div>
            </Teleport>
          </component>
          </component>
        </div>
        </div>

        <div v-if="split" ref="rightCol" class="desk-col col-right" />
      </div>
    </div>

    <PostBillDialog
      v-model="postBillOpen"
      :lease-id="leaseId"
      :student-id="lease.studentId"
      :student-name="lease.studentName"
      :utilities="monthlyUtilities"
      @posted="load(true)"
    />

    <AppModal v-model="reviewOpen" :title="`Rate ${lease.studentName}`">
      <StarRating v-model="reviewForm.rating" interactive :size="26" />
      <label class="pay-field">
        <span class="pay-label">Notes (optional)</span>
        <textarea v-model="reviewForm.comment" class="pay-input review-textarea" rows="3" placeholder="How was this boarder to have?" />
      </label>
      <template #footer>
        <q-btn
          unelevated
          rounded
          no-caps
          color="primary"
          class="pay-submit"
          :loading="submittingReview"
          label="Submit"
          @click="submitTenantReview"
        />
      </template>
    </AppModal>

    <!-- Payment review — verifying only ever happens from here, never
         straight off the row, so a proof/reference actually gets looked at. -->
    <PaymentReviewSheet v-model="paymentDetailOpen" :payment-id="selectedPayment?.id ?? null" @changed="load(true)" />
    <LogPaymentSheet
      v-model="logOpen"
      :lease-id="leaseId"
      :subtitle="`From ${lease.studentName} · ${lease.roomLabel}`"
      :settle-only="lease.status === 'ended' || lease.status === 'terminated'"
      :start-date="lease.startDate"
      @submitted="load(true)"
    />
    <ForgiveSheet v-model="forgiveOpen" :lease-id="leaseId" :student-name="lease.studentName" :target="forgiveTarget" @done="load(true)" />
    <BillFixSheet v-model="fixOpen" :student-name="lease.studentName" :bill="fixBill" @done="load(true)" />
    <UseDepositSheet
      v-model="depositOpen"
      :lease-id="leaseId"
      :student-name="lease.studentName"
      :end-date="lease.endDate || null"
      :held="depositHeld"
      :ledger="ledger"
      @done="load(true)"
    />

    <!-- When rent falls due, the grace before it's late, and part payments. -->
    <AppModal v-model="termsOpen" title="Payment terms" size="sm">
      <div class="terms-form">
        <label class="mx-field">
          <span class="mx-label">Rent is due</span>
          <AppSelect
            class="mx-input"
            placeholder="Rent is due"
            :model-value="lease.rentDueDay ?? 0"
            :options="dueDayOptions"
            :disable="savingTerms"
            @update:model-value="(d) => setDueTerms(d || null, lease.graceDays)"
          />
        </label>
        <label class="mx-field">
          <span class="mx-label">Late after</span>
          <AppSelect
            class="mx-input"
            placeholder="Late after"
            :model-value="lease.graceDays"
            :options="[0, 3, 5, 7, 15].map((g) => ({ label: g ? `${g} days of grace` : 'no grace — late the next day', value: g }))"
            :disable="savingTerms"
            @update:model-value="(g) => setDueTerms(lease.rentDueDay, g)"
          />
        </label>
        <div class="terms-toggle">
          <span class="terms-body">
            <span class="terms-main">Partial payments</span>
            <span class="terms-sub">Let {{ lease.studentName.split(' ')[0] }} pay part of an item at a time.</span>
          </span>
          <q-toggle :model-value="lease.allowPartial" :disable="savingPartial" color="primary" aria-label="Allow partial payments" @update:model-value="(v) => setPartial(v)" />
        </div>
        <label v-if="lease.allowPartial" class="mx-field">
          <span class="mx-label">At least</span>
          <AppSelect
            class="mx-input"
            placeholder="At least"
            :model-value="lease.partialMinPct"
            :options="[10, 25, 50, 75].map((p) => ({ label: `${p}% of the item`, value: p }))"
            :disable="savingPartial"
            @update:model-value="(p) => setPartial(true, p)"
          />
        </label>
      </div>
    </AppModal>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useDeskPanels } from '@/utils/useDeskPanels'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { formatPeso, formatDate, formatMonth, initialsOf, LEASE_STATUS, statusText, statusColor, stayProgress } from '@/utils/format'
import { useNotify } from '@/utils/notify'
import { confirmAction } from '@/utils/confirmAction'
import { respondToApplication } from '@/utils/applications'
import { resolveAsset, AVATAR, COVER } from '@/utils/cloudinaryUrl'
import { signRows } from '@/utils/upload'
import StarRating from '@/components/shared/StarRating.vue'
import PostBillDialog from '@/components/manager/PostBillDialog.vue'
import PaymentReviewSheet from '@/components/manager/PaymentReviewSheet.vue'
import LogPaymentSheet from '@/components/manager/LogPaymentSheet.vue'
import ForgiveSheet, { type ForgiveTarget } from '@/components/manager/ForgiveSheet.vue'
import BillFixSheet, { type FixBill } from '@/components/manager/BillFixSheet.vue'
import UseDepositSheet from '@/components/manager/UseDepositSheet.vue'
import PaymentStatement from '@/components/shared/PaymentStatement.vue'
import { BILL_TAG, isBillSettled, manilaToday, toLedger, type LedgerRow } from '@/utils/payments'
import { UTILITIES, isBilledMonthly, roomTypeLabel, type UtilityKey } from '@/utils/listings'
import EmptyState from '@/components/shared/EmptyState.vue'
import BoardingTimeline, { type TimelineStay } from '@/components/shared/BoardingTimeline.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import AppModal from '@/components/shared/AppModal.vue'
import AppSelect from '@/components/shared/AppSelect.vue'

const TABS = [
  { key: 'overview', label: 'Overview' },
  { key: 'payments', label: 'Payments' },
  { key: 'history', label: 'Boarding History' },
] as const

const route = useRoute()
const router = useRouter()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const deciding = ref(false)
const tab = ref<(typeof TABS)[number]['key']>('overview')

// Desktop lays the tabs out as the two halves of a card instead (useDeskPanels).
const { split, panelsIs, panelIs, panelsProps } = useDeskPanels(tab)
const rightCol = ref<HTMLElement | null>(null)

const lease = reactive({
  status: '',
  studentId: '',
  studentName: '',
  studentInitials: '?',
  studentAvatarUrl: '' as string | null,
  email: '',
  phone: '',
  roomLabel: '',
  accommodationName: '',
  startDate: '',
  endDate: '',
  leaveDate: '' as string | null,
  monthlyRent: 0,
  addedByLandlord: false,
  allowPartial: false,
  partialMinPct: 10,
  rentDueDay: null as number | null,
  graceDays: 3,
})

// What is owed on this stay (lease_ledger): the balance line and the partial-
// payment terms below read it; the database enforces both.
const ledger = ref<LedgerRow[]>([])
async function loadLedger() {
  if (!leaseId.value || lease.status === 'pending') { ledger.value = []; return }
  const { data } = await supabase.rpc('lease_ledger', { p_lease: leaseId.value })
  ledger.value = toLedger(data)
}

const savingPartial = ref(false)
async function setPartial(allow: boolean, pct = lease.partialMinPct) {
  if (savingPartial.value) return
  savingPartial.value = true
  const { error: e } = await supabase.from('leases').update({ allow_partial: allow, partial_min_pct: pct }).eq('id', leaseId.value)
  savingPartial.value = false
  if (e) return notify.error(errorMessage(e, 'Could not change partial payments.'))
  lease.allowPartial = allow
  lease.partialMinPct = pct
  notify.success(allow ? `Partial payments on — at least ${pct}% at a time.` : 'Partial payments off.')
}
// When rent falls due each month, and how long before it counts as overdue.
const moveInDay = computed(() => Math.min(Number(lease.startDate.slice(8, 10)) || 1, 28))
function ordinal(n: number): string {
  const s = n % 100 >= 11 && n % 100 <= 13 ? 'th' : ({ 1: 'st', 2: 'nd', 3: 'rd' } as Record<number, string>)[n % 10] ?? 'th'
  return `${n}${s}`
}
const dueDayOptions = computed(() => [
  { label: `on the move-in day (${ordinal(moveInDay.value)})`, value: 0 },
  ...Array.from({ length: 28 }, (_, i) => ({ label: `every ${ordinal(i + 1)}`, value: i + 1 })),
])
const savingTerms = ref(false)
async function setDueTerms(day: number | null, grace: number) {
  if (savingTerms.value) return
  savingTerms.value = true
  const { error: e } = await supabase.from('leases').update({ rent_due_day: day, grace_days: grace }).eq('id', leaseId.value)
  savingTerms.value = false
  if (e) return notify.error(errorMessage(e, 'Could not change when rent is due.'))
  lease.rentDueDay = day
  lease.graceDays = grace
  notify.success(`Rent is due every ${ordinal(day ?? moveInDay.value)}${grace ? `, overdue ${grace} days later` : ''}.`)
  void loadLedger()
}

const termsOpen = ref(false)
const termsLine = computed(() => {
  const grace = lease.graceDays ? `${lease.graceDays} days grace` : 'no grace'
  const partial = lease.allowPartial ? `partial payments of ${lease.partialMinPct}% or more` : 'no partial payments'
  return `${grace} · ${partial}`
})

// Forgiving what's left of an item (ForgiveSheet → waive_balance).
const logOpen = ref(false)
const forgiveOpen = ref(false)
const forgiveTarget = ref<ForgiveTarget | null>(null)
function forgiveRow(r: LedgerRow) {
  const b = r.kind === 'bill' ? bills.value.find((x) => x.id === r.billId) : undefined
  forgiveTarget.value = b
    ? { kind: 'bill', month: b.month, billId: b.id, balance: r.balance, label: `the ${BILL_TAG[b.utility].toLowerCase()} for ${formatMonth(b.month).split(' ')[0]}` }
    : { kind: r.kind, month: r.month ?? today, billId: null, balance: r.balance, label: r.kind === 'rent' ? `${formatMonth(r.month).split(' ')[0]} rent` : 'the deposit' }
  forgiveOpen.value = true
}

// Correcting a bill posted with the wrong amount (BillFixSheet).
const fixOpen = ref(false)
const fixBill = ref<FixBill | null>(null)
function openFixBill(billId: string) {
  const b = bills.value.find((x) => x.id === billId)
  if (!b) return
  const row = ledger.value.find((r) => r.billId === billId)
  fixBill.value = {
    id: b.id,
    label: `${BILL_TAG[b.utility]} · ${formatMonth(b.month).split(' ')[0]}`,
    amount: b.amount,
    paid: row ? row.confirmed + row.pending + row.waived : 0,
  }
  fixOpen.value = true
}

// The deposit still held: what was paid toward it, less what it has paid for.
// It can be used once the stay is ending (UseDepositSheet).
const depositOpen = ref(false)
const depositReturned = ref(false)
const depositHeld = computed(() => {
  if (depositReturned.value) return 0
  const paidIn = payments.value.filter((p) => p.kind === 'deposit' && p.status === 'paid').reduce((s, p) => s + p.amount, 0)
  const usedUp = payments.value.filter((p) => p.method === 'deposit' && p.status === 'paid').reduce((s, p) => s + p.amount, 0)
  return Math.max(paidIn - usedUp, 0)
})
const depositUsable = computed(
  () => ['leave_requested', 'ended', 'terminated'].includes(lease.status) || (!!lease.endDate && lease.endDate.slice(0, 7) <= today.slice(0, 7)),
)

const coverUrl = ref('')
const payments = ref<
  {
    id: string
    month: string
    kind: string
    billId: string | null
    amount: number
    status: string
    method: string
    description: string
    txnReference: string
    proofUrl: string
    paidAt: string | null
    verifiedByName: string
    rejectionReason: string
    note: string
    promiseDate: string | null
    createdAt: string
    batchId: string | null
  }[]
>([])
const history = ref<TimelineStay[]>([])
const tenantReview = ref<{ rating: number; comment: string } | null>(null)

// Utilities this place bills monthly, and the bills posted against this lease.
const billing = ref<Record<UtilityKey, string | null>>({ water: null, electric: null, wifi: null })
const monthlyUtilities = computed(() =>
  UTILITIES.filter((u) => isBilledMonthly(billing.value[u.key])).map((u) => ({ key: u.key, label: u.label, billing: billing.value[u.key] as string })),
)
const canPostBill = computed(() => monthlyUtilities.value.length > 0 && (lease.status === 'active' || lease.status === 'leave_requested'))
type Bill = { id: string; utility: UtilityKey; month: string; amount: number; note: string; dueDate: string; settled: boolean }
const bills = ref<Bill[]>([])
// Which utility each bill is, for the statement's labels.
const billUtility = computed(() => Object.fromEntries(bills.value.map((b) => [b.id, b.utility])))
const postBillOpen = ref(false)
const today = manilaToday()

const leaseId = computed(() => String(route.params.leaseId || ''))

// The Overview's stay bar. A stay that never began has nothing to measure.
const stay = computed(() =>
  lease.status === 'pending' ? { pct: 0, label: 'Starts once you accept' }
    : lease.status === 'rejected' ? { pct: 0, label: 'Declined — this stay never started' }
      : stayProgress(lease.startDate, lease.endDate, today),
)

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data, error: loadError } = await supabase
      .from('leases')
      .select(
        'id,status,start_date,end_date,leave_date,deposit_returned_at,monthly_rent,allow_partial,partial_min_pct,rent_due_day,grace_days,student_id,landlord_id,room_id,added_by_landlord,water_billing,electric_billing,wifi_billing,users!leases_student_id_fkey(full_name,initials,avatar_url,cover_url),contact:users_full!leases_student_id_fkey(email,phone),rooms(label,room_number,room_type,accommodation_id,accommodations(name,accommodation_images(url,sort_order)))',
      )
      .eq('id', leaseId.value)
      .maybeSingle()
    if (loadError) throw loadError
    if (!data) {
      error.value = 'This boarder record could not be found.'
      return
    }

    // E-mail and phone come from users_full, which answers only while the lease
    // is current; a past tenant keeps their name here but not their contacts.
    const contact = data.contact as unknown as { email: string | null; phone: string | null } | null
    const person = data.users as unknown as { full_name: string | null; initials: string | null; avatar_url: string | null; cover_url: string | null } | null
    const student = person ? { ...person, email: contact?.email ?? null, phone: contact?.phone ?? null } : null
    const room = data.rooms as unknown as {
      label: string | null
      room_number: string | null
      room_type: string | null
      accommodation_id: string
      accommodations: {
        name: string | null
        accommodation_images: { url: string; sort_order: number | null }[] | null
      } | null
    } | null
    // The terms this tenant's lease was agreed under decide which bills can
    // be posted for them — not whatever the room says today.
    billing.value = { water: data.water_billing, electric: data.electric_billing, wifi: data.wifi_billing }

    lease.status = data.status
    lease.addedByLandlord = data.added_by_landlord
    lease.studentId = data.student_id
    lease.studentName = student?.full_name || 'A student'
    lease.studentInitials = student?.initials || initialsOf(lease.studentName)
    lease.studentAvatarUrl = student?.avatar_url ? resolveAsset(student.avatar_url, AVATAR) : null
    lease.email = student?.email || ''
    lease.phone = student?.phone || ''
    lease.roomLabel = room?.label || (room?.room_number ? `Room ${room.room_number}` : 'Room')
    lease.accommodationName = room?.accommodations?.name || 'Accommodation'

    const cover = [...(room?.accommodations?.accommodation_images ?? [])].sort(
      (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
    )[0]
    // The student's own cover photo when they set one; the boarding house otherwise.
    const coverSrc = student?.cover_url || cover?.url
    coverUrl.value = coverSrc ? resolveAsset(coverSrc, COVER) : ''
    lease.startDate = data.start_date
    lease.endDate = data.end_date
    lease.leaveDate = data.leave_date
    lease.monthlyRent = Number(data.monthly_rent ?? 0)
    lease.allowPartial = Boolean(data.allow_partial)
    lease.partialMinPct = Number(data.partial_min_pct ?? 10)
    lease.rentDueDay = data.rent_due_day
    lease.graceDays = data.grace_days
    depositReturned.value = !!data.deposit_returned_at
    void loadLedger()

    const [{ data: paymentRows }, { data: historyRows }, { data: billRows }] = await Promise.all([
      supabase
        .from('payments')
        .select(
          'id,month,amount,status,method,kind,bill_id,description,txn_reference,proof_url,paid_at,rejection_reason,note,promise_date,created_at,batch_id,verified_by_user:users!payments_verified_by_fkey(full_name)',
        )
        .eq('lease_id', leaseId.value)
        .order('month', { ascending: false }),
      supabase
        .from('boarding_history')
        .select('id,accommodation_name,room_type,period_start,period_end,end_reason,accommodations(landlord_id)')
        .eq('student_id', data.student_id)
        .order('period_start', { ascending: false }),
      supabase
        .from('utility_bills')
        .select('id,utility,month,amount,note,due_date,payments(status, amount)')
        .eq('lease_id', leaseId.value)
        .order('month', { ascending: true }),
    ])
    bills.value = (billRows ?? []).map((b) => ({
      id: b.id,
      utility: b.utility as UtilityKey,
      month: b.month,
      amount: Number(b.amount),
      note: b.note || '',
      dueDate: b.due_date,
      settled: isBillSettled(b.payments, Number(b.amount)),
    }))
    await signRows('payments', paymentRows, 'proof_url')
    payments.value = (paymentRows ?? []).map((p) => ({
      id: p.id,
      month: p.month,
      kind: p.kind,
      billId: p.bill_id,
      amount: Number(p.amount),
      status: p.status,
      method: p.method,
      description: p.description || '',
      txnReference: p.txn_reference || '',
      proofUrl: p.proof_url || '',
      paidAt: p.paid_at,
      verifiedByName: (p.verified_by_user as { full_name: string | null } | null)?.full_name || '',
      rejectionReason: p.rejection_reason || '',
      note: p.note || '',
      promiseDate: p.promise_date,
      createdAt: p.created_at,
      batchId: p.batch_id,
    }))
    // Only this landlord/landlady's leases are readable here, so the lease's
    // landlord_id is the viewer — no extra auth round trip.
    history.value = (historyRows ?? []).map((h) => ({
      id: h.id,
      name: h.accommodation_name || 'Accommodation',
      room: roomTypeLabel(h.room_type),
      start: h.period_start,
      end: h.period_end,
      endReason: h.end_reason,
      mine: (h.accommodations as { landlord_id: string } | null)?.landlord_id === data.landlord_id,
    }))

    if (data.status === 'ended' || data.status === 'terminated') {
      // The review this landlord/landlady wrote, read back through the "written by me"
      // view. `unique (lease_id)` now guarantees at most one row, which is what
      // maybeSingle() always assumed — a second row used to make it throw.
      const { data: reviewRow } = await supabase
        .from('review_written_leases')
        .select('rating,comment')
        .eq('kind', 'tenant')
        .eq('lease_id', leaseId.value)
        .maybeSingle()
      tenantReview.value = reviewRow ? { rating: reviewRow.rating ?? 0, comment: reviewRow.comment || '' } : null
    }
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

const decisionReasonFor = ref<'' | 'reject' | 'keep' | 'end'>('')
const decisionReason = ref('')

async function decide(next: 'active' | 'rejected') {
  if (deciding.value) return
  if (next === 'rejected' && !decisionReason.value.trim()) return
  deciding.value = true
  try {
    await respondToApplication(leaseId.value, next, next === 'rejected' ? decisionReason.value.trim() : undefined)
    lease.status = next
    notify.success(next === 'active' ? 'Application accepted.' : 'Application declined.')
    decisionReasonFor.value = ''
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update this application.'))
  } finally {
    deciding.value = false
  }
}

async function approveLeave() {
  const today = manilaToday()
  const later = !!lease.leaveDate && lease.leaveDate > today
  if (!(await confirmAction({
    title: 'Approve this leave request?',
    message: later
      ? `The stay runs until ${formatDate(lease.leaveDate)}, then ends and the room is freed.`
      : 'Their stay ends today and the room is freed.',
  }))) return
  if (deciding.value) return
  deciding.value = true
  try {
    // approve_leave (20261012010000) runs the stay to the leave date, or ends
    // it today if that day has come. Ending stamps the end date and writes the
    // stay into the student's history (tg_lease_history) server-side.
    const { error: rpcError } = await supabase.rpc('approve_leave', { p_lease: leaseId.value })
    if (rpcError) throw rpcError
    notify.success(later ? `Approved — they move out ${formatDate(lease.leaveDate)}.` : 'Leave request approved.')
    void load(true)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not approve the leave request.'))
  } finally {
    deciding.value = false
  }
}

// The landlord/landlady closes a stay the student never asked to leave: the term
// is over, they moved out without a word, or (terminate) they broke the house
// rules. The student is told the reason; the database requires one.
async function endStay(terminate: boolean) {
  const reason = decisionReason.value.trim()
  if (deciding.value || !reason) return
  if (!(await confirmAction({
    title: terminate ? 'Terminate this stay?' : 'End this stay?',
    message: 'It ends today and the room is freed. The student sees your reason.',
  }))) return
  deciding.value = true
  try {
    const { error: updateError } = await supabase
      .from('leases')
      .update({
        status: terminate ? 'terminated' : 'ended',
        ended_reason: terminate ? 'terminated' : 'stay_ended',
        decision_reason: reason,
      })
      .eq('id', leaseId.value)
    if (updateError) throw updateError
    lease.status = terminate ? 'terminated' : 'ended'
    decisionReasonFor.value = ''
    notify.success(terminate ? 'Stay terminated.' : 'Stay ended.')
    void load(true)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not end this stay.'))
  } finally {
    deciding.value = false
  }
}

async function declineLeave() {
  const reason = decisionReason.value.trim()
  if (deciding.value || !reason) return
  deciding.value = true
  try {
    const { error: updateError } = await supabase
      .from('leases')
      .update({ status: 'active', leave_requested_at: null, leave_date: null, decision_reason: reason })
      .eq('id', leaseId.value)
    if (updateError) throw updateError
    lease.status = 'active'
    notify.success('Leave request declined.')
    decisionReasonFor.value = ''
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update the leave request.'))
  } finally {
    deciding.value = false
  }
}

const paymentDetailOpen = ref(false)
const selectedPayment = ref<(typeof payments.value)[number] | null>(null)
function openPaymentDetail(p: (typeof payments.value)[number]) {
  selectedPayment.value = p
  paymentDetailOpen.value = true
}

const reviewOpen = ref(false)
const submittingReview = ref(false)
const reviewForm = reactive({ rating: 0, comment: '' })

function openReview() {
  reviewForm.rating = 0
  reviewForm.comment = ''
  reviewOpen.value = true
}

async function submitTenantReview() {
  if (submittingReview.value) return
  if (!reviewForm.rating) {
    notify.error('Give a star rating.')
    return
  }
  submittingReview.value = true
  try {
    const { data: authData } = await authUser()
    const managerId = authData?.user?.id
    if (!managerId) throw new Error('Not logged in.')

    const { error: insertError } = await supabase.from('tenant_reviews').insert({
      lease_id: leaseId.value,
      student_id: lease.studentId,
      landlord_id: managerId,
      rating: reviewForm.rating,
      comment: reviewForm.comment.trim() || null,
    })
    if (insertError) throw insertError

    tenantReview.value = { rating: reviewForm.rating, comment: reviewForm.comment.trim() }
    reviewOpen.value = false
    notify.success('Rating submitted.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not submit your rating.'))
  } finally {
    submittingReview.value = false
  }
}

// Kept alive per lease id (see MainLayout's KEEP_ALIVE_PAGES + the
// route.fullPath key), so lease and payment changes push here instead of the
// page re-asking on return. utils/useLiveData.ts owns the whole policy — the
// key folds in the lease id so each tenant gets its own freshness clock.
useLiveData({
  key: () => `manager-tenant:${leaseId.value}`,
  load,
  watch: () =>
    leaseId.value
      ? [
          { table: 'leases', filter: `id=eq.${leaseId.value}` },
          { table: 'payments', filter: `lease_id=eq.${leaseId.value}` },
        ]
      : [],
})

</script>

<style scoped>
.tprof {
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

.tabbed {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  margin: -8px calc(var(--m-page-gutter) * -1) 0;
}
/* Cover band — bleeds to the very top of the page (cancels .stack's own
   top padding via .tabbed's negative margin) and to both edges. No text
   sits on it; the avatar straddling its bottom edge is the only thing
   that touches it directly. */
.hero {
  position: relative;
  flex: 0 0 auto;
  height: 170px;
  overflow: hidden;
  background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%);
}
.hero-img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.hero-scrim {
  position: absolute;
  inset: 0;
  background: linear-gradient(to bottom, rgba(0, 0, 0, 0.18) 0%, rgba(0, 0, 0, 0) 70%);
}
.hero-msg {
  position: absolute;
  top: 10px;
  right: var(--m-page-gutter);
  z-index: 2;
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.55);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.hero-back {
  right: auto;
  left: var(--m-page-gutter);
}

/* Profile info only — the avatar pulls up into the hero via a negative
   margin so it straddles the seam, cover-photo style. Tabs and their
   content live in separate elements below, not nested in this card. */
.body-card {
  position: relative;
  margin: -85px var(--m-page-gutter) 0;
  padding: 0 var(--m-page-gutter) 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  box-shadow: var(--m-shadow);
}
.head {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding-top: 8px;
  text-align: center;
}
.head-avatar {
  display: grid;
  /* The hero sits in a column flex container, so height is the main axis and
     flex-shrink defaults to 1 -- a tight column squashed this 84px circle into
     an oval. Every other avatar in the app already pins itself this way. */
  flex: none;
  width: 84px;
  height: 84px;
  place-items: center;
  overflow: hidden;
  margin-top: -42px;
  margin-bottom: 4px;
  border: 4px solid var(--m-surface);
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 24px;
  font-weight: 800;
  box-shadow: 0 2px 6px rgba(15, 23, 42, 0.12);
}
.head-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.head-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.head-chip {
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
.head-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.head-sub {
  margin-top: 4px;
  color: var(--m-muted);
  font-size: 12.5px;
}

/* Rounded-top pill tabs rising into the bordered panel below — same
   tab-folder shape as accommodation detail, recolored for a plain white
   card instead of a photo backdrop (no gradient sits behind these). */
.tabs {
  position: relative;
  z-index: 2;
  display: flex;
  gap: 4px;
  /* -2px, not -1px: see ManagerTenantsPage.vue's .tabs comment — an exact 1px
     overlap can round the wrong way on real (non-@1x) device pixel ratios
     and leave a hairline gap under the active tab. */
  margin: 14px var(--m-page-gutter) -2px;
}
/* Its own card, distinct from .body-card above — not a shared surface. The
   active tab's background matches this panel's, so the -1px overlap above
   fuses them with no visible seam, while unselected tabs still show the
   border. Bleeds to the page edges and fills to the bottom, same as
   accommodation detail's own .panel. */
.panel {
  display: flex;
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  padding: 0 var(--m-page-gutter) 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
/* Same treatment as accommodation detail's status-box — its own bordered
   card for anything decision-related, not a bare row of buttons. */
.decide-box {
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
}
.decide {
  display: flex;
  gap: 8px;
}
.decide-note {
  flex: 1;
  align-self: center;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
  text-align: center;
}
.decide-btn {
  flex: 1;
  min-height: 44px;
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
.decide-btn:disabled {
  opacity: 0.6;
}
.decide-btn--ghost {
  background: var(--m-bg);
  color: var(--m-text);
  border: 1px solid var(--m-border);
}
.decide-btn--danger {
  background: var(--m-danger);
}
.decide-reason {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.decide-reason-label {
  display: flex;
  flex-direction: column;
  gap: 4px;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.decide-reason-textarea {
  min-height: 60px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  text-transform: none;
  letter-spacing: normal;
  font-weight: 400;
  resize: vertical;
}
.decide-reason-actions {
  display: flex;
  gap: 8px;
}

.sec {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

/* ---- Desktop: two columns ----
   Off the desktop these wrappers are transparent: .col-left and .sec-body are
   display: contents, so the phone layout is exactly the tabbed one it was. */
.col-left,
.sec-body {
  display: contents;
}
/* Desktop: the card (.desk-card / .desk-col, app.scss) — the same card as the
   Tenants page, so opening a tenant reads as that card changing its contents. */
/* The cover runs to the half's edges; the card's own rounding clips its corner. */
.desk-card .hero {
  margin: -14px -18px 0;
}
/* The avatar card's gap below the cover is its own; the column's gap would add
   to it. */
.desk-card .desk-col:first-child {
  gap: 0;
}
/* Inside the half, the overview is just content — not a second card. */
.desk-card .panel {
  flex: none;
  margin-top: 14px;
  padding: 0;
  border: 0;
  border-radius: 0;
  background: transparent;
}
.desk-card .col-right {
  gap: 22px;
}
.col-right .sec-body {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
/* The emptied tab shells left behind in the left column once their content has
   moved right. */
.sec--moved {
  display: none;
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
.sec-link {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
/* Cancels .body-card's own side padding so this card reaches its left and
   right edges instead of sitting doubly inset (card padding + card padding). */
.group {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
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
.rule-verify {
  display: block;
  margin-top: 3px;
  margin-left: auto;
  padding: 3px 10px;
  border: 1px solid var(--m-primary);
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 11px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.rule-verify:disabled {
  opacity: 0.6;
}
.terms-row,
.terms-toggle {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 12px;
  margin-bottom: 14px;
  padding: 12px 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: inherit;
  cursor: pointer;
  font: inherit;
  text-align: left;
}
/* The statement opens the tab; give it the room a heading used to. */
.sec-body > .st:first-child {
  margin-top: 16px;
}
.terms-row--after {
  margin-top: 18px;
}
.terms-toggle {
  margin: 0;
  cursor: default;
}
.terms-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.terms-main {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.terms-sub {
  color: var(--m-muted);
  font-size: 12.5px;
}
.terms-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.leave-ask {
  display: flex;
  gap: 8px;
  margin: 0 0 10px;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.45;
  text-align: left;
}
.leave-ask > :first-child {
  flex: 0 0 auto;
  margin-top: 2px;
  color: var(--m-warning);
}
/* ---- Overview ----
   Stay and Contact are each one recessed card on the panel (--m-bg on
   --m-surface, so the card reads as its own). */
.ov-title {
  margin-top: 16px;
}
.decide-box + .ov-title {
  margin-top: 18px;
}
.ov-card {
  display: flex;
  flex-direction: column;
  padding: 14px 14px 0;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
}
.tl-ends {
  display: flex;
  justify-content: space-between;
  gap: 12px;
}
.tl-end {
  display: flex;
  flex-direction: column;
  gap: 2px;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.tl-end--r {
  text-align: right;
}
.tl-k {
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.tl-track {
  height: 8px;
  margin-top: 12px;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-border);
}
.tl-fill {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: var(--m-primary);
}
.tl-label {
  margin: 8px 0 0;
  color: var(--m-text);
  font-size: 12.5px;
  font-weight: 600;
}
.tl-note {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  margin: 8px 0 0;
  color: var(--m-text);
  font-size: 12.5px;
  line-height: 1.4;
}
.tl-note > :first-child {
  flex: none;
  margin-top: 1px;
  color: var(--m-warning);
}
/* Rent closes the card on its own band, the one figure worth reading big. */
.ov-rent {
  display: flex;
  align-items: baseline;
  gap: 6px;
  margin: 14px -14px 0;
  padding: 12px 14px;
  border-top: 1px solid var(--m-border);
}
.ov-rent-amt {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 800;
}
.ov-rent-per {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.ov-rated {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-left: auto;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
/* Contact: a tile per way to reach them, tapping it calls or writes. */
.ov-contact {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 8px;
}
.ov-tile {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  align-items: center;
  gap: 2px 10px;
  min-height: 56px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  color: inherit;
  text-decoration: none;
  -webkit-tap-highlight-color: transparent;
}
.ov-tile-ic {
  display: grid;
  grid-row: span 2;
  width: 32px;
  height: 32px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.ov-tile-k {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.ov-tile-v {
  overflow: hidden;
  color: var(--m-muted);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ov-end {
  display: inline-flex;
  align-self: center;
  align-items: center;
  gap: 2px;
  margin-top: 22px;
  padding: 10px 12px;
  border: 0;
  background: transparent;
  color: var(--m-danger);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.ov-end-form {
  margin-top: 18px;
}


.pay-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.pay-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.pay-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.pay-submit {
  flex: 1;
  min-height: 48px;
  font-weight: 700;
}
.review-textarea {
  min-height: 70px;
  padding: 10px 12px;
  resize: vertical;
}

.group > .pay-detail-rule:first-child {
  border-top: 0;
}
</style>
