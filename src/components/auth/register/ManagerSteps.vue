<template>
  <!-- Requirements (landlord/landlady, both required), one per screen -->
  <template v-if="current === 'governmentId'">
    <AuthDocumentCard
      v-model="form.governmentIdFile"
      title="Valid Government ID"
      hint="Any government-issued ID showing your photo and name."
      icon="lucide:id-card"
      :rules="[(val: File | null) => !!val || 'Government ID is required']"
    />
    <!-- OSAS has to know when a document lapses, not only that it was
         approved once. Asked here because the uploader is the one
         holding the document. -->
    <label class="doc-expiry">
      <span class="doc-expiry-label">Expiry date on this ID</span>
      <DateTimeField v-model="form.governmentIdExpiresAt" mode="date" placeholder="Pick the expiry date" :rules="expiryRules" />
    </label>
</template>

<template v-else-if="current === 'businessPermit'">
  <AuthDocumentCard
    v-model="form.businessPermitFile"
    title="Business / Mayor's Permit"
    hint="The current permit for the property you are listing."
    icon="lucide:file-text"
    :rules="[(val: File | null) => !!val || 'Business Permit is required']"
  />
  <label class="doc-expiry">
    <span class="doc-expiry-label">Expiry date on this permit</span>
    <DateTimeField v-model="form.businessPermitExpiresAt" mode="date" placeholder="Pick the expiry date" :rules="expiryRules" />
  </label>
</template>
</template>

<script setup lang="ts">
// A landlord/landlady's requirements, one per screen.
import AuthDocumentCard from '@/components/auth/AuthDocumentCard.vue';
import DateTimeField from '@/components/shared/DateTimeField.vue';
import { useRegister } from './register';

const {
  current,
  form,
  expiryRules,
} = useRegister();
</script>

<style scoped>
/* Sits under the document card it belongs to, indented to the card's gutter. */
.doc-expiry {
  display: block;
  margin: 8px 12px 0;
}
.doc-expiry-label {
  display: block;
  margin-bottom: 6px;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
</style>
