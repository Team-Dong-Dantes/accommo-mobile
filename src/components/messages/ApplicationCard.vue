<template>
  <!-- The tenancy handshake, as a banner above the conversation: ask → manager
       issues a form → student fills it → manager decides. Extracted from
       ChatThread so the messaging side stays messaging. -->

  <!-- Student: where they are in that handshake. The room page only offers "Ask
       to apply", so this is the one place the remaining steps are spelled out. -->
  <ol v-if="studentStep !== null" class="app-steps" aria-label="Application progress">
    <li
      v-for="(label, i) in STUDENT_STEPS"
      :key="label"
      class="app-step"
      :class="{ 'app-step--done': i < studentStep, 'app-step--on': i === studentStep }"
      :aria-current="i === studentStep ? 'step' : undefined"
    >
      <IconifyIcon v-if="i < studentStep" icon="lucide:check" width="12" />
      <span v-else class="app-step-no">{{ i + 1 }}</span>
      {{ label }}
    </li>
  </ol>
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
        {{ applyRoom.label }} · {{ formatPeso(monthlyDue) }}/mo{{ applyRoom.capacity > 1 ? (applyRoom.rentBasis === 'person' ? ' per person' : ' your share') : '' }}
      </span>
    </div>
    <label class="app-field">
      <span class="app-field-label">Move-in date</span>
      <DateTimeField v-model="applyForm.startDate" mode="date" :min="todayStr()" placeholder="Pick a move-in date" />
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

  <!-- No application in flight and no form issued yet. The form is the landlord/landlady's
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
    <!-- A student OSAS turned down, suspended or paused cannot be issued a form,
         so they are not offered the request at all — the reason stands in for
         the button. Unverified is not a reason: they may apply, only not move in. -->
    <p v-if="applyBlocked" class="app-card-reason">{{ applyBlocked }}</p>
    <div v-if="applyBlocked && owesPast" class="app-card-actions">
      <button type="button" class="app-btn" @click="router.push('/student/payments')">Pay the balance</button>
    </div>
    <div v-else-if="!applyBlocked" class="app-card-actions">
      <button type="button" class="app-btn app-btn--ghost" :disabled="requesting" @click="requestForm">
        {{ requesting ? 'Requested' : declined ? 'Ask for another form' : 'Request application form' }}
      </button>
    </div>
  </div>

  <ApplicationSheets />
</template>

<script setup lang="ts">
import ApplicationSheets from './application/ApplicationSheets.vue'
import DateTimeField from '@/components/shared/DateTimeField.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { STUDENT_STEPS, todayStr } from '@/components/messages/application/model'
import { formatPeso } from '@/utils/format'
import { provideApplication } from './application/application'

// The handshake's state lives in ./application/; this is the banner itself.
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


const {
  router,
  application,
  applyRoom,
  applyUnavailable,
  applyForm,
  applying,
  deciding,
  inquiryRoom,
  invitedRoomId,
  otherLease,
  declined,
  issuing,
  requesting,
  applyBlocked,
  owesPast,
  reviewOpen,
  monthlyDue,
  isMyTenant,
  canViewOtherLease,
  studentStep,
  viewOtherLease,
  refresh,
  requestForm,
  sendForm,
  openReview,
} = provideApplication({ props, emit })

defineExpose({ refresh })
</script>

<style scoped>
/* Sits directly on top of the card below, same tint, so the two read as one banner. */
.app-steps {
  display: flex;
  flex: 0 0 auto;
  gap: 6px;
  margin: 0;
  padding: 10px var(--m-page-gutter) 0;
  list-style: none;
  background: var(--m-primary-soft);
}
.app-step {
  display: flex;
  flex: 1 1 0;
  min-width: 0;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
  white-space: nowrap;
}
.app-step-no {
  display: inline-grid;
  width: 16px;
  height: 16px;
  flex: 0 0 auto;
  place-items: center;
  border: 1px solid currentColor;
  border-radius: 50%;
  font-size: 10px;
}
.app-step--done {
  color: var(--m-primary);
}
.app-step--on {
  color: var(--m-ink);
}
.app-step--on .app-step-no {
  border-color: var(--m-primary);
  background: var(--m-primary);
  color: #fff;
}
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
</style>
