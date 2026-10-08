<template>
  <q-page class="terms-page">
    <section class="terms-section">
      <h2 class="terms-heading">Terms you accepted</h2>
      <p class="terms-intro">
        The agreement between you and accommo. You were asked to accept these when
        you registered.
      </p>
      <LegalDocuments />
    </section>
  </q-page>
</template>

<script setup lang="ts">
import LegalDocuments from '@/components/shared/LegalDocuments.vue'
</script>

<style scoped>
.terms-page { padding: 12px 12px 24px; }
.terms-heading {
  margin: 0 2px 2px;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
}
.terms-intro {
  margin: 0 2px 10px;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.45;
}
</style>
