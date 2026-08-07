<template>
  <q-file v-model="model" borderless color="teal-9" class="file-dropzone" v-bind="$attrs">
    <template v-for="(_, name) in $slots" #[name]="slotData">
      <slot :name="name" v-bind="slotData || {}" />
    </template>
  </q-file>
</template>

<script setup lang="ts">
const model = defineModel<File | null>();
</script>

<style scoped>
.file-dropzone {
  border-radius: 16px;
}

.file-dropzone :deep(.q-field__control) {
  min-height: 72px;
  background: #fafafa;
  border: 2px dashed #b2dfdb;
  border-radius: 16px;
  padding: 0 16px;
  transition: all 0.3s ease;
}

.file-dropzone:hover :deep(.q-field__control) {
  border-color: #009688;
  background: #e0f2f1;
}

.file-dropzone :deep(svg.iconify) {
  width: 20px !important;
  height: 20px !important;
}
</style>
