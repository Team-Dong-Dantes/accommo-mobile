<template>
  <AppModal :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <template #header>
      <span class="mx-head">
        <span class="mx-head-sub">{{ studentName }}<template v-if="endDate"> · stay ends {{ formatDate(endDate) }}</template></span>
        <h3 class="mx-head-title">Use the {{ formatPesoExact(held) }} deposit</h3>
      </span>
    </template>

    <div class="mx-body" role="radiogroup" aria-label="What the deposit pays for">
      <span class="mx-label">What should it pay for?</span>
      <button
        v-for="o in options"
        :key="o.key"
        type="button"
        role="radio"
        class="ud-opt"
        :class="{ 'ud-opt--on': mode === o.key, 'ud-opt--off': o.disabled }"
        :aria-checked="mode === o.key"
        :disabled="o.disabled"
        @click="mode = o.key"
      >
        <span class="mx-radio-dot ud-dot" />
        <span class="ud-body">
          <span class="ud-name">{{ o.name }}</span>
          <span class="ud-note">{{ o.note }}</span>
        </span>
      </button>

      <div class="ud-sum">
        <span><span>Deposit held</span><b>{{ formatPesoExact(held) }}</b></span>
        <span v-if="spend > 0.009"><span>{{ mode === 'last_month' ? `Pays ${lastName}` : 'Pays what is owed' }}</span><b>− {{ formatPesoExact(spend) }}</b></span>
        <span class="ud-sum-total"><span>To return to {{ firstName }}</span><b>{{ formatPesoExact(held - spend) }}</b></span>
      </div>
    </div>

    <template #footer>
      <div class="mx-foot">
        <button type="button" class="mx-btn" :disabled="busy" @click="go">{{ busy ? 'Saving…' : buttonLabel }}</button>
        <p class="mx-foot-note">{{ firstName }} is told, and it shows on both statements.</p>
      </div>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { confirmMoney } from '@/utils/confirmAction'
import { formatDate, formatMonth, formatPesoExact } from '@/utils/format'
import type { LedgerRow } from '@/utils/payments'
import AppModal from '@/components/shared/AppModal.vue'

// The deposit at the end of a stay (use_deposit / return_deposit,
// 20261012000000): it pays the last month's rent, or what is still owed at
// move-out, or goes back to the tenant. Payments it makes carry method
// 'deposit', so they're never counted as new money in.
const props = defineProps<{
  modelValue: boolean
  leaseId: string
  studentName: string
  endDate: string | null
  held: number
  ledger: LedgerRow[]
}>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; done: [] }>()
const notify = useNotify()

type Mode = 'last_month' | 'owed' | 'return'
const mode = ref<Mode>('last_month')
const busy = ref(false)
const firstName = computed(() => props.studentName.split(' ')[0] || 'The tenant')
const today = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Manila' })

const lastMonth = computed(() => (props.endDate ? `${props.endDate.slice(0, 7)}-01` : null))
const lastRow = computed(() => props.ledger.find((r) => r.kind === 'rent' && r.month?.slice(0, 7) === lastMonth.value?.slice(0, 7)) ?? null)
const lastName = computed(() => (lastMonth.value ? `${formatMonth(lastMonth.value).split(' ')[0]} rent` : 'the last month'))
const earlierOwed = computed(() => props.ledger.some((r) => r.kind === 'rent' && r.balance > 0.009 && lastMonth.value && (r.month ?? '') < lastMonth.value))
const owed = computed(() => props.ledger.filter((r) => r.balance > 0.009 && ((r.kind === 'rent' && (r.dueDate ?? '') <= today) || r.kind === 'bill')))
const owedTotal = computed(() => owed.value.reduce((s, r) => s + r.balance, 0))

