<template>
  <AppModal :model-value="modelValue" tall @update:model-value="emit('update:modelValue', $event)">
    <template #header>
      <span class="mx-head">
        <h3 class="mx-head-title">Log a payment</h3>
        <span class="mx-head-sub">{{ subtitle }}</span>
      </span>
    </template>

    <div v-if="loading" class="mx-body lp-center"><q-spinner size="24px" color="primary" /></div>
    <div v-else-if="!items.length" class="mx-body lp-center">
      <IconifyIcon icon="lucide:circle-check" width="32" class="lp-done" />
      <p class="mx-hint">Nothing is owed on this stay right now.</p>
    </div>

    <!-- One screen: what, how much, how. -->
    <div v-else class="mx-body">
      <div class="mx-field">
        <span class="mx-label">For</span>
        <PayItemList :items="items" />
      </div>

      <label class="mx-field">
        <span class="mx-label">Amount received</span>
        <span class="mx-money">
          <span class="mx-money-sign">₱</span>
          <input v-model.number="amount" type="number" min="0.01" :max="total" step="0.01" inputmode="decimal" class="mx-money-input" aria-label="Amount received" />
          <span v-if="amount + 0.009 < total" class="mx-money-of">of {{ formatPesoExact(total) }}</span>
        </span>
        <span class="mx-hint">Got less? Type what you got — the rest stays owed.</span>
      </label>

      <div class="mx-field" role="radiogroup" aria-label="Paid with">
        <span class="mx-label">Paid with</span>
        <div class="lp-chips">
          <button
            v-for="m in METHODS"
            :key="m"
            type="button"
            role="radio"
            class="mx-chip"
            :class="{ 'mx-chip--on': method === m }"
            :aria-checked="method === m"
            @click="method = m"
          >
            <IconifyIcon v-if="m === 'cash'" icon="lucide:banknote" width="16" />
            {{ PAYMENT_METHOD_LABEL[m] }}
          </button>
        </div>
      </div>

      <label class="mx-field">
        <span class="mx-label">Note (optional)</span>
        <input v-model="note" type="text" maxlength="300" class="mx-input" placeholder="e.g. Handed over at the gate" />
      </label>
    </div>

    <template v-if="items.length" #footer>
      <div class="mx-foot">
        <button type="button" class="mx-btn" :disabled="busy || !(pay > 0)" @click="submit">
          <IconifyIcon icon="lucide:check" width="18" />
          {{ busy ? 'Logging…' : `Log ${formatPesoExact(pay)} as received` }}
        </button>
        <p class="mx-foot-note">You'll type CONFIRM next. A logged payment can't be undone.</p>
      </div>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { confirmMoney } from '@/utils/requirePin'
import { formatPesoExact, PAYMENT_METHOD_LABEL } from '@/utils/format'
import { usePayItems } from '@/utils/usePayItems'
import AppModal from '@/components/shared/AppModal.vue'
import PayItemList from '@/components/shared/PayItemList.vue'

// The landlord/landlady recording money they got themselves (cash at the door,
// a transfer they saw arrive). It counts as paid at once, so it ends with the
// typed CONFIRM step, the same as confirming a student's payment.
const props = defineProps<{
  modelValue: boolean
  leaseId: string
  subtitle: string
  startDate?: string | undefined
  /** An ended stay: only rent and bills are left to settle. */
  settleOnly?: boolean
}>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; submitted: [] }>()
const notify = useNotify()

const METHODS = ['cash', 'gcash', 'maya', 'bank', 'others'] as const
const { loading, months, billIds, deposit, depositRow, total, items, load } = usePayItems(
  () => props.leaseId,
  () => props.startDate,
  () => Boolean(props.settleOnly),
)
const amount = ref(0)
const method = ref<(typeof METHODS)[number]>('cash')
const note = ref('')
const busy = ref(false)
const pay = computed(() => Math.round((Number(amount.value) || 0) * 100) / 100)

// Ticking or unticking resets the amount to the new total.
watch(total, (t) => { amount.value = t })

watch(
  () => props.modelValue,
  async (open) => {
    if (!open || !props.leaseId) return
    method.value = 'cash'
    note.value = ''
    try {
      await load()
      amount.value = total.value
    } catch (e) {
      notify.error(errorMessage(e, 'Could not load what is owed.'))
    }
  },
  { immediate: true },
)

async function submit() {
  if (busy.value) return
  if (!(pay.value > 0)) return notify.error('Enter the amount you received.')
  if (pay.value > total.value + 0.009) return notify.error(`That is more than what you ticked (${formatPesoExact(total.value)}).`)
  const ok = await confirmMoney(
    `Did ${formatPesoExact(pay.value)} really reach you?`,
    `It's recorded as paid for ${props.subtitle.split(' · ')[0]}. This can't be undone.`,
    [`I have ${formatPesoExact(pay.value)} in ${method.value === 'cash' ? 'hand' : `my ${PAYMENT_METHOD_LABEL[method.value]}`}`],
    `Log ${formatPesoExact(pay.value)}`,
  )
  if (!ok) return
  busy.value = true
  try {
    const { error } = await supabase.rpc('record_payments', {
      p_lease: props.leaseId,
      p_months: months.value,
      p_bills: billIds.value,
      p_advance: false,
      p_deposit: deposit.value && !!depositRow.value,
      p_method: method.value,
      ...(pay.value + 0.009 < total.value ? { p_amount: pay.value } : {}),
      ...(note.value.trim() ? { p_note: note.value.trim() } : {}),
    })
    if (error) throw error
    notify.success('Payment logged.')
    emit('update:modelValue', false)
    emit('submitted')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not log this payment.'))
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.lp-center {
  align-items: center;
  justify-content: center;
}
.lp-done {
  color: var(--m-success);
}
.lp-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
</style>
