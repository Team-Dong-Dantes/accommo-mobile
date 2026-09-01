<template>
  <q-page class="dashboard-page">
    <main class="dashboard-shell" aria-label="Student dashboard">
      <template v-if="loading">
        <div class="dashboard-skeleton" role="status" aria-live="polite" aria-label="Loading your stay dashboard">
          <q-skeleton class="skeleton-panel" height="210px" />
          <q-skeleton class="skeleton-panel" height="250px" />
          <div class="skeleton-actions">
            <q-skeleton v-for="item in 3" :key="item" height="88px" />
          </div>
          <span class="sr-only">Loading your stay dashboard</span>
        </div>
      </template>

      <template v-else-if="error">
        <section class="state-card error-state" role="alert" aria-labelledby="dashboard-error-title">
          <span class="state-icon state-icon--danger" aria-hidden="true">
            <IconifyIcon icon="lucide:circle-alert" width="25" />
          </span>
          <h1 id="dashboard-error-title">We couldn't load your dashboard</h1>
          <p>{{ error }}</p>
          <q-btn unelevated no-caps class="primary-button" :loading="loading" @click="loadDashboard">
            <IconifyIcon icon="lucide:refresh-cw" width="18" />
            <span>Try again</span>
          </q-btn>
        </section>
      </template>

      <template v-else>
        <template v-if="!lease">
          <section class="state-card empty-state" aria-labelledby="empty-stay-title">
            <span class="state-icon" aria-hidden="true">
              <IconifyIcon icon="lucide:bed-double" width="27" />
            </span>
            <p class="eyebrow">Your stay</p>
            <h2 id="empty-stay-title">No active stay yet</h2>
            <p>Browse verified accommodations and find a room that fits your needs.</p>
            <q-btn unelevated no-caps class="primary-button full-width" @click="goToDiscover">
              <IconifyIcon icon="lucide:search" width="18" />
              <span>Discover accommodations</span>
            </q-btn>
          </section>

          <section v-if="showVerificationPrompt" class="verification-prompt" aria-labelledby="verification-title">
            <span class="verification-icon" aria-hidden="true">
              <IconifyIcon :icon="verificationPending ? 'lucide:clock-3' : 'lucide:badge-check'" width="22" />
            </span>
            <div>
              <h2 id="verification-title">{{ verificationPending ? 'OSAS verification is in review' : 'Verify your enrollment with OSAS' }}</h2>
              <p>{{ verificationPending ? 'You can track your submitted documents from your profile.' : 'Verification helps accommodation managers confirm your student status.' }}</p>
            </div>
            <q-btn flat no-caps class="text-button" @click="goToProfile">{{ verificationPending ? 'View status' : 'Verify now' }}</q-btn>
          </section>
        </template>

        <template v-else>
          <section class="payment-panel" :class="`payment-panel--${paymentTone}`" aria-labelledby="payment-heading">
            <div class="payment-topline">
              <span class="payment-icon" aria-hidden="true">
                <IconifyIcon :icon="paymentIcon" width="22" />
              </span>
              <span class="status-pill">{{ paymentStatus }}</span>
            </div>
            <p class="eyebrow">Next payment</p>
            <h2 id="payment-heading">{{ paymentHeading }}</h2>
            <p class="payment-amount">{{ paymentAmount }}</p>
            <p class="payment-detail">{{ paymentDetail }}</p>
            <q-btn v-if="paymentActionable" unelevated no-caps class="primary-button full-width payment-cta" @click="goToPayments">
              <IconifyIcon icon="lucide:wallet-cards" width="18" />
              <span>Pay now</span>
            </q-btn>
          </section>

          <section class="surface-card stay-card" aria-labelledby="stay-heading">
            <div class="section-heading">
              <div>
                <p class="eyebrow">Current stay</p>
                <h2 id="stay-heading">{{ accommodationName }}</h2>
                <p class="stay-room"><IconifyIcon icon="lucide:door-open" width="16" /> {{ roomLabel }}</p>
              </div>
              <q-btn outline no-caps class="secondary-button" @click="goToStay">View stay</q-btn>
            </div>

            <div class="stay-metrics">
              <div>
                <span>Lease period</span>
                <strong>{{ leaseDateRange }}</strong>
              </div>
              <div>
                <span>Time remaining</span>
                <strong>{{ daysLeftLabel }}</strong>
              </div>
            </div>

            <div v-if="hasLeaseTimeline" class="progress-block">
              <div class="progress-label">
                <span>Lease progress</span>
                <span>{{ leaseProgressPercent }}%</span>
              </div>
              <q-linear-progress :value="leaseProgress" rounded size="7px" color="teal-7" track-color="grey-3" />
            </div>

            <div class="stay-footer">
              <span class="monthly-rent"><IconifyIcon icon="lucide:receipt-text" width="16" /> {{ monthlyRent }} monthly</span>
              <button type="button" class="tertiary-action" @click="requestLeave">
                <IconifyIcon icon="lucide:log-out" width="16" />
                Request to leave
              </button>
            </div>
          </section>

          <section aria-labelledby="quick-actions-heading">
            <div class="section-title-row">
              <h2 id="quick-actions-heading">Quick actions</h2>
            </div>
            <div class="quick-actions">
              <button type="button" @click="goToMessages">
                <span class="action-icon"><IconifyIcon icon="lucide:message-circle" width="21" /></span>
                <span>Message manager</span>
              </button>
              <button type="button" @click="goToConcerns">
                <span class="action-icon"><IconifyIcon icon="lucide:triangle-alert" width="21" /></span>
                <span>Report concern</span>
              </button>
              <button type="button" @click="goToPayments">
                <span class="action-icon"><IconifyIcon icon="lucide:wallet-cards" width="21" /></span>
                <span>Payments</span>
              </button>
            </div>
          </section>

          <section v-if="showReviewCard" class="surface-card review-card" aria-labelledby="review-heading">
            <span class="review-icon" aria-hidden="true"><IconifyIcon icon="lucide:star" width="21" /></span>
            <div>
              <p class="eyebrow">Stay feedback</p>
              <h2 id="review-heading">{{ reviewUnlocked ? 'Your review is unlocked' : 'Review available soon' }}</h2>
              <p>{{ reviewUnlockText }}</p>
            </div>
          </section>

          <section class="surface-card manager-card" aria-labelledby="manager-heading">
            <q-avatar size="42px" class="manager-avatar" aria-hidden="true">{{ managerInitials }}</q-avatar>
            <div class="manager-copy">
              <p class="eyebrow">Accommodation manager</p>
              <h2 id="manager-heading">{{ managerName || 'Manager details unavailable' }}</h2>
              <p>{{ accommodationName }}</p>
            </div>
            <q-btn v-if="managerId" flat round class="manager-message" aria-label="Message accommodation manager" @click="goToMessages">
              <IconifyIcon icon="lucide:message-circle" width="21" />
            </q-btn>
          </section>
        </template>
      </template>
    </main>

    <q-dialog v-model="leaveDialog" persistent transition-show="scale" transition-hide="scale">
      <q-card class="leave-dialog" role="dialog" aria-labelledby="leave-dialog-title" aria-describedby="leave-dialog-description">
        <q-card-section class="dialog-heading">
          <span class="dialog-icon" aria-hidden="true"><IconifyIcon icon="lucide:log-out" width="21" /></span>
          <div>
            <h2 id="leave-dialog-title">Request to leave?</h2>
            <p id="leave-dialog-description">Your accommodation manager will be notified. Your stay remains active until they confirm the request.</p>
          </div>
        </q-card-section>
        <q-card-actions align="right" class="dialog-actions">
          <q-btn flat no-caps label="Cancel" class="dialog-button" :disable="leaving" v-close-popup />
          <q-btn unelevated no-caps label="Request leave" class="danger-button dialog-button" :loading="leaving" @click="confirmLeave" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useQuasar } from 'quasar'
import { useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'

interface AccommodationRow {
  id: string
  name: string | null
  business_name: string | null
}

interface LeaseRow {
  id: string
  status: string
  start_date: string | null
  end_date: string | null
  monthly_rent: number | null
  room_id: string | null
  accommodation_manager_id: string | null
  room: {
    room_number: string | null
    accommodation_id: string | null
    accommodation: AccommodationRow | null
  } | null
}

interface PaymentRow {
  amount: number
  status: string
  month: string | null
  description: string | null
}

interface StudentProfileRow {
  osas_verified_at: string | null
  school_id_url: string | null
  assessment_of_fees_url: string | null
}

const router = useRouter()
const $q = useQuasar()

const loading = ref(true)
const error = ref<string | null>(null)
const lease = ref<LeaseRow | null>(null)
const nextPayment = ref<PaymentRow | null>(null)
const managerName = ref('')
const managerId = ref<string | null>(null)
const osasVerified = ref(false)
const verificationPending = ref(false)
const leaveDialog = ref(false)
const leaving = ref(false)

function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return 'ST'
  if (parts.length === 1) return (parts[0] ?? 'ST').slice(0, 2).toUpperCase()
  return `${parts[0]?.[0] ?? ''}${parts.at(-1)?.[0] ?? ''}`.toUpperCase()
}

