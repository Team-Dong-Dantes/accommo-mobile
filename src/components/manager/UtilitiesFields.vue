<template>
  <div class="uf">
    <div v-for="u in UTILITIES" :key="u.key" class="uf-row">
      <span class="uf-name">
        <IconifyIcon :icon="u.icon" width="15" />
        {{ u.label }}
      </span>
      <div class="m-chips">
        <button
          v-for="b in u.modes"
          :key="b"
          type="button"
          class="m-chip"
          :class="{ 'm-chip--on': modelValue[u.key].billing === b }"
          @click="setBilling(u.key, b)"
        >
          {{ UTILITY_BILLING_LABEL[b] }}
        </button>
      </div>
      <label v-if="modelValue[u.key].billing === 'flat_fee'" class="uf-fee">
        <span class="uf-fee-label">Monthly fee (₱)</span>
        <input
          :value="modelValue[u.key].flatFee ?? ''"
          type="number"
          min="1"
          step="1"
          inputmode="numeric"
          class="uf-input"
          placeholder="e.g. 300"
          @input="setFee(u.key, ($event.target as HTMLInputElement).value)"
        />
      </label>
      <p v-else-if="isBilledMonthly(modelValue[u.key].billing)" class="uf-hint">
        You'll post each tenant's {{ u.key === 'wifi' ? u.label : u.label.toLowerCase() }} bill monthly from their profile.
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'
import { UTILITIES, UTILITY_BILLING_LABEL, isBilledMonthly, type UtilityKey, type UtilityTerms } from '@/utils/listings'

// How a room's water, electricity and Wi-Fi are paid. Per room, because one
// house can bill its rooms differently (own meter for the air-con rooms, power
// in the rent for the rest). Lives in the room form.
const props = defineProps<{ modelValue: Record<UtilityKey, UtilityTerms> }>()
const emit = defineEmits<{ 'update:modelValue': [Record<UtilityKey, UtilityTerms>] }>()

function update(key: UtilityKey, next: UtilityTerms) {
  emit('update:modelValue', { ...props.modelValue, [key]: next })
}
function setBilling(key: UtilityKey, billing: string) {
  // A fee only means something on a flat fee; the database rejects it otherwise.
  update(key, { billing, flatFee: billing === 'flat_fee' ? props.modelValue[key].flatFee : null })
}
function setFee(key: UtilityKey, raw: string) {
  const n = Number(raw)
  update(key, { ...props.modelValue[key], flatFee: raw && n > 0 ? n : null })
}
</script>

<style scoped>
.uf {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.uf-row {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.uf-name {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.uf-fee {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.uf-fee-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.uf-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background-color: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.uf-hint {
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.5;
}
</style>
