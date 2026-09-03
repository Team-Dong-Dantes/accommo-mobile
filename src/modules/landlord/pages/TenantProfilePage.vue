<template>
  <q-page class="student-detail-page">
    <main class="detail-shell">
      <div v-if="loading" class="detail-state" role="status" aria-live="polite">
        <q-spinner color="primary" size="32px" />
        <span>Loading student…</span>
      </div>

      <div v-else-if="error" class="detail-state detail-state--error" role="alert">
        <IconifyIcon icon="lucide:circle-alert" width="26" />
        <strong>Couldn’t load this student</strong>
        <span>{{ error }}</span>
        <q-btn outline no-caps color="primary" label="Try again" @click="load" />
      </div>

      <template v-else-if="student">
        <!-- Profile hero -->
        <section class="surface-card profile-card">
          <div class="profile-hero">
            <span class="profile-avatar-wrap">
              <span class="profile-avatar">{{ student.initials }}</span>
            </span>
            <div class="profile-headline">
              <h1>{{ student.name }}</h1>
              <p>{{ student.program || 'Student' }}</p>
              <span class="verified-pill" :class="{ 'verified-pill--on': student.verified }">
                <IconifyIcon :icon="student.verified ? 'lucide:badge-check' : 'lucide:clock-3'" width="13" />
                {{ student.verified ? 'OSAS verified' : 'Not OSAS verified' }}
              </span>
            </div>
          </div>

          <ul class="profile-info">
            <li><span class="info-icon"><IconifyIcon icon="lucide:id-card" width="17" /></span><div><small>Student ID</small><strong>{{ student.studentId || '—' }}</strong></div></li>
            <li><span class="info-icon"><IconifyIcon icon="lucide:school" width="17" /></span><div><small>College</small><strong>{{ student.college || '—' }}</strong></div></li>
            <li><span class="info-icon"><IconifyIcon icon="lucide:graduation-cap" width="17" /></span><div><small>Year level</small><strong>{{ student.yearLevel || '—' }}</strong></div></li>
            <li><span class="info-icon"><IconifyIcon icon="lucide:mail" width="17" /></span><div><small>Email</small><strong>{{ student.email || '—' }}</strong></div></li>
            <li><span class="info-icon"><IconifyIcon icon="lucide:phone" width="17" /></span><div><small>Phone</small><strong>{{ student.phone || '—' }}</strong></div></li>
          </ul>
        </section>

        <!-- Pending decision (only when this manager has a pending application from them) -->
        <section v-if="pendingLease" class="surface-card decision-card" aria-label="Application decision">
          <div class="decision-head">
            <span class="decision-icon"><IconifyIcon icon="lucide:clock-3" width="18" /></span>
            <div>
              <h2>Application pending</h2>
              <p>{{ pendingLease.roomLabel }} · {{ pendingLease.property }} · {{ formatPeso(pendingLease.monthlyRent) }}/mo · move-in {{ formatDate(pendingLease.startDate) }}</p>
            </div>
          </div>
          <div class="decision-actions">
            <q-btn unelevated no-caps class="primary-btn" label="Accept application" :loading="acting === 'accept'" @click="decide('accept')" />
            <q-btn outline no-caps class="ghost-danger-btn" label="Decline" :loading="acting === 'decline'" @click="decide('decline')" />
          </div>
        </section>

        <!-- Leave request decision (when tenant requested to leave) -->
        <section v-if="leaveRequestedLease" class="surface-card decision-card leave-decision-card" aria-label="Leave request decision">
          <div class="decision-head">
            <span class="decision-icon leave-icon"><IconifyIcon icon="lucide:log-out" width="18" /></span>
            <div>
              <h2>Leave requested</h2>
              <p>Tenant requested to leave {{ leaveRequestedLease.roomLabel }} · {{ leaveRequestedLease.property }}<template v-if="leaveRequestedLease.leaveRequestedAt"> on {{ formatDate(leaveRequestedLease.leaveRequestedAt) }}</template></p>
            </div>
          </div>
          <div class="decision-actions">
            <q-btn unelevated no-caps class="primary-btn" label="Approve leave" :loading="actingLeave === 'approve'" @click="decideLeave('approve')" />
            <q-btn outline no-caps class="ghost-danger-btn" label="Decline leave" :loading="actingLeave === 'decline'" @click="decideLeave('decline')" />
          </div>
        </section>

        <!-- Tabs (folder-tab design, same as accommodation detail) -->
        <section class="tab-workspace" aria-label="Student sections">
          <q-tabs v-model="activeTab" dense no-caps align="left" class="folder-tabs">
            <q-tab v-for="tab in tabs" :key="tab.value" :name="tab.value" :label="tab.label" class="folder-tab" />
          </q-tabs>

          <q-tab-panels v-model="activeTab" animated class="tab-card">
            <!-- Overview: current stay info -->
            <q-tab-panel name="overview" class="q-pa-none">
              <div v-if="!activeLease && !pendingLease" class="tab-empty">
                <IconifyIcon icon="lucide:house" width="26" />
                <p>No active stay for this student at your property.</p>
              </div>
              <div v-else class="content-stack">
                <div v-if="activeLease" class="inner-card">
                  <p class="list-eyebrow">Current stay</p>
                  <div class="fact-row"><span>Property</span><strong>{{ activeLease.property }}</strong></div>
                  <div class="fact-row"><span>Room</span><strong>{{ activeLease.roomLabel }}<template v-if="activeLease.floor"> · {{ activeLease.floor }}</template></strong></div>
                  <div class="fact-row"><span>Monthly rent</span><strong>{{ formatPeso(activeLease.monthlyRent) }}</strong></div>
                  <div class="fact-row"><span>Lease</span><strong>{{ formatDate(activeLease.startDate) }} – {{ formatDate(activeLease.endDate) }}</strong></div>
                  <div class="fact-row"><span>Advance</span><strong>{{ formatPeso(activeLease.advancePaid) }}</strong></div>
                  <div class="fact-row"><span>Deposit</span><strong>{{ formatPeso(activeLease.depositPaid) }}</strong></div>
                  <div class="fact-row"><span>Rent status</span><strong :class="(activeLease.balanceDue ?? 0) > 0 ? 'tone-danger' : 'tone-ok'">{{ (activeLease.balanceDue ?? 0) > 0 ? 'Has dues' : 'All paid up' }}</strong></div>
                </div>
                <div v-if="pendingLease" class="inner-card">
                  <p class="list-eyebrow">Pending request</p>
                  <div class="fact-row"><span>Room</span><strong>{{ pendingLease.roomLabel }}</strong></div>
                  <div class="fact-row"><span>Property</span><strong>{{ pendingLease.property }}</strong></div>
                  <div class="fact-row"><span>Monthly</span><strong>{{ formatPeso(pendingLease.monthlyRent) }}</strong></div>
                  <div class="fact-row"><span>Move-in</span><strong>{{ formatDate(pendingLease.startDate) }}</strong></div>
                  <div class="fact-row"><span>Term ends</span><strong>{{ formatDate(pendingLease.endDate) }}</strong></div>
                </div>
              </div>
            </q-tab-panel>

            <!-- Payments -->
            <q-tab-panel name="payments" class="q-pa-none">
              <div class="pay-head">
                <div class="pay-summary">
                  <span class="pay-kicker">Rent balance</span>
                  <strong v-if="outstandingTotal > 0" class="pay-amount tone-danger">{{ formatPeso(outstandingTotal) }}</strong>
                  <strong v-else class="pay-amount tone-ok">All settled</strong>
                  <small>{{ payments.length }} {{ payments.length === 1 ? 'record' : 'records' }}</small>
                </div>
                <button type="button" class="log-pay-btn" :disabled="!activeLease" @click="logDialog = true">
                  <IconifyIcon icon="lucide:wallet-cards" width="16" />
                  Log payment
                </button>
              </div>

              <div v-if="!payments.length" class="tab-empty">
                <IconifyIcon icon="lucide:receipt-text" width="26" />
                <p>{{ activeLease ? 'No payments recorded yet.' : 'No active lease for this student.' }}</p>
              </div>

              <div v-else class="content-stack">
                <template v-if="attentionPayments.length">
                  <p class="pay-section-label">Needs attention</p>
                  <div v-for="payment in attentionPayments" :key="payment.id" class="payment-row">
                    <span class="payment-dot" :class="`payment-dot--${payment.tone}`" aria-hidden="true" />
                    <div class="payment-copy">
                      <strong>{{ formatPeso(payment.amount) }}</strong>
                      <span>{{ payment.monthLabel }}</span>
                    </div>
                    <span class="status-chip" :class="`status-chip--${payment.tone}`">{{ payment.label }}</span>
                  </div>
                </template>

                <template v-if="paidPayments.length">
                  <p class="pay-section-label">Recorded payments</p>
                  <div v-for="payment in paidPayments" :key="payment.id" class="payment-row">
                    <span class="payment-dot payment-dot--success" aria-hidden="true"><IconifyIcon icon="lucide:circle-check" width="14" /></span>
                    <div class="payment-copy">
                      <strong>{{ formatPeso(payment.amount) }}</strong>
                      <span>{{ payment.monthLabel }}</span>
                    </div>
                    <span class="status-chip status-chip--success">{{ payment.label }}</span>
                  </div>
                </template>
              </div>
            </q-tab-panel>

            <!-- Boarding history -->
            <q-tab-panel name="history" class="q-pa-none">
              <div class="history-head">
                <div class="history-title">
                  <p class="pay-kicker">Boarding history</p>
                  <strong>{{ pastLeases.length }} past {{ pastLeases.length === 1 ? 'stay' : 'stays' }}</strong>
                </div>
              </div>
              <div v-if="!pastLeases.length" class="tab-empty">
                <IconifyIcon icon="lucide:history" width="26" />
                <p>No past stays at your property yet.</p>
              </div>
              <div v-else class="timeline">
                <div v-for="lease in pastLeases" :key="lease.id" class="timeline-item">
                  <span class="timeline-marker" aria-hidden="true">
                    <span class="timeline-dot" />
                    <span v-if="lease !== pastLeases[pastLeases.length - 1]" class="timeline-line" />
                  </span>
                  <div class="history-card">
                    <div class="history-top">
                      <strong>{{ lease.property }}</strong>
                      <span class="status-chip" :class="historyTone(lease.status)">{{ historyLabel(lease.status) }}</span>
                    </div>
                    <span class="history-room"><IconifyIcon icon="lucide:door-open" width="13" /> {{ lease.roomLabel }}</span>
                    <span class="history-dates"><IconifyIcon icon="lucide:calendar" width="13" /> {{ formatDate(lease.startDate) }} – {{ formatDate(lease.endDate) }}</span>
                  </div>
                </div>
              </div>
            </q-tab-panel>
          </q-tab-panels>
        </section>
      </template>
    <!-- Log payment dialog -->
    <q-dialog v-model="logDialog" position="bottom">
      <q-card class="sheet-card full-width pb-safe">
        <div class="sheet-head">
          <h2>Log payment</h2>
          <q-btn flat round dense icon="close" color="grey-6" v-close-popup aria-label="Close" />
        </div>
        <q-card-section class="sheet-body">
          <p class="field-label">Amount (₱)</p>
          <q-input v-model="logAmount" type="number" outlined dense class="field-input" placeholder="e.g. 2500" />
          <p class="field-label">Method</p>
          <q-select v-model="logMethod" outlined dense class="field-input" bg-color="white" :options="logMethods" emit-value map-options />
          <q-btn unelevated no-caps color="primary" label="Save payment" class="primary-btn full-width" :loading="logging" :disable="!logAmount || Number(logAmount) <= 0 || !logMethod" @click="submitLogPayment" />
        </q-card-section>
      </q-card>
    </q-dialog>
    </main>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute } from 'vue-router'
