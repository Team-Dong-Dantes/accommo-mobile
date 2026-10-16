<template>
  <AppModal :model-value="modelValue" tall @update:model-value="emit('update:modelValue', $event)">
    <template #header>
      <button v-if="step === 2" type="button" class="ps-back" aria-label="Back to step 1" @click="step = 1">
        <IconifyIcon icon="lucide:chevron-left" width="20" />
      </button>
      <span class="mx-head">
        <span class="mx-head-step">Step {{ step }} of 2 · {{ step === 1 ? 'send it' : method === 'cash' ? 'cash' : 'prove it' }}</span>
        <h3 class="mx-head-title">
          {{ step === 1 ? (payLess ? 'Pay part now' : `Pay your ${who}`) : method === 'cash' ? `Hand over ${formatPesoExact(payAmount)}` : `Show you paid ${formatPesoExact(payAmount)}` }}
        </h3>
        <span v-if="subtitle && step === 1" class="mx-head-sub">{{ subtitle }}</span>
      </span>
      <button v-if="step === 1 && payLess" type="button" class="mx-link ps-all" @click="payLess = false">Pay all</button>
    </template>

    <PaySheetBody />

    <template v-if="!loading && items.length" #footer>
      <div v-if="step === 1" class="mx-foot">
        <button type="button" class="mx-btn" :disabled="!(payAmount > 0)" @click="next">
          {{ method === 'cash' ? 'Next' : `I've sent ${formatPesoExact(payAmount)}` }}
          <IconifyIcon icon="lucide:arrow-right" width="18" />
        </button>
        <p v-if="!payLess && canPayLess" class="mx-foot-note">
          Can't pay it all? <button type="button" class="mx-link" @click="startPayLess">Pay part now</button> — at least {{ formatPesoExact(minAmount) }}.
        </p>
      </div>
      <div v-else class="mx-foot">
        <button type="button" class="mx-btn" :disabled="submitting || uploading" @click="submit">
          {{ submitting ? 'Sending…' : method === 'cash' ? 'I handed it over' : resubmit ? 'Send again for confirmation' : 'Send for confirmation' }}
        </button>
        <p class="mx-foot-note">
          {{ method === 'cash' ? 'Only tap this once the cash has changed hands.' : `Your ${who} confirms once it checks out. You can take it back until then.` }}
        </p>
      </div>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
import AppModal from '@/components/shared/AppModal.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import PaySheetBody from './pay/PaySheetBody.vue'
import { type Resubmit } from '@/components/shared/pay/model'
import { formatPesoExact } from '@/utils/format'
import { providePaySheet } from './pay/paySheet'

// Its state lives in ./pay/; this is the sheet's frame.
// The student's Pay: step 1 picks what to pay and shows where to send it;
// step 2 proves it (reference + screenshot), or for cash just says it was handed
// over. Everything goes to record_payments() as one transfer that the
// landlord/landlady confirms or sends back. A transfer sent back opens straight
// on step 2 with the same items, the same method, and the reason in view.
const props = defineProps<{
  modelValue: boolean
  leaseId: string
  /** For "Send to". */
  landlordId?: string
  allowPartial?: boolean
  partialMinPct?: number
  subtitle?: string
  /** An ended stay: only rent and bills are left to settle. */
  settleOnly?: boolean
  /** The stay's move-in date: the rent due on it is the advance. */
  startDate?: string
  resubmit?: Resubmit | null
}>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; submitted: [] }>()

const {
  loading,
  items,
  who,
  step,
  payLess,
  method,
  uploading,
  submitting,
  minAmount,
  canPayLess,
  payAmount,
  startPayLess,
  next,
  submit,
} = providePaySheet({ props, emit })
</script>

<style scoped>
.ps-back {
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
.ps-all {
  flex: 0 0 auto;
  font-size: 13.5px;
}
</style>
