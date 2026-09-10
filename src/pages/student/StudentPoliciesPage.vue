<template>
  <q-page class="policies-page">
    <p class="policies-intro">
      Rules and guidelines published by OSAS. They apply to everyone using accommo.
    </p>
    <PoliciesList />
  </q-page>
</template>

<script setup lang="ts">
import PoliciesList from '@/components/shared/PoliciesList.vue'
</script>

<style scoped>
.policies-page { padding: 12px 12px 24px; }
.policies-intro {
  margin: 0 2px 10px;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.45;
}
</style>
