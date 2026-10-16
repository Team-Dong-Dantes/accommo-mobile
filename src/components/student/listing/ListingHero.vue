<template>
  <div class="hero">
    <PhotoEmpty :size="26" label />
    <img v-for="(src, i) in images" :key="i" :src="src" :alt="alt" class="hero-img" />
    <span v-if="images.length > 1" class="hero-count">
      <IconifyIcon icon="lucide:image" width="11" />{{ images.length }}
    </span>
  </div>
</template>

<script setup lang="ts">
// Edge-to-edge, one photo at a time, not a boxed thumbnail strip.
// The photo strip on top of a listing or a room. The placeholder sits under
// the photos, so it shows only while there are none (or they are loading).
import { Icon as IconifyIcon } from '@iconify/vue'
import PhotoEmpty from '@/components/shared/PhotoEmpty.vue'

defineProps<{ images: string[]; alt: string }>()
</script>

<style scoped>
/* Hero — one photo filling the width at a time, no card frame around it */
.hero {
  position: relative;
  display: flex;
  height: 240px;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
  background: var(--m-primary-soft);
}
.hero-img {
  position: relative;
  z-index: 1;
  width: 100%;
  height: 100%;
  flex: 0 0 100%;
  object-fit: cover;
  scroll-snap-align: start;
}
.hero-count {
  position: absolute;
  right: 12px;
  bottom: 12px;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 10px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.55);
  backdrop-filter: blur(6px);
  -webkit-backdrop-filter: blur(6px);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
}
</style>
