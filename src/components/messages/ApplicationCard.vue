<template>
  <!-- The tenancy handshake, as a banner above the conversation: ask → manager
       issues a form → student fills it → manager decides. Extracted from
       ChatThread so the messaging side stays messaging. -->

  <div v-if="application" class="app-card">
    <div class="app-card-body">
      <IconifyIcon icon="lucide:file-check-2" width="16" />
      <span class="app-card-text">Application for {{ application.roomLabel }}</span>
    </div>
    <div v-if="role === 'manager'" class="app-card-actions">
      <button type="button" class="app-btn" :disabled="deciding" @click="openReview">Review</button>
    </div>
    <span v-else class="app-card-status">Awaiting response</span>
  </div>

  <div v-else-if="applyRoom" class="app-card">
    <div class="app-card-body">
      <IconifyIcon icon="lucide:file-check-2" width="16" />
      <span class="app-card-text">
        {{ applyRoom.label }} · {{ formatPeso(applyRoom.rent) }}/mo{{ applyRoom.rentBasis === 'person' && applyRoom.capacity > 1 ? ' per person' : '' }}
      </span>
    </div>
    <label class="app-field">
      <span class="app-field-label">Move-in date</span>
      <input v-model="applyForm.startDate" type="date" class="app-date" :min="todayStr()" />
    </label>
    <button type="button" class="app-btn app-btn--submit" :disabled="applying" @click="reviewOpen = true">
      Review application
    </button>
  </div>

  <div v-else-if="applyUnavailable" class="app-card">
    <span class="app-card-text">This room is no longer available.</span>
  </div>

  <!-- A student holds at most one lease at a time (DB-enforced). While one is
       running, no form can be issued or filled in this thread. -->
  <div v-else-if="otherLease" class="app-card">
    <div class="app-card-body">
      <IconifyIcon icon="lucide:info" width="16" />
      <span class="app-card-text">
        <template v-if="role === 'student'">
          {{ otherLease.status === 'pending'
            ? `You have already applied for ${otherLease.roomLabel}.`
            : `You already have a stay at ${otherLease.roomLabel}.` }}
        </template>
        <template v-else>
          {{ otherLease.status === 'pending'
            ? 'This student has an application pending elsewhere.'
            : isMyTenant
              ? `This student already stays in ${otherLease.roomLabel}.`
              : 'This student already has a current stay.' }}
        </template>
      </span>
    </div>
    <!-- Only offered when there is somewhere real to go: a student always has
         My Stay, but a manager can only open a tenancy that is their own —
         someone else's lease is not theirs to read. -->
    <div v-if="canViewOtherLease" class="app-card-actions">
      <button type="button" class="app-btn app-btn--ghost" @click="viewOtherLease">View</button>
    </div>
  </div>

  <!-- No application in flight and no form issued yet. The form is the manager's
       to hand over: the student asked about one specific room in discovery, so
       there is nothing here for the manager to choose. -->
  <div v-else-if="role === 'manager'" class="app-card">
    <div class="app-card-body">
      <IconifyIcon :icon="invitedRoomId ? 'lucide:file-clock' : 'lucide:file-plus-2'" width="16" />
      <span class="app-card-text">
        {{
          invitedRoomId
            ? `Application form sent · ${inquiryRoom?.label ?? 'this room'}`
            : inquiryRoom
              ? `Application form · ${inquiryRoom.label}`
              : 'No room asked about yet'
        }}
      </span>
    </div>
    <p v-if="declined" class="app-card-reason">You declined {{ declined.roomLabel }} — {{ declined.reason }}</p>
    <span v-if="invitedRoomId" class="app-card-status">Awaiting their application</span>
    <div v-else class="app-card-actions">
      <button type="button" class="app-btn" :disabled="!inquiryRoom || issuing" @click="sendForm">
        {{ issuing ? 'Sending…' : 'Send application form' }}
      </button>
    </div>
  </div>

  <div v-else-if="inquiryRoom" class="app-card">
    <div class="app-card-body">
      <IconifyIcon :icon="declined ? 'lucide:circle-x' : 'lucide:file-clock'" width="16" />
      <span class="app-card-text">
        {{ declined ? `Application declined · ${declined.roomLabel}` : `Asking about ${inquiryRoom.label}` }}
      </span>
    </div>
    <p v-if="declined" class="app-card-reason">Reason: {{ declined.reason }}</p>
    <div class="app-card-actions">
      <button type="button" class="app-btn app-btn--ghost" :disabled="requesting" @click="requestForm">
        {{ requesting ? 'Requested' : declined ? 'Ask for another form' : 'Request application form' }}
      </button>
    </div>
  </div>

  <!-- Student: what they are committing to, before anything is written. -->
  <q-dialog v-model="reviewOpen" position="bottom">
    <div v-if="role === 'student' && applyRoom" class="sheet">
      <h3 class="sheet-title">Review your application</h3>
      <dl class="sum">
        <div class="sum-row">
          <dt>Room</dt>
          <dd>{{ applyRoom.accommodation }} · {{ applyRoom.label }}</dd>
        </div>
        <div class="sum-row">
          <dt>Move-in</dt>
          <dd>{{ formatDate(applyForm.startDate) }}</dd>
        </div>
        <div class="sum-row">
          <dt>Monthly rent</dt>
          <dd>{{ formatPeso(monthlyDue) }}</dd>
        </div>
        <div v-if="applyRoom.advanceMonths" class="sum-row">
          <dt>Advance</dt>
          <dd>{{ applyRoom.advanceMonths }} month{{ applyRoom.advanceMonths === 1 ? '' : 's' }} · {{ formatPeso(monthlyDue * applyRoom.advanceMonths) }}</dd>
        </div>
        <div v-if="applyRoom.depositMonths" class="sum-row">
          <dt>Deposit</dt>
          <dd>{{ applyRoom.depositMonths }} month{{ applyRoom.depositMonths === 1 ? '' : 's' }} · {{ formatPeso(monthlyDue * applyRoom.depositMonths) }}</dd>
        </div>
        <div v-if="upfrontTotal" class="sum-row sum-row--total">
          <dt>Due on move-in</dt>
          <dd>{{ formatPeso(upfrontTotal) }}</dd>
        </div>
      </dl>
      <p class="sheet-note">
        Your manager decides on this application. Nothing is charged through Accommo.
      </p>
      <div class="sheet-actions">
        <button type="button" class="app-btn app-btn--ghost" @click="reviewOpen = false">Back</button>
        <button type="button" class="app-btn" :disabled="applying" @click="submitApplication">
          {{ applying ? 'Submitting…' : 'Submit application' }}
        </button>
      </div>
    </div>

    <!-- Manager: who is applying and on what terms, with both decisions here so
         an application cannot be approved without the details in view. -->
    <div v-else-if="role === 'manager' && application" class="sheet">
      <h3 class="sheet-title">Review application</h3>
      <div class="who">
        <span class="who-name">{{ otherName }}</span>
        <span v-if="applicant?.verified" class="who-chip who-chip--ok">
          <IconifyIcon icon="lucide:shield-check" width="13" /> OSAS verified
        </span>
        <span v-else class="who-chip who-chip--warn">
          <IconifyIcon icon="lucide:shield-alert" width="13" /> Not OSAS verified
        </span>
      </div>
      <dl class="sum">
        <div v-if="applicant?.studentNo" class="sum-row">
          <dt>Student no.</dt>
          <dd>{{ applicant.studentNo }}</dd>
        </div>
        <div v-if="applicant?.program || applicant?.yearLevel" class="sum-row">
          <dt>Course</dt>
          <dd>{{ [applicant.program, applicant.yearLevel ? `${applicant.yearLevel} year` : ''].filter(Boolean).join(' · ') }}</dd>
        </div>
        <div v-if="applicant?.college" class="sum-row">
          <dt>College</dt>
          <dd>{{ applicant.college }}</dd>
        </div>
        <div class="sum-row">
          <dt>Room</dt>
          <dd>{{ application.roomLabel }}</dd>
        </div>
        <div class="sum-row">
          <dt>Move-in</dt>
          <dd>{{ formatDate(application.startDate) }}</dd>
        </div>
        <div class="sum-row">
          <dt>Until</dt>
          <dd>{{ formatDate(application.endDate) }}</dd>
        </div>
        <div class="sum-row sum-row--total">
          <dt>Monthly rent</dt>
          <dd>{{ formatPeso(application.monthlyRent) }}</dd>
        </div>
      </dl>
      <div class="sheet-actions">
        <button type="button" class="app-btn app-btn--ghost" :disabled="deciding" @click="reviewOpen = false; declineOpen = true">
          Decline
        </button>
        <button type="button" class="app-btn" :disabled="deciding" @click="decideApplication('active')">
          {{ deciding ? 'Accepting…' : 'Accept' }}
        </button>
      </div>
    </div>
  </q-dialog>

  <!-- A decline the student can act on: the reason reaches them in the
       notification and stays on the lease. -->
  <q-dialog v-model="declineOpen" position="bottom">
    <div class="sheet">
      <h3 class="sheet-title">Decline application</h3>
      <p class="sheet-note">The student sees this reason.</p>
      <textarea v-model="declineReason" class="sheet-input" rows="3" placeholder="Why are you declining?" />
      <div class="sheet-actions">
        <button type="button" class="app-btn app-btn--ghost" @click="declineOpen = false">Cancel</button>
        <button
          type="button"
          class="app-btn"
          :disabled="!declineReason.trim() || deciding"
          @click="decideApplication('rejected')"
        >
          {{ deciding ? 'Declining…' : 'Decline' }}
        </button>
      </div>
    </div>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatDate, formatPeso } from '@/utils/format'
