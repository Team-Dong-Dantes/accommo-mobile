<template>
  <div class="rule-list">
    <div v-for="row in rows" :key="row.label" class="rule-row">
      <span class="rule-label">{{ row.label }}</span>
      <span class="rule-value">{{ row.value }}</span>
    </div>
  </div>
</template>

<script setup lang="ts">
// Label-left, value-right rows: house rules, utilities, what moving in costs.
export interface RuleRow {
  label: string
  value: string
}

defineProps<{ rows: RuleRow[] }>()
</script>

<style scoped>
/* Move-in cost */
.rule-list {
  display: flex;
  flex-direction: column;
}
.rule-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 0;
  border-top: 1px solid var(--m-border);
}
.rule-list > .rule-row:first-child {
  border-top: 0;
  padding-top: 0;
}
.rule-label {
  color: var(--m-muted);
  font-size: 13px;
  font-weight: 600;
}
.rule-value {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 600;
  text-align: right;
}
</style>
