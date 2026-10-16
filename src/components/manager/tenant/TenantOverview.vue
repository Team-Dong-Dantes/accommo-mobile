<template>
  <!-- Decisions -->
  <div v-if="lease.status === 'pending'" class="decide-box">
    <div v-if="decisionReasonFor === 'reject'" class="decide-reason">
      <label class="decide-reason-label">
        Reason for declining
        <textarea v-model="decisionReason" class="decide-reason-textarea" rows="2" placeholder="Let the student know why…" />
      </label>
      <div class="decide-reason-actions">
        <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = ''">Cancel</button>
        <button
          type="button"
          class="decide-btn decide-btn--danger"
          :disabled="deciding || !decisionReason.trim()"
          @click="decide('rejected')"
        >
          {{ deciding ? 'Declining…' : 'Confirm decline' }}
        </button>
      </div>
    </div>
    <div v-else class="decide">
      <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = 'reject'; decisionReason = ''">
        Decline
      </button>
      <!-- Added by hand: accepted only by scanning their QR (DB-enforced). -->
      <template v-if="lease.addedByLandlord">
        <button
          type="button"
          class="decide-btn"
          @click="router.push(`/manager/profile/qr-scanner?accept=${leaseId}`)"
        >
          Scan to accept
        </button>
      </template>
      <button v-else type="button" class="decide-btn" :disabled="deciding" @click="decide('active')">
        Accept
      </button>
    </div>
  </div>
  <div v-else-if="lease.status === 'leave_requested'" class="decide-box">
    <p class="leave-ask">
      <IconifyIcon icon="lucide:log-out" width="16" />
      <span>Wants to move out on <b>{{ formatDate(lease.leaveDate) }}</b>. If you approve, the stay runs until then.</span>
    </p>
    <div v-if="decisionReasonFor === 'keep'" class="decide-reason">
      <label class="decide-reason-label">
        Reason for keeping the boarder
        <textarea v-model="decisionReason" class="decide-reason-textarea" rows="2" placeholder="Let the student know why…" />
      </label>
      <div class="decide-reason-actions">
        <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = ''">Cancel</button>
        <button
          type="button"
          class="decide-btn decide-btn--danger"
          :disabled="deciding || !decisionReason.trim()"
          @click="declineLeave"
        >
          {{ deciding ? 'Sending…' : 'Confirm' }}
        </button>
      </div>
    </div>
    <div v-else class="decide">
      <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = 'keep'; decisionReason = ''">
        Keep boarder
      </button>
      <button type="button" class="decide-btn" :disabled="deciding" @click="approveLeave">
        Approve leave
      </button>
    </div>
  </div>
  <!-- Asked of the landlord/landlady once the stay is over. -->
  <div v-else-if="(lease.status === 'ended' || lease.status === 'terminated') && !tenantReview" class="decide-box decide">
    <button type="button" class="decide-btn" @click="openReview">Rate this boarder</button>
  </div>

  <!-- Stay: where today falls between move-in and the lease's end. -->
  <h2 class="sec-title ov-title">Stay</h2>
  <div class="ov-card">
    <div class="tl-ends">
      <span class="tl-end"><span class="tl-k">Move-in</span>{{ formatDate(lease.startDate) }}</span>
      <span class="tl-end tl-end--r"><span class="tl-k">Lease ends</span>{{ formatDate(lease.endDate) }}</span>
    </div>
    <div class="tl-track" role="progressbar" :aria-valuenow="stay.pct" aria-valuemin="0" aria-valuemax="100" :aria-label="stay.label">
      <span class="tl-fill" :style="{ width: `${stay.pct}%` }" />
    </div>
    <p class="tl-label">{{ stay.label }}</p>
    <p v-if="lease.status === 'active' && lease.leaveDate" class="tl-note">
      <IconifyIcon icon="lucide:log-out" width="14" />
      <span>Moving out on <b>{{ formatDate(lease.leaveDate) }}</b> — you approved it.</span>
    </p>
    <div class="ov-rent">
      <span class="ov-rent-amt">{{ formatPeso(lease.monthlyRent) }}</span>
      <span class="ov-rent-per">a month</span>
      <span v-if="tenantReview" class="ov-rated">
        <StarRating :model-value="tenantReview.rating" :size="13" />
        <span>your rating</span>
      </span>
    </div>
  </div>

  <template v-if="lease.email || lease.phone">
    <h2 class="sec-title ov-title">Contact</h2>
    <div class="ov-contact">
      <a v-if="lease.email" :href="`mailto:${lease.email}`" class="ov-tile">
        <span class="ov-tile-ic"><IconifyIcon icon="lucide:mail" width="16" /></span>
        <span class="ov-tile-k">Email</span>
        <span class="ov-tile-v">{{ lease.email }}</span>
      </a>
      <a v-if="lease.phone" :href="`tel:${lease.phone}`" class="ov-tile">
        <span class="ov-tile-ic"><IconifyIcon icon="lucide:phone" width="16" /></span>
        <span class="ov-tile-k">Call</span>
        <span class="ov-tile-v">{{ lease.phone }}</span>
      </a>
    </div>
