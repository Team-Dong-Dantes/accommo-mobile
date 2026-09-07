<template>
  <q-page class="sp">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="120px" class="sk" />
      <q-skeleton type="rect" height="90px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your stay</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load()" />
      </q-card>
    </div>

    <EmptyState
      v-else-if="!lease && !payments.length"
      icon="lucide:home"
      title="No active stay"
      message="Once a manager accepts your application, your tenancy details, rent and manager contact will show up here."
    >
      <template #actions>
        <q-btn unelevated rounded no-caps color="primary" label="Browse rooms" @click="router.push('/student/discover')" />
      </template>
    </EmptyState>

    <div v-else class="stack">
      <div class="tabbed">
        <div class="tabs">
          <button type="button" class="tab" :class="{ 'tab--on': activeTab === 'stay' }" @click="activeTab = 'stay'">
            My Stay
          </button>
          <button type="button" class="tab" :class="{ 'tab--on': activeTab === 'payments' }" @click="activeTab = 'payments'">
            Payments
          </button>
        </div>

        <div class="panel">
          <q-tab-panels v-model="activeTab" animated swipeable class="panels">
            <q-tab-panel name="stay" class="tab-panel">
              <template v-if="lease">
                <div class="head">
                  <div class="head-top">
                    <span class="head-name">{{ lease.accommodationName }}</span>
                    <button type="button" class="head-history-link" @click="router.push('/student/profile/history')">View history</button>
                  </div>
                  <span v-if="lease.roomLabel" class="head-room">{{ lease.roomLabel }}</span>
                  <span class="head-chip" :class="`head-chip--${statusColor(LEASE_STATUS, lease.status)}`">{{ statusText(LEASE_STATUS, lease.status) }}</span>
                  <p v-if="lease.status === 'pending'" class="head-note">Application pending — awaiting manager decision.</p>
                  <p v-else-if="lease.status === 'leave_requested'" class="head-note">Leave requested — awaiting manager decision.</p>
                </div>

                <!-- Manager contact -->
                <section class="sec">
                  <h2 class="sec-title">Managed by</h2>
                  <div class="mgr">
                    <span class="mgr-avatar">
                      <img v-if="lease.managerAvatarUrl" :src="lease.managerAvatarUrl" alt="" class="mgr-avatar-img" @error="lease.managerAvatarUrl = null" />
                      <template v-else>{{ lease.managerInitials }}</template>
                    </span>
                    <span class="mgr-body">
                      <span class="mgr-name">{{ lease.managerName }}</span>
                      <span class="mgr-sub">{{ lease.replyMinutes ? `Replies in ~${lease.replyMinutes} min` : 'Accommodation manager' }}</span>
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
                message="Once a manager accepts your application, your tenancy details, rent and manager contact will show up here."
              >
                <template #actions>
                  <q-btn unelevated rounded no-caps color="primary" label="Browse rooms" @click="router.push('/student/discover')" />
                </template>
              </EmptyState>
            </q-tab-panel>

            <q-tab-panel name="payments" class="tab-panel">
              <div v-if="lease" class="pay-head">
                <span class="pay-head-label">Expected rent</span>
                <span class="pay-head-rent">{{ formatPeso(lease.monthlyRent) }}<span class="pay-head-per">/mo</span></span>
                <span class="pay-head-sub">{{ lease.roomLabel || 'Your room' }} · {{ lease.accommodationName }}</span>
                <button v-if="canPay" type="button" class="pay-head-btn" @click="openSubmit('rent')">
                  <IconifyIcon icon="lucide:circle-plus" width="16" />
                  Submit a payment
                </button>
                <p v-else class="pay-head-note">You'll be able to submit payments once your application is accepted.</p>

                <div v-if="canPay && (canPayAdvance || canPayDeposit)" class="pay-dues">
                  <button v-if="canPayAdvance" type="button" class="pay-due" @click="openSubmit('advance')">
                    <span class="pay-due-body">
                      <span class="pay-due-label">Advance</span>
                      <span class="pay-due-note">Not yet paid</span>
                    </span>
                    <span class="pay-due-action">Pay <IconifyIcon icon="lucide:chevron-right" width="14" /></span>
                  </button>
                  <button v-if="canPayDeposit" type="button" class="pay-due" @click="openSubmit('deposit')">
                    <span class="pay-due-body">
                      <span class="pay-due-label">Deposit</span>
                      <span class="pay-due-note">Not yet paid</span>
                    </span>
                    <span class="pay-due-action">Pay <IconifyIcon icon="lucide:chevron-right" width="14" /></span>
                  </button>
                </div>
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
                      <span class="pay-month">{{ formatMonth(p.month) }}</span>
                      <span class="pay-method">{{ PAYMENT_METHOD_LABEL[p.method] || p.method }} · {{ p.accommodationName }}</span>
                    </span>
                    <span class="pay-side">
                      <span class="pay-amount">{{ formatPeso(p.amount) }}</span>
                      <span class="pay-chip" :class="`pay-chip--${statusColor(PAYMENT_STATUS, p.status)}`">
                        {{ statusText(PAYMENT_STATUS, p.status) }}
                      </span>
                    </span>
                    <IconifyIcon icon="lucide:chevron-right" width="16" class="pay-chevron" />
                  </button>
                </div>
                <p v-else class="none">No payments {{ showAllPayments ? 'submitted yet' : 'for this room yet' }}.</p>
              </section>
            </q-tab-panel>
          </q-tab-panels>
        </div>
      </div>
    </div>

    <q-dialog v-model="leaveDialog" position="bottom">
      <q-card class="leave-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <h3 class="leave-title">Request to leave?</h3>
        <p class="leave-body">
          Your manager will be notified and needs to approve this before your stay ends. You'll stay on your
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

    <q-dialog v-model="submitOpen" position="bottom">
      <q-card class="submit-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <h3 class="submit-title">{{ submitTitle }}</h3>
        <p class="submit-note">Your manager will verify this before it's marked paid.</p>

        <div v-if="form.category === 'rent'" class="submit-field">
          <span class="submit-label">Month</span>
          <div class="submit-locked-month">
            <IconifyIcon icon="lucide:calendar" width="15" />
            {{ formatMonth(`${nextRentMonth}-01`) }}
          </div>
          <span class="submit-hint">Months are paid in order — this is the next one due.</span>
        </div>

        <label class="submit-field">
          <span class="submit-label">Amount</span>
          <input v-model.number="form.amount" type="number" min="0" step="0.01" class="submit-input" />
        </label>
        <label class="submit-field">
          <span class="submit-label">Method</span>
          <select v-model="form.method" class="submit-input">
            <option value="gcash">GCash</option>
            <option value="maya">Maya</option>
            <option value="bank">Bank transfer</option>
            <option value="cash">Cash</option>
            <option value="others">Other</option>
          </select>
        </label>
        <label class="submit-field">
          <span class="submit-label">Reference number{{ isCash ? ' (optional)' : '' }}</span>
          <input v-model="form.reference" type="text" class="submit-input" placeholder="e.g. GCash ref no." />
        </label>
        <label class="submit-field">
          <span class="submit-label">Proof of payment{{ isCash ? ' (optional)' : '' }}</span>
          <span class="file-picker" :class="{ 'file-picker--chosen': form.proofUrl }">
            <IconifyIcon :icon="form.proofUrl ? 'lucide:file-check' : 'lucide:upload'" width="16" />
            <span class="file-picker-text">{{ uploadingProof ? 'Uploading…' : form.proofUrl ? 'Replace file' : 'Choose file' }}</span>
            <input type="file" accept="image/*" class="file-picker-input" :disabled="uploadingProof" @change="onProofSelected" />
          </span>
          <img v-if="form.proofUrl" :src="resolveAsset(form.proofUrl)" alt="Proof of payment" class="submit-proof-preview" />
          <span v-if="!isCash" class="submit-hint">Required for non-cash payments, so there's something to verify against.</span>
        </label>

        <q-btn
          unelevated
          rounded
          no-caps
          color="primary"
          class="submit-btn"
          :loading="submitting"
          :disable="uploadingProof"
          label="Submit"
          @click="submitPayment"
        />
      </q-card>
    </q-dialog>

    <q-dialog v-model="paymentDetailOpen" position="bottom">
      <q-card v-if="selectedPayment" class="detail-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <h3 class="detail-title">
          {{ selectedPayment.description === ADVANCE_TAG || selectedPayment.description === DEPOSIT_TAG ? selectedPayment.description : formatMonth(selectedPayment.month) }}
        </h3>
        <span class="detail-chip" :class="`detail-chip--${statusColor(PAYMENT_STATUS, selectedPayment.status)}`">
          {{ statusText(PAYMENT_STATUS, selectedPayment.status) }}
        </span>

        <div class="group">
          <div class="rule">
            <span class="rule-label">Amount</span>
            <span class="rule-value">{{ formatPeso(selectedPayment.amount) }}</span>
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

        <template v-if="selectedPayment.description">
          <p class="detail-label">Note</p>
          <p class="detail-text">{{ selectedPayment.description }}</p>
        </template>

        <template v-if="selectedPayment.proofUrl">
          <p class="detail-label">Proof of payment</p>
          <img :src="resolveAsset(selectedPayment.proofUrl)" alt="Proof of payment" class="proof-img" />
        </template>

        <q-btn unelevated rounded no-caps color="primary" class="detail-close" label="Close" @click="paymentDetailOpen = false" />
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'
import type { RealtimeChannel } from '@supabase/supabase-js'
import { useRouter, useRoute } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import {
  formatPeso,
  formatDate,
  formatMonth,
  initialsOf,
  LEASE_STATUS,
  PAYMENT_STATUS,
  PAYMENT_METHOD_LABEL,
  statusText,
  statusColor,
} from '@/utils/format'
import { useNotify } from '@/utils/notify'
import { createNotification } from '@/boot/notify'
import { uploadDocument } from '@/utils/upload'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { AMENITY_META, roomTypeLabel } from '@/utils/listings'
import EmptyState from '@/components/shared/EmptyState.vue'

