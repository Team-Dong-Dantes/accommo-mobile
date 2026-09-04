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
      <div class="head">
        <span class="head-avatar">{{ lease.studentInitials }}</span>
        <span class="head-name">{{ lease.studentName }}</span>
        <span class="head-chip" :class="`head-chip--${statusColor(LEASE_STATUS, lease.status)}`">
          {{ statusText(LEASE_STATUS, lease.status) }}
        </span>
        <span class="head-sub">{{ lease.roomLabel }} · {{ lease.accommodationName }}</span>
        <button type="button" class="head-msg" @click="router.push(`/manager/messages?to=${lease.studentId}`)">
          <IconifyIcon icon="lucide:message-circle" width="14" />
          Message
        </button>
      </div>

      <!-- Decisions -->
      <div v-if="lease.status === 'pending'" class="decide">
        <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decide('rejected')">
          Decline
        </button>
        <button type="button" class="decide-btn" :disabled="deciding" @click="decide('active')">
          Accept
        </button>
      </div>
      <div v-else-if="lease.status === 'leave_requested'" class="decide">
        <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="declineLeave">
          Keep tenant
        </button>
        <button type="button" class="decide-btn" :disabled="deciding" @click="approveLeave">
          Approve leave
        </button>
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

      <section v-if="tab === 'overview'" class="sec">
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
          <div v-if="lease.email" class="rule">
            <span class="rule-label">Email</span>
            <span class="rule-value">{{ lease.email }}</span>
          </div>
          <div v-if="lease.phone" class="rule">
            <span class="rule-label">Phone</span>
            <span class="rule-value">{{ lease.phone }}</span>
          </div>
        </div>
      </section>

      <section v-else-if="tab === 'payments'" class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Payments</h2>
          <button type="button" class="sec-link" @click="openLogPayment">Log payment</button>
        </div>
        <div v-if="payments.length" class="group">
          <div v-for="p in payments" :key="p.id" class="rule">
            <span class="rule-label">{{ formatMonth(p.month) }}</span>
            <span class="rule-value">
              {{ formatPeso(p.amount) }} · {{ statusText(PAYMENT_STATUS, p.status) }}
              <button
                v-if="p.status === 'pending_verification'"
                type="button"
                class="rule-verify"
                :disabled="verifying === p.id"
                @click="verifyPayment(p.id)"
              >
                {{ verifying === p.id ? 'Verifying…' : 'Mark verified' }}
              </button>
            </span>
          </div>
        </div>
        <p v-else class="none">No payments logged yet.</p>
      </section>

      <section v-else class="sec">
        <h2 class="sec-title">Boarding history</h2>
        <div v-if="history.length" class="group">
          <div v-for="h in history" :key="h.id" class="rule">
            <span class="rule-label">{{ h.accommodationName }} · {{ h.roomType || 'Room' }}</span>
            <span class="rule-value">{{ formatDate(h.periodStart) }} – {{ formatDate(h.periodEnd) }}</span>
          </div>
        </div>
        <p v-else class="none">No prior stays on record.</p>
      </section>

      <div class="tail" />
    </div>

    <q-dialog v-model="paymentOpen" position="bottom">
      <q-card class="pay-sheet">
        <h3 class="pay-title">Log a payment</h3>
        <label class="pay-field">
          <span class="pay-label">Month</span>
          <input v-model="paymentForm.month" type="month" class="pay-input" />
        </label>
        <label class="pay-field">
          <span class="pay-label">Amount</span>
          <input v-model.number="paymentForm.amount" type="number" min="0" step="0.01" class="pay-input" />
        </label>
        <label class="pay-field">
          <span class="pay-label">Method</span>
          <select v-model="paymentForm.method" class="pay-input">
            <option value="cash">Cash</option>
            <option value="gcash">GCash</option>
            <option value="maya">Maya</option>
            <option value="bank">Bank transfer</option>
            <option value="others">Other</option>
          </select>
        </label>
        <q-btn
          unelevated
          rounded
          no-caps
          color="primary"
          class="pay-submit"
          :loading="logging"
          label="Log payment"
          @click="submitPayment"
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
import { formatPeso, formatDate, formatMonth, initialsOf, LEASE_STATUS, PAYMENT_STATUS, statusText, statusColor } from '@/utils/format'
import { createNotification } from '@/boot/notify'
import { useNotify } from '@/utils/notify'

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
const payments = ref<{ id: string; month: string; amount: number; status: string }[]>([])
const history = ref<{ id: string; accommodationName: string; roomType: string | null; periodStart: string; periodEnd: string }[]>([])