import { useNotify } from '@/utils/notify'
import { createNotification } from '@/boot/notify'
import {
  respondToApplication,
  stampInquiryRoom,
  requestApplicationForm,
  issueApplicationForm,
  clearApplicationInvite,
} from '@/utils/applications'

const props = defineProps<{
  conversationId: string
  role: 'manager' | 'student'
  me: string
  otherId: string
  otherName: string
  roomId?: string | undefined
}>()

// The parent owns the transcript, so every step asks it to post the system line.
const emit = defineEmits<{ system: [body: string] }>()

const notify = useNotify()
const router = useRouter()

interface RoomBrief {
  id: string
  label: string
  accommodation: string
  rent: number
  minStay: number
  capacity: number
  rentBasis: 'room' | 'person'
  advanceMonths: number
  depositMonths: number
}

const application = ref<{
  leaseId: string
  roomLabel: string
  startDate: string
  endDate: string
  monthlyRent: number
} | null>(null)
const applyRoom = ref<RoomBrief | null>(null)
const applyUnavailable = ref(false)
const applyForm = reactive({ startDate: todayStr() })
const applying = ref(false)
const deciding = ref(false)
/** The room this conversation is about — what the manager can issue a form for. */
const inquiryRoom = ref<{ id: string; label: string } | null>(null)
/** Set once the manager has issued a form; the student's apply card reads it. */
const invitedRoomId = ref<string | null>(null)
/** The student's current lease when it is NOT this thread's pending application. */
const otherLease = ref<{ leaseId: string; status: string; roomLabel: string; managerId: string } | null>(null)
/** The last refused application between these two, so the reason outlives the message. */
const declined = ref<{ roomLabel: string; reason: string } | null>(null)
const issuing = ref(false)
const requesting = ref(false)
const reviewOpen = ref(false)
const declineOpen = ref(false)
const declineReason = ref('')
const applicant = ref<{
  studentNo: string | null
  program: string | null
  college: string | null
  yearLevel: number | null
  verified: boolean
} | null>(null)