function yesNo(value: boolean | null | undefined): string {
  if (value === null || value === undefined) return ''
  return value ? 'Allowed' : 'Not allowed'
}

// Advance/deposit have no dedicated column on `payments` (only `month`,
// which rent needs and these don't) — tagged via `description` instead of a
// schema change, and excluded from the rent month-sequence by that tag.
const ADVANCE_TAG = 'Advance payment'
const DEPOSIT_TAG = 'Security deposit'

interface Lease {
  id: string
  managerId: string
  managerName: string
  managerInitials: string
  managerAvatarUrl: string | null
  replyMinutes: number | null
  accommodationName: string
  roomLabel: string
  status: 'active' | 'pending' | 'leave_requested'
  monthlyRent: number
  advancePaid: number
  depositPaid: number
  startDate: string
  endDate: string
  roomType: string
  capacity: number | null
  address: string
  amenities: string[]
  rules: { label: string; value: string }[]
  roommateCount: number | null
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
}

const router = useRouter()
const route = useRoute()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const lease = ref<Lease | null>(null)
const payments = ref<Payment[]>([])
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

const leaveDialog = ref(false)
const leaving = ref(false)

const submitOpen = ref(false)
const submitting = ref(false)
const uploadingProof = ref(false)
const form = reactive({
  category: 'rent' as 'rent' | 'advance' | 'deposit',
  month: new Date().toISOString().slice(0, 7),
  amount: 0,
  method: 'gcash' as 'gcash' | 'maya' | 'bank' | 'cash' | 'others',
  reference: '',
  proofUrl: '',
})

