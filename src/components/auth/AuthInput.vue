<template>
  <q-input v-model="model" borderless hide-bottom-space color="teal-9" class="auth-input"
    v-bind="$attrs">
    <template v-for="(_, name) in $slots" #[name]="slotData">
      <slot :name="name" v-bind="slotData || {}" />
    </template>
  </q-input>
</template>

<script setup lang="ts">
const model = defineModel<string | number | null>();
</script>

<style scoped>
.auth-input {
  border-radius: 16px;
  padding-bottom: 4px;
}

.auth-input :deep(.q-field__control) {
  min-height: 56px;
  background: var(--m-bg);
  border: 1px solid var(--m-border);
  border-radius: 16px;
  padding: 0 16px;
}

.auth-input :deep(svg.iconify) {
  width: 20px !important;
  height: 20px !important;
}
</style>