function todayStr(): string {
  return new Date().toISOString().slice(0, 10)
}

function addMonths(dateStr: string, months: number): string {
  const d = new Date(dateStr)
  d.setMonth(d.getMonth() + months)
  return d.toISOString().slice(0, 10)
}

const applyEndDate = computed(() => addMonths(applyForm.startDate || todayStr(), applyRoom.value?.minStay || 12))

/**
 * What this tenant actually pays each month. A "whole room" rate is split evenly
 * across capacity — the same expression the insert uses, kept in one place so the
 * summary can never quote a figure different from the one written to the lease.
 */
const monthlyDue = computed(() => {
  const room = applyRoom.value
  if (!room) return 0
  return room.rentBasis === 'person' ? room.rent : room.rent / (room.capacity || 1)
})

const upfrontTotal = computed(() => {
  const room = applyRoom.value
  if (!room) return 0
  return monthlyDue.value * (room.advanceMonths + room.depositMonths)
})

function roomLabelOf(r: { label: string | null; room_number: string | null } | null): string {
  return r?.label || (r?.room_number ? `Room ${r.room_number}` : 'this room')
}

/** The blocking lease is one of this manager's own — so it is theirs to open. */
const isMyTenant = computed(
  () => props.role === 'manager' && otherLease.value?.managerId === props.me,
)

// A student can always open their own stay; a manager only their own tenancy.
// RLS would refuse another manager's lease anyway, so offering the button would
// only promise a screen that cannot load.
const canViewOtherLease = computed(() => props.role === 'student' || isMyTenant.value)

