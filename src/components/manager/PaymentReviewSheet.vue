<template>
  <AppModal :model-value="modelValue" tall @update:model-value="emit('update:modelValue', $event)">
    <template #header>
      <button v-if="mode === 'reject'" type="button" class="rv-back" aria-label="Back to the payment" @click="mode = ''">
        <IconifyIcon icon="lucide:chevron-left" width="20" />
      </button>
      <template v-if="mode === 'reject'">
        <span class="mx-head">
          <h3 class="mx-head-title">Why reject it?</h3>
          <span class="mx-head-sub">{{ who.name }} · {{ formatPesoExact(total) }} by {{ methodLabel }}</span>
        </span>
      </template>
      <template v-else>
        <span class="rv-avatar" :class="who.color ? [`bg-${who.color}`, 'text-white'] : []">
          <img v-if="who.avatar" :src="who.avatar" alt="" />
          <template v-else>{{ initialsOf(who.name) }}</template>
        </span>
        <span class="mx-head">
          <span class="rv-name">{{ who.name }}</span>
          <span class="mx-head-sub">{{ who.place }}<template v-if="sentAt"> · sent {{ formatDate(sentAt) }}</template></span>
        </span>
        <span v-if="pending && waitDays >= 1" class="rv-wait" :class="{ 'rv-wait--long': waitDays >= 3 }">
          Waiting {{ waitDays }} day{{ waitDays === 1 ? '' : 's' }}
        </span>
      </template>
    </template>

    <PaymentReviewBody />

    <template v-if="!loading && rows.length && (pending || mode === 'reject')" #footer>
      <div v-if="mode === 'reject'" class="mx-foot">
        <button type="button" class="mx-btn mx-btn--danger" :disabled="busy || !reasonText" @click="reject">
          {{ busy ? 'Rejecting…' : 'Reject and ask to resend' }}
        </button>
      </div>
      <div v-else class="mx-foot">
        <!-- Reject sends it back for the student to fix and resend (the reject
             screen says so); the amount to check is already on the sheet. -->
        <div class="mx-foot-row">
          <button type="button" class="mx-btn mx-btn--reject rv-reject" :disabled="busy" @click="startReject">Reject</button>
          <button type="button" class="mx-btn rv-ok" :disabled="busy" @click="confirm">
            {{ busy ? 'Confirming…' : 'Confirm payment' }}
          </button>
        </div>
      </div>
    </template>
  </AppModal>
  <!-- Opened from a pending payment, the viewer carries the figures the
       receipt in the photo should show, so the check needs no switching back. -->
  <PhotoViewer v-model="viewer" :caption="proofCaption" v-bind="proofCompare ? { compare: proofCompare } : {}" />
</template>

<script setup lang="ts">
import AppModal from '@/components/shared/AppModal.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import PaymentReviewBody from './review/PaymentReviewBody.vue'
import PhotoViewer from '@/components/shared/PhotoViewer.vue'
import { formatDate, formatPesoExact, initialsOf } from '@/utils/format'
import { providePaymentReview } from './review/paymentReview'

// Its state lives in ./review/; this is the sheet's frame and the proof viewer.

// The landlord/landlady's view of one payment, and the only place it is
// reviewed. review_payment acts on the whole transfer (every row of its batch),
// so a payment that covered rent and a bill is confirmed or sent back as one.
// Confirming can't be undone, so it ends with the typed CONFIRM step; rejecting
// needs a reason the student reads before they send it again.
const props = defineProps<{ modelValue: boolean; paymentId: string | null }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; changed: [] }>()

const {
  loading,
  rows,
  who,
  mode,
  busy,
  viewer,
  pending,
  methodLabel,
  total,
  sentAt,
  waitDays,
  proofCaption,
  proofCompare,
  reasonText,
  startReject,
  confirm,
  reject,
} = providePaymentReview({ props, emit })
</script>

<style scoped>
.rv-back {
  display: flex;
  width: 36px;
  height: 36px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  margin-left: -8px;
  border: 0;
  border-radius: 999px;
  background: none;
  color: var(--m-ink);
  cursor: pointer;
}
.rv-avatar {
  display: inline-flex;
  width: 40px;
  height: 40px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  border-radius: 50%;
  background: var(--m-primary-dark);
  color: #fff;
  font-size: 13px;
  font-weight: 800;
}
.rv-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.rv-name {
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
}
.rv-wait {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 5px;
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-info-soft);
  color: var(--m-info);
  font-size: 11px;
  font-weight: 700;
}
/* Three days or more reads as a nudge, not just a count. */
.rv-wait--long {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.rv-reject {
  flex: 1;
}
.rv-ok {
  flex: 2;
}
</style>
