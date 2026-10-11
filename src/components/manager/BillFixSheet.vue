<template>
  <AppModal :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <template #header>
      <span class="mx-head">
        <span class="mx-head-sub">{{ studentName }} · {{ bill?.label }}</span>
        <h3 class="mx-head-title">Correct this bill</h3>
      </span>
    </template>

    <div v-if="bill" class="mx-body">
      <div class="mx-list">
        <div class="mx-kv"><span class="mx-kv-key">Posted</span><span class="mx-kv-val">{{ formatPesoExact(bill.amount) }}</span></div>
        <div class="mx-kv"><span class="mx-kv-key">Already paid</span><span class="mx-kv-val bf-paid">{{ bill.paid > 0.009 ? formatPesoExact(bill.paid) : 'Nothing yet' }}</span></div>
      </div>

      <label class="mx-field">
        <span class="mx-label">Correct amount</span>
        <span class="mx-money">
          <span class="mx-money-sign">₱</span>
          <input v-model.number="amount" type="number" :min="bill.paid || 0.01" step="0.01" inputmode="decimal" class="mx-money-input" aria-label="Correct amount" />
        </span>
        <span class="mx-hint" :class="{ 'mx-hint--bad': tooLow }">
          <template v-if="tooLow">Can't go below the {{ formatPesoExact(bill.paid) }} already paid.</template>
          <template v-else-if="bill.paid > 0.009">{{ firstName }} will owe <b>{{ formatPesoExact(left) }}</b> instead of {{ formatPesoExact(bill.amount - bill.paid) }}.</template>
          <template v-else>{{ firstName }} will owe <b>{{ formatPesoExact(left) }}</b>.</template>
        </span>
      </label>

      <label class="mx-field">
        <span class="mx-label">What was wrong ({{ firstName }} sees this)</span>
        <input v-model="note" type="text" maxlength="300" class="mx-input" placeholder="e.g. Misread the meter: 312 → 349, not 358" />
      </label>

      <div v-if="bill.paid > 0.009" class="bf-lock">
        <IconifyIcon icon="lucide:lock" width="16" class="bf-lock-icon" />
        This bill can't be removed: {{ firstName }} has already paid part of it.
      </div>
      <button v-else type="button" class="mx-link bf-remove" :disabled="busy" @click="remove">Remove this bill instead</button>
    </div>

    <template #footer>
      <div class="mx-foot">
        <button type="button" class="mx-btn" :disabled="busy || !changed || tooLow || !note.trim()" @click="save">
          {{ busy ? 'Saving…' : `Change to ${formatPesoExact(Number(amount) || 0)}` }}
        </button>
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
import { confirmAction } from '@/utils/confirmAction'
import { formatPesoExact } from '@/utils/format'
import AppModal from '@/components/shared/AppModal.vue'

// Fixing a bill posted with the wrong amount. The database allows any amount at
// least what's already paid toward it (guard_utility_bills, 20261012000000) and
// tells the student, with the note saying why. Only an unpaid bill can go.
export interface FixBill {
  id: string
  label: string
  amount: number
  paid: number
}
const props = defineProps<{ modelValue: boolean; studentName: string; bill: FixBill | null }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; done: [] }>()
const notify = useNotify()

const amount = ref<number | ''>('')
const note = ref('')
const busy = ref(false)
const firstName = computed(() => props.studentName.split(' ')[0] || 'The tenant')
const value = computed(() => Math.round((Number(amount.value) || 0) * 100) / 100)
const tooLow = computed(() => !!props.bill && value.value + 0.009 < props.bill.paid)
const changed = computed(() => !!props.bill && value.value > 0 && Math.abs(value.value - props.bill.amount) > 0.009)
const left = computed(() => Math.max(value.value - (props.bill?.paid ?? 0), 0))

watch(() => props.modelValue, (open) => {
  if (!open || !props.bill) return
  amount.value = props.bill.amount
  note.value = ''
})

async function save() {
  const b = props.bill
  if (!b || busy.value) return
  busy.value = true
  try {
    const { error } = await supabase.from('utility_bills').update({ amount: value.value, note: note.value.trim() }).eq('id', b.id)
    if (error) throw error
    notify.success('Bill corrected.')
    emit('update:modelValue', false)
    emit('done')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not correct this bill.'))
  } finally {
    busy.value = false
  }
}

async function remove() {
  const b = props.bill
  if (!b || busy.value) return
  if (!(await confirmAction({ title: 'Remove this bill?', message: `${firstName.value} will no longer see it as due.` }))) return
  busy.value = true
  try {
    const { error } = await supabase.from('utility_bills').delete().eq('id', b.id)
    if (error) throw error
    notify.success('Bill removed.')
    emit('update:modelValue', false)
    emit('done')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not remove this bill.'))
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.bf-paid {
  color: var(--m-success);
}
.bf-lock {
  display: flex;
  gap: 10px;
  color: var(--m-muted);
  font-size: 12.5px;
  line-height: 1.45;
}
.bf-lock-icon {
  flex: 0 0 auto;
  margin-top: 1px;
}
.bf-remove {
  align-self: flex-start;
  min-height: 40px;
  color: var(--m-danger);
  font-size: 13.5px;
}
</style>