function viewOtherLease() {
  if (!otherLease.value) return
  void router.push(
    props.role === 'student' ? '/student/stay' : `/manager/tenant/${otherLease.value.leaseId}`,
  )
}

// refresh() runs from three places (mount, every incoming realtime message, and
// after each action), so several can be in flight at once. Without this they all
// read the same pre-stamp state, all decide the inquiry has changed, and each
// posts its own "Asking about Room 3." — which is how four identical system
// messages ended up in one thread. Collapsing concurrent calls onto one promise
// is the same trick the router guard uses for its role lookup.
let refreshing: Promise<void> | null = null
/** Rooms this instance has already announced; the emit is not idempotent. */
let announcedRoom: string | null = null

function refresh(): Promise<void> {
  if (refreshing) return refreshing
  refreshing = runRefresh().finally(() => {
    refreshing = null
  })
  return refreshing
}

async function runRefresh() {
  const studentId = props.role === 'student' ? props.me : props.otherId
  const managerId = props.role === 'student' ? props.otherId : props.me
  if (!studentId || !managerId) return

  // At most one of these can exist: leases_one_current_per_student is a UNIQUE
  // index on student_id over ('pending','active','leave_requested'). Reading the
  // student's lease across ALL managers, not just this thread's, is what stops a
  // form being offered to someone already housed — that insert can only ever
  // fail on the index, as a raw 409 after they have filled the form in.
  const { data: current } = await supabase
    .from('leases')
    .select('id,status,start_date,end_date,monthly_rent,accommodation_manager_id,rooms(label,room_number)')
    .eq('student_id', studentId)
    .in('status', ['pending', 'active', 'leave_requested'])
    .maybeSingle()

  const currentLabel = roomLabelOf(current?.rooms as never)

  if (current && current.status === 'pending' && current.accommodation_manager_id === managerId) {
    application.value = {
      leaseId: current.id,
      roomLabel: currentLabel,
      startDate: current.start_date,
      endDate: current.end_date,
      monthlyRent: Number(current.monthly_rent ?? 0),
    }
    otherLease.value = null
    declined.value = null
    return
  }

  application.value = null
  // A stay or application that is not this thread's business. Nothing can be
  // offered or submitted here until it ends.
  otherLease.value = current
    ? {
        leaseId: current.id,
        status: current.status,
        roomLabel: currentLabel,
        managerId: current.accommodation_manager_id,
      }
    : null

  // Why the last attempt failed. The system message saying so scrolls out of
  // sight, and the notification is long gone by the time they come back.
  // leases has no created_at, so the requested move-in is the best ordering key.
  const { data: refused } = await supabase
    .from('leases')
    .select('decision_reason,rooms(label,room_number)')
    .eq('student_id', studentId)
    .eq('accommodation_manager_id', managerId)
    .eq('status', 'rejected')
    .not('decision_reason', 'is', null)
    .order('start_date', { ascending: false })
    .limit(1)
    .maybeSingle()
  declined.value = refused?.decision_reason
    ? { roomLabel: roomLabelOf(refused.rooms as never), reason: refused.decision_reason }
    : null

  const { data: convo } = await supabase
    .from('conversations')
    .select('inquiry_room_id,invited_room_id')
    .eq('id', props.conversationId)
    .maybeSingle()

  // Arriving from a room page records what the student is asking about, so the
  // manager's side of the thread knows which form to offer — before this the room
  // lived only in the student's URL. Stamped only when it CHANGES, or re-opening
  // the thread would re-post the system message every time.
  let inquiryId = convo?.inquiry_room_id ?? null
  if (
    props.roomId &&
    props.role === 'student' &&
    props.roomId !== inquiryId &&
    props.roomId !== announcedRoom
  ) {
    // Claimed before the first await, so a call that starts while this one is
    // mid-flight cannot reach the emit as well. The lease-closed trigger clears
    // inquiry_room_id, which would otherwise make an open thread re-announce
    // the same room every time it refreshed.
    announcedRoom = props.roomId
    const label = await fetchRoomLabel(props.roomId)
    await stampInquiryRoom(props.conversationId, props.roomId)
    inquiryId = props.roomId
    inquiryRoom.value = { id: inquiryId, label }
    emit('system', `Asking about ${label}.`)
  } else {
    inquiryRoom.value = inquiryId ? { id: inquiryId, label: await fetchRoomLabel(inquiryId) } : null
  }

  // The apply form opens only for a room the manager has actually issued one for,
  // and only on the student's side — the manager sees that it is out, not the form.
  invitedRoomId.value = convo?.invited_room_id ?? null
  if (invitedRoomId.value && props.role === 'student' && !otherLease.value) {
    await loadApplyRoom(invitedRoomId.value)
  }
}