const managerInitials = computed(() => managerName.value ? initialsOf(managerName.value) : 'AM')

const accommodationName = computed(() => lease.value?.room?.accommodation?.name ?? 'Your accommodation')
const roomLabel = computed(() => lease.value?.room?.room_number ? `Room ${lease.value.room.room_number}` : 'Room not assigned')
const monthlyRent = computed(() => formatPeso(lease.value?.monthly_rent ?? 0))
const hasLeaseTimeline = computed(() => Boolean(lease.value?.start_date && lease.value?.end_date))

const leaseProgress = computed(() => {
  if (!lease.value?.start_date || !lease.value.end_date) return 0
  const start = new Date(lease.value.start_date).getTime()
  const end = new Date(lease.value.end_date).getTime()
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return 0
  return Math.min(1, Math.max(0, (Date.now() - start) / (end - start)))
})

const leaseProgressPercent = computed(() => Math.round(leaseProgress.value * 100))
const leaseDateRange = computed(() => {
  if (!lease.value?.start_date || !lease.value.end_date) return 'Dates unavailable'
  return `${formatDate(lease.value.start_date)} – ${formatDate(lease.value.end_date)}`
})
const daysLeftLabel = computed(() => {
  if (!lease.value?.end_date) return 'Not available'
  const days = Math.ceil((new Date(lease.value.end_date).getTime() - Date.now()) / 86400000)
  if (days < 0) return 'Lease ended'
  if (days === 0) return 'Ends today'
  return `${days} day${days === 1 ? '' : 's'} left`
})

const paymentActionable = computed(() => ['due', 'overdue'].includes(nextPayment.value?.status ?? ''))
const paymentTone = computed(() => {
  if (!nextPayment.value) return 'success'
  if (nextPayment.value.status === 'overdue') return 'danger'
  if (nextPayment.value.status === 'pending_verification') return 'info'
  return 'warning'
})
const paymentIcon = computed(() => ({
  danger: 'lucide:circle-alert',
  warning: 'lucide:calendar-clock',
  info: 'lucide:clock-3',
  success: 'lucide:circle-check',
}[paymentTone.value] ?? 'lucide:wallet-cards'))
const paymentStatus = computed(() => {
  if (!nextPayment.value) return 'Up to date'
  if (nextPayment.value.status === 'overdue') return 'Overdue'
  if (nextPayment.value.status === 'pending_verification') return 'Pending verification'
  return 'Due'
})
const paymentHeading = computed(() => {
  if (!nextPayment.value) return 'No payment due'
  if (nextPayment.value.status === 'pending_verification') return 'Payment is being verified'
  const days = daysUntilDue(nextPayment.value.month)
  if (nextPayment.value.status === 'overdue' || (days !== null && days < 0)) return 'Rent payment overdue'
  if (days === 0) return 'Rent is due today'
  if (days !== null) return `Rent due in ${days} day${days === 1 ? '' : 's'}`
  return 'Rent payment due'
})
const paymentAmount = computed(() => formatPeso(nextPayment.value?.amount ?? 0))
const paymentDetail = computed(() => {
  if (!nextPayment.value) return 'You have no outstanding rent payments.'
  const details = [nextPayment.value.month ? formatMonth(nextPayment.value.month) : null, nextPayment.value.description]
  return details.filter((item): item is string => Boolean(item)).join(' · ') || 'View payments for details.'
})

