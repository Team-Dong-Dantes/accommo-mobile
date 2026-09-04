<template>
  <EmptyPage
    title="OSAS"
    subtitle="Your verification standing and the OSAS housing office."
    icon="lucide:shield-check"
    emptyTitle="All verified with OSAS"
    emptyMessage="Your required documents and their status will appear here, alongside a way to raise a ticket with OSAS when something needs attention."
    action-label="Go to dashboard"
    action-icon="lucide:house"
    action-to="/student/home"
  />
</template>

<script setup lang="ts">
import EmptyPage from '@/components/shared/EmptyPage.vue'
</script>