async function fetchRoomLabel(roomId: string): Promise<string> {
  const { data } = await supabase
    .from('rooms')
    .select('label,room_number')
    .eq('id', roomId)
    .maybeSingle()
  return roomLabelOf(data)
}

/** Student nudge. Holds no state beyond the transcript line and the notification. */
async function requestForm() {
  if (requesting.value || !inquiryRoom.value) return
  requesting.value = true
  try {
    await requestApplicationForm(props.conversationId, props.otherId, inquiryRoom.value.label)
    emit('system', `Requested an application form for ${inquiryRoom.value.label}.`)
    notify.success('Request sent.')
  } catch (e) {
    requesting.value = false
    notify.error(errorMessage(e, 'Could not send that request.'))
  }
}

/** Manager hands over the form for whichever room the student asked about. */
async function sendForm() {
  if (issuing.value || !inquiryRoom.value) return
  issuing.value = true
  try {
    const { id, label } = inquiryRoom.value
    await issueApplicationForm(props.conversationId, props.otherId, label)
    emit('system', `Sent you an application form for ${label}.`)
    invitedRoomId.value = id
    declined.value = null
    notify.success('Application form sent.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not send the application form.'))
  } finally {
    issuing.value = false
  }
}

async function loadApplyRoom(roomId: string) {
  const { data } = await supabase
    .from('rooms')
    .select(
      'id,label,room_number,monthly_rent,capacity,rent_basis,status,advance_months,deposit_months,accommodations(name,accommodation_manager_id,accommodation_policies(min_stay))',
    )
    .eq('id', roomId)
    .maybeSingle()

  const acc = data?.accommodations as unknown as {
    name: string | null
    accommodation_manager_id: string | null
    accommodation_policies: unknown
  } | null

  if (!data || !acc || acc.accommodation_manager_id !== props.otherId || data.status !== 'available') {
    applyRoom.value = null
    applyUnavailable.value = Boolean(data)
    return
  }

  const policyRows = acc.accommodation_policies as unknown
  const policyRow = (Array.isArray(policyRows) ? policyRows[0] : policyRows) as { min_stay: number | null } | null

  applyForm.startDate = todayStr()
  applyRoom.value = {
    id: data.id,
    label: data.label || (data.room_number ? `Room ${data.room_number}` : 'Room'),
    accommodation: acc.name || 'This accommodation',
    rent: Number(data.monthly_rent ?? 0),
    minStay: policyRow?.min_stay ?? 12,
    capacity: data.capacity ?? 1,
    rentBasis: data.rent_basis === 'person' ? 'person' : 'room',
    advanceMonths: Number(data.advance_months ?? 0),
    depositMonths: Number(data.deposit_months ?? 0),
  }
}

/** Manager opens the details. Loaded on demand — most threads never need it. */
async function openReview() {
  reviewOpen.value = true
  if (applicant.value) return
  const { data } = await supabase
    .from('student_profiles')
    .select('student_id,program,college,year_level,osas_verified_at')
    .eq('user_id', props.otherId)
    .maybeSingle()
  applicant.value = {
    studentNo: data?.student_id ?? null,
    program: data?.program ?? null,
    college: data?.college ?? null,
    yearLevel: data?.year_level ?? null,
    verified: Boolean(data?.osas_verified_at),
  }
}

