<template>
  <!-- The profile's "Complete your profile" entry: red dot when something needed
       is blank (same rule as the Menu dot), plain when only the photo is left. -->
  <button v-if="gaps.length" type="button" class="pcs" @click="router.push(to)">
    <span class="pcs-icon">
      <IconifyIcon icon="lucide:user-round-pen" width="18" />
      <span v-if="gaps.some((g) => g.needed)" class="pcs-dot" />
    </span>
    <span class="pcs-text">
      <span class="pcs-title">Complete your profile · {{ gaps.length }} left</span>
      <span class="pcs-hint">Add your {{ listGaps(gaps) }}</span>
    </span>
    <IconifyIcon icon="lucide:chevron-right" width="18" class="pcs-chevron" />
  </button>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { listGaps, type ProfileGap } from '@/utils/profile'

defineProps<{ gaps: ProfileGap[]; to: string }>()

const router = useRouter()
</script>

<style scoped>
.pcs {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  min-height: 56px;
  padding: 10px 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.pcs-icon {
  position: relative;
  display: inline-flex;
  flex: 0 0 36px;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.pcs-dot {
  position: absolute;
  top: 0;
  right: 0;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: var(--m-danger, #b42318);
  border: 2px solid var(--m-surface);
}
.pcs-text {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
}
.pcs-title { font-size: 13.5px; font-weight: 700; }
.pcs-hint {
  overflow: hidden;
  color: var(--m-muted);
  font-size: 12.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pcs-chevron { flex: 0 0 auto; color: var(--m-muted); }
</style>
