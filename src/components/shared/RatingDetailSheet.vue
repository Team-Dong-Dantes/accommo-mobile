<template>
  <AppModal :model-value="modelValue" size="sm" @update:model-value="emit('update:modelValue', $event)">
    <template #header>
      <span class="rd-about"><IconifyIcon icon="lucide:building-2" width="14" />About {{ review?.about }}</span>
    </template>
    <template v-if="review">
      <div class="rd-top">
        <StarRating :model-value="review.rating" :size="26" />
        <span class="rd-score">{{ review.rating }} out of 5</span>
        <span class="rd-meta">Anonymous · {{ formatDate(review.createdAt) }}</span>
      </div>
      <blockquote v-if="review.comment" class="rd-quote">{{ review.comment }}</blockquote>
      <p class="rd-note"><IconifyIcon icon="lucide:eye-off" width="15" />Names stay hidden so ratings stay honest.</p>
    </template>
    <template #footer>
      <button type="button" class="rd-close" @click="emit('update:modelValue', false)">Close</button>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'
import AppModal from '@/components/shared/AppModal.vue'
import StarRating from '@/components/shared/StarRating.vue'
import { formatDate } from '@/utils/format'

// One anonymous rating in full. `about` is who it is about (a place for the
// landlord's ratings, "a past landlord/landlady" for the student's); the
// author is never shown, for either role.
defineProps<{
  modelValue: boolean
  review: { rating: number; comment: string | null; createdAt: string; about: string } | null
}>()
const emit = defineEmits<{ 'update:modelValue': [open: boolean] }>()
</script>

<style scoped>
.rd-about {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 3px 10px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 11.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.rd-top {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  padding: 8px 0 4px;
}
.rd-score {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
}
.rd-meta {
  color: var(--m-muted);
  font-size: 13px;
  font-weight: 600;
}
.rd-quote {
  margin: 0;
  padding: 14px 16px;
  border-radius: var(--m-radius);
  background: var(--m-bg);
  color: var(--m-ink);
  font-size: 15px;
  line-height: 1.5;
  white-space: pre-wrap;
}
.rd-note {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
}
.rd-close {
  flex: 1;
  min-height: 46px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
</style>
