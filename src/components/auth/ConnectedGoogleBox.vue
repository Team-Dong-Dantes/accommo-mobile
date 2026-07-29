<template>
  <div class="connected-google-box q-mb-md q-pa-md">
    <div class="row items-center">
      <q-icon name="check_circle" color="teal-9" size="sm" class="q-mr-sm" />
      <div class="col">
        <div class="text-weight-bold text-teal-10">Google Connected</div>
        <div class="text-caption text-teal-8">{{ email }}</div>
      </div>
      <q-btn flat dense round icon="close" color="teal-9" @click="$emit('cancel')" />
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{ email: string }>();
defineEmits(['cancel']);
</script>

<style scoped>
.connected-google-box {
  background: #e0f2f1;
  border: 1px solid #b2dfdb;
  border-radius: 16px;
}
</style>
