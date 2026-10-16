<template>
  <div />
</template>

<script setup lang="ts">
// Stub: filled in by the student history work package.
defineProps<{
  modelValue: boolean
  review: { rating: number; comment: string | null; createdAt: string; about: string } | null
}>()
defineEmits<{ 'update:modelValue': [open: boolean] }>()
</script>