</template>

<!-- Ending a stay is rare and final: a quiet link, not a button
     beside everything else. -->
<template v-if="lease.status === 'active'">
  <div v-if="decisionReasonFor === 'end'" class="decide-box decide-reason ov-end-form">
    <label class="decide-reason-label">
      Why is this stay ending?
      <textarea v-model="decisionReason" class="decide-reason-textarea" rows="2" placeholder="The student sees this…" />
    </label>
    <p class="decide-note" style="margin: 0; text-align: left">End it when the term is over or they moved out. Terminate it only for breaking the house rules.</p>
    <div class="decide-reason-actions">
      <button type="button" class="decide-btn decide-btn--ghost" :disabled="deciding" @click="decisionReasonFor = ''">Cancel</button>
      <button type="button" class="decide-btn decide-btn--danger" :disabled="deciding || !decisionReason.trim()" @click="endStay(true)">Terminate</button>
      <button type="button" class="decide-btn" :disabled="deciding || !decisionReason.trim()" @click="endStay(false)">
        {{ deciding ? 'Ending…' : 'End stay' }}
      </button>
    </div>
  </div>
  <button v-else type="button" class="ov-end" :disabled="deciding" @click="decisionReasonFor = 'end'; decisionReason = ''">
    End this stay<IconifyIcon icon="lucide:chevron-right" width="14" />
  </button>
</template>
</template>

<script setup lang="ts">
// The Overview tab: the pending decision (application or leave), the stay
// bar, contact tiles and ending the stay.
import { Icon as IconifyIcon } from '@iconify/vue'
import StarRating from '@/components/shared/StarRating.vue'
import { formatDate, formatPeso } from '@/utils/format'
import { useTenant } from './tenant'

const {
  router,
  deciding,
  lease,
  tenantReview,
  leaseId,
  stay,
  decisionReasonFor,
  decisionReason,
  decide,
  approveLeave,
  endStay,
  declineLeave,
  openReview,
} = useTenant()
</script>

<style scoped>
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
.decide-note {
  flex: 1;
  align-self: center;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
  text-align: center;
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
.decide-btn--danger {
  background: var(--m-danger);
}
.decide-reason {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.decide-reason-label {
  display: flex;
  flex-direction: column;
  gap: 4px;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.decide-reason-textarea {
  min-height: 60px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
  text-transform: none;
  letter-spacing: normal;
  font-weight: 400;
  resize: vertical;
}
.decide-reason-actions {
  display: flex;
  gap: 8px;
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
.leave-ask {
  display: flex;
  gap: 8px;
  margin: 0 0 10px;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.45;
  text-align: left;
}
.leave-ask > :first-child {
  flex: 0 0 auto;
  margin-top: 2px;
  color: var(--m-warning);
}
/* ---- Overview ----
   Stay and Contact are each one recessed card on the panel (--m-bg on
   --m-surface, so the card reads as its own). */
.ov-title {
  margin-top: 16px;
}
.decide-box + .ov-title {
  margin-top: 18px;
}
.ov-card {
  display: flex;
  flex-direction: column;
  padding: 14px 14px 0;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
}
.tl-ends {
  display: flex;
  justify-content: space-between;
  gap: 12px;
}
.tl-end {
  display: flex;
  flex-direction: column;
  gap: 2px;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.tl-end--r {
  text-align: right;
}
.tl-k {
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.tl-track {
  height: 8px;
  margin-top: 12px;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-border);
}
.tl-fill {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: var(--m-primary);
}
.tl-label {
  margin: 8px 0 0;
  color: var(--m-text);
  font-size: 12.5px;
  font-weight: 600;
}
.tl-note {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  margin: 8px 0 0;
  color: var(--m-text);
  font-size: 12.5px;
  line-height: 1.4;
}
.tl-note > :first-child {
  flex: none;
  margin-top: 1px;
  color: var(--m-warning);
}
/* Rent closes the card on its own band, the one figure worth reading big. */
.ov-rent {
  display: flex;
  align-items: baseline;
  gap: 6px;
  margin: 14px -14px 0;
  padding: 12px 14px;
  border-top: 1px solid var(--m-border);
}
.ov-rent-amt {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 800;
}
.ov-rent-per {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.ov-rated {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-left: auto;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
/* Contact: a tile per way to reach them, tapping it calls or writes. */
.ov-contact {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 8px;
}
.ov-tile {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  align-items: center;
  gap: 2px 10px;
  min-height: 56px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  color: inherit;
  text-decoration: none;
  -webkit-tap-highlight-color: transparent;
}
.ov-tile-ic {
  display: grid;
  grid-row: span 2;
  width: 32px;
  height: 32px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.ov-tile-k {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.ov-tile-v {
  overflow: hidden;
  color: var(--m-muted);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ov-end {
  display: inline-flex;
  align-self: center;
  align-items: center;
  gap: 2px;
  margin-top: 22px;
  padding: 10px 12px;
  border: 0;
  background: transparent;
  color: var(--m-danger);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.ov-end-form {
  margin-top: 18px;
}
</style>
