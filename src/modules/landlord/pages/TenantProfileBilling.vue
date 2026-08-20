<template>
  <q-page class="tenant-profile-page bg-white">
    <div class="page-shell">
      <div class="top-header q-px-md q-py-sm row items-center no-wrap">
        <div class="col-auto">
          <q-btn flat round dense icon="arrow_back" class="back-btn" @click="goBack" />
        </div>

        <div class="col text-center">
          <div class="tenant-name">{{ tenantName }}</div>
          <div class="tenant-course">{{ courseLine }}</div>
        </div>

        <div class="col-auto row items-center no-wrap q-gutter-sm">
          <q-btn flat round dense icon="chat_bubble_outline" class="chat-btn" @click="openChat" />
          <q-btn flat round dense icon="close" class="close-btn" @click="goBack" />
        </div>
      </div>

      <div v-if="isLoading" class="center-state">
        <q-spinner size="42px" color="teal-8" />
      </div>

      <div v-else-if="loadError" class="q-px-md q-pb-xl">
        <q-banner class="bg-red-1 text-red-8 rounded-borders">
          <template #avatar><q-icon name="error_outline" /></template>
          {{ loadError }}
        </q-banner>
      </div>

      <div v-else-if="!lease" class="center-state text-grey-7">
        No lease found for this tenant under your account.
      </div>

      <template v-else>
        <q-banner v-if="isSample" class="bg-amber-1 text-amber-9 rounded-borders q-mx-md q-mt-md">
          SAMPLE tenant preview — not from your database. Real tenant details appear once leases exist and are shared with landlords.
        </q-banner>

        <div class="profile-header q-px-md q-py-md row items-center">
          <q-avatar size="64px" :color="avatarColor" text-color="white" class="profile-avatar">
            {{ initials }}
          </q-avatar>

          <div class="profile-meta q-ml-md">
            <div class="profile-name row items-center no-wrap">
              <span>{{ tenantName }}</span>
              <q-icon name="verified" size="18px" color="teal-7" class="q-ml-xs" />
            </div>
            <div class="student-id">Student ID {{ maskedId }}</div>
          </div>
        </div>

        <div class="assignment-card q-mx-md q-my-md">
          <div class="row items-center no-wrap">
            <div class="assignment-icon">
              <q-icon name="person_outline" size="22px" color="teal-8" />
            </div>

            <div class="assignment-copy q-ml-md col">
              <div class="assignment-title">{{ roomTitle }}</div>
              <div class="assignment-subtitle">{{ propertyName }}<template v-if="floor !== null && floor !== undefined"> · Floor {{ floor }}</template></div>
            </div>

            <div class="assignment-status q-ml-auto" :class="`status-${statusInfo.label.toLowerCase().replace(/[^a-z]/g, '')}`">
              {{ statusInfo.label }}
            </div>
          </div>
        </div>

        <div class="metrics-grid q-px-md row q-col-gutter-sm">
          <div class="col-4">
            <div class="metric-card teal">
              <q-icon name="credit_card" size="20px" color="teal-8" />
              <div class="metric-value">{{ rent }}</div>
              <div class="metric-label">MONTHLY</div>
            </div>
          </div>

          <div class="col-4">
            <div class="metric-card purple">
              <q-icon name="check_circle" size="20px" color="purple-7" />
              <div class="metric-value">{{ paidCount }} mo</div>
              <div class="metric-label">PAY STREAK</div>
            </div>
          </div>

          <div class="col-4">
            <div class="metric-card orange">
              <q-icon name="star" size="20px" color="orange-7" />
              <div class="metric-value">0</div>
              <div class="metric-label">REVIEWS</div>
            </div>
          </div>
        </div>

        <div class="tab-wrap q-mt-lg">
          <q-tabs
            v-model="activeTab"
            dense
            align="left"
            active-color="black"
            indicator-color="black"
            class="billing-tabs"
          >
            <q-tab name="billing" label="Billing" />
            <q-tab name="info" label="Info" />
            <q-tab name="history" label="History" />
            <q-tab name="reviews" label="Reviews (0)" />
          </q-tabs>
        </div>

        <div v-if="activeTab === 'billing'" class="billing-tab q-px-md q-pb-xl">
          <div
            class="status-banner q-mt-md row items-center no-wrap"
            :class="pendingPayment ? 'banner-pending' : 'banner-current'"
          >
            <div class="banner-icon">
              <q-icon :name="pendingPayment ? 'warning' : 'check'" size="18px" :color="pendingPayment ? 'orange-7' : 'green-7'" />
            </div>

            <div class="banner-copy q-ml-md">
              <div class="banner-title">{{ pendingPayment ? 'Payment due' : 'All payments current' }}</div>
              <div class="banner-subtitle">{{ rent }}/mo - Deposit: {{ depositPaid ? 'Paid' : 'Unpaid' }}</div>
            </div>
          </div>

          <q-btn
            unelevated
            color="black"
            class="full-width q-mt-md log-payment-btn"
            icon="add"
            label="Log Cash Payment"
            @click="openLog"
          />

          <div class="section-label q-mt-lg">PAYMENT STREAK</div>

          <div class="streak-row q-mt-sm row items-center no-wrap">
            <div class="streak-label left">{{ streakDots[0]?.label }}</div>

            <div class="streak-track row items-center justify-between col">
              <div v-for="(dot, i) in streakDots" :key="i" class="streak-dot" :class="dot.filled ? 'filled' : ''" />
            </div>

            <div class="streak-label center text-teal-8">{{ paidCount }}/12 on time</div>
            <div class="streak-label right">{{ streakDots[streakDots.length - 1]?.label }}</div>
          </div>

          <div class="section-label q-mt-lg">PAYMENT HISTORY</div>

          <div v-if="!historyItems.length" class="empty-hint">No payments recorded yet.</div>

          <div v-else class="history-list q-mt-sm">
            <div v-for="payment in historyItems" :key="payment.month + payment.date" class="history-item row items-center no-wrap">
              <div class="history-check" :class="payment.status === 'paid' ? '' : 'history-check-pending'">
                <q-icon :name="payment.status === 'paid' ? 'check' : 'schedule'" size="14px" color="white" />
              </div>

              <div class="history-copy q-ml-sm col">
                <div class="history-month">{{ payment.month }}</div>
                <div class="history-meta">{{ payment.date }} - {{ payment.method }}</div>
              </div>

              <div class="history-side text-right">
                <div class="history-amount">{{ payment.amount }}</div>
                <div class="history-status" :class="statusClass(payment.status)">{{ payment.status }}</div>
              </div>
            </div>
          </div>

          <div class="section-label q-mt-lg">BILLING SUMMARY</div>

          <div class="summary-list q-mt-sm">
            <div class="summary-row">
              <span>Monthly Rent</span>
              <strong>{{ rent }}</strong>
            </div>

            <div class="summary-row">
              <span>Security Deposit</span>
              <strong>{{ depositPaid ? 'Paid' : 'Unpaid' }}</strong>
            </div>

            <div class="summary-row">
              <span>Total Paid est.</span>
              <strong>{{ totalPaidLabel }}</strong>
            </div>

            <div class="summary-row">
              <span>Active Repairs</span>
              <strong>0</strong>
            </div>
          </div>
        </div>

        <div v-else-if="activeTab === 'info'" class="info-tab q-px-md q-pb-xl">
          <div class="section-label q-mt-lg">LEASE DETAILS</div>
          <div class="summary-list q-mt-sm">
            <div v-for="row in infoRows" :key="row.label" class="summary-row">
              <span>{{ row.label }}</span>
              <strong>{{ row.value }}</strong>
            </div>
          </div>

          <div class="section-label q-mt-lg">STUDENT BACKGROUND</div>
          <q-banner v-if="showRlsNote" class="bg-amber-1 text-amber-9 rounded-borders q-mt-sm">
            <template #avatar><q-icon name="lock" /></template>
            Tenant name and school details aren't visible to landlords (privacy rules). A database change is needed to share them.
          </q-banner>
          <div class="summary-list q-mt-sm">
            <div v-for="row in studentBackgroundRows" :key="row.label" class="summary-row">
              <span>{{ row.label }}</span>
              <strong>{{ row.value }}</strong>
            </div>
          </div>
        </div>

        <div v-else-if="activeTab === 'history'" class="history-tab q-px-md q-pb-xl">
          <div class="section-label q-mt-lg">PAYMENT HISTORY</div>
          <div v-if="!historyItems.length" class="empty-hint">No payments recorded yet.</div>
          <div v-else class="history-list q-mt-sm">
            <div v-for="payment in historyItems" :key="payment.month + payment.date" class="history-item row items-center no-wrap">
              <div class="history-check" :class="payment.status === 'paid' ? '' : 'history-check-pending'">
                <q-icon :name="payment.status === 'paid' ? 'check' : 'schedule'" size="14px" color="white" />
              </div>

              <div class="history-copy q-ml-sm col">
                <div class="history-month">{{ payment.month }}</div>
                <div class="history-meta">{{ payment.date }} - {{ payment.method }}</div>
              </div>

              <div class="history-side text-right">
                <div class="history-amount">{{ payment.amount }}</div>
                <div class="history-status" :class="statusClass(payment.status)">{{ payment.status }}</div>
              </div>
            </div>
          </div>
        </div>

        <div v-else class="reviews-tab q-px-md q-pb-xl">
          <div class="empty-state q-mt-xl column items-center text-grey-7">
            <q-icon name="star_border" size="48px" color="grey-5" />
            <div class="q-mt-sm">No reviews yet for this tenant.</div>
          </div>
        </div>
      </template>
    </div>

    <q-dialog v-model="logDialog">
      <q-card class="log-dialog">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6">Log Cash Payment</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input
            v-model="payForm.amount"
            type="number"
            outlined
            dense
            label="Amount (PHP)"
            prefix="P"
          />
          <q-input v-model="payForm.month" type="date" outlined dense label="Month" />
          <q-select
            v-model="payForm.method"
            :options="['cash', 'bank_transfer', 'gcash']"
            outlined
            dense
            label="Method"
          />
        </q-card-section>

        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn flat label="Cancel" color="grey-8" v-close-popup />
          <q-btn unelevated label="Save" color="teal-8" @click="savePayment" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useQuasar } from 'quasar'
