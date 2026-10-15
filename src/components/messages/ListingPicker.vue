<template>
  <BottomSheet
    :model-value="modelValue"
    title="Share a listing"
    clear-label=""
    done-label=""
    @update:model-value="emit('update:modelValue', $event)"
  >
    <p v-if="loading" class="lp-note">Loading…</p>
    <p v-else-if="error" class="lp-note lp-note--bad">{{ error }}</p>
    <p v-else-if="!items.length" class="lp-note">No listed accommodations to share yet.</p>
    <div v-else class="lp-list">
      <button v-for="l in items" :key="l.id" type="button" class="lp-row" @click="emit('pick', l.id)">
        <img v-if="l.cover" :src="l.cover" alt="" class="lp-img" />
        <span v-else class="lp-img lp-img--none"><IconifyIcon icon="lucide:house" width="18" /></span>
        <span class="lp-body">
          <span class="lp-name">{{ l.name }}</span>
          <span v-if="l.place" class="lp-place">{{ l.place }}</span>
        </span>
      </button>
    </div>
  </BottomSheet>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { LISTING_COLS, toListingCard, type ListingCard } from '@/utils/chat'
import BottomSheet from '@/components/shared/BottomSheet.vue'

// Only the landlord/landlady in this conversation's listings, and only ones
// students can actually open — a card for a hidden listing is a dead end.
const props = defineProps<{ modelValue: boolean; landlordId: string }>()
const emit = defineEmits<{ 'update:modelValue': [open: boolean]; pick: [id: string] }>()

const items = ref<ListingCard[]>([])
const loading = ref(false)
const error = ref('')

watch(
  () => props.modelValue,
  async (open) => {
    if (!open || !props.landlordId) return
    loading.value = true
    error.value = ''
    try {
      const { data, error: e } = await supabase
        .from('accommodations')
        .select(LISTING_COLS)
        .eq('landlord_id', props.landlordId)
        .eq('status', 'accredited')
        .eq('hidden_from_listings', false)
        .order('name')
      if (e) throw e
      items.value = (data ?? []).map(toListingCard)
    } catch (e) {
      error.value = errorMessage(e, 'Could not load listings.')
    } finally {
      loading.value = false
    }
  },
)
</script>

<style scoped>
.lp-note {
  margin: 8px 0;
  color: var(--m-muted);
  font-size: 13px;
  text-align: center;
}
.lp-note--bad {
  color: var(--m-danger);
}
.lp-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.lp-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.lp-img {
  width: 48px;
  height: 48px;
  flex: 0 0 48px;
  border-radius: var(--m-radius-sm);
  object-fit: cover;
}
.lp-img--none {
  display: grid;
  place-items: center;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.lp-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
}
.lp-name {
  overflow: hidden;
  font-size: 13.5px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.lp-place {
  color: var(--m-muted);
  font-size: 12px;
}
</style>