const leaseId = computed(() => String(route.params.leaseId || ''))

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data, error: loadError } = await supabase
      .from('leases')
      .select(
        'id,status,start_date,end_date,monthly_rent,student_id,room_id,users!leases_student_id_fkey(full_name,initials,email,phone),rooms(label,room_number,room_type,accommodation_id,accommodations(name))',
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
      accommodations: { name: string | null } | null
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
    lease.startDate = data.start_date
    lease.endDate = data.end_date
    lease.monthlyRent = Number(data.monthly_rent ?? 0)

    const [{ data: paymentRows }, { data: historyRows }] = await Promise.all([
      supabase
        .from('payments')
        .select('id,month,amount,status')
        .eq('lease_id', leaseId.value)
        .order('month', { ascending: false }),
      supabase
        .from('boarding_history')
        .select('id,accommodation_name,room_type,period_start,period_end')
        .eq('student_id', data.student_id)
        .order('period_start', { ascending: false }),
    ])
    payments.value = (paymentRows ?? []).map((p) => ({ id: p.id, month: p.month, amount: Number(p.amount), status: p.status }))
    history.value = (historyRows ?? []).map((h) => ({
      id: h.id,
      accommodationName: h.accommodation_name || 'Accommodation',
      roomType: h.room_type,
      periodStart: h.period_start,
      periodEnd: h.period_end,
    }))
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
    const { error: updateError } = await supabase.from('leases').update({ status: next }).eq('id', leaseId.value)
    if (updateError) throw updateError
    lease.status = next
    void createNotification(
      lease.studentId,
      next === 'active' ? 'Application accepted' : 'Application declined',
      next === 'active'
        ? `You're in! Your application for ${lease.roomLabel} was accepted.`
        : `Your application for ${lease.roomLabel} was declined.`,
      'lease',
      '/student/profile',
    )
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
    void createNotification(lease.studentId, 'Leave request declined', `Your request to leave ${lease.roomLabel} was declined.`, 'lease', '/student/profile')
    notify.success('Leave request declined.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update the leave request.'))
  } finally {
    deciding.value = false
  }
}

const paymentOpen = ref(false)
const logging = ref(false)
const paymentForm = reactive({
  month: new Date().toISOString().slice(0, 7),
  amount: 0,
  method: 'cash' as 'cash' | 'gcash' | 'maya' | 'bank' | 'others',
})

function openLogPayment() {
  paymentForm.month = new Date().toISOString().slice(0, 7)
  paymentForm.amount = lease.monthlyRent
  paymentForm.method = 'cash'
  paymentOpen.value = true
}

async function submitPayment() {
  if (logging.value) return
  logging.value = true
  try {
    const { data: created, error: insertError } = await supabase
      .from('payments')
      .insert({
        lease_id: leaseId.value,
        month: `${paymentForm.month}-01`,
        amount: paymentForm.amount,
        method: paymentForm.method,
        status: 'paid',
        paid_at: new Date().toISOString(),
      })
      .select('id,month,amount,status')
      .single()
    if (insertError) throw insertError
    payments.value = [{ id: created.id, month: created.month, amount: Number(created.amount), status: created.status }, ...payments.value]
    paymentOpen.value = false
    notify.success('Payment logged.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not log this payment.'))
  } finally {
    logging.value = false
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

onMounted(load)
</script>

<style scoped>
.tprof {
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 8px var(--m-page-gutter) 0;
}
.sk {
  border-radius: var(--m-radius);
}
.tail {
  height: 24px;
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
  align-items: center;
  gap: 4px;
  padding: 8px 0 4px;
  text-align: center;
}
.head-avatar {
  display: grid;
  width: 56px;
  height: 56px;
  place-items: center;
  margin-bottom: 4px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 19px;
  font-weight: 800;
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
.head-msg {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  margin-top: 8px;
  padding: 6px 14px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

.decide {
  display: flex;
  gap: 8px;
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

.tabs {
  display: flex;
  gap: 6px;
  border-bottom: 1px solid var(--m-border);
}
.tab {
  padding: 8px 4px;
  border: 0;
  border-bottom: 2px solid transparent;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.tab--on {
  border-bottom-color: var(--m-primary);
  color: var(--m-primary-dark);
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
</style>