import { useQuasar } from 'quasar'
import { supabase } from '@/shared/utils/supabase'
import { createNotification } from '@/boot/notify'

interface StayLease {
  id: string
  status: string
  startDate: string | null
  endDate: string | null
  monthlyRent: number
  advancePaid: number
  depositPaid: number
  roomLabel: string
  floor: string | null
  property: string
  accommodationId: string | null
  balanceDue: number
  leaveRequestedAt: string | null
}

const route = useRoute()
const $q = useQuasar()
const loading = ref(true)
const error = ref<string | null>(null)
const acting = ref<'accept' | 'decline' | null>(null)
const actingLeave = ref<'approve' | 'decline' | null>(null)
const logDialog = ref(false)
const logging = ref(false)
const logAmount = ref('')
const logMethod = ref<string | null>(null)
const logMethods = [
  { label: 'GCash', value: 'gcash' },
  { label: 'Maya', value: 'maya' },
  { label: 'Bank transfer', value: 'bank' },
  { label: 'Cash', value: 'cash' },
  { label: 'Other', value: 'others' },
]

const student = ref<{
  name: string; initials: string; studentId: string | null; program: string | null
  college: string | null; yearLevel: string | null; email: string | null; phone: string | null; verified: boolean
} | null>(null)
const leases = ref<StayLease[]>([])
const payments = ref<{ id: string; amount: number; monthLabel: string; label: string; tone: string }[]>([])
const attentionPayments = computed(() => payments.value.filter((p) => p.tone !== 'success'))
const paidPayments = computed(() => payments.value.filter((p) => p.tone === 'success'))
const outstandingTotal = computed(() => attentionPayments.value.reduce((sum, p) => sum + p.amount, 0))

