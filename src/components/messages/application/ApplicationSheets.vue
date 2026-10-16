<template>
  <!-- Student: what they are committing to, before anything is written. -->
  <AppModal v-model="reviewOpen" :title="props.role === 'student' ? 'Review your application' : 'Review application'">
    <template v-if="props.role === 'student' && applyRoom">
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
        <div v-for="u in UTILITIES" :key="u.key" class="sum-row">
          <dt>{{ u.label }}</dt>
          <dd>{{ utilityTermsLabel(applyRoom.utilities[u.key]) }}</dd>
        </div>
        <div v-if="monthlyFees" class="sum-row">
          <dt>Monthly total</dt>
          <dd>{{ formatPeso(monthlyDue + monthlyFees) }} <span class="sum-sub">rent + flat fees</span></dd>
        </div>
        <div v-if="applyRoom.advanceMonths" class="sum-row">
          <dt>Advance</dt>
          <dd>{{ applyRoom.advanceMonths === 1 ? 'first month' : `first ${applyRoom.advanceMonths} months` }} of rent · {{ formatPeso(monthlyDue * applyRoom.advanceMonths) }}</dd>
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
        Your {{ otherTitle }} decides on this application. Nothing is charged through Accommo.
      </p>
    </template>

    <!-- Manager: who is applying and on what terms, with both decisions here so
         an application cannot be approved without the details in view. -->
    <template v-else-if="props.role === 'manager' && application">
      <div class="who">
        <span class="who-name">{{ props.otherName }}</span>
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
        <div v-for="u in UTILITIES" :key="u.key" class="sum-row">
          <dt>{{ u.label }}</dt>
          <dd>{{ utilityTermsLabel(application.utilities[u.key]) }}</dd>
        </div>
        <div class="sum-row sum-row--total">
          <dt>Monthly rent</dt>
          <dd>{{ formatPeso(application.monthlyRent) }}</dd>
        </div>
      </dl>
      <!-- Applying no longer waits for OSAS, but moving in does: the database
           refuses the acceptance until the student is verified, so say so
           instead of offering a button that fails. -->
      <p v-if="!applicant?.verified" class="sheet-note">
        OSAS has not verified this student yet. You can accept once they do; scan their QR in person to see the documents they sent.
      </p>
    </template>

    <template #footer>
      <template v-if="props.role === 'student' && applyRoom">
        <button type="button" class="app-btn app-btn--ghost" @click="reviewOpen = false">Back</button>
        <button type="button" class="app-btn" :disabled="applying" @click="submitApplication">
          {{ applying ? 'Submitting…' : 'Submit application' }}
        </button>
      </template>
      <template v-else-if="props.role === 'manager' && application">
        <button type="button" class="app-btn app-btn--ghost" :disabled="deciding" @click="reviewOpen = false; declineOpen = true">
          Decline
        </button>
        <button type="button" class="app-btn" :disabled="deciding || !applicant?.verified" @click="decideApplication('active')">
          {{ deciding ? 'Accepting…' : 'Accept' }}
        </button>
      </template>
    </template>
  </AppModal>

  <!-- A decline the student can act on: the reason reaches them in the
       notification and stays on the lease. -->
  <AppModal v-model="declineOpen" title="Decline application" size="sm">
    <p class="sheet-note">The student sees this reason.</p>
    <textarea v-model="declineReason" class="sheet-input" rows="3" placeholder="Why are you declining?" />
    <template #footer>
      <button type="button" class="app-btn app-btn--ghost" @click="declineOpen = false">Cancel</button>
      <button
        type="button"
        class="app-btn"
        :disabled="!declineReason.trim() || deciding"
        @click="decideApplication('rejected')"
      >
        {{ deciding ? 'Declining…' : 'Decline' }}
      </button>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
// The handshake's sheets: the student's review before applying, the
// landlord/landlady's review of an application, and declining one.
import AppModal from '@/components/shared/AppModal.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { UTILITIES, utilityTermsLabel } from '@/utils/listings'
import { formatDate, formatPeso } from '@/utils/format'
import { useApplication } from './application'

const {
  props,
  application,
  applyRoom,
  otherTitle,
  applyForm,
  applying,
  deciding,
  reviewOpen,
  declineOpen,
  declineReason,
  applicant,
  monthlyDue,
  monthlyFees,
  upfrontTotal,
  submitApplication,
  decideApplication,
} = useApplication()
</script>

<style scoped>
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
.sum-sub {
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 500;
}
</style>