const options = computed(() => [
  {
    key: 'last_month' as Mode,
    name: `${lastName.value}, the last month`,
    note: !lastRow.value || lastRow.value.balance <= 0.009
      ? 'Already paid, or this stay has no last month set.'
      : earlierOwed.value
        ? 'Settle the earlier months first — rent is paid in order.'
        : `Covers ${formatPesoExact(Math.min(props.held, lastRow.value.balance))} of rent. ${firstName.value} won't be asked to pay it.`,
    disabled: !lastRow.value || lastRow.value.balance <= 0.009 || earlierOwed.value,
  },
  {
    key: 'owed' as Mode,
    name: `What's still owed when ${firstName.value} moves out`,
    note: owedTotal.value > 0.009
      ? `${formatPesoExact(owedTotal.value)} owed now. ${props.held > owedTotal.value ? `The ${formatPesoExact(props.held - owedTotal.value)} left goes back to ${firstName.value}.` : ''}`
      : 'Nothing is owed right now.',
    disabled: owedTotal.value <= 0.009,
  },
  { key: 'return' as Mode, name: 'Nothing, give it all back', note: `Mark the ${formatPesoExact(props.held)} as returned once you've handed it over.`, disabled: false },
])
const spend = computed(() => {
  if (mode.value === 'last_month') return Math.min(props.held, lastRow.value?.balance ?? 0)
  if (mode.value === 'owed') return Math.min(props.held, owedTotal.value)
  return 0
})
const buttonLabel = computed(() =>
  mode.value === 'return' ? `Mark ${formatPesoExact(props.held)} as returned` : mode.value === 'last_month' ? `Use deposit for ${lastName.value}` : `Use ${formatPesoExact(spend.value)} of the deposit`,
)

watch(() => props.modelValue, (open) => {
  if (!open) return
  mode.value = options.value.find((o) => !o.disabled)?.key ?? 'return'
})

async function go() {
  if (busy.value) return
  const ok = await confirmMoney(
    mode.value === 'return' ? `Returned ${formatPesoExact(props.held)} to ${firstName.value}?` : `Use ${formatPesoExact(spend.value)} of the deposit?`,
    mode.value === 'return' ? 'Only mark it once the money is back in their hands. This can\'t be undone.' : 'It pays for what you picked. This can\'t be undone.',
    [],
    buttonLabel.value,
  )
  if (!ok) return
  busy.value = true
  try {
    const { error } = mode.value === 'return'
      ? await supabase.rpc('return_deposit', { p_lease: props.leaseId })
      : await supabase.rpc('use_deposit', { p_lease: props.leaseId, p_mode: mode.value })
    if (error) throw error
    notify.success(mode.value === 'return' ? 'Deposit marked as returned.' : 'Deposit used.')
    emit('update:modelValue', false)
    emit('done')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update the deposit.'))
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.ud-opt {
  display: flex;
  width: 100%;
  flex: 0 0 auto;
  align-items: flex-start;
  gap: 12px;
  padding: 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: inherit;
  cursor: pointer;
  font: inherit;
  text-align: left;
}
.ud-opt--on {
  padding: 13px;
  border: 2px solid var(--m-primary);
  background: var(--m-primary-soft);
}
.ud-opt--off {
  opacity: 0.55;
  cursor: default;
}
.ud-dot {
  margin-top: 1px;
}
.ud-opt--on .ud-dot {
  border-color: var(--m-primary);
}
.ud-opt--on .ud-dot::after {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: var(--m-primary);
  content: "";
}
.ud-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 3px;
}
.ud-name {
  color: var(--m-ink);
  font-size: 14.5px;
  font-weight: 700;
}
.ud-note {
  color: var(--m-muted);
  font-size: 12.5px;
  line-height: 1.4;
}
.ud-sum {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  gap: 4px;
  padding: 12px 14px;
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 13px;
}
.ud-sum > span {
  display: flex;
  justify-content: space-between;
}
.ud-sum-total {
  margin-top: 2px;
  padding-top: 6px;
  border-top: 1px solid var(--m-border);
}
</style>