const pendingLease = computed(() => leases.value.find((l) => l.status === 'pending') ?? null)
const leaveRequestedLease = computed(() => leases.value.find((l) => l.status === 'leave_requested') ?? null)
const activeLease = computed(() => leases.value.find((l) => l.status === 'active' || l.status === 'leave_requested') ?? null)
const pastLeases = computed(() => leases.value.filter((l) => !['pending', 'active', 'leave_requested'].includes(l.status)))

const tabs = [
  { value: 'overview', label: 'Overview' },
  { value: 'payments', label: 'Payments' },
  { value: 'history', label: 'Boarding history' },
]
const activeTab = ref('overview')

function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  const first = parts[0] ?? ''
  const last = parts[parts.length - 1] ?? ''
  if (!parts.length) return 'ST'
  if (parts.length === 1) return first.slice(0, 2).toUpperCase()
  return `${first.charAt(0)}${last.charAt(0)}`.toUpperCase()
}
function formatPeso(v: number | null | undefined): string {
  return '₱' + (Number(v) || 0).toLocaleString('en-PH', { maximumFractionDigits: 0 })
}
function formatDate(v: string | null | undefined): string {
  if (!v) return '—'
  const d = new Date(v)
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' })
}
function historyLabel(status: string): string {
  if (status === 'terminated') return 'Terminated'
  if (status === 'leave_requested') return 'Left early'
  return 'Ended'
}
function historyTone(status: string): string {
  if (status === 'terminated') return 'status-chip--danger'
  return 'status-chip--neutral'
}
function monthLabel(month: string | null): string {
  if (!month) return '—'
  const d = new Date(`${month}-01T00:00:00`)
  return Number.isNaN(d.getTime()) ? month : d.toLocaleDateString('en-PH', { month: 'long', year: 'numeric' })
}

