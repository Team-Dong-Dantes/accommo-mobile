<template>
  <div class="connected-google-box q-mb-md q-pa-md">
    <div class="row items-center">
      <IconifyIcon width="20" icon="material-icons:check_circle" color="teal-9" class="q-mr-sm" />
      <div class="col">
        <div class="text-weight-bold connected-title">Google Connected</div>
        <div class="text-caption connected-email">{{ email }}</div>
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
  background: var(--m-primary-soft);
  border: 1px solid var(--m-primary);
  border-radius: 16px;
}
.connected-title {
  color: var(--m-ink);
}
.connected-email {
  color: var(--m-muted);
}
</style>
