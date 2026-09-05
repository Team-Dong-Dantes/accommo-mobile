<template>
  <div class="stars" :class="{ 'stars--interactive': interactive }">
    <button
      v-for="n in 5"
      :key="n"
      type="button"
      class="star"
      :tabindex="interactive ? 0 : -1"
      :aria-label="interactive ? `Rate ${n} out of 5` : undefined"
      @click="interactive && emit('update:modelValue', n)"
    >
      <IconifyIcon :icon="n <= Math.round(modelValue) ? 'mdi:star' : 'mdi:star-outline'" :width="size" />
    </button>
  </div>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

withDefaults(
  defineProps<{
    modelValue: number
    interactive?: boolean
    size?: number
  }>(),
  { interactive: false, size: 16 },
)

const emit = defineEmits<{ 'update:modelValue': [value: number] }>()
</script>

<style scoped>
.stars {
  display: inline-flex;
  gap: 2px;
}
.star {
  display: grid;
  place-items: center;
  padding: 0;
  border: 0;
  background: transparent;
  color: #f5a623;
  cursor: default;
  -webkit-tap-highlight-color: transparent;
}
.stars--interactive .star {
  cursor: pointer;
  padding: 2px;
}
</style>
