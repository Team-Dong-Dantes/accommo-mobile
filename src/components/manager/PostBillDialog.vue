<template>
  <q-dialog :model-value="modelValue" position="bottom" @update:model-value="emit('update:modelValue', $event)">
    <q-card class="pb-sheet">
      <h3 class="pb-title">Post utility bill</h3>
      <p class="pb-note">{{ studentName }} will see it under Payments and pay it like rent.</p>

      <label class="pb-field">
        <span class="pb-label">Month</span>
        <input v-model="month" type="month" class="pb-input" />
      </label>
      <label v-for="u in utilities" :key="u.key" class="pb-field">
        <span class="pb-label">{{ u.label }} (₱) · {{ UTILITY_BILLING_LABEL[u.billing] }}</span>
        <input v-model.number="amounts[u.key]" type="number" min="0" step="0.01" inputmode="decimal" class="pb-input" placeholder="Leave blank to skip" />
      </label>
      <label class="pb-field">
        <span class="pb-label">Due date</span>
        <input v-model="dueDate" type="date" :min="today" class="pb-input" />
      </label>
      <label class="pb-field">
        <span class="pb-label">Note (optional)</span>
        <input v-model="note" type="text" class="pb-input" placeholder="e.g. Meter 1,204 → 1,262 kWh" />
      </label>

      <q-btn unelevated rounded no-caps color="primary" class="pb-submit" :loading="posting" label="Post bill" @click="post" />
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { formatMonth } from '@/utils/format'
import { UTILITY_BILLING_LABEL, type UtilityKey } from '@/utils/listings'
import { manilaToday } from '@/utils/payments'

// The landlord/landlady's side of a metered or split utility: one month's
// amount per utility, posted as utility_bills rows. The student pays each one
// from their Payments tab; verifying it is the same flow as rent.
const props = defineProps<{
  modelValue: boolean
  leaseId: string
  studentId: string
  studentName: string
  /** Only the utilities this place bills monthly (own meter / split). */
  utilities: { key: UtilityKey; label: string; billing: string }[]
}>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; posted: [] }>()
const notify = useNotify()

const month = ref('')
const note = ref('')
const dueDate = ref('')
// Manila's date, not the device's — bills are due by Manila's calendar.
const today = manilaToday()
const amounts = reactive<Partial<Record<UtilityKey, number | ''>>>({})
const posting = ref(false)

// Fresh form each time it opens, on the current month.
watch(
  () => props.modelValue,
  (open) => {
    if (!open) return
    month.value = today.slice(0, 7)
    note.value = ''
    // A week to pay, the same default the database uses.
    const due = new Date(`${today}T00:00:00`)
    due.setDate(due.getDate() + 7)
    dueDate.value = due.toLocaleDateString('en-CA')
    for (const u of props.utilities) amounts[u.key] = ''
  },
)

async function post() {
  if (posting.value) return
  const rows = props.utilities
    .filter((u) => Number(amounts[u.key]) > 0)
    .map((u) => ({
      lease_id: props.leaseId,
      utility: u.key,
      month: `${month.value}-01`,
      amount: Number(amounts[u.key]),
      note: note.value.trim() || null,
      due_date: dueDate.value,
    }))
  if (!month.value) return notify.error('Pick the month this bill is for.')
  if (!dueDate.value) return notify.error('Pick a due date.')
  if (!rows.length) return notify.error('Enter at least one amount.')

  posting.value = true
  try {
    const { error } = await supabase.from('utility_bills').insert(rows)
    if (error) {
      // unique (lease_id, utility, month)
      if (error.code === '23505') throw new Error(`A bill for ${formatMonth(`${month.value}-01`)} is already posted.`)
      throw error
    }
    notify.success('Bill posted.')
    emit('posted')
    emit('update:modelValue', false)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not post the bill.'))
  } finally {
    posting.value = false
  }
}
</script>

<style scoped>
.pb-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.pb-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.pb-note {
  margin: -6px 0 0;
  color: var(--m-muted);
  font-size: 13px;
}
.pb-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.pb-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.pb-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.pb-submit {
  min-height: 48px;
  font-weight: 700;
}
</style>
