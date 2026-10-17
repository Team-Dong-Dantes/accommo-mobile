<template>
  <div :class="isDesktop ? 'desk-col' : 'desk-pass'">
  <ProfileCompleteStrip :gaps="gaps" to="/manager/profile/complete" />
  <ProfileCard :open="isDesktop">
    <template #always>
      <ProfileBlock v-show="shows('ps-details')" id="ps-details" icon="lucide:user" title="Personal details">
        <template #actions>
          <EditButton v-if="!editing" @click="startEdit" />
        </template>
        <ProfileField v-model="draft.fullName" label="Full name" :editing="editing" />
        <ProfileField v-model="draft.phone" label="Phone" type="tel" :editing="editing" placeholder="+63…" />
        <ProfileField v-model="draft.email" label="Email" readonly :editing="editing" />
        <!-- Filled in through Complete your profile; changed after that by OSAS only. -->
        <ProfileField :model-value="sexLabel(me.sex)" label="Sex" readonly :editing="editing" />
        <ProfileField :model-value="birthDateLabel(me.dob)" label="Date of birth" readonly :editing="editing" />
        <template v-if="editing" #foot>
          <div class="card-actions">
            <button class="btn-cancel" :disabled="saving" @click="cancelEdit">Cancel</button>
            <button class="btn-save" :disabled="saving" @click="save">
              {{ saving ? 'Saving…' : 'Save changes' }}
            </button>
          </div>
        </template>
      </ProfileBlock>
    </template>

    <template #more>
      <ProfileBlock
        v-show="shows('ps-verification')"
        id="ps-verification"
        icon="lucide:shield-check"
        title="Verification"
        :badge="pendingDocs > 0 ? `${pendingDocs} pending` : ''"
      >
        <div v-if="documents.length" class="doc-list">
          <div v-for="doc in documents" :key="doc.id" class="doc-item">
            <span class="doc-icon" :class="`doc-${doc.tone}`">
              <IconifyIcon :icon="doc.icon" width="14" />
            </span>
            <div class="doc-info">
              <span class="doc-name">{{ doc.label }}</span>
              <span class="doc-when">{{ doc.when }}</span>
            </div>
            <span class="doc-status" :class="`status-${doc.tone}`">{{ doc.statusLabel }}</span>
          </div>
        </div>
        <EmptyState v-else variant="compact" icon="lucide:file-text" title="No requirements yet" message="Requirements you submit to OSAS show up here." />
        <button class="link-btn" @click="go('/manager/osas?tab=mine')">
          <IconifyIcon icon="lucide:arrow-right" width="16" />
          <span>Open OSAS</span>
        </button>
      </ProfileBlock>

      <ProfileBlock v-show="shows('ps-accommodations')" id="ps-accommodations" icon="lucide:building-2" title="Accommodations">
        <template #actions>
          <button
            class="icon-btn"
            :disabled="!auth.isVerifiedLandlord"
            :title="auth.isVerifiedLandlord ? 'Add accommodation' : 'Available once OSAS verifies your account'"
            aria-label="Add accommodation"
            @click="go('/manager/properties/new')"
          >
            <IconifyIcon icon="lucide:plus" width="18" />
          </button>
        </template>
        <button class="link-btn" @click="go('/manager/properties')">
          <IconifyIcon icon="lucide:list" width="16" />
          <span>Manage {{ accommodationCount }} {{ accommodationCount === 1 ? 'accommodation' : 'accommodations' }}</span>
          <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
        </button>
        <button class="link-btn" @click="go('/manager/tenants')">
          <IconifyIcon icon="lucide:users" width="16" />
          <span>{{ tenantCount }} active {{ tenantCount === 1 ? 'boarder' : 'boarders' }}</span>
          <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
        </button>
      </ProfileBlock>

      <ProfileBlock v-show="shows('ps-settings')" id="ps-settings" icon="lucide:settings" title="Settings">
        <button class="link-btn" @click="go('/manager/settings')">
          <IconifyIcon icon="lucide:sliders-horizontal" width="16" />
          <span>Notifications, security, appearance &amp; more</span>
          <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
        </button>
      </ProfileBlock>
    </template>

    <template #footer>
      Member since {{ memberSinceLabel || 'recently' }}
      <span v-if="updatedAt" class="updated">· {{ ago(updatedAt) }}</span>
    </template>
  </ProfileCard>
  </div>
</template>

<script setup lang="ts">
// The profile's details half: what is still missing, the fields, documents
// and payout details.
import { Icon as IconifyIcon } from '@iconify/vue'
// ProfileField before ProfileBlock: their padding rules tie on specificity,
// so stylesheet order decides, and ProfileBlock's rows must win.
import ProfileField from '@/components/shared/ProfileField.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import ProfileCard from '@/components/shared/ProfileCard.vue'
import ProfileBlock from '@/components/shared/ProfileBlock.vue'
import EditButton from '@/components/shared/EditButton.vue'
import ProfileCompleteStrip from '@/components/shared/ProfileCompleteStrip.vue'
import { ago, birthDateLabel, sexLabel } from '@/utils/profile'
import { isDesktop } from '@/utils/useTabletMode'
import { useManagerProfile } from './managerProfile'

const {
  auth,
  saving,
  editing,
  me,
  gaps,
  draft,
  updatedAt,
  accommodationCount,
  tenantCount,
  documents,
  memberSinceLabel,
  pendingDocs,
  shows,
  go,
  startEdit,
  cancelEdit,
  save,
} = useManagerProfile()
</script>

<style scoped>
/* Action Scan */
/* ===== CARDS ===== */
.icon-btn {
  display: flex;
  width: 32px;
  height: 32px;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
  transition: all 0.15s;
}
.icon-btn:hover {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.card-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding: 12px 16px;
  border-top: 1px solid var(--m-bg);
  background: var(--m-surface);
}
.btn-cancel,
.btn-save {
  padding: 8px 22px;
  border: 0;
  border-radius: 999px;
  font-size: 14px;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.15s;
  min-height: 44px;
}
.btn-cancel {
  background: transparent;
  color: var(--m-muted);
}
.btn-cancel:hover {
  background: var(--m-bg);
}
.btn-save {
  background: var(--mp-accent);
  color: white;
}
.btn-save:hover {
  background: var(--mp-accent-dark);
}
.btn-cancel:disabled,
.btn-save:disabled {
  opacity: 0.5;
  pointer-events: none;
}
.updated {
  color: var(--m-muted);
  opacity: 0.7;
}
/* ===== DOCS ===== */
.doc-item {
  display: flex;
  align-items: center;
  gap: 12px;
}
.doc-icon {
  flex: 0 0 32px;
  width: 32px;
  height: 32px;
  display: grid;
  place-items: center;
  border-radius: 999px;
}
.doc-good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.doc-idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.doc-warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.doc-danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.doc-info {
  flex: 1;
  min-width: 0;
}
.doc-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--m-ink);
  display: block;
}
.doc-when {
  font-size: 12px;
  color: var(--m-muted);
}
.doc-status {
  padding: 2px 10px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}
.status-good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.status-idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.status-warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.status-danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
/* ===== LINK BUTTONS ===== */
.link-btn {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 12px;
  background: transparent;
  border: 0;
  cursor: pointer;
  font: inherit;
  text-align: left;
  color: var(--m-ink);
  padding: 12px 16px;
  min-height: 48px;
  transition: background 0.12s;
}
.link-btn:hover {
  background: var(--m-bg);
}
.link-btn .chevron {
  margin-left: auto;
  color: var(--m-muted);
}
</style>