const canPayAdvance = computed(() => Boolean(lease.value && !lease.value.advancePaid))
const canPayDeposit = computed(() => Boolean(lease.value && !lease.value.depositPaid))

// The one rent month actually payable right now: the earliest month since
// lease start with no 'paid' or 'pending_verification' row yet. Locking the
// form to this (instead of a free month picker) is what makes "pay in
// order, never skip ahead, never backdate" hold — there's no field left to
// game.
const nextRentMonth = computed(() => {
  if (!lease.value) return ''
  const covered = new Set(
    payments.value
      .filter((p) => p.description !== ADVANCE_TAG && p.description !== DEPOSIT_TAG)
      .filter((p) => p.status === 'paid' || p.status === 'pending_verification')
      .map((p) => p.month.slice(0, 7)),
  )
  const start = new Date(lease.value.startDate)
  const cursor = new Date(start.getFullYear(), start.getMonth(), 1)
  for (let i = 0; i < 240; i++) {
    const key = `${cursor.getFullYear()}-${String(cursor.getMonth() + 1).padStart(2, '0')}`
    if (!covered.has(key)) return key
    cursor.setMonth(cursor.getMonth() + 1)
  }
  return `${cursor.getFullYear()}-${String(cursor.getMonth() + 1).padStart(2, '0')}`
})

const submitTitle = computed(() => {
  if (form.category === 'advance') return 'Pay your advance'
  if (form.category === 'deposit') return 'Pay your deposit'
  return 'Submit a payment'
})

// Cash has nothing to reference or photograph — every other method leaves a
// trail, and the manager needs it to actually verify against.
const isCash = computed(() => form.method === 'cash')

const paymentDetailOpen = ref(false)
const selectedPayment = ref<Payment | null>(null)
function openPaymentDetail(p: Payment) {
  selectedPayment.value = p
  paymentDetailOpen.value = true
}

