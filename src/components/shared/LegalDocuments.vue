<template>
  <div class="legal-stack">
    <article v-for="doc in documents" :key="doc.id" class="legal-doc">
      <header class="legal-head">
        <h3 class="legal-title">{{ doc.title }}</h3>
        <span class="legal-meta">Effective {{ formatMonth(doc.effectiveDate) }}</span>
      </header>
      <p class="legal-body">{{ doc.body }}</p>
    </article>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { formatMonth } from '@/utils/format'
import { LEGAL_DOCUMENTS, type LegalDocumentId } from '@/constants/legal'

// The Terms of Service and Privacy Notice, straight from the bundle. Shared by
// the register screen's consent dialog, the re-consent gate, and the Policies
// screen — the last of which is the only place a signed-in user can go back and
// re-read what they agreed to.
//
// Rendered expanded rather than as an accordion, deliberately. The consent
// dialogs decide "has this been read?" by whether the content fits without
// scrolling, and two collapsed accordion headers always fit — which let the
// whole agreement be dismissed in one flick past two closed rows. Full text is
// what makes scrolling to the end mean anything.
//
// There is no loading or error state because there is no fetch: that is the
// point of bundling these. `loaded` fires once so the consent dialogs can run
// their fits-without-scrolling check against real content.
const props = defineProps<{
  /** Limit to these documents. Omitted means all of them. */
  ids?: LegalDocumentId[]
}>()

const emit = defineEmits<{ (e: 'loaded'): void }>()

const documents = computed(() =>
  props.ids?.length ? LEGAL_DOCUMENTS.filter((d) => props.ids!.includes(d.id)) : LEGAL_DOCUMENTS,
)

onMounted(() => emit('loaded'))
</script>

<style scoped>
.legal-stack { display: flex; flex-direction: column; gap: 16px; }

.legal-doc {
  padding: 13px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.legal-head { margin-bottom: 8px; }
.legal-title {
  margin: 0;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
  line-height: 1.25;
}
.legal-meta {
  display: block;
  margin-top: 2px;
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 600;
}
.legal-body {
  margin: 0;
  color: var(--m-text);
  font-size: 12.5px;
  line-height: 1.55;
  white-space: pre-wrap;
}
</style>
