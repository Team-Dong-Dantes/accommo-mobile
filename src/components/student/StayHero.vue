<template>
  <!-- My Stay's cover: where the student lives, said once. On a phone it sits
       above the tab strip, which is pulled up over its bottom edge; on desktop
       it heads the stay half. The page sets the geometry for each. -->
  <div class="stay-hero">
    <img v-if="photoUrl && !broken" :src="photoUrl" alt="" class="stay-hero-img" @error="broken = true" />
    <PhotoEmpty v-else :size="28" label />
    <span class="stay-hero-scrim" aria-hidden="true" />

    <div class="stay-hero-head">
      <span class="stay-hero-name">{{ name }}</span>
      <span v-if="subtitle" class="stay-hero-sub">{{ subtitle }}</span>
    </div>
    <span class="stay-hero-chip" :class="`stay-hero-chip--${statusColor(LEASE_STATUS, status)}`">
      {{ statusText(LEASE_STATUS, status) }}
    </span>
  </div>
</template>

<script setup lang="ts">
import PhotoEmpty from '@/components/shared/PhotoEmpty.vue'
import { computed, ref } from 'vue'
import { LEASE_STATUS, statusColor, statusText } from '@/utils/format'

const props = defineProps<{ name: string; room: string; address: string; status: string; photoUrl: string }>()

const broken = ref(false)
const subtitle = computed(() => [props.room, props.address].filter(Boolean).join(' · '))
</script>

<style scoped>
.stay-hero {
  position: relative;
  flex: 0 0 auto;
  height: 200px;
  overflow: hidden;
  background: var(--m-primary-soft);
}
.stay-hero-img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
/* Dark at the top, where the name sits; the bottom is left to the tab strip. */
.stay-hero-scrim {
  position: absolute;
  inset: 0;
  background: linear-gradient(to bottom, rgba(12, 18, 26, 0.72) 0%, rgba(12, 18, 26, 0.3) 45%, rgba(12, 18, 26, 0) 70%);
}
.stay-hero-head {
  position: absolute;
  top: 14px;
  left: var(--m-page-gutter);
  right: 96px;
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.stay-hero-name {
  display: -webkit-box;
  overflow: hidden;
  color: #fff;
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.15;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.35);
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
.stay-hero-sub {
  overflow: hidden;
  color: rgba(255, 255, 255, 0.86);
  font-size: 12.5px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.stay-hero-chip {
  position: absolute;
  top: 14px;
  right: var(--m-page-gutter);
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.stay-hero-chip--teal {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.stay-hero-chip--amber,
.stay-hero-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.stay-hero-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.stay-hero-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
</style>
