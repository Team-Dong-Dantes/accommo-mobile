<template>
  <q-page class="tprof">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="120px" class="sk" />
      <q-skeleton type="rect" height="90px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load this tenant</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <div v-else class="stack">
      <div class="tabbed">
        <div class="hero">
          <img v-if="coverUrl" :src="coverUrl" alt="" class="hero-img" />
          <div class="hero-scrim" />
          <button type="button" class="hero-msg" aria-label="Message tenant" @click="router.push(`/manager/messages?to=${lease.studentId}`)">
            <IconifyIcon icon="lucide:message-circle" width="16" />
          </button>
        </div>

        <div class="body-card">
          <div class="head">
            <span class="head-avatar">{{ lease.studentInitials }}</span>
            <span class="head-name">{{ lease.studentName }}</span>
            <span class="head-chip" :class="`head-chip--${statusColor(LEASE_STATUS, lease.status)}`">
              {{ statusText(LEASE_STATUS, lease.status) }}
            </span>
            <span class="head-sub">{{ lease.roomLabel }} · {{ lease.accommodationName }}</span>
          </div>
        </div>

        <div class="tabs">
          <button
            v-for="t in TABS"
            :key="t.key"
            type="button"
            class="tab"
            :class="{ 'tab--on': tab === t.key }"
            @click="tab = t.key"
          >
            {{ t.label }}
          </button>
        </div>

        <div class="panel">
          <q-tab-panels v-model="tab" animated swipeable class="panels">
            <q-tab-panel name="overview" class="sec">
            <!-- Decisions -->
            <div v-if="lease.status === 'pending'" class="decide-box decide">
              <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decide('rejected')">
                Decline
              </button>
              <button type="button" class="decide-btn" :disabled="deciding" @click="decide('active')">
                Accept
              </button>
            </div>
            <div v-else-if="lease.status === 'leave_requested'" class="decide-box decide">
              <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="declineLeave">
                Keep tenant
              </button>
              <button type="button" class="decide-btn" :disabled="deciding" @click="approveLeave">
                Approve leave
              </button>
            </div>
            <div v-else-if="(lease.status === 'ended' || lease.status === 'terminated') && tenantReview" class="decide-box rated">
              <StarRating :model-value="tenantReview.rating" :size="16" />
              <span class="rated-label">You rated this tenant</span>
            </div>
            <div v-else-if="lease.status === 'ended' || lease.status === 'terminated'" class="decide-box decide">
              <button type="button" class="decide-btn" @click="openReview">Rate this tenant</button>
            </div>

            <div class="sec-head">
              <h2 class="sec-title">Stay</h2>
            </div>
            <div class="group">
              <div class="rule">
                <span class="rule-label">Move-in</span>
                <span class="rule-value">{{ formatDate(lease.startDate) }}</span>
              </div>
              <div class="rule">
                <span class="rule-label">Lease ends</span>
                <span class="rule-value">{{ formatDate(lease.endDate) }}</span>
              </div>
              <div class="rule">
                <span class="rule-label">Monthly rent</span>
                <span class="rule-value">{{ formatPeso(lease.monthlyRent) }}</span>
              </div>
            </div>

            <template v-if="lease.email || lease.phone">
              <div class="sec-head">
                <h2 class="sec-title">Contact</h2>
              </div>
              <div class="group">
                <div v-if="lease.email" class="rule">
                  <span class="rule-label">Email</span>
                  <span class="rule-value">{{ lease.email }}</span>
                </div>
                <div v-if="lease.phone" class="rule">
                  <span class="rule-label">Phone</span>
                  <span class="rule-value">{{ lease.phone }}</span>
                </div>
              </div>
            </template>
          </q-tab-panel>

          <q-tab-panel name="payments" class="sec">
            <div class="sec-head">
              <h2 class="sec-title">Payments</h2>
              <button v-if="payments.length > 3" type="button" class="sec-link" @click="paymentsExpanded = !paymentsExpanded">
                {{ paymentsExpanded ? 'Show less' : `Show all (${payments.length})` }}
              </button>
            </div>

            <div v-if="payments.length" class="group">
              <div v-for="p in visiblePayments" :key="p.id" class="pay-row">
                <div class="pay-row-main">
                  <span class="pay-row-month">{{ formatMonth(p.month) }}</span>
                  <span class="pay-row-amount">{{ formatPeso(p.amount) }}</span>
                </div>
                <div class="pay-row-sub">
                  <span class="pay-row-method">{{ PAYMENT_METHOD_LABEL[p.method] || p.method }}</span>
                  <span class="pay-chip" :class="`pay-chip--${statusColor(PAYMENT_STATUS, p.status)}`">
                    {{ statusText(PAYMENT_STATUS, p.status) }}
                  </span>
                </div>
                <button
                  v-if="p.status === 'pending_verification'"
                  type="button"
                  class="rule-verify"
                  :disabled="verifying === p.id"
                  @click="verifyPayment(p.id)"
                >
                  {{ verifying === p.id ? 'Verifying…' : 'Mark verified' }}
                </button>
              </div>
            </div>
            <EmptyState
              v-else
              variant="compact"
              icon="lucide:receipt"
              title="No payments yet"
              message="Log a payment for this tenant from the tenants list to start their history."
            />
          </q-tab-panel>

          <q-tab-panel name="history" class="sec">
            <h2 class="sec-title">Boarding history</h2>
            <div v-if="history.length" class="group">
              <div v-for="h in history" :key="h.id" class="rule">
                <span class="rule-label">{{ h.accommodationName }} · {{ h.roomType || 'Room' }}</span>
                <span class="rule-value">{{ formatDate(h.periodStart) }} – {{ formatDate(h.periodEnd) }}</span>
              </div>
            </div>
            <p v-else class="none">No prior stays on record.</p>
          </q-tab-panel>
          </q-tab-panels>
        </div>
      </div>
    </div>

    <q-dialog v-model="reviewOpen" position="bottom">
      <q-card class="pay-sheet">
        <h3 class="pay-title">Rate {{ lease.studentName }}</h3>
        <StarRating v-model="reviewForm.rating" interactive :size="26" />
        <label class="pay-field">
          <span class="pay-label">Notes (optional)</span>
          <textarea v-model="reviewForm.comment" class="pay-input review-textarea" rows="3" placeholder="How was this tenant to have?" />
        </label>
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
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatPeso, formatDate, formatMonth, initialsOf, LEASE_STATUS, PAYMENT_STATUS, PAYMENT_METHOD_LABEL, statusText, statusColor } from '@/utils/format'
import { createNotification } from '@/boot/notify'
import { useNotify } from '@/utils/notify'
import { respondToApplication } from '@/utils/applications'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import StarRating from '@/components/shared/StarRating.vue'
import EmptyState from '@/components/shared/EmptyState.vue'