// A pending application isn't an accepted lease yet, so there's nothing to pay.
const canPay = computed(() => lease.value?.status !== 'pending')

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data: authData } = await supabase.auth.getUser()
    const user = authData?.user
    if (!user) {
      error.value = 'Not signed in.'
      return
    }

    // The current lease (for the Stay tab) and all-time payment history (for
    // the Payments tab) are independent — a student with no active lease can
    // still have real payments on file from a past stay, so the Payments tab
    // must not be gated on there being a lease right now.
    const [{ data: leaseRow, error: leaseError }, { data: paymentRows, error: paymentsError }] = await Promise.all([
      supabase
        .from('leases')
        .select(
          'id, room_id, status, start_date, end_date, monthly_rent, advance_paid, deposit_paid, accommodation_manager_id, rooms(room_number, label, room_type, custom_room_type, capacity, accommodations(name, address, barangay, city, accommodation_amenities(amenity), accommodation_policies(curfew_time,quiet_hours,visitor_policy,cooking,laundry,pets,smoking,min_stay,contract_type)))',
        )
        .eq('student_id', user.id)
        .in('status', ['active', 'pending', 'leave_requested'])
        .order('start_date', { ascending: false })
        .limit(1)
        .maybeSingle(),
      supabase
        .from('payments')
        .select(
          'id, lease_id, month, amount, status, method, description, txn_reference, proof_url, paid_at, rejection_reason, verified_by_user:users!payments_verified_by_fkey(full_name), leases!inner(student_id, rooms(room_number, label, accommodations(name)))',
        )
        .eq('leases.student_id', user.id)
        .order('month', { ascending: false }),
    ])
    if (leaseError) throw leaseError
    if (paymentsError) throw paymentsError

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
    const amenities = ((acc?.accommodation_amenities ?? []) as { amenity: string }[]).map((a) => a.amenity)
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
            { label: 'Smoking', value: yesNo(policy.smoking as boolean | null) },
            { label: 'Minimum stay', value: policy.min_stay ? `${policy.min_stay} month(s)` : '' },
            { label: 'Contract type', value: String(policy.contract_type ?? '') },
          ] as { label: string; value: string }[]
        ).filter((r) => r.value)
      : []

    const [{ data: manager }, { data: profile }, roommateResult] = await Promise.all([
      supabase.from('users').select('full_name, initials, avatar_url').eq('id', leaseRow.accommodation_manager_id).maybeSingle(),
      supabase
        .from('accommodation_manager_profiles')
        .select('avg_response_minutes')
        .eq('user_id', leaseRow.accommodation_manager_id)
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
      managerId: leaseRow.accommodation_manager_id,
      managerName: manager?.full_name || 'Accommodation manager',
      managerInitials: manager?.initials || initialsOf(manager?.full_name || '?'),
      managerAvatarUrl: manager?.avatar_url ? resolveAsset(manager.avatar_url) : null,
      replyMinutes: profile?.avg_response_minutes ?? null,
      accommodationName: room?.accommodations?.name || 'Your accommodation',
      roomLabel: room?.label || (room?.room_number ? `Room ${room.room_number}` : ''),
      status: leaseRow.status as Lease['status'],
      monthlyRent: Number(leaseRow.monthly_rent ?? 0),
      advancePaid: Number(leaseRow.advance_paid ?? 0),
      depositPaid: Number(leaseRow.deposit_paid ?? 0),
      startDate: leaseRow.start_date,
      endDate: leaseRow.end_date,
      roomType: roomTypeLabel(room?.custom_room_type || room?.room_type),
      capacity: room?.capacity ?? null,
      address: acc?.address || [acc?.barangay, acc?.city].filter(Boolean).join(', ') || '',
      amenities,
      rules,
      roommateCount: roommateResult.count,
    }
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

async function requestLeave() {
  if (leaving.value || !lease.value) return
  leaving.value = true
  try {
    const { data: authData } = await supabase.auth.getUser()
    const user = authData?.user
    if (!user) throw new Error('Not signed in.')

    const { error: updateError } = await supabase
      .from('leases')
      .update({ status: 'leave_requested', leave_requested_at: new Date().toISOString() })
      .eq('id', lease.value.id)
      .eq('student_id', user.id)
    if (updateError) throw updateError

    void createNotification(
      lease.value.managerId,
      'Leave request',
      `A tenant requested to leave ${lease.value.accommodationName}.`,
      'lease',
      `/manager/tenant/${lease.value.id}`,
    )

    lease.value = { ...lease.value, status: 'leave_requested' }
    leaveDialog.value = false
    notify.success('Leave request sent.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not send your leave request.'))
  } finally {
    leaving.value = false
  }
}

function openSubmit(category: typeof form.category) {
  form.category = category
  form.month = nextRentMonth.value
  form.amount = lease.value?.monthlyRent ?? 0
  form.method = 'gcash'
  form.reference = ''
  form.proofUrl = ''
  submitOpen.value = true
}

