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
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <EmptyState
      v-else-if="!stay"
      icon="lucide:home"
      title="No active stay"
      message="Once a manager accepts your application, your tenancy details, rent and manager contact will show up here."
    >
      <template #actions>
        <q-btn unelevated rounded no-caps color="primary" label="Browse rooms" @click="router.push('/student/discover')" />
      </template>
    </EmptyState>

    <div v-else class="stack">
      <div class="head">
        <span class="head-name">{{ stay.accommodationName }}</span>
        <span v-if="stay.roomLabel" class="head-room">{{ stay.roomLabel }}</span>
        <span class="head-chip" :class="`head-chip--${statusColor(LEASE_STATUS, stay.status)}`">{{ statusText(LEASE_STATUS, stay.status) }}</span>
        <p v-if="stay.status === 'pending'" class="head-note">Application pending — awaiting manager decision.</p>
        <p v-else-if="stay.status === 'leave_requested'" class="head-note">Leave requested — awaiting manager decision.</p>
      </div>

      <!-- Manager contact -->
      <section class="sec">
        <h2 class="sec-title">Managed by</h2>
        <div class="mgr">
          <span class="mgr-avatar">{{ stay.managerInitials }}</span>
          <span class="mgr-body">
            <span class="mgr-name">{{ stay.managerName }}</span>
            <span class="mgr-sub">{{ stay.replyMinutes ? `Replies in ~${stay.replyMinutes} min` : 'Accommodation manager' }}</span>
          </span>
          <button type="button" class="mgr-msg" @click="router.push(`/student/messages?to=${stay.managerId}`)">
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
            <span class="rule-value">{{ formatPeso(stay.monthlyRent) }}</span>
          </div>
          <div v-if="stay.advancePaid" class="rule">
            <span class="rule-label">Advance paid</span>
            <span class="rule-value">{{ formatPeso(stay.advancePaid) }}</span>
          </div>
          <div v-if="stay.depositPaid" class="rule">
            <span class="rule-label">Deposit paid</span>
            <span class="rule-value">{{ formatPeso(stay.depositPaid) }}</span>
          </div>
          <div class="rule">
            <span class="rule-label">Lease term</span>
            <span class="rule-value">{{ formatDate(stay.startDate) }} – {{ formatDate(stay.endDate) }}</span>
          </div>
        </div>
      </section>

      <!-- Quick links -->
      <section class="sec">
        <div class="group">
          <button type="button" class="row-link" @click="router.push('/student/payments')">
            <IconifyIcon icon="lucide:wallet-cards" width="16" />
            <span>Payments</span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
          </button>
          <button type="button" class="row-link" @click="router.push('/student/concerns')">
            <IconifyIcon icon="lucide:message-square-warning" width="16" />
            <span>Concerns</span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
          </button>
        </div>
      </section>

      <button v-if="stay.status === 'active'" type="button" class="leave-link" @click="leaveDialog = true">
        Request to leave
      </button>

      <div class="tail" />
    </div>

    <q-dialog v-model="leaveDialog" position="bottom">
      <q-card class="leave-sheet">
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
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatPeso, formatDate, initialsOf, LEASE_STATUS, statusText, statusColor } from '@/utils/format'
import { useNotify } from '@/utils/notify'
import { createNotification } from '@/boot/notify'
import EmptyState from '@/components/shared/EmptyState.vue'

interface Stay {
  leaseId: string
  managerId: string
  managerName: string
  managerInitials: string
  replyMinutes: number | null
  accommodationName: string
  roomLabel: string
  status: 'active' | 'pending' | 'leave_requested'
  monthlyRent: number
  advancePaid: number
  depositPaid: number
  startDate: string
  endDate: string
}

const router = useRouter()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const stay = ref<Stay | null>(null)
const leaveDialog = ref(false)
const leaving = ref(false)

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: authData } = await supabase.auth.getUser()
    const user = authData?.user
    if (!user) {
      error.value = 'Not signed in.'
      return
    }

    const { data: leaseRow, error: loadError } = await supabase
      .from('leases')
      .select(
        'id, status, start_date, end_date, monthly_rent, advance_paid, deposit_paid, accommodation_manager_id, rooms(room_number, label, accommodations(name))',
      )
      .eq('student_id', user.id)
      .in('status', ['active', 'pending', 'leave_requested'])
      .order('start_date', { ascending: false })
      .limit(1)
      .maybeSingle()
    if (loadError) throw loadError

    if (!leaseRow) {
      stay.value = null
      return
    }

    const room = leaseRow.rooms as unknown as {
      room_number: string | null
      label: string | null
      accommodations: { name: string | null } | null
    } | null

    const [{ data: manager }, { data: profile }] = await Promise.all([
      supabase.from('users').select('full_name, initials').eq('id', leaseRow.accommodation_manager_id).maybeSingle(),
      supabase
        .from('accommodation_manager_profiles')
        .select('avg_response_minutes')
        .eq('user_id', leaseRow.accommodation_manager_id)
        .maybeSingle(),
    ])

    stay.value = {
      leaseId: leaseRow.id,
      managerId: leaseRow.accommodation_manager_id,
      managerName: manager?.full_name || 'Accommodation manager',
      managerInitials: manager?.initials || initialsOf(manager?.full_name || '?'),
      replyMinutes: profile?.avg_response_minutes ?? null,
      accommodationName: room?.accommodations?.name || 'Your accommodation',
      roomLabel: room?.label || (room?.room_number ? `Room ${room.room_number}` : ''),
      status: leaseRow.status as Stay['status'],
      monthlyRent: Number(leaseRow.monthly_rent ?? 0),
      advancePaid: Number(leaseRow.advance_paid ?? 0),
      depositPaid: Number(leaseRow.deposit_paid ?? 0),
      startDate: leaseRow.start_date,
      endDate: leaseRow.end_date,
    }
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

async function requestLeave() {
  if (leaving.value || !stay.value) return
  leaving.value = true
  try {
    const { data: authData } = await supabase.auth.getUser()
    const user = authData?.user
    if (!user) throw new Error('Not signed in.')

    const { error: updateError } = await supabase
      .from('leases')
      .update({ status: 'leave_requested', leave_requested_at: new Date().toISOString() })
      .eq('id', stay.value.leaseId)
      .eq('student_id', user.id)
    if (updateError) throw updateError

    void createNotification(
      stay.value.managerId,
      'Leave request',
      `A tenant requested to leave ${stay.value.accommodationName}.`,
      'lease',
      `/manager/tenant/${stay.value.leaseId}`,
    )

    stay.value = { ...stay.value, status: 'leave_requested' }
    leaveDialog.value = false
    notify.success('Leave request sent.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not send your leave request.'))
  } finally {
    leaving.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.sp {
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 10px var(--m-page-gutter) 24px;
}
.sk {
  border-radius: var(--m-radius);
}
.tail {
  height: 12px;
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
  padding: 8px 2px 0;
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
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 800;
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

.leave-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
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
</style>