const TABS = [
  { key: 'overview', label: 'Overview' },
  { key: 'payments', label: 'Payments' },
  { key: 'history', label: 'History' },
] as const

const route = useRoute()
const router = useRouter()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const deciding = ref(false)
const tab = ref<(typeof TABS)[number]['key']>('overview')

const lease = reactive({
  status: '',
  studentId: '',
  studentName: '',
  studentInitials: '?',
  email: '',
  phone: '',
  roomLabel: '',
  accommodationId: '',
  accommodationName: '',
  roomType: '',
  startDate: '',
  endDate: '',
  monthlyRent: 0,
})
const coverUrl = ref('')
const payments = ref<{ id: string; month: string; amount: number; status: string; method: string }[]>([])
const paymentsExpanded = ref(false)
const visiblePayments = computed(() => (paymentsExpanded.value ? payments.value : payments.value.slice(0, 3)))
const history = ref<{ id: string; accommodationName: string; roomType: string | null; periodStart: string; periodEnd: string }[]>([])
const tenantReview = ref<{ rating: number; comment: string } | null>(null)

const leaseId = computed(() => String(route.params.leaseId || ''))

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data, error: loadError } = await supabase
      .from('leases')
      .select(
        'id,status,start_date,end_date,monthly_rent,student_id,room_id,users!leases_student_id_fkey(full_name,initials,email,phone),rooms(label,room_number,room_type,accommodation_id,accommodations(name,accommodation_images(url,sort_order)))',
      )
      .eq('id', leaseId.value)
      .maybeSingle()
    if (loadError) throw loadError
    if (!data) {
      error.value = 'This tenant record could not be found.'
      return
    }

    const student = data.users as unknown as { full_name: string | null; initials: string | null; email: string | null; phone: string | null } | null
    const room = data.rooms as unknown as {
      label: string | null
      room_number: string | null
      room_type: string | null
      accommodation_id: string
      accommodations: { name: string | null; accommodation_images: { url: string; sort_order: number | null }[] | null } | null
    } | null

    lease.status = data.status
    lease.studentId = data.student_id
    lease.studentName = student?.full_name || 'A student'
    lease.studentInitials = student?.initials || initialsOf(lease.studentName)
    lease.email = student?.email || ''
    lease.phone = student?.phone || ''
    lease.roomLabel = room?.label || (room?.room_number ? `Room ${room.room_number}` : 'Room')
    lease.accommodationId = room?.accommodation_id || ''
    lease.accommodationName = room?.accommodations?.name || 'Accommodation'
    lease.roomType = room?.room_type || ''

    const cover = [...(room?.accommodations?.accommodation_images ?? [])].sort(
      (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
    )[0]
    coverUrl.value = cover?.url ? resolveAsset(cover.url) : ''
    lease.startDate = data.start_date
    lease.endDate = data.end_date
    lease.monthlyRent = Number(data.monthly_rent ?? 0)

    const [{ data: paymentRows }, { data: historyRows }] = await Promise.all([
      supabase
        .from('payments')
        .select('id,month,amount,status,method')
        .eq('lease_id', leaseId.value)
        .order('month', { ascending: false }),
      supabase
        .from('boarding_history')
        .select('id,accommodation_name,room_type,period_start,period_end')
        .eq('student_id', data.student_id)
        .order('period_start', { ascending: false }),
    ])
    payments.value = (paymentRows ?? []).map((p) => ({ id: p.id, month: p.month, amount: Number(p.amount), status: p.status, method: p.method }))
    history.value = (historyRows ?? []).map((h) => ({
      id: h.id,
      accommodationName: h.accommodation_name || 'Accommodation',
      roomType: h.room_type,
      periodStart: h.period_start,
      periodEnd: h.period_end,
    }))

    if (data.status === 'ended' || data.status === 'terminated') {
      const { data: reviewRow } = await supabase
        .from('tenant_reviews')
        .select('rating,comment')
        .eq('lease_id', leaseId.value)
        .maybeSingle()
      tenantReview.value = reviewRow ? { rating: reviewRow.rating, comment: reviewRow.comment || '' } : null
    }
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

async function decide(next: 'active' | 'rejected') {
  if (deciding.value) return
  deciding.value = true
  try {
    await respondToApplication(leaseId.value, lease.studentId, lease.roomLabel, next)
    lease.status = next
    notify.success(next === 'active' ? 'Application accepted.' : 'Application declined.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update this application.'))
  } finally {
    deciding.value = false
  }
}