async function onProofSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  uploadingProof.value = true
  try {
    form.proofUrl = await uploadDocument(file, '', 'payment_proof')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload the proof image.'))
  } finally {
    uploadingProof.value = false
    input.value = ''
  }
}

async function submitPayment() {
  if (submitting.value || uploadingProof.value || !lease.value) return

  // Re-validate against current state rather than trusting the form — the
  // UI already locks these, but a stale dialog (left open while something
  // changed) shouldn't be able to slip a payment through anyway.
  if (form.category === 'rent' && form.month !== nextRentMonth.value) {
    notify.error(`Pay ${formatMonth(`${nextRentMonth.value}-01`)} first — months are paid in order.`)
    return
  }
  if (form.category === 'advance' && !canPayAdvance.value) {
    notify.error('Advance is already on file.')
    return
  }
  if (form.category === 'deposit' && !canPayDeposit.value) {
    notify.error('Deposit is already on file.')
    return
  }
  if (!isCash.value && !form.reference.trim()) {
    notify.error('Enter a reference number, or switch the method to Cash.')
    return
  }
  if (!isCash.value && !form.proofUrl) {
    notify.error('Attach proof of payment, or switch the method to Cash.')
    return
  }

  const description = form.category === 'advance' ? ADVANCE_TAG : form.category === 'deposit' ? DEPOSIT_TAG : null
  const month = form.category === 'rent' ? `${form.month}-01` : `${new Date().toISOString().slice(0, 7)}-01`

  submitting.value = true
  try {
    const { data: created, error: insertError } = await supabase
      .from('payments')
      .insert({
        lease_id: lease.value.id,
        month,
        amount: form.amount,
        method: form.method,
        status: 'pending_verification',
        description,
        txn_reference: form.reference.trim() || null,
        proof_url: form.proofUrl || null,
      })
      .select('id, month, amount, status, method')
      .single()
    if (insertError) throw insertError

    payments.value = [
      {
        id: created.id,
        leaseId: lease.value.id,
        month: created.month,
        amount: Number(created.amount),
        status: created.status,
        method: created.method,
        roomLabel: lease.value.roomLabel || 'Your room',
        accommodationName: lease.value.accommodationName,
        description: description || '',
        txnReference: form.reference.trim(),
        proofUrl: form.proofUrl,
        paidAt: null,
        verifiedByName: '',
        rejectionReason: '',
      },
      ...payments.value,
    ]

    void createNotification(
      lease.value.managerId,
      'Payment submitted',
      `A payment of ${formatPeso(form.amount)} was submitted for verification.`,
      'payment',
      `/manager/tenant/${lease.value.id}`,
    )

    submitOpen.value = false
    notify.success('Payment submitted for verification.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not submit your payment.'))
  } finally {
    submitting.value = false
  }
}

// Kept alive across navigation (see MainLayout's KEEP_ALIVE_PAGES), so this
// only really runs once per session rather than on every visit. The database
// pushes lease changes here instead of the page re-asking on every return —
// same channel shape as stores/notifications.ts, just refetching instead of
// merging since this page has no per-row incremental-update need.
let leaseChannel: RealtimeChannel | null = null

onMounted(async () => {
  await load()
  const { data: authData } = await supabase.auth.getUser()
  const uid = authData?.user?.id
  if (!uid || typeof supabase.channel !== 'function') return
  leaseChannel = supabase
    .channel(`stay-leases:${uid}`)
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'leases', filter: `student_id=eq.${uid}` },
      () => void load(true),
    )
    .subscribe()
})

onUnmounted(() => {
  if (leaseChannel) void supabase.removeChannel(leaseChannel)
})
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
.tabbed {
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
  padding: 14px 14px 20px;
  border: 1px solid var(--m-border);
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
.detail-close {
  min-height: 46px;
  margin-top: 6px;
  font-weight: 700;
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
  cursor: pointer;
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

.submit-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.submit-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.submit-note {
  margin: -6px 0 0;
  color: var(--m-muted);
  font-size: 12.5px;
}
.submit-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.submit-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.submit-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.submit-locked-month {
  display: flex;
  min-height: 44px;
  align-items: center;
  gap: 8px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.submit-proof-preview {
  width: 100%;
  max-height: 200px;
  margin-top: 8px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  object-fit: contain;
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
.submit-hint {
  color: var(--m-muted);
  font-size: 11.5px;
}
.submit-hint--ok {
  color: var(--m-success);
  font-weight: 600;
}
.submit-btn {
  min-height: 48px;
  font-weight: 700;
}
</style>
