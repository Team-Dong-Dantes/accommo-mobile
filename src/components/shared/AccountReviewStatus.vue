<template>
  <!-- An account's verification, told the way a listing's accreditation is
       (AccreditationStatus): where it stands, and the one thing to do. -->
  <StatusBox
    v-if="status === 'pending' || status === 'reviewing'"
    :icon="status === 'reviewing' ? 'lucide:eye' : 'lucide:hourglass'"
    :title="status === 'reviewing' ? 'OSAS is reviewing it now' : 'Waiting for OSAS'"
  >
    <p class="box-text">{{ lastSent ? `Sent ${since(lastSent)} ago.` : 'Sent to OSAS.' }} {{ unlocks }}</p>
  </StatusBox>

  <!-- Sent back: OSAS's reason and the way back in. Each document's state and
       its Replace button are the requirement rows just above, not repeated here. -->
  <StatusBox v-else-if="status === 'rejected' || status === 'needs_resubmission'" tone="warn" icon="lucide:file-pen" title="What OSAS needs">
    <p v-if="reason" class="quote">“{{ reason }}”</p>
    <p class="box-text">Replace what OSAS asked about above, then resubmit. {{ unlocks }}</p>
    <button type="button" class="main-btn" :disabled="!replacedAny || busy" @click="emit('resubmit')">
      {{ busy ? 'Sending…' : replacedAny ? 'Resubmit to OSAS' : 'Replace a document first' }}
    </button>
  </StatusBox>

  <StatusBox v-else-if="status === 'verified'" icon="lucide:shield-check" title="Verified by OSAS">
    <p v-if="decision?.status === 'approved'" class="box-text">Approved {{ longDate(decision.reviewed_at) }}.</p>
  </StatusBox>

  <StatusBox v-else-if="status === 'suspended'" tone="danger" icon="lucide:ban" title="Suspended by OSAS">
    <p class="box-text">Raise a ticket to find out what to fix.</p>
  </StatusBox>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { parseServerTime } from '@/utils/format'
import { since } from '@/utils/notifications'
import type { AccountDecision } from '@/utils/profile'
import StatusBox from './StatusBox.vue'

const props = withDefaults(
  defineProps<{
    status: string
    /** OSAS's latest decision on the account, newest first from verification_requests. */
    decision: AccountDecision | null
    /** When each requirement's current file was sent (null: never). */
    sentAt: (string | null)[]
    /** What verification opens up, said while it waits. */
    unlocks?: string
    busy?: boolean
  }>(),
  { unlocks: '', busy: false },
)
const emit = defineEmits<{ resubmit: [] }>()

const reason = computed(() => props.decision?.decision_notes || (props.decision?.rejection_reasons ?? []).join(' · '))
const lastSent = computed(() => props.sentAt.filter(Boolean).sort().pop() ?? null)

// OSAS decides on the account, not per document, so anything sent after its
// decision counts as a fix.
const decidedAt = computed(() => (props.decision ? parseServerTime(props.decision.reviewed_at).getTime() : 0))
const replacedAny = computed(() => props.sentAt.some((at) => at && parseServerTime(at).getTime() > decidedAt.value))

function longDate(iso: string) {
  return parseServerTime(iso).toLocaleDateString('en-PH', { month: 'long', day: 'numeric', year: 'numeric' })
}
</script>
