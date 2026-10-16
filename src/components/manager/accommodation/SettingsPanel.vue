<template>
  <!-- Amenities and house rules are separate questions, each its own
       section. Utilities are per room — see the room form. -->
  <h2 class="sec-title">Amenities</h2>
  <div class="view-group">
    <button type="button" class="view-row view-row--tap" @click="amenitiesDialogOpen = true">
      <span class="view-label">Amenities</span>
      <span class="view-value">
        {{ rules.amenities.length ? rules.amenities.map((a) => AMENITY_META[a]?.label || a).join(', ') : 'None yet' }}
      </span>
      <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
    </button>
  </div>

  <h2 class="sec-title">House rules</h2>
  <div class="view-group">
    <button type="button" class="view-row view-row--tap" @click="openFieldDialog('curfewTime')">
      <span class="view-label">Curfew</span>
      <span class="view-value">{{ rules.curfewTime || '—' }}</span>
      <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
    </button>
    <button type="button" class="view-row view-row--tap" @click="openFieldDialog('quietHours')">
      <span class="view-label">Quiet hours</span>
      <span class="view-value">{{ rules.quietHours || '—' }}</span>
      <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
    </button>
    <button type="button" class="view-row view-row--tap" @click="openFieldDialog('visitorPolicy')">
      <span class="view-label">Visitor policy</span>
      <span class="view-value">{{ rules.visitorPolicy || '—' }}</span>
      <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
    </button>
  </div>
  <div class="toggles">
    <label v-for="t in RULE_TOGGLES" :key="t.key" class="toggle-row">
      <span>{{ t.label }}</span>
      <q-toggle v-model="rules[t.key]" color="primary" dense @update:model-value="saveToggle(t.key)" />
    </label>
  </div>

  <h2 class="sec-title">Permits</h2>
  <p class="sec-hint">
    Accreditation depends on these staying current.
    {{ acc.status === 'accredited' || acc.status === 'delisted'
      ? 'Locked while accredited — a permit can be replaced within 30 days of its expiry, or when OSAS asks. The new file goes to OSAS; the listing stays up meanwhile.'
      : '' }}
  </p>
  <div class="group">
    <div v-for="d in docs" :key="d.type" class="doc-row">
      <span class="doc-icon" :class="`doc-icon--${d.tone}`">
        <IconifyIcon :icon="d.icon" width="16" />
      </span>
      <span class="doc-body">
        <span class="doc-name">{{ DOC_TYPE_LABEL[d.type] }}</span>
        <span class="doc-when">{{ d.when }}</span>
      </span>
      <span class="doc-tag" :class="`doc-tag--${d.tone}`">{{ d.statusLabel }}</span>
      <button
        v-if="d.fileUrl"
        type="button"
        class="doc-view"
        aria-label="View file"
        @click="viewDoc(d.fileUrl)"
      >
        <IconifyIcon icon="lucide:eye" width="15" />
      </button>
      <button
        v-if="d.canReplace"
        type="button"
        class="doc-view"
        :aria-label="d.fileUrl ? `Replace ${DOC_TYPE_LABEL[d.type]}` : `Upload ${DOC_TYPE_LABEL[d.type]}`"
        @click="openPermitSheet(d.type)"
      >
        <IconifyIcon :icon="d.fileUrl ? 'lucide:refresh-cw' : 'lucide:upload'" width="15" />
      </button>
    </div>
  </div>

  <template v-if="acc.status === 'draft'">
    <h2 class="sec-title">Listing status</h2>
    <div class="status-box">
      <p class="status-text">
        {{ draftMissing.length
          ? 'A private draft — only you can see it. Before OSAS can review it, add: ' + draftMissing.join(', ') + '.'
          : 'A private draft, and complete. Submit it when you’re ready for OSAS to review.' }}
      </p>
      <button type="button" class="status-btn" :disabled="submittingDraft || draftMissing.length > 0" @click="submitDraft">
        {{ submittingDraft ? 'Submitting…' : 'Submit to OSAS' }}
      </button>
      <button type="button" class="status-btn status-btn--danger" @click="confirmDeleteAccommodationOpen = true">
        Delete draft
      </button>
    </div>
  </template>
  <AccreditationCard
    v-else
    ref="accreditationCard"
    :accommodation-id="id"
    :status="acc.status"
    :appeal-used="acc.appealUsed"
    :accreditation-expires-at="acc.accreditationExpiresAt"
    :docs="docRows"
    @changed="refreshAccreditation"
    @docs-changed="loadDocs"
    @delete="confirmDeleteAccommodationOpen = true"
  />
  <template v-if="acc.status === 'accredited' || acc.status === 'delisted'">
    <h2 class="sec-title">Listing status</h2>
    <div class="status-box">
      <p class="status-text">
        {{ acc.status === 'accredited'
          ? 'This accommodation is live and visible to students.'
          : 'This accommodation is delisted and hidden from students.' }}
      </p>
      <button
        type="button"
        class="status-btn"
        :class="{ 'status-btn--danger': acc.status === 'accredited' }"
        :disabled="delisting"
        @click="acc.status === 'accredited' ? delistAccommodation() : reactivateAccommodation()"
      >
        {{ acc.status === 'accredited' ? 'Delist this accommodation' : 'Reactivate this accommodation' }}
      </button>
    </div>
  </template>
</template>

<script setup lang="ts">
// The Settings tab: amenities, house rules, permits and listing status.
import { Icon as IconifyIcon } from '@iconify/vue'
import AccreditationCard from '@/components/manager/AccreditationCard.vue'
import { AMENITY_META } from '@/utils/listings'
import { DOC_TYPE_LABEL, RULE_TOGGLES } from './model'
import { useAccommodationDetail } from './detail'

const {
  acc,
  accreditationCard,
  amenitiesDialogOpen,
  confirmDeleteAccommodationOpen,
  delistAccommodation,
  delisting,
  docRows,
  docs,
  draftMissing,
  id,
  loadDocs,
  openFieldDialog,
  openPermitSheet,
  reactivateAccommodation,
  refreshAccreditation,
  rules,
  saveToggle,
  submitDraft,
  submittingDraft,
  viewDoc,
} = useAccommodationDetail()
</script>

<style scoped src="./detail.css"></style>

<style scoped>
.toggles {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.toggle-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  border-top: 1px solid var(--m-border);
  color: var(--m-text);
  font-size: 13.5px;
  font-weight: 600;
}
.toggles > .toggle-row:first-child {
  border-top: 0;
}
.doc-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .doc-row:first-child {
  border-top: 0;
}
.doc-icon {
  display: grid;
  width: 30px;
  height: 30px;
  flex: 0 0 30px;
  place-items: center;
  border-radius: 999px;
}
.doc-icon--good { background: var(--m-success-soft); color: var(--m-success); }
.doc-icon--warn { background: var(--m-warning-soft); color: var(--m-warning); }
.doc-icon--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.doc-icon--idle { background: var(--m-bg); color: var(--m-muted); }
.doc-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.doc-name { color: var(--m-ink); font-size: 13px; font-weight: 700; }
.doc-when { color: var(--m-muted); font-size: 11px; }
.doc-tag {
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}
.doc-tag--good { background: var(--m-success-soft); color: var(--m-success); }
.doc-tag--warn { background: var(--m-warning-soft); color: var(--m-warning); }
.doc-tag--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.doc-tag--idle { background: var(--m-bg); color: var(--m-muted); }
.doc-view {
  display: grid;
  width: 30px;
  height: 30px;
  flex: 0 0 30px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
}
</style>
