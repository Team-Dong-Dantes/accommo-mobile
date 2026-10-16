<template>
  <!-- Waiting on OSAS: a new listing, a resubmission or an appeal. -->
  <div v-if="props.status === 'pending' || props.status === 'reviewing'" class="box">
    <span class="box-head">
      <IconifyIcon :icon="props.status === 'reviewing' ? 'lucide:eye' : 'lucide:hourglass'" width="16" />
      {{ props.status === 'reviewing' ? 'OSAS is reviewing it now' : 'Waiting for OSAS' }}
    </span>
    <p class="box-text">
      {{ openRound ? `${KIND_LABEL[openRound.kind]} sent ${since(openRound.submitted_at)} ago.` : 'Sent to OSAS.' }}
      {{ waitLine }}
    </p>
    <p class="box-text">The location is locked until OSAS decides.</p>
  </div>

  <!-- Sent back: exactly what to fix, and the way back in. -->
  <div v-else-if="props.status === 'needs_revision'" class="box box--warn">
    <span class="box-head"><IconifyIcon icon="lucide:file-pen" width="16" /> What OSAS needs</span>
    <p v-if="lastReturned?.note" class="quote">“{{ lastReturned.note }}”</p>
    <p v-if="lastReturned?.tags?.length" class="box-text">{{ lastReturned.tags.join(' · ') }}</p>
    <div v-if="flagged.length" class="flag-list">
      <div v-for="f in flagged" :key="f.type" class="flag-row">
        <span class="flag-icon" :class="f.replaced ? 'flag-icon--done' : 'flag-icon--todo'">
          <IconifyIcon :icon="f.replaced ? 'lucide:check' : 'lucide:file-warning'" width="15" />
        </span>
        <span class="flag-body">
          <span class="flag-name">{{ permitLabel(f.type) }}</span>
          <span class="flag-when">{{ f.replaced ? 'Replaced' : 'Needs a new file' }}</span>
        </span>
        <button type="button" class="pill-btn" @click="openReplace(f.type)">
          {{ f.replaced ? 'Change' : 'Replace' }}
        </button>
      </div>
    </div>
    <p v-else class="box-text">Make the changes OSAS asked for, then resubmit.</p>
    <textarea v-model="message" class="note-input" rows="2" maxlength="1000" placeholder="Note for OSAS (optional)" />
    <button type="button" class="main-btn" :disabled="!allReplaced || busy" @click="resubmit">
      {{ busy ? 'Sending…' : allReplaced ? 'Resubmit to OSAS' : `Replace ${unreplacedCount} more permit${unreplacedCount === 1 ? '' : 's'} first` }}
    </button>
  </div>

  <!-- Refused: one appeal, then it is final. -->
  <div v-else-if="props.status === 'rejected'" class="box box--danger">
    <span class="box-head"><IconifyIcon icon="lucide:circle-x" width="16" /> OSAS refused this listing</span>
    <p v-if="lastDecided?.note" class="quote">“{{ lastDecided.note }}”</p>
    <template v-if="canAppeal">
      <p class="box-text">If you think OSAS got it wrong, you can appeal once. Say what OSAS should look at again.</p>
      <textarea v-model="message" class="note-input" rows="3" maxlength="1000" placeholder="Why should OSAS reconsider?" />
      <button type="button" class="main-btn" :disabled="!message.trim() || busy" @click="appeal">
        {{ busy ? 'Sending…' : 'Appeal this decision' }}
      </button>
    </template>
    <p v-else class="box-text">OSAS upheld its decision on appeal. This is final; it is hidden from students.</p>
    <button type="button" class="pill-btn pill-btn--danger" @click="emit('delete')">Delete this accommodation</button>
  </div>

  <!-- Live. -->
  <div v-else-if="props.status === 'accredited' || props.status === 'delisted'" class="box">
    <span class="box-head"><IconifyIcon icon="lucide:shield-check" width="16" /> Accredited{{ expiresAt ? ` until ${longDate(expiresAt)}` : '' }}</span>
    <p v-if="daysLeft !== null && daysLeft <= RENEW_WINDOW_DAYS" class="box-text">
      {{ daysLeft <= 0 ? 'The term ends today.' : `The term ends in ${daysLeft} day${daysLeft === 1 ? '' : 's'}.` }}
      Renew now so it stays visible to students.
    </p>
    <template v-if="openRound">
      <p class="box-text box-text--strong">
        OSAS is reviewing your {{ KIND_LABEL[openRound.kind].toLowerCase() }}{{ props.status === 'accredited' ? ' — the listing stays visible meanwhile' : '' }}.
      </p>
      <div v-if="openRound.kind === 'change' && changeRows.length" class="change-list">
        <div v-for="row in changeRows" :key="row.label" class="change-row">
          <span class="change-label">{{ row.label }}</span>
          <span class="change-value">{{ row.to }}</span>
        </div>
        <button type="button" class="pill-btn" :disabled="busy" @click="withdrawChange">Withdraw change</button>
      </div>
    </template>
    <button
      v-else-if="daysLeft !== null && daysLeft <= RENEW_WINDOW_DAYS"
      type="button"
      class="main-btn"
      :disabled="busy"
      @click="renew"
    >
      {{ busy ? 'Sending…' : 'Renew accreditation' }}
    </button>
  </div>

  <div v-else-if="props.status === 'expired'" class="box box--danger">
    <span class="box-head"><IconifyIcon icon="lucide:calendar-x" width="16" /> Accreditation ended</span>
    <p class="box-text">
      {{ expiresAt && new Date(expiresAt) < new Date() ? `The term ended ${longDate(expiresAt)}.` : 'A permit expired.' }}
      It is hidden from students until OSAS renews it. Make sure every permit is current first.
    </p>
    <p v-if="openRound" class="box-text box-text--strong">Renewal sent — OSAS is reviewing it.</p>
    <button v-else type="button" class="main-btn" :disabled="busy" @click="renew">
      {{ busy ? 'Sending…' : 'Renew accreditation' }}
    </button>
  </div>

  <div v-else-if="props.status === 'suspended'" class="box box--danger">
    <span class="box-head"><IconifyIcon icon="lucide:ban" width="16" /> Suspended by OSAS</span>
    <p class="box-text">It is hidden from students. Your boarders were told. Contact OSAS to find out what to fix.</p>
    <button type="button" class="pill-btn" @click="router.push('/manager/osas')">Contact OSAS</button>
  </div>