import { supabase } from '@/shared/utils/supabase'
import { useChatStore } from '@/stores/chat'

// RLS note: `users`/`student_profiles` only return the caller's own row, so a
// landlord cannot read a tenant's real name. We show a stable fallback derived
// from the student id and surface it consistently in the UI.

const router = useRouter()
const route = useRoute()
const $q = useQuasar()
const chat = useChatStore()

const AVATAR_PALETTE = ['teal-8', 'purple-6', 'pink-5', 'orange-5', 'blue-6', 'green-6']

function hashIndex(id: string, mod: number): number {
  let sum = 0
  for (const ch of id) sum += ch.charCodeAt(0)
  return sum % mod
}

function initialsOf(name: string): string {
  return (name || '?')
    .trim()
    .split(/\s+/)
    .map((p) => p[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

function formatCurrency(n: number | string | null | undefined): string {
  const v = Number(n || 0)
  return 'P' + v.toLocaleString('en-US')
}

function formatMonth(dateStr: string): string {
  const d = new Date(dateStr)
  if (isNaN(d.getTime())) return dateStr
  return d.toLocaleString('en-US', { month: 'long', year: 'numeric' })
}

function firstOfMonth(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`
}

const isLoading = ref(false)
const loadError = ref<string | null>(null)
const lease = ref<any>(null)
const payments = ref<any[]>([])
const studentProfile = ref<any>(null)
const studentUser = ref<any>(null)
const isSample = ref(false)

// In-memory SAMPLE tenant profiles so the click-through can be previewed end to
// end without a database. Mirrors the real shape used by the loaders below.
function buildSamplePayments(rent: number, paidCount: number, includeDue: boolean): any[] {
  const out: any[] = []
  const now = new Date()
  for (let i = paidCount - 1; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
    const y = d.getFullYear()
    const m = String(d.getMonth() + 1).padStart(2, '0')
    const month = `${y}-${m}-01`
    out.push({ id: `sp-${y}-${m}`, month, description: 'Rent', amount: rent, status: 'paid', method: 'gcash', paid_at: month })
  }
  if (includeDue) {
    const d = new Date(now.getFullYear(), now.getMonth(), 1)
    const month = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`
    out.push({ id: 'sp-due', month, description: 'Rent', amount: rent, status: 'due', method: 'cash', paid_at: null })
  }
  return out
}

const SAMPLE_TENANTS: Record<string, any> = {
  'sample-1': {
    user: { full_name: 'Maria Santos', initials: 'MS', sex: 'Female', phone: '+63 912 345 6789', email: 'maria.santos@example.edu.ph', avatar_color: 'teal-8' },
    profile: { student_id: '2023-001234', college: 'College of Engineering', program: 'BS Computer Science', year_level: 2, sex: 'Female' },
    lease: {
      id: 'sample-lease-1', student_id: 'sample-1', status: 'active',
      start_date: '2025-06-01', end_date: '2026-05-31', monthly_rent: 3500, deposit_paid: true, leave_requested_at: null,
      room: { id: 'sample-room-101', room_number: '101', label: 'Room 101', floor: 1, capacity: 4, current_pax: 2, status: 'occupied',
        property: { name: 'Sample Boarding House', address: 'Sample St., Sample City' } },
    },
    payments: buildSamplePayments(3500, 6, false),
  },
  'sample-2': {
    user: { full_name: 'John Dela Cruz', initials: 'JD', sex: 'Male', phone: '+63 998 111 2233', email: 'john.delacruz@example.edu.ph', avatar_color: 'purple-6' },
    profile: { student_id: '2023-005678', college: 'College of Arts and Sciences', program: 'AB Psychology', year_level: 1, sex: 'Male' },
    lease: {
      id: 'sample-lease-2', student_id: 'sample-2', status: 'active',
      start_date: '2025-07-01', end_date: '2026-06-30', monthly_rent: 3500, deposit_paid: true, leave_requested_at: null,
      room: { id: 'sample-room-101', room_number: '101', label: 'Room 101', floor: 1, capacity: 4, current_pax: 2, status: 'occupied',
        property: { name: 'Sample Boarding House', address: 'Sample St., Sample City' } },
    },
    payments: buildSamplePayments(3500, 3, false),
  },
  'sample-3': {
    user: { full_name: 'Ana Reyes', initials: 'AR', sex: 'Female', phone: '+63 917 444 5566', email: 'ana.reyes@example.edu.ph', avatar_color: 'orange-5' },
    profile: { student_id: '2022-009876', college: 'College of Business', program: 'BS Accountancy', year_level: 3, sex: 'Female' },
    lease: {
      id: 'sample-lease-3', student_id: 'sample-3', status: 'active',
      start_date: '2025-01-01', end_date: '2025-12-31', monthly_rent: 4000, deposit_paid: false, leave_requested_at: null,
      room: { id: 'sample-room-102', room_number: '102', label: 'Room 102', floor: 1, capacity: 2, current_pax: 1, status: 'occupied',
        property: { name: 'Sample Boarding House', address: 'Sample St., Sample City' } },
    },
    payments: buildSamplePayments(4000, 2, true),
  },
}

function loadSample() {
  isSample.value = true
  const sample = SAMPLE_TENANTS[studentId.value]
  if (!sample) {
    loadError.value = 'Sample tenant not found'
    return
  }
  studentUser.value = sample.user
  studentProfile.value = sample.profile
  lease.value = sample.lease
  payments.value = sample.payments
}

const studentId = computed(() => String(route.params.tenantId || ''))

function leaseStatusInfo(status: string | undefined, leaveRequested: boolean) {
  if (leaveRequested) return { label: 'Leaving', color: 'amber-1', textColor: 'amber-8' }
  switch (status) {
    case 'active':
      return { label: 'Current', color: 'teal-1', textColor: 'teal-8' }
    case 'pending':
      return { label: 'Pending', color: 'blue-1', textColor: 'blue-8' }
    case 'terminated':
    case 'ended':
    case 'expired':
      return { label: 'Ended', color: 'grey-3', textColor: 'grey-8' }
    default:
      return { label: (status || 'Unknown').replace('_', ' '), color: 'grey-3', textColor: 'grey-8' }
  }
}

async function loadData() {
  if (studentId.value.startsWith('sample-')) {
    isLoading.value = true
    loadError.value = null
    try {
      loadSample()
    } catch (e: any) {
      loadError.value = e?.message || 'Failed to load sample'
    } finally {
      isLoading.value = false
    }
    return
  }

  isLoading.value = true
  loadError.value = null
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser()
    if (!user) {
      loadError.value = 'Not signed in'
      return
    }

    const { data, error } = await supabase
      .from('leases')
      .select(
        `id, student_id, status, start_date, end_date, monthly_rent, deposit_paid, leave_requested_at,
         room:rooms!room_id(id, room_number, label, floor, capacity, current_pax, status,
           property:properties(name, address))`,
      )
      .eq('student_id', studentId.value)
      .eq('landlord_id', user.id)
      .order('start_date', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (error) throw error
    lease.value = data as any
    if (!data) return

    // RLS note: `users` and `student_profiles` only return the caller's own
    // row, so a landlord cannot read a tenant's name/background. These queries
    // succeed but return null for real tenants — the UI surfaces that honestly.
    const [
      { data: pays, error: payErr },
      { data: u },
      { data: p },
    ] = await Promise.all([
      supabase
        .from('payments')
        .select('id, month, description, amount, status, method, paid_at')
        .eq('lease_id', data.id)
        .order('month', { ascending: false }),
      supabase
        .from('users')
        .select('id, full_name, initials, sex, phone, email, avatar_color')
        .eq('id', data.student_id)
        .maybeSingle(),
      supabase
        .from('student_profiles')
        .select('student_id, college, program, year_level, sex')
        .eq('user_id', data.student_id)
        .maybeSingle(),
    ])

    if (payErr) throw payErr
    payments.value = (pays || []) as any[]
    studentUser.value = (u as any) || null
    studentProfile.value = (p as any) || null
  } catch (e: any) {
    loadError.value = e?.message || 'Failed to load tenant'
  } finally {
    isLoading.value = false
  }
}

const room = computed(() => (lease.value?.room as any) || {})
const property = computed(() => (room.value.property as any) || {})

const tenantName = computed(() => studentUser.value?.full_name || `Tenant ${studentId.value.slice(0, 4)}`)
const initials = computed(() => studentUser.value?.initials || initialsOf(tenantName.value))
const avatarColor = computed(() => studentUser.value?.avatar_color || AVATAR_PALETTE[hashIndex(studentId.value, AVATAR_PALETTE.length)])
const maskedId = computed(() => studentProfile.value?.student_id || '—')
const courseLine = computed(() => {
  const p = studentProfile.value
  if (p?.program) {
    const parts: string[] = [p.program]
    if (p.year_level != null) parts.push(`Year ${p.year_level}`)
    if (p.college) parts.push(p.college)
    return parts.join(' · ')
  }
  const r = room.value
  const parts: string[] = []
  if (r.label) parts.push(r.label)
  else if (r.room_number) parts.push(`Room ${r.room_number}`)
  if (r.floor) parts.push(`Floor ${r.floor}`)
  return parts.join(' · ') || '—'
})
const roomTitle = computed(() => room.value.label || (room.value.room_number ? `Room ${room.value.room_number}` : 'Room'))
const propertyName = computed(() => property.value.name || 'Property')
const floor = computed(() => room.value.floor)
const statusInfo = computed(() =>
  lease.value ? leaseStatusInfo(lease.value.status, !!lease.value.leave_requested_at) : { label: '—', color: 'grey-3', textColor: 'grey-8' },
)
const rent = computed(() => formatCurrency(lease.value?.monthly_rent))
const depositPaid = computed(() => !!lease.value?.deposit_paid)

const paidPayments = computed(() => payments.value.filter((p) => p.status === 'paid'))
const paidCount = computed(() => paidPayments.value.length)
const pendingPayment = computed(() =>
  payments.value.some((p) => ['due', 'overdue', 'pending_verification'].includes(p.status)),
)
const totalPaid = computed(() =>
  payments.value.filter((p) => p.status === 'paid').reduce((s, p) => s + Number(p.amount || 0), 0),
)
const totalPaidLabel = computed(() => formatCurrency(totalPaid.value))

const streakDots = computed(() => {
  const now = new Date()
  const arr: { label: string; filled: boolean }[] = []
  for (let i = 11; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
    const y = d.getFullYear()
    const m = d.getMonth()
    const filled = payments.value.some((p) => {
      if (p.status !== 'paid') return false
      const pd = new Date(p.month)
      return !isNaN(pd.getTime()) && pd.getFullYear() === y && pd.getMonth() === m
    })
    arr.push({ label: d.toLocaleString('en-US', { month: 'short' }), filled })
  }
  return arr
})

const historyItems = computed(() =>
  payments.value.map((p) => ({
    month: formatMonth(p.month),
    date: p.paid_at ? formatMonth(p.paid_at) : formatMonth(p.month),
    method: (p.method || '—').replace('_', ' '),
    amount: formatCurrency(p.amount),
    status: p.status,
  })),
)

const infoRows = computed(() => {
  if (!lease.value) return [] as { label: string; value: string }[]
  const l = lease.value
  const r = room.value
  const p = property.value
  return [
    { label: 'Property', value: p.name || '—' },
    { label: 'Address', value: p.address || '—' },
    { label: 'Room', value: r.label || (r.room_number ? `Room ${r.room_number}` : '—') },
    { label: 'Floor', value: r.floor !== null && r.floor !== undefined ? String(r.floor) : '—' },
    { label: 'Occupancy', value: `${r.current_pax ?? 0}/${r.capacity ?? 0}` },
    { label: 'Lease start', value: l.start_date ? formatMonth(l.start_date) : '—' },
    { label: 'Lease end', value: l.end_date ? formatMonth(l.end_date) : '—' },
    { label: 'Monthly rent', value: formatCurrency(l.monthly_rent) },
    { label: 'Deposit', value: l.deposit_paid ? 'Paid' : 'Unpaid' },
  ]
})

// When a real (non-sample) tenant's profile is empty, it means RLS blocked the
// landlord read. We surface that honestly instead of faking data.
const showRlsNote = computed(() => !isSample.value && !!lease.value && !studentUser.value?.full_name)

const studentBackgroundRows = computed(() => {
  const u = studentUser.value
  const p = studentProfile.value
  return [
    { label: 'Full name', value: u?.full_name || '—' },
    { label: 'Sex', value: u?.sex || '—' },
    { label: 'Contact', value: u?.phone || '—' },
    { label: 'Email', value: u?.email || '—' },
    { label: 'Student ID', value: p?.student_id || '—' },
    { label: 'College', value: p?.college || '—' },
    { label: 'Program', value: p?.program || '—' },
    { label: 'Year level', value: p?.year_level != null ? `Year ${p.year_level}` : '—' },
  ]
})

function statusClass(status: string): string {
  if (status === 'paid') return 'text-green-7'
  if (status === 'due' || status === 'overdue') return 'text-red-7'
  if (status === 'pending_verification') return 'text-amber-7'
  return 'text-grey-7'
}

const activeTab = ref<'billing' | 'info' | 'history' | 'reviews'>('billing')

async function openChat() {
  if (!studentId.value) return
  if (isSample.value) {
    $q.notify({ type: 'info', message: 'Sample tenant — chat is disabled in preview mode.' })
    return
  }
  try {
    const id = await chat.ensureConversation(studentId.value)
    if (id) {
      await chat.loadMessages(id)
      void router.push('/landlord/chat')
    }
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to open chat' })
  }
}

const logDialog = ref(false)
const payForm = ref({ amount: '', month: firstOfMonth(), method: 'cash' })

function openLog() {
  payForm.value = { amount: '', month: firstOfMonth(), method: 'cash' }
  logDialog.value = true
}

async function savePayment() {
  if (!lease.value) return
  if (isSample.value) {
    $q.notify({ type: 'info', message: 'Sample tenant — payment logging is disabled in preview mode.' })
    return
  }
  const amount = Number(payForm.value.amount)
  if (!amount || amount <= 0) {
    $q.notify({ type: 'warning', message: 'Enter a valid amount' })
    return
  }
  try {
    const { error } = await supabase.from('payments').insert({
      lease_id: lease.value.id,
      month: payForm.value.month,
      description: 'Cash payment',
      amount,
      status: 'pending_verification',
      method: payForm.value.method,
      paid_at: new Date().toISOString(),
    } as any)
    if (error) throw error
    logDialog.value = false
    $q.notify({ type: 'positive', message: 'Payment logged for verification' })
    await loadData()
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to log payment' })
  }
}

function goBack() {
  void router.back()
}

onMounted(() => {
  void loadData()
})
</script>

<style scoped>
.tenant-profile-page {
  min-height: 100vh;
}

.page-shell {
  padding-bottom: 32px;
}

.top-header {
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
}

.tenant-name {
  color: #111827;
  font-size: 18px;
  font-weight: 800;
}

.tenant-course {
  color: #6b7280;
  font-size: 12px;
  margin-top: 2px;
}

.back-btn,
.chat-btn,
.close-btn {
  color: #00897b;
}

.close-btn {
  color: #dc2626;
}

.center-state {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 48px 24px;
  text-align: center;
  color: #6b7280;
}

.empty-hint {
  color: #6b7280;
  font-size: 13px;
  margin-top: 12px;
  text-align: center;
}

.empty-state {
  color: #6b7280;
  font-size: 13px;
}

.profile-header {
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
}

.profile-avatar {
  font-size: 24px;
  font-weight: 700;
}

.profile-name {
  font-size: 20px;
  font-weight: 800;
  color: #111827;
}

.student-id {
  color: #6b7280;
  font-size: 13px;
  margin-top: 4px;
}

.assignment-card {
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 18px;
  padding: 16px;
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.02);
}

.assignment-icon {
  width: 40px;
  height: 40px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 137, 123, 0.08);
}

