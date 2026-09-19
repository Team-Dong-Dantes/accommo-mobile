<template>
  <router-view />
  <!-- Outside the layouts on purpose: a build old enough to be cut off may also
       be too old to sign in, so the gate has to reach the auth screens too. -->
  <UpdateGate />
  <!-- Same reasoning: login/register need this exactly as much as the app shell. -->
  <OfflineBanner />
</template>

<script setup lang="ts">
import UpdateGate from '@/components/shared/UpdateGate.vue'
import OfflineBanner from '@/components/shared/OfflineBanner.vue'
</script>