async function load() {
  loading.value = true
  error.value = null
  try {
    const studentId = String(route.params.tenantId || '')
    if (!studentId) throw new Error('No student id provided')
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error('Not signed in')

    const [userResult, profileResult, leaseResult, pendingPay] = await Promise.all([
      supabase.from('users').select('full_name, initials, email, phone, status').eq('id', studentId).maybeSingle(),
      supabase.from('student_profiles').select('student_id, program, college, year_level, osas_verified_at').eq('user_id', studentId).maybeSingle(),
      (supabase as any)
        .from('leases')
        .select('id, status, start_date, end_date, monthly_rent, advance_paid, deposit_paid, leave_requested_at, room:rooms(room_number, label, floor, accommodation:accommodations(id, name))')
        .eq('student_id', studentId)
        .eq('accommodation_manager_id', user.id)
        .order('start_date', { ascending: false }),
      supabase.from('payments').select('id, amount, status, month, paid_at').eq('lease_id', user.id).limit(1),
    ])

    const u = userResult.data as { full_name: string | null; initials: string | null; email: string | null; phone: string | null; status: string | null } | null
    const p = profileResult.data as { student_id: string | null; program: string | null; college: string | null; year_level: number | null; osas_verified_at: string | null } | null
    const leaseRows = (leaseResult.data ?? []) as any[]

    const name = u?.full_name || 'Student'
    student.value = {
      name,
      initials: u?.initials || initialsOf(name),
      studentId: p?.student_id ?? null,
      program: p?.program ?? null,
      college: p?.college ?? null,
      yearLevel: p?.year_level ? `${p.year_level}${p.year_level === 1 ? 'st' : p.year_level === 2 ? 'nd' : p.year_level === 3 ? 'rd' : 'th'} Year` : null,
      email: u?.email ?? null,
      phone: u?.phone ?? null,
      verified: Boolean(p?.osas_verified_at),
    }

    leases.value = leaseRows.map((l) => {
      const room = l.room || {}
      return {
        id: l.id,
        status: l.status,
        startDate: l.start_date,
        endDate: l.end_date,
        monthlyRent: Number(l.monthly_rent || 0),
        advancePaid: Number(l.advance_paid || 0),
        depositPaid: Number(l.deposit_paid || 0),
        roomLabel: room.label || (room.room_number ? `Room ${room.room_number}` : 'Room'),
        floor: room.floor || null,
        property: room.accommodation?.name || 'Accommodation',
        accommodationId: room.accommodation?.id ?? null,
        balanceDue: 0,
        leaveRequestedAt: l.leave_requested_at ?? null,
      }
    })

    const active = leases.value.find((l) => l.status === 'active' || l.status === 'leave_requested')
    if (active) {
      const { data: payRows } = await supabase
        .from('payments')
        .select('id, amount, status, month, paid_at')
        .eq('lease_id', active.id)
        .order('month', { ascending: true })
      const tone = { overdue: 'danger', due: 'warning', pending_verification: 'warning', paid: 'success' } as Record<string, string>
      const label = { overdue: 'Overdue', due: 'Due', pending_verification: 'Pending review', paid: 'Paid' } as Record<string, string>
      payments.value = ((payRows ?? []) as any[]).map((pay) => ({
        id: pay.id,
        amount: Number(pay.amount || 0),
        monthLabel: monthLabel(pay.month),
        label: label[pay.status] || pay.status || '—',
        tone: tone[pay.status] || 'neutral',
      }))
    } else {
      payments.value = []
    }
  } catch (caught) {
    error.value = caught instanceof Error ? caught.message : 'Failed to load student'
  } finally {
    loading.value = false
  }
}

