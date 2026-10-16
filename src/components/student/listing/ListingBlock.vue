<template>
  <section class="block">
    <h2 class="block-title">{{ title }}</h2>
    <slot />
  </section>
</template>

<script setup lang="ts">
// One titled section of a listing or room page, ruled off from the one above.
defineProps<{ title: string }>()
</script>

<style scoped>
/* Each block carries its own leading divider — so an empty, un-rendered
   section never leaves a doubled gap the way a fixed divider between every
   pair of sections would. */
.block {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 22px;
  padding-top: 22px;
  border-top: 1px solid var(--m-border);
}
.block:first-of-type {
  border-top: 0;
  padding-top: 0;
}
.block-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
}
</style>
