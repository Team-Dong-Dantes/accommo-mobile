<template>
  <q-select v-model="model" borderless hide-bottom-space bg-color="grey-2" color="teal-9" class="auth-input"
    v-bind="$attrs">
    <template #selected-item="scope">
      <div class="ellipsis" style="min-width: 0; max-width: 100%; width: 100%">
        {{ truncate(String(scope.opt)) }}
      </div>
    </template>
    <template v-for="(_, name) in $slots" #[name]="slotData">
      <slot :name="name" v-bind="slotData || {}" />
    </template>
  </q-select>
</template>

<script setup lang="ts">
const model = defineModel<string | number | null>();

const props = withDefaults(defineProps<{
  truncateLength?: number
}>(), {
  truncateLength: 34
});

function truncate(val: string) {
  return val.length > props.truncateLength ? val.slice(0, props.truncateLength) + '…' : val;
}
</script>

<style scoped>
.auth-input {
  border-radius: 16px;
  padding-bottom: 4px;
  width: 100%;
  max-width: 100%;
  min-width: 0;
  overflow: hidden;
}

.auth-input :deep(.q-field__control) {
  min-height: 56px;
  background: #f5f5f5;
  border-radius: 16px;
  padding: 0 16px;
  overflow: hidden;
}

.auth-input :deep(svg.iconify) {
  width: 20px !important;
  height: 20px !important;
}
</style>