async function submitLogPayment() {
  const lease = activeLease.value
  const amount = Number(logAmount.value)
  if (!lease || !logMethod.value || !amount || amount <= 0 || logging.value) return
  logging.value = true
  try {
    const now = new Date()
    // payments.month is a DATE column (not a text 'YYYY-MM'), so send the first
    // of the month — 'YYYY-MM-01' — otherwise PostgREST rejects it (400).
    const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
    const { data: { user } } = await supabase.auth.getUser()
    const { error } = await (supabase as any).from('payments').insert({
      lease_id: lease.id,
      amount,
      month,
      method: logMethod.value,
      status: 'paid',
      paid_at: now.toISOString(),
      verified_by: user?.id ?? null,
      description: 'Logged by manager',
    })
    if (error) throw error
    logDialog.value = false
    logAmount.value = ''
    $q.notify({ type: 'positive', message: 'Payment logged.' })
    const studentUserId = String(route.params.tenantId || '')
    try {
      await createNotification(studentUserId, 'Payment received', `We recorded your ${formatPeso(amount)} rent payment. Thanks!`, 'payment', '/student/payments')
    } catch { /* notifications are non-critical */ }
    await load()
  } catch (cause) {
    $q.notify({ type: 'negative', message: cause instanceof Error ? cause.message : 'Could not log payment' })
  } finally {
    logging.value = false
  }
}

async function decide(action: 'accept' | 'decline') {
  const lease = pendingLease.value
  if (!lease || acting.value) return
  acting.value = action
  try {
    const { error: err } = await (supabase as any)
      .from('leases')
      .update({ status: action === 'accept' ? 'active' : 'ended' })
      .eq('id', lease.id)
    if (err) throw err
    $q.notify({ type: 'positive', message: action === 'accept' ? 'Application accepted — lease is active.' : 'Application declined.' })
    const studentUserId = String(route.params.tenantId || '')
    try {
      await createNotification(
        studentUserId,
        action === 'accept' ? 'Application accepted 🎉' : 'Application declined',
        action === 'accept' ? 'Your room application was approved — your lease is now active.' : 'Your room application was declined by the manager.',
        'application',
        action === 'accept' ? '/student/stay' : '/student/discover',
      )
    } catch { /* notifications are non-critical */ }
    await load()
  } catch (cause) {
    $q.notify({ type: 'negative', message: cause instanceof Error ? cause.message : 'Update failed' })
  } finally {
    acting.value = null
  }
}

async function decideLeave(action: 'approve' | 'decline') {
  const lease = leaveRequestedLease.value
  if (!lease || actingLeave.value) return
  actingLeave.value = action
  try {
    const studentUserId = String(route.params.tenantId || '')
    const now = new Date()
    if (action === 'approve') {
      const { error: err } = await (supabase as any)
        .from('leases')
        .update({
          status: 'ended',
          ended_reason: 'leave_approved',
          end_date: now.toISOString().split('T')[0],
        })
        .eq('id', lease.id)
      if (err) throw err

      // boarding_history.accommodation_id is NOT NULL, and RLS requires the
      // caller to manage that accommodation — skip if we somehow lack the id
      // rather than firing a guaranteed-failing insert.
      if (lease.accommodationId) {
        try {
          await (supabase as any).from('boarding_history').insert({
            student_id: studentUserId,
            accommodation_id: lease.accommodationId,
            accommodation_name: lease.property,
            period_start: lease.startDate || now.toISOString(),
            period_end: now.toISOString(),
            room_type: lease.roomLabel,
            end_reason: 'leave_approved',
          })
        } catch { /* non-critical */ }
      }

      $q.notify({ type: 'positive', message: 'Leave request approved. Lease has ended.' })
      try {
        await createNotification(
          studentUserId,
          'Leave request approved',
          `Your leave request for ${lease.roomLabel} at ${lease.property} was approved by the manager. Your stay has ended.`,
          'leave',
          '/student/stay',
        )
      } catch { /* non-critical */ }
    } else {
      const { error: err } = await (supabase as any)
        .from('leases')
        .update({
          status: 'active',
          leave_requested_at: null,
        })
        .eq('id', lease.id)
      if (err) throw err

      $q.notify({ type: 'warning', message: 'Leave request declined.' })
      try {
        await createNotification(
          studentUserId,
          'Leave request declined',
          `Your leave request for ${lease.roomLabel} at ${lease.property} was declined. Please contact your manager for details.`,
          'leave',
          '/student/stay',
        )
      } catch { /* non-critical */ }
    }
    await load()
  } catch (cause) {
    $q.notify({ type: 'negative', message: cause instanceof Error ? cause.message : 'Action failed' })
  } finally {
    actingLeave.value = null
  }
}

