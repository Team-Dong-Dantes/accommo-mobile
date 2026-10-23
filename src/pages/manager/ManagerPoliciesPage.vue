<template>
  <q-page class="policies-page">
    <section class="policies-section">
      <h2 class="policies-heading">Terms you accepted</h2>
      <p class="policies-intro">
        The agreement between you and accommo. You were asked to accept these when
        you registered.
      </p>
      <LegalDocuments />
    </section>

    <section class="policies-section">
      <h2 class="policies-heading">OSAS policies &amp; guidelines</h2>
      <p class="policies-intro">
        Rules and guidelines published by OSAS. They apply to everyone using accommo.
      </p>
      <PoliciesList />
    </section>
  </q-page>
</template>

<script setup lang="ts">
import PoliciesList from '@/components/shared/PoliciesList.vue'
import LegalDocuments from '@/components/shared/LegalDocuments.vue'
</script>

<style scoped>
.policies-page { padding: 12px 12px 24px; }
.policies-section + .policies-section { margin-top: 22px; }
.policies-heading {
  margin: 0 2px 2px;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
}
.policies-intro {
  margin: 0 2px 10px;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.45;
}
</style>