async function submitApplication() {
  if (applying.value || !applyRoom.value) return
  applying.value = true
  try {
    const { data: studentProfile } = await supabase
      .from('student_profiles')
      .select('osas_verified_at')
      .eq('user_id', props.me)
      .maybeSingle()
    if (!studentProfile?.osas_verified_at) {
      notify.warning('Get OSAS-verified before applying for a room.')
      return
    }

    const room = applyRoom.value
    const { data: created, error: insertError } = await supabase
      .from('leases')
      .insert({
        room_id: room.id,
        student_id: props.me,
        accommodation_manager_id: props.otherId,
        start_date: applyForm.startDate,
        end_date: applyEndDate.value,
        // ponytail: "whole room" rent is split evenly assuming full occupancy;
        // a partially-filled room still charges this rate per tenant rather
        // than rebalancing existing co-tenants' leases as others join/leave.
        monthly_rent: monthlyDue.value,
        status: 'pending',
      })
      .select('id')
      .single()
    if (insertError) throw insertError

    void createNotification(
      props.otherId,
      'New application',
      `Applied for ${room.label}`,
      'lease',
      `/manager/messages?to=${props.me}`,
    )

    emit('system', `Applied for ${room.label} — move-in ${formatDate(applyForm.startDate)}.`)
    // The form has been used up; a second one has to be issued again.
    await clearApplicationInvite(props.conversationId)
    invitedRoomId.value = null
    declined.value = null
    application.value = {
      leaseId: created.id,
      roomLabel: room.label,
      startDate: applyForm.startDate,
      endDate: applyEndDate.value,
      monthlyRent: monthlyDue.value,
    }
    applyRoom.value = null
    reviewOpen.value = false
    notify.success('Application submitted.')
  } catch (e) {
    // 23505 = leases_one_current_per_student. Reachable if a stay began in
    // another thread while this form sat open; the raw text is unreadable.
    const code = (e as { code?: string } | null)?.code
    notify.error(
      code === '23505'
        ? 'You already have a current application or stay.'
        : errorMessage(e, 'Could not submit your application.'),
    )
    reviewOpen.value = false
    void refresh()
  } finally {
    applying.value = false
  }
}

async function decideApplication(next: 'active' | 'rejected') {
  if (deciding.value || !application.value) return
  deciding.value = true
  try {
    const { leaseId, roomLabel } = application.value
    const reason = declineReason.value.trim()
    await respondToApplication(leaseId, props.otherId, roomLabel, next, reason)
    emit(
      'system',
      next === 'active'
        ? `Accepted your application for ${roomLabel}.`
        : `Declined your application for ${roomLabel}. Reason: ${reason}`,
    )
    application.value = null
    reviewOpen.value = false
    declineOpen.value = false
    declineReason.value = ''
    notify.success(next === 'active' ? 'Application accepted.' : 'Application declined.')
    void refresh()
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update this application.'))
  } finally {
    deciding.value = false
  }
}

defineExpose({ refresh })
</script>

<style scoped>
.app-card {
  display: flex;
  flex: 0 0 auto;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px 12px;
  padding: 10px var(--m-page-gutter);
  border-bottom: 1px solid var(--m-border);
  background: var(--m-primary-soft);
}
.app-card-body {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 8px;
  color: var(--m-ink);
}
.app-card-text {
  font-size: 13px;
  font-weight: 600;
}
.app-card-reason {
  flex: 1 1 100%;
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
}
.app-card-status {
  margin-left: auto;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}
.app-card-actions {
  display: flex;
  margin-left: auto;
  gap: 8px;
}
.app-field {
  display: flex;
  flex: 1 1 100%;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}
.app-field-label {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.app-date {
  padding: 7px 10px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-text);
  font: inherit;
  font-size: 13px;
}
.app-btn {
  min-height: 34px;
  padding: 0 14px;
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
.app-btn:disabled {
  opacity: 0.6;
}
.app-btn--ghost {
  background: var(--m-surface);
  color: var(--m-text);
  border: 1px solid var(--m-border);
}
.app-btn--submit {
  flex: 1 1 100%;
  min-height: 40px;
}
.sheet {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 12px;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0;
  background: var(--m-surface);
}
.sheet-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.sheet-note {
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
}
.sheet-input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  color: var(--m-text);
  font: inherit;
  font-size: 14px;
  resize: none;
}
.sheet-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
.who {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}
.who-name {
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
}
.who-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 700;
}
.who-chip--ok {
  background: rgba(16, 148, 96, 0.12);
  color: #0f7a50;
}
.who-chip--warn {
  background: rgba(200, 120, 0, 0.14);
  color: #a35c00;
}
.sum {
  display: flex;
  margin: 0;
  flex-direction: column;
  gap: 2px;
}
.sum-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 16px;
  padding: 7px 0;
  border-bottom: 1px solid var(--m-border);
}
.sum-row:last-child {
  border-bottom: 0;
}
.sum-row dt {
  flex: 0 0 auto;
  color: var(--m-muted);
  font-size: 12.5px;
}
.sum-row dd {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  font-weight: 600;
  text-align: right;
}
.sum-row--total dt,
.sum-row--total dd {
  color: var(--m-ink);
  font-size: 14.5px;
  font-weight: 700;
}
</style>
