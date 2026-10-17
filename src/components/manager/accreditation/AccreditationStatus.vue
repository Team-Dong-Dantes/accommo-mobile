<template>
  <!-- Waiting on OSAS: a new listing, a resubmission or an appeal. -->
  <StatusBox
    v-if="props.status === 'pending' || props.status === 'reviewing'"
    :icon="props.status === 'reviewing' ? 'lucide:eye' : 'lucide:hourglass'"
    :title="props.status === 'reviewing' ? 'OSAS is reviewing it now' : 'Waiting for OSAS'"
  >
    <p class="box-text">
      {{ openRound ? `${KIND_LABEL[openRound.kind]} sent ${since(openRound.submitted_at)} ago.` : 'Sent to OSAS.' }}
      {{ waitLine }}
    </p>
    <p class="box-text">The location is locked until OSAS decides.</p>
  </StatusBox>

  <!-- Sent back: exactly what to fix, and the way back in. -->
  <StatusBox v-else-if="props.status === 'needs_revision'" tone="warn" icon="lucide:file-pen" title="What OSAS needs">
    <p v-if="lastReturned?.note" class="quote">“{{ lastReturned.note }}”</p>
    <p v-if="lastReturned?.tags?.length" class="box-text">{{ lastReturned.tags.join(' · ') }}</p>
    <ReplaceList
      v-if="flagged.length"
      :items="flagged.map((f) => ({ type: f.type, label: permitLabel(f.type), replaced: f.replaced }))"
      @replace="openReplace"
    />
    <p v-else class="box-text">Make the changes OSAS asked for, then resubmit.</p>
    <textarea v-model="message" class="note-input" rows="2" maxlength="1000" placeholder="Note for OSAS (optional)" />
    <button type="button" class="main-btn" :disabled="!allReplaced || busy" @click="resubmit">
      {{ busy ? 'Sending…' : allReplaced ? 'Resubmit to OSAS' : `Replace ${unreplacedCount} more permit${unreplacedCount === 1 ? '' : 's'} first` }}
    </button>
  </StatusBox>

  <!-- Refused: one appeal, then it is final. -->
  <StatusBox v-else-if="props.status === 'rejected'" tone="danger" icon="lucide:circle-x" title="OSAS refused this listing">
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
  </StatusBox>

  <!-- Live. -->
  <StatusBox
    v-else-if="props.status === 'accredited' || props.status === 'delisted'"
    icon="lucide:shield-check"
    :title="`Accredited${expiresAt ? ` until ${longDate(expiresAt)}` : ''}`"
  >
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
  </StatusBox>

  <StatusBox v-else-if="props.status === 'expired'" tone="danger" icon="lucide:calendar-x" title="Accreditation ended">
    <p class="box-text">
      {{ expiresAt && new Date(expiresAt) < new Date() ? `The term ended ${longDate(expiresAt)}.` : 'A permit expired.' }}
      It is hidden from students until OSAS renews it. Make sure every permit is current first.
    </p>
    <p v-if="openRound" class="box-text box-text--strong">Renewal sent — OSAS is reviewing it.</p>
    <button v-else type="button" class="main-btn" :disabled="busy" @click="renew">
      {{ busy ? 'Sending…' : 'Renew accreditation' }}
    </button>
  </StatusBox>

  <StatusBox v-else-if="props.status === 'suspended'" tone="danger" icon="lucide:ban" title="Suspended by OSAS">
    <p class="box-text">It is hidden from students. Your boarders were told. Contact OSAS to find out what to fix.</p>
    <button type="button" class="pill-btn" @click="router.push('/manager/osas')">Contact OSAS</button>
  </StatusBox>
</template>

<script setup lang="ts">
// Where accreditation stands, and the one thing to do about it.
import { KIND_LABEL, RENEW_WINDOW_DAYS } from './model'
import { permitLabel } from '@/utils/permits'
import { since } from '@/utils/notifications'
import { useAccreditation } from './accreditation'
import StatusBox from '@/components/shared/StatusBox.vue'
import ReplaceList from '@/components/shared/ReplaceList.vue'

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
.change-list { display: flex; flex-direction: column; gap: 6px; }
.change-row { display: flex; justify-content: space-between; gap: 12px; font-size: 12.5px; }
.change-label { color: var(--m-muted); }
.change-value { color: var(--m-ink); font-weight: 600; text-align: right; overflow-wrap: anywhere; }
</style>