</template>

<script setup lang="ts">
// Where accreditation stands, and the one thing to do about it.
import { Icon as IconifyIcon } from '@iconify/vue'
import { KIND_LABEL, RENEW_WINDOW_DAYS } from './model'
import { permitLabel } from '@/utils/permits'
import { since } from '@/utils/notifications'
import { useAccreditation } from './accreditation'

const {
  props,
  emit,
  router,
  message,
  busy,
  expiresAt,
  daysLeft,
  openRound,
  lastDecided,
  lastReturned,
  canAppeal,
  flagged,
  unreplacedCount,
  allReplaced,
  waitLine,
  changeRows,
  longDate,
  resubmit,
  appeal,
  renew,
  withdrawChange,
  openReplace,
} = useAccreditation()
</script>

<style scoped>
.box {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
}
.box--warn { border-color: color-mix(in srgb, var(--m-warning) 45%, var(--m-border)); }
.box--danger { border-color: color-mix(in srgb, var(--m-danger) 40%, var(--m-border)); }
.box-head {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.box-head :deep(svg) { color: var(--m-primary-dark); }
.box--warn .box-head :deep(svg) { color: var(--m-warning); }
.box--danger .box-head :deep(svg) { color: var(--m-danger); }
.box-text { margin: 0; color: var(--m-muted); font-size: 12.5px; line-height: 1.45; }
.box-text--strong { color: var(--m-ink); font-weight: 600; }
.quote {
  margin: 0;
  padding: 8px 10px;
  border-left: 3px solid var(--m-warning);
  border-radius: 0 var(--m-radius-sm) var(--m-radius-sm) 0;
  background: var(--m-surface);
  color: var(--m-ink);
  font-size: 13px;
  line-height: 1.45;
}
.box--danger .quote { border-left-color: var(--m-danger); }
.flag-list {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.flag-row { display: flex; align-items: center; gap: 10px; padding: 10px 12px; border-top: 1px solid var(--m-border); }
.flag-row:first-child { border-top: 0; }
.flag-icon {
  display: grid;
  width: 30px;
  height: 30px;
  flex: 0 0 30px;
  place-items: center;
  border-radius: 999px;
}
.flag-icon--todo { background: var(--m-warning-soft); color: var(--m-warning); }
.flag-icon--done { background: var(--m-success-soft); color: var(--m-success); }
.flag-body { display: flex; min-width: 0; flex: 1; flex-direction: column; gap: 1px; }
.flag-name { color: var(--m-ink); font-size: 13px; font-weight: 700; }
.flag-when { color: var(--m-muted); font-size: 11px; }
.note-input {
  box-sizing: border-box;
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
  resize: vertical;
}
.main-btn {
  min-height: 46px;
  padding: 0 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.main-btn:disabled { background: var(--m-border); color: var(--m-muted); cursor: not-allowed; }
.pill-btn {
  align-self: flex-start;
  min-height: 36px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.flag-row .pill-btn { align-self: center; }
.pill-btn--danger { border-color: var(--m-danger); background: var(--m-danger-soft); color: var(--m-danger); }
.pill-btn:disabled { opacity: 0.6; }
.change-list { display: flex; flex-direction: column; gap: 6px; }
.change-row { display: flex; justify-content: space-between; gap: 12px; font-size: 12.5px; }
.change-label { color: var(--m-muted); }
.change-value { color: var(--m-ink); font-weight: 600; text-align: right; overflow-wrap: anywhere; }
</style>
