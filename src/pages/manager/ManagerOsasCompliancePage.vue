<template>
  <EmptyPage
    title="OSAS"
    subtitle="Keep your permits and clearances current for the OSAS housing office."
    icon="lucide:shield-check"
    emptyTitle="All clear with OSAS"
    emptyMessage="Your accommodation documents and any OSAS notices will live here — a clearance matrix for every property, plus a way to raise a ticket when something's wrong."
    action-label="Go to dashboard"
    action-icon="lucide:house"
    action-to="/manager/dashboard"
  />
</template>

<script setup lang="ts">
import EmptyPage from '@/components/shared/EmptyPage.vue'
</script>