.assignment-title {
  color: #111827;
  font-size: 15px;
  font-weight: 700;
}

.assignment-subtitle {
  color: #6b7280;
  font-size: 12px;
  margin-top: 3px;
}

.assignment-status {
  border: 1px solid rgba(0, 137, 123, 0.35);
  color: #00897b;
  background: rgba(0, 137, 123, 0.05);
  border-radius: 999px;
  padding: 6px 10px;
  font-size: 11px;
  font-weight: 700;
  white-space: nowrap;
}

.status-ended {
  border-color: rgba(107, 114, 128, 0.35);
  color: #6b7280;
  background: rgba(107, 114, 128, 0.05);
}

.status-leaving {
  border-color: rgba(217, 119, 6, 0.4);
  color: #d97706;
  background: rgba(245, 158, 11, 0.06);
}

.metrics-grid {
  margin-top: 4px;
}

.metric-card {
  border-radius: 18px;
  border: 1px solid rgba(15, 23, 42, 0.06);
  padding: 14px 10px;
  text-align: center;
  min-height: 116px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.metric-card.teal {
  background: rgba(0, 137, 123, 0.04);
}

.metric-card.purple {
  background: rgba(124, 58, 237, 0.04);
}

.metric-card.orange {
  background: rgba(245, 158, 11, 0.04);
}

.metric-value {
  color: #111827;
  font-size: 18px;
  font-weight: 800;
  margin-top: 12px;
}

.metric-label {
  color: #6b7280;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.08em;
  margin-top: 8px;
}

.tab-wrap {
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
}

.billing-tabs {
  padding: 0 16px;
}

.billing-tabs :deep(.q-tab) {
  color: #6b7280;
  font-weight: 600;
  font-size: 13px;
}

.billing-tabs :deep(.q-tab--active) {
  color: #111827;
}

.billing-tab,
.info-tab,
.history-tab,
.reviews-tab {
  padding-top: 16px;
}

.status-banner {
  border: 1px solid rgba(0, 137, 123, 0.15);
  border-radius: 18px;
  padding: 16px;
}

.banner-current {
  background: rgba(0, 137, 123, 0.08);
}

.banner-pending {
  background: rgba(245, 158, 11, 0.08);
  border-color: rgba(245, 158, 11, 0.2);
}

.banner-icon {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.banner-current .banner-icon {
  background: rgba(34, 197, 94, 0.14);
}

.banner-pending .banner-icon {
  background: rgba(245, 158, 11, 0.16);
}

.banner-title {
  color: #111827;
  font-size: 15px;
  font-weight: 800;
}

.banner-subtitle {
  color: #374151;
  font-size: 12px;
  margin-top: 3px;
}

.log-payment-btn {
  height: 48px;
  font-weight: 700;
}

.section-label {
  color: #6b7280;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.08em;
}

.streak-row {
  gap: 10px;
  margin-top: 12px;
}

.streak-label {
  color: #6b7280;
  font-size: 10px;
  font-weight: 700;
}

.streak-label.center {
  min-width: 82px;
  text-align: center;
}

.streak-track {
  flex: 1;
  gap: 8px;
}

.streak-dot {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #e5e7eb;
  border: 1px solid rgba(15, 23, 42, 0.04);
}

.streak-dot.filled {
  background: #00897b;
}

.history-list {
  margin-top: 12px;
}

.history-item {
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 16px;
  padding: 12px 14px;
  margin-bottom: 10px;
}

.history-check {
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: #22c55e;
  display: flex;
  align-items: center;
  justify-content: center;
}

.history-check-pending {
  background: #f59e0b;
}

.history-month {
  color: #111827;
  font-size: 14px;
  font-weight: 700;
}

.history-meta {
  color: #6b7280;
  font-size: 11px;
  margin-top: 2px;
}

.history-amount {
  color: #111827;
  font-weight: 800;
  font-size: 14px;
}

.history-status {
  font-size: 11px;
  font-weight: 700;
  margin-top: 4px;
}

.summary-list {
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 16px;
  overflow: hidden;
  margin-top: 12px;
}

.summary-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 16px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  color: #111827;
  font-size: 14px;
}

.summary-row:last-child {
  border-bottom: none;
}

.summary-row strong {
  font-weight: 800;
  color: #111827;
}

.log-dialog {
  width: 360px;
  max-width: 92vw;
}
</style>