async function approveLeave() {
  if (deciding.value) return
  deciding.value = true
  try {
    const today = new Date().toISOString().slice(0, 10)
    const { error: updateError } = await supabase
      .from('leases')
      .update({ status: 'ended', ended_reason: 'leave_approved', end_date: today })
      .eq('id', leaseId.value)
    if (updateError) throw updateError

    await supabase.from('boarding_history').insert({
      student_id: lease.studentId,
      accommodation_id: lease.accommodationId,
      accommodation_name: lease.accommodationName,
      room_type: lease.roomType || null,
      period_start: lease.startDate,
      period_end: today,
      end_reason: 'leave_approved',
    })

    lease.status = 'ended'
    void createNotification(lease.studentId, 'Leave request approved', `Your move-out from ${lease.roomLabel} was approved.`, 'lease', '/student/profile')
    notify.success('Leave request approved.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not approve the leave request.'))
  } finally {
    deciding.value = false
  }
}

async function declineLeave() {
  if (deciding.value) return
  deciding.value = true
  try {
    const { error: updateError } = await supabase
      .from('leases')
      .update({ status: 'active', leave_requested_at: null })
      .eq('id', leaseId.value)
    if (updateError) throw updateError
    lease.status = 'active'
    void createNotification(lease.studentId, 'Leave request declined', `Your request to leave ${lease.roomLabel} was declined.`, 'lease', '/student/stay')
    notify.success('Leave request declined.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update the leave request.'))
  } finally {
    deciding.value = false
  }
}

const verifying = ref('')

async function verifyPayment(paymentId: string) {
  if (verifying.value) return
  verifying.value = paymentId
  try {
    const { error: updateError } = await supabase
      .from('payments')
      .update({ status: 'paid', paid_at: new Date().toISOString() })
      .eq('id', paymentId)
    if (updateError) throw updateError

    const row = payments.value.find((p) => p.id === paymentId)
    if (row) row.status = 'paid'

    void createNotification(lease.studentId, 'Payment verified', `Your payment for ${lease.roomLabel} was marked as paid.`, 'payment', '/student/payments')
    notify.success('Payment verified.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not verify this payment.'))
  } finally {
    verifying.value = ''
  }
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
    const { data: authData } = await supabase.auth.getUser()
    const managerId = authData?.user?.id
    if (!managerId) throw new Error('Not signed in.')

    const { error: insertError } = await supabase.from('tenant_reviews').insert({
      lease_id: leaseId.value,
      student_id: lease.studentId,
      accommodation_manager_id: managerId,
      rating: reviewForm.rating,
      comment: reviewForm.comment.trim() || null,
    })
    if (insertError) throw insertError

    tenantReview.value = { rating: reviewForm.rating, comment: reviewForm.comment.trim() }
    reviewOpen.value = false
    notify.success('Review submitted.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not submit your review.'))
  } finally {
    submittingReview.value = false
  }
}

onMounted(load)
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
  width: 84px;
  height: 84px;
  place-items: center;
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
  margin: 14px var(--m-page-gutter) -1px;
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
.panels { background: transparent; }
.panels :deep(.q-tab-panel) { padding: 0; }

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
.rated {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 8px 0;
}
.rated-label {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
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

.sec {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.sec-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
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

.pay-row {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 9px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .pay-row:first-child {
  border-top: 0;
}
.pay-row-main,
.pay-row-sub {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.pay-row-month,
.pay-row-amount {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.pay-row-method {
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
.pay-chip {
  flex: 0 0 auto;
  padding: 2px 9px;
  border-radius: 999px;
  font-size: 10.5px;
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
.none {
  padding: 14px 12px;
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}

.pay-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.pay-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
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
  min-height: 48px;
  font-weight: 700;
}
.review-textarea {
  min-height: 70px;
  padding: 10px 12px;
  resize: vertical;
}
</style>