const monthsElapsed = computed(() => {
  if (!lease.value?.start_date) return 0
  return Math.max(0, (Date.now() - new Date(lease.value.start_date).getTime()) / (30.4375 * 86400000))
})
const monthsUntilReview = computed(() => Math.max(0, 6 - monthsElapsed.value))
const reviewUnlocked = computed(() => monthsUntilReview.value <= 0)
const showReviewCard = computed(() => reviewUnlocked.value || monthsUntilReview.value <= 1)
const reviewUnlockText = computed(() => reviewUnlocked.value
  ? 'Share feedback to help OSAS monitor accommodation standards.'
  : 'Available after six months of your stay — less than one month to go.')

const showVerificationPrompt = computed(() => !osasVerified.value)

function formatPeso(amount: number): string {
  return `₱${amount.toLocaleString('en-PH', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
}

function parseDate(value: string): Date {
  const normalized = /^\d{4}-\d{2}$/.test(value) ? `${value}-01T00:00:00` : value
  return new Date(normalized)
}

function formatDate(value: string): string {
  const date = parseDate(value)
  if (!Number.isFinite(date.getTime())) return '—'
  return date.toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' })
}

function formatMonth(value: string): string {
  const date = parseDate(value)
  if (!Number.isFinite(date.getTime())) return 'Date unavailable'
  return date.toLocaleDateString('en-PH', { month: 'long', year: 'numeric' })
}

function daysUntilDue(month: string | null): number | null {
  if (!month) return null
  const due = parseDate(month)
  if (!Number.isFinite(due.getTime())) return null
  return Math.ceil((due.getTime() - Date.now()) / 86400000)
}

async function loadDashboard() {
  loading.value = true
  error.value = null
  lease.value = null
  nextPayment.value = null
  managerName.value = ''
  managerId.value = null

  try {
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError) throw authError
    if (!user) {
      await router.push('/login')
      return
    }

    const metadata = user.user_metadata as Record<string, unknown> | undefined
    const metadataName = typeof metadata?.full_name === 'string' ? metadata.full_name : null
    const [userResult, profileResult, leaseResult] = await Promise.all([
      supabase.from('users').select('full_name').eq('id', user.id).maybeSingle(),
      supabase.from('student_profiles')
        .select('osas_verified_at, school_id_url, assessment_of_fees_url')
        .eq('user_id', user.id)
        .maybeSingle(),
      (supabase as any).from('leases')
        .select('id, status, start_date, end_date, monthly_rent, room_id, accommodation_manager_id, room:rooms(room_number, accommodation_id, accommodation:accommodations(id, name, business_name))')
        .eq('student_id', user.id)
        .eq('status', 'active')
        .maybeSingle(),
    ])

    if (userResult.error) throw userResult.error
    if (profileResult.error) throw profileResult.error
    if (leaseResult.error) throw leaseResult.error

    const profile = profileResult.data as StudentProfileRow | null
    osasVerified.value = Boolean(profile?.osas_verified_at)
    verificationPending.value = !profile?.osas_verified_at && Boolean(profile?.school_id_url || profile?.assessment_of_fees_url)

    if (!leaseResult.data) return
    lease.value = leaseResult.data as LeaseRow
    managerId.value = lease.value.accommodation_manager_id ?? null

    if (managerId.value) {
      const { data: manager, error: managerError } = await supabase
        .from('users')
        .select('full_name')
        .eq('id', managerId.value)
        .maybeSingle()
      if (managerError) throw managerError
      const managerFullName = (manager as { full_name: string | null } | null)?.full_name
      managerName.value = lease.value.room?.accommodation?.business_name || managerFullName || 'Accommodation manager'
    }

    const { data: paymentData, error: paymentError } = await supabase
      .from('payments')
      .select('amount, status, month, description')
      .eq('lease_id', lease.value.id)
      .in('status', ['due', 'overdue', 'pending_verification'])
      .order('month', { ascending: true })
      .limit(1)
      .maybeSingle()
    if (paymentError) throw paymentError
    nextPayment.value = paymentData as PaymentRow | null
  } catch (caught) {
    error.value = caught instanceof Error ? caught.message : 'Something went wrong while loading your stay. Please try again.'
  } finally {
    loading.value = false
  }
}

function goToPayments() { void router.push('/student/payments') }
function goToDiscover() { void router.push('/student/discover') }
function goToStay() { void router.push('/student/stay') }
function goToConcerns() { void router.push('/student/concerns') }
function goToProfile() { void router.push('/student/profile') }
function goToMessages() {
  const query = managerId.value ? { landlord: managerId.value } : {}
  void router.push({ path: '/student/messages', query })
}

function requestLeave() {
  if (!lease.value?.id) {
    $q.notify({ message: 'No active lease to leave.', color: 'warning', position: 'top' })
    return
  }
  leaveDialog.value = true
}

async function confirmLeave() {
  if (!lease.value?.id) return
  leaving.value = true
  try {
    const { error: leaveError } = await supabase
      .from('leases')
      .update({ status: 'leave_requested', leave_requested_at: new Date().toISOString() })
      .eq('id', lease.value.id)
    if (leaveError) throw leaveError
    leaveDialog.value = false
    $q.notify({ message: 'Leave request sent to your accommodation manager.', color: 'teal-8', position: 'top' })
    await loadDashboard()
  } catch (caught) {
    $q.notify({ message: caught instanceof Error ? caught.message : 'Failed to request leave', color: 'negative', position: 'top' })
  } finally {
    leaving.value = false
  }
}

onMounted(loadDashboard)
</script>

<style scoped>
.dashboard-page {
  min-height: 100%;
  background: var(--m-bg);
  color: var(--m-text);
}

.dashboard-shell {
  width: min(100%, 760px);
  margin: 0 auto;
  padding: max(var(--m-space-3), env(safe-area-inset-top)) max(var(--m-page-gutter), env(safe-area-inset-right)) calc(var(--m-space-8) + env(safe-area-inset-bottom)) max(var(--m-page-gutter), env(safe-area-inset-left));
}

.surface-card,
.payment-panel,
.state-card,
.verification-prompt {
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
}

.payment-panel {
  margin-bottom: var(--m-space-4);
  padding: var(--m-space-5);
  border-color: color-mix(in srgb, var(--panel-color) 22%, var(--m-border));
  background: var(--panel-soft);
}

.payment-panel--danger { --panel-color: var(--m-danger); --panel-soft: var(--m-danger-soft); }
.payment-panel--warning { --panel-color: var(--m-warning); --panel-soft: var(--m-warning-soft); }
.payment-panel--info { --panel-color: var(--m-info); --panel-soft: var(--m-info-soft); }
.payment-panel--success { --panel-color: var(--m-success); --panel-soft: var(--m-success-soft); }

.payment-topline { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--m-space-4); }
.payment-icon { display: grid; width: 40px; height: 40px; place-items: center; border-radius: 10px; background: var(--m-surface); color: var(--panel-color); }
.status-pill { display: inline-flex; min-height: 28px; align-items: center; padding: 0 9px; border: 1px solid color-mix(in srgb, var(--panel-color) 25%, transparent); border-radius: 999px; background: var(--m-surface); color: var(--panel-color); font-size: 11px; font-weight: 750; }
.eyebrow { margin: 0 0 5px; color: var(--m-muted); font-size: 10px; font-weight: 800; letter-spacing: .1em; line-height: 1.4; text-transform: uppercase; }
.payment-panel h2 { margin: 0; color: var(--m-ink); font-size: 17px; font-weight: 700; line-height: 1.25; }
.payment-amount { margin: 6px 0 0; color: var(--m-ink); font-size: clamp(30px, 10vw, 38px); font-weight: 800; line-height: 1.1; letter-spacing: -.035em; }
.payment-detail { margin: 7px 0 0; color: var(--m-text); font-size: 13px; line-height: 1.45; }
.payment-cta { margin-top: var(--m-space-4); }

.primary-button,
.secondary-button,
.danger-button {
  min-height: 44px;
  border-radius: 8px;
  font-weight: 700;
}
.primary-button { background: var(--m-primary-dark); color: white; }
.primary-button :deep(.q-btn__content) { gap: 8px; }
.secondary-button { min-width: 94px; border-color: var(--m-border); color: var(--m-primary-dark); }
.danger-button { background: var(--m-danger); color: white; }

.stay-card { margin-bottom: var(--m-space-5); padding: var(--m-space-5); }
.section-heading { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--m-space-3); }
.section-heading > div { min-width: 0; }
.section-heading h2 { overflow-wrap: anywhere; margin: 0; color: var(--m-ink); font-size: 20px; line-height: 1.25; }
.stay-room { display: flex; align-items: center; gap: 6px; margin: 7px 0 0; color: var(--m-muted); font-size: 13px; }
.stay-metrics { display: grid; grid-template-columns: 1fr 1fr; gap: var(--m-space-2); margin-top: var(--m-space-5); }
.stay-metrics > div { min-width: 0; padding: var(--m-space-3); border-radius: 8px; background: var(--m-bg); }
.stay-metrics span { display: block; margin-bottom: 4px; color: var(--m-muted); font-size: 10px; font-weight: 700; text-transform: uppercase; }
.stay-metrics strong { display: block; color: var(--m-ink); font-size: 12px; line-height: 1.4; }
.progress-block { margin-top: var(--m-space-4); }
.progress-label { display: flex; justify-content: space-between; margin-bottom: 7px; color: var(--m-muted); font-size: 11px; font-weight: 650; }
.stay-footer { display: flex; min-height: 44px; align-items: center; justify-content: space-between; gap: var(--m-space-2); margin-top: var(--m-space-3); border-top: 1px solid var(--m-border); padding-top: var(--m-space-3); }
.monthly-rent { display: flex; align-items: center; gap: 6px; color: var(--m-text); font-size: 12px; font-weight: 650; }
.tertiary-action { display: inline-flex; min-height: 44px; align-items: center; gap: 6px; padding: 0 4px; border: 0; background: transparent; color: var(--m-muted); cursor: pointer; font: inherit; font-size: 12px; font-weight: 650; }

.section-title-row h2 { margin: 0 0 var(--m-space-3); color: var(--m-ink); font-size: 16px; line-height: 1.3; }
.quick-actions { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: var(--m-space-2); margin-bottom: var(--m-space-5); }
.quick-actions button { display: flex; min-width: 0; min-height: 90px; align-items: center; justify-content: flex-start; flex-direction: column; gap: 8px; padding: 12px 6px; border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); color: var(--m-ink); cursor: pointer; font: inherit; font-size: 11px; font-weight: 700; line-height: 1.25; text-align: center; }
.action-icon { display: grid; width: 38px; height: 38px; place-items: center; border-radius: 8px; background: var(--m-primary-soft); color: var(--m-primary-dark); }

.review-card,
.manager-card { display: flex; align-items: center; gap: var(--m-space-3); margin-bottom: var(--m-space-4); padding: var(--m-space-4); }
.review-icon { display: grid; width: 42px; height: 42px; flex: 0 0 auto; place-items: center; border-radius: 10px; background: var(--m-warning-soft); color: var(--m-warning); }
.review-card h2,
.manager-card h2 { margin: 0; color: var(--m-ink); font-size: 14px; line-height: 1.3; }
.review-card p:last-child,
.manager-copy p:last-child { margin: 4px 0 0; color: var(--m-muted); font-size: 11px; line-height: 1.4; }
.manager-card { margin-bottom: 0; }
.manager-avatar { flex: 0 0 auto; background: var(--m-primary-soft); color: var(--m-primary-dark); font-size: 12px; font-weight: 800; }
.manager-copy { min-width: 0; flex: 1; }
.manager-copy h2,
.manager-copy p:last-child { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.manager-message { width: 44px; height: 44px; flex: 0 0 auto; color: var(--m-primary-dark); }

.state-card { max-width: 520px; margin: 8vh auto 0; padding: var(--m-space-6); text-align: center; }
.state-icon { display: grid; width: 52px; height: 52px; margin: 0 auto var(--m-space-4); place-items: center; border-radius: var(--m-radius-sm); background: var(--m-primary-soft); color: var(--m-primary-dark); }
.state-icon--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.state-card h1,
.state-card h2 { margin: 0; color: var(--m-ink); font-size: 21px; line-height: 1.25; }
.state-card > p:not(.eyebrow) { margin: var(--m-space-2) 0 var(--m-space-5); color: var(--m-muted); font-size: 14px; line-height: 1.55; }
.empty-state { margin-top: var(--m-space-4); }
.verification-prompt { display: grid; grid-template-columns: 42px 1fr; gap: var(--m-space-3); margin-top: var(--m-space-4); padding: var(--m-space-4); }
.verification-icon { display: grid; width: 42px; height: 42px; place-items: center; border-radius: 9px; background: var(--m-warning-soft); color: var(--m-warning); }
.verification-prompt h2 { margin: 1px 0 4px; color: var(--m-ink); font-size: 14px; }
.verification-prompt p { margin: 0; color: var(--m-muted); font-size: 12px; line-height: 1.45; }
.text-button { grid-column: 2; min-height: 44px; justify-self: start; padding: 0 8px; color: var(--m-primary-dark); font-weight: 700; }

.dashboard-skeleton { display: grid; gap: var(--m-space-4); }
.skeleton-panel,
.skeleton-actions :deep(.q-skeleton) { border-radius: var(--m-radius-sm); }
.skeleton-actions { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--m-space-2); }

.leave-dialog { width: min(92vw, 390px); border-radius: var(--m-radius-sm); box-shadow: none; }
.dialog-heading { display: grid; grid-template-columns: 42px 1fr; gap: var(--m-space-3); padding: var(--m-space-5); }
.dialog-icon { display: grid; width: 42px; height: 42px; place-items: center; border-radius: 9px; background: var(--m-danger-soft); color: var(--m-danger); }
.dialog-heading h2 { margin: 1px 0 6px; color: var(--m-ink); font-size: 18px; }
.dialog-heading p { margin: 0; color: var(--m-muted); font-size: 13px; line-height: 1.5; }
.dialog-actions { gap: var(--m-space-2); padding: 0 var(--m-space-5) var(--m-space-5); }
.dialog-button { min-height: 44px; border-radius: 8px; font-weight: 700; }

button:focus-visible,
.q-btn:focus-visible { outline: 2px solid var(--m-primary); outline-offset: 2px; }
.quick-actions button:hover { border-color: color-mix(in srgb, var(--m-primary) 35%, var(--m-border)); background: var(--m-primary-soft); }
.tertiary-action:hover { color: var(--m-danger); }
.sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; margin: -1px; padding: 0; border: 0; clip: rect(0, 0, 0, 0); white-space: nowrap; }

@media (min-width: 600px) {
  .dashboard-shell { padding-top: var(--m-space-6); padding-bottom: calc(var(--m-space-8) + env(safe-area-inset-bottom)); }
  .payment-panel,
  .stay-card { padding: var(--m-space-6); }
  .quick-actions button { min-height: 100px; font-size: 12px; }
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { scroll-behavior: auto !important; transition-duration: .01ms !important; animation-duration: .01ms !important; animation-iteration-count: 1 !important; }
}
</style>
