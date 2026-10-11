<template>
  <AppModal :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <template #header>
      <span class="mx-head">
        <span class="mx-head-sub">{{ studentName }} · {{ target?.label }}</span>
        <h3 class="mx-head-title">Forgive {{ formatPesoExact(target?.balance ?? 0) }}?</h3>
      </span>
    </template>

    <div class="mx-body">
      <div class="fg-means">
        <span><IconifyIcon icon="lucide:check" width="16" class="fg-icon" />{{ capitalize(target?.label ?? '') }} stops being owed. {{ firstName }} won't be reminded about it.</span>
        <span><IconifyIcon icon="lucide:x" width="16" class="fg-icon" />It isn't counted as money you collected.</span>
      </div>

      <div class="mx-field">
        <span class="mx-label">Why ({{ firstName }} sees this)</span>
        <div class="fg-chips">
          <button
            v-for="r in REASONS"
            :key="r"
            type="button"
            class="mx-chip"
            :class="{ 'mx-chip--on': pick === r }"
            :aria-pressed="pick === r"
            @click="pick = r"
          >
            {{ r }}
          </button>
        </div>
        <textarea v-model="detail" rows="2" maxlength="300" class="mx-input" aria-label="More detail" :placeholder="pick === 'Other' ? 'Say why' : 'More detail (optional)'" />
      </div>

      <div class="mx-banner mx-banner--warn">
        <IconifyIcon icon="lucide:circle-alert" width="18" class="mx-banner-icon" />
        <span>Like confirming a payment, this can't be undone. You'll type CONFIRM next.</span>
      </div>
    </div>

    <template #footer>
      <div class="mx-foot">
        <button type="button" class="mx-btn mx-btn--ink" :disabled="busy || !reason" @click="forgive">
          {{ busy ? 'Forgiving…' : `Forgive ${formatPesoExact(target?.balance ?? 0)}` }}
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
import { confirmMoney } from '@/utils/confirmAction'
import { formatPesoExact } from '@/utils/format'
import AppModal from '@/components/shared/AppModal.vue'

// Forgiving what is left of one item (waive_balance): it settles the item
// without counting as money received, and the student reads the reason.
export interface ForgiveTarget {
  kind: 'rent' | 'deposit' | 'bill' | 'advance'
  month: string | null
  billId: string | null
  balance: number
  /** "October rent", "the water bill for October". */
  label: string
}
const props = defineProps<{ modelValue: boolean; leaseId: string; studentName: string; target: ForgiveTarget | null }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; done: [] }>()
const notify = useNotify()

const REASONS = ['Away for the break', 'Discount we agreed on', 'Room had a problem', 'Other'] as const
const pick = ref<string>(REASONS[0])
const detail = ref('')
const busy = ref(false)
const firstName = computed(() => props.studentName.split(' ')[0] || 'The tenant')
const reason = computed(() => {
  const more = detail.value.trim()
  if (pick.value === 'Other') return more
  return more ? `${pick.value}: ${more}` : pick.value
})
const capitalize = (s: string) => s.charAt(0).toUpperCase() + s.slice(1)

watch(() => props.modelValue, (open) => {
  if (!open) return
  pick.value = REASONS[0]
  detail.value = ''
})

async function forgive() {
  const t = props.target
  if (!t || busy.value || !reason.value) return
  const ok = await confirmMoney(`Forgive ${formatPesoExact(t.balance)}?`, `${capitalize(t.label)} is settled without payment. This can't be undone.`, [], `Forgive ${formatPesoExact(t.balance)}`)
  if (!ok) return
  busy.value = true
  try {
    const { error } = await supabase.rpc('waive_balance', {
      p_lease: props.leaseId,
      p_kind: t.kind,
      p_month: t.month as string,
      p_bill: t.billId as string,
      p_reason: reason.value,
    })
    if (error) throw error
    notify.success('Balance forgiven.')
    emit('update:modelValue', false)
    emit('done')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not forgive this balance.'))
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.fg-means {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 14px;
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.45;
}
.fg-means span {
  display: flex;
  gap: 10px;
}
.fg-icon {
  flex: 0 0 auto;
  margin-top: 2px;
}
.fg-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
</style>