onMounted(() => void load())
</script>

<style scoped>
.student-detail-page { min-height: 100%; background: var(--m-bg); color: var(--m-text); }
.detail-shell { width: min(100%, 760px); margin: 0 auto; padding: var(--m-space-3) var(--m-page-gutter) var(--m-space-8); }
.detail-state { display: grid; min-height: 40vh; place-items: center; align-content: center; gap: 10px; color: var(--m-muted); text-align: center; }
.detail-state--error { color: var(--m-danger); }
.surface-card { border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }

/* Profile hero */
.profile-card { margin-bottom: var(--m-space-4); padding: var(--m-space-5); }
.profile-hero { display: flex; align-items: center; gap: var(--m-space-4); }
.profile-avatar-wrap { position: relative; }
.profile-avatar { display: grid; width: 76px; height: 76px; place-items: center; border-radius: 50%; background: linear-gradient(135deg, var(--m-primary-dark), var(--m-primary)); color: #fff; font-family: var(--m-font-display); font-size: 26px; font-weight: 800; box-shadow: 0 0 0 3px var(--m-surface), 0 0 0 5px var(--m-primary-soft); }
.profile-headline { min-width: 0; flex: 1; }
.profile-headline h1 { margin: 0; color: var(--m-ink); font-family: var(--m-font-display); font-size: 21px; font-weight: 800; letter-spacing: -0.02em; line-height: 1.15; overflow-wrap: anywhere; }
.profile-headline p { margin: 3px 0 8px; color: var(--m-muted); font-size: 12px; }
.verified-pill { display: inline-flex; min-height: 24px; align-items: center; gap: 5px; padding: 0 9px; border-radius: 999px; font-size: 11px; font-weight: 750; background: var(--m-warning-soft); color: var(--m-warning); }
.verified-pill--on { background: var(--m-success-soft); color: var(--m-success); }
.profile-info { display: grid; gap: 0; margin: var(--m-space-4) 0 0; padding: 0; list-style: none; border-top: 1px solid var(--m-border); }
.profile-info li { display: flex; align-items: center; gap: var(--m-space-3); padding: 11px 2px; }
.profile-info li + li { border-top: 1px solid var(--m-border); }
.info-icon { display: grid; width: 32px; height: 32px; flex: 0 0 auto; place-items: center; border-radius: 8px; background: var(--m-bg); color: var(--m-primary-dark); }
.profile-info li > div { display: flex; min-width: 0; flex-direction: column; }
.profile-info small { color: var(--m-muted); font-size: 9px; font-weight: 800; text-transform: uppercase; letter-spacing: .06em; }
.profile-info strong { color: var(--m-ink); font-size: 13px; margin-top: 1px; overflow-wrap: anywhere; }

.decision-card { margin-bottom: var(--m-space-4); padding: var(--m-space-4); border-color: color-mix(in srgb, var(--m-warning) 30%, var(--m-border)); background: var(--m-warning-soft); }
.decision-head { display: flex; align-items: flex-start; gap: var(--m-space-3); }
.decision-icon { display: grid; width: 36px; height: 36px; flex: 0 0 auto; place-items: center; border-radius: 9px; background: var(--m-surface); color: var(--m-warning); }
.decision-head h2 { margin: 0; color: var(--m-ink); font-size: 15px; font-weight: 800; }
.decision-head p { margin: 3px 0 0; color: var(--m-muted); font-size: 12px; }
.decision-actions { display: grid; grid-template-columns: 1fr auto; gap: var(--m-space-2); margin-top: var(--m-space-4); }
.primary-btn { border-radius: var(--m-radius-sm); background: var(--m-primary-dark); }
.ghost-danger-btn { border-radius: var(--m-radius-sm); color: var(--m-danger); }

.stay-card { margin-bottom: var(--m-space-4); padding: var(--m-space-4); }
.stay-top { display: flex; align-items: center; gap: var(--m-space-3); }
.stay-icon { display: grid; width: 40px; height: 40px; flex: 0 0 auto; place-items: center; border-radius: 10px; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.stay-copy { min-width: 0; flex: 1; }
.stay-copy h2 { margin: 0; color: var(--m-ink); font-size: 16px; font-weight: 800; }
.stay-copy p { margin: 2px 0 0; color: var(--m-muted); font-size: 12px; }
.stay-badge { flex: 0 0 auto; min-height: 22px; padding: 0 9px; border-radius: 999px; background: var(--m-success-soft); color: var(--m-success); font-size: 11px; font-weight: 800; }
.stay-meta { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: var(--m-space-2); margin-top: var(--m-space-4); }
.stay-meta > div { min-width: 0; padding: 10px; border-radius: 8px; background: var(--m-bg); }
.stay-meta span { display: block; color: var(--m-muted); font-size: 9px; font-weight: 800; text-transform: uppercase; letter-spacing: .05em; }
.stay-meta strong { display: block; margin-top: 3px; color: var(--m-ink); font-size: 11px; overflow-wrap: anywhere; }
.tone-danger { color: var(--m-danger); }
.tone-ok { color: var(--m-success); }

/* Folder-tab design (same as accommodation detail) */
.tab-workspace { margin: 0 calc(-1 * var(--m-page-gutter)) !important; padding: 0 !important; }
.tab-workspace :deep(.q-tabs) { margin: 0 !important; box-shadow: none; }
.folder-tabs { margin: 0 !important; }
.tab-card { margin: 0 !important; }
.tab-card :deep(.q-tab-panel) { margin: 0 !important; }

.tab-workspace { margin: 0; padding: 0; }
.folder-tabs { margin: 0; }
.tab-card { margin: 0; }
.folder-tabs { position: relative; z-index: 1; min-height: 42px; padding: 0 8px; overflow: visible; background: transparent; }
.folder-tabs :deep(.q-tabs__content) { justify-content: flex-start; flex-wrap: nowrap; overflow: visible; }
.folder-tabs :deep(.folder-tab) { min-width: max-content; min-height: 42px; margin-right: 4px; padding: 0 16px; border: 1px solid var(--m-border); border-bottom: 0; border-radius: 11px 11px 0 0; background: var(--m-bg); color: var(--m-muted); font-size: 12px; font-weight: 750; }
.folder-tabs :deep(.folder-tab.q-tab--active) { z-index: 2; margin-bottom: -1px; position: relative; border-bottom: 1px solid var(--m-surface); background: var(--m-surface); color: var(--m-primary-dark); }
.folder-tabs :deep(.folder-tab.q-tab--active)::after { position: absolute; right: 0; bottom: -1px; left: 0; height: 2px; content: ''; background: var(--m-surface); }
.folder-tabs :deep(.q-tab__indicator) { display: none; }
.tab-card { overflow: hidden; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }
.tab-card :deep(.q-tab-panel) { padding: 0; }
.tab-empty { display: flex; align-items: center; flex-direction: column; gap: 8px; padding: var(--m-space-8); color: var(--m-muted); text-align: center; }
.tab-empty p { margin: 0; font-size: 13px; }
.content-stack { display: grid; gap: 12px; padding: var(--m-space-3); }
.inner-card { overflow: hidden; border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); }
.list-card { overflow: hidden; margin-bottom: var(--m-space-3); }
.list-eyebrow { margin: 0; padding: var(--m-space-3) var(--m-space-4); border-bottom: 1px solid var(--m-border); color: var(--m-muted); font-size: 10px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; }
.fact-row { display: flex; align-items: center; justify-content: space-between; gap: var(--m-space-3); padding: 12px var(--m-space-4); }
.fact-row + .fact-row { border-top: 1px solid var(--m-border); }
.fact-row span { color: var(--m-muted); font-size: 12px; }
.fact-row strong { color: var(--m-ink); font-size: 13px; text-align: right; overflow-wrap: anywhere; }

.past-row { padding: 12px var(--m-space-4); }
.past-row + .past-row { border-top: 1px solid var(--m-border); }
.past-row strong { display: block; color: var(--m-ink); font-size: 13px; }
.past-row span { display: block; margin-top: 2px; color: var(--m-muted); font-size: 12px; }

.payment-row { display: flex; align-items: center; gap: var(--m-space-3); margin: 0 var(--m-space-3); padding: var(--m-space-3) var(--m-space-3); border-bottom: 1px solid var(--m-border); }
.payment-row:last-child { border-bottom: 0; }
.payment-dot { display: grid; width: 28px; height: 28px; place-items: center; border-radius: 50%; flex: 0 0 auto; background: var(--m-bg); color: var(--m-muted); }
.payment-dot--success { background: var(--m-success-soft); color: var(--m-success); }
.payment-dot--warning { background: var(--m-warning-soft); color: var(--m-warning); }
.payment-dot--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.payment-dot--neutral { background: var(--m-bg); color: var(--m-muted); }
.payment-dot svg { display: none; }
.payment-dot--success svg { display: inline; }
.payment-dot { width: 10px; height: 10px; border-radius: 50%; flex: 0 0 auto; }
.payment-dot--success { background: var(--m-success); }
.payment-dot--warning { background: var(--m-warning); }
.payment-dot--danger { background: var(--m-danger); }
.payment-dot--neutral { background: var(--m-muted); }
.payment-copy { display: flex; min-width: 0; flex: 1; flex-direction: column; }
.payment-copy strong { color: var(--m-ink); font-size: 14px; }
.payment-copy span { color: var(--m-muted); font-size: 11px; }
.status-chip { flex: 0 0 auto; min-height: 22px; padding: 0 9px; border-radius: 999px; font-size: 11px; font-weight: 750; }
.status-chip--success { background: var(--m-success-soft); color: var(--m-success); }
.status-chip--warning { background: var(--m-warning-soft); color: var(--m-warning); }
.status-chip--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.status-chip--neutral { background: var(--m-bg); color: var(--m-muted); }

/* student info + log payment */
.identity-top { display: flex; align-items: center; gap: var(--m-space-4); }
.profile-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0 12px; margin-top: var(--m-space-4); border-top: 1px solid var(--m-border); padding-top: var(--m-space-3); }
.profile-grid > div { min-width: 0; padding: 6px 0; }
.profile-grid span { display: block; color: var(--m-muted); font-size: 9px; font-weight: 800; text-transform: uppercase; letter-spacing: .05em; }
.profile-grid strong { display: block; margin-top: 2px; color: var(--m-ink); font-size: 12px; overflow-wrap: anywhere; }
/* Payments panel */
.pay-head { display: flex; align-items: center; justify-content: space-between; gap: var(--m-space-3); padding: var(--m-space-3); border-bottom: 1px solid var(--m-border); }
.pay-summary { display: flex; flex-direction: column; }
.pay-kicker { color: var(--m-muted); font-size: 9px; font-weight: 800; text-transform: uppercase; letter-spacing: .07em; }
.pay-amount { font-family: var(--m-font-display); font-size: 22px; font-weight: 800; letter-spacing: -0.02em; }
.pay-summary small { color: var(--m-muted); font-size: 11px; }
.log-pay-btn { display: inline-flex; min-height: 40px; align-items: center; gap: 7px; padding: 0 14px; border: 0; border-radius: var(--m-radius-sm); background: var(--m-primary-dark); color: #fff; font: inherit; font-size: 12px; font-weight: 800; cursor: pointer; }
.log-pay-btn:disabled { opacity: .5; cursor: default; }
.pay-section-label { margin: var(--m-space-3) var(--m-space-3) 0; color: var(--m-muted); font-size: 10px; font-weight: 800; text-transform: uppercase; letter-spacing: .06em; }
.pay-section-label + .payment-row { margin-top: 6px; }

.sheet-card { grid-column: 1 / -1; border: 0; border-radius: 18px 18px 0 0; background: var(--m-surface); }
.sheet-head { display: flex; align-items: center; justify-content: space-between; padding: 18px 20px 6px; }
.sheet-head h2 { margin: 0; font-size: 17px; color: var(--m-ink); }
.sheet-body { display: flex; flex-direction: column; gap: 6px; padding: 8px 20px 24px; }
.field-label { margin: 6px 0 0; color: var(--m-muted); font-size: 12px; }
.field-input { width: 100%; }
.full-width { width: 100%; }


/* Boarding history timeline */
.history-head { display: flex; align-items: center; justify-content: space-between; padding: 14px var(--m-space-4); border-bottom: 1px solid var(--m-border); }
.history-title { display: flex; flex-direction: column; }
.history-title strong { color: var(--m-ink); font-family: var(--m-font-display); font-size: 16px; font-weight: 800; }
.timeline { padding: var(--m-space-4); }
.timeline-item { display: flex; }
.timeline-marker { display: flex; flex-direction: column; align-items: center; margin-right: 12px; }
.timeline-dot { width: 10px; height: 10px; margin-top: 5px; border-radius: 50%; background: var(--m-primary); box-shadow: 0 0 0 3px var(--m-primary-soft); }
.timeline-line { width: 2px; flex: 1; background: var(--m-border); margin: 4px 0; }
.history-card { flex: 1; min-width: 0; margin-bottom: 14px; padding: 12px; border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); }
.history-top { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.history-top strong { color: var(--m-ink); font-size: 14px; font-weight: 700; }
.history-room, .history-dates { display: flex; align-items: center; gap: 6px; margin-top: 6px; color: var(--m-muted); font-size: 12px; }
.history-dates { margin-top: 3px; }

</style>
