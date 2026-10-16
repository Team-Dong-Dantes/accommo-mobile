<template>
  <div :class="isDesktop ? 'desk-col' : 'desk-pass'">
  <ProfileCompleteStrip :gaps="gaps" to="/student/profile/complete" />
  <!-- Profile -->
  <ProfileCard :open="isDesktop">
    <template #always>
      <ProfileBlock v-show="shows('ps-details')" id="ps-details" icon="lucide:user" title="Your details">
        <template #actions>
          <EditButton v-if="!editing" @click="startEdit" />
        </template>
        <ProfileField v-model="draft.fullName" label="Full name" :editing="editing" />
        <ProfileField v-model="draft.phone" label="Phone" type="tel" :editing="editing" placeholder="+63…" />
        <ProfileField v-model="draft.email" label="Email" readonly :editing="editing" />
        <!-- Filled in through Complete your profile; changed after that by OSAS only. -->
        <ProfileField :model-value="sexLabel(me.sex)" label="Sex" readonly :editing="editing" />
        <ProfileField :model-value="birthDateLabel(me.dob)" label="Date of birth" readonly :editing="editing" />
      </ProfileBlock>
    </template>

    <template #more>
      <ProfileBlock v-show="shows('ps-academics')" id="ps-academics" icon="lucide:graduation-cap" title="Academics">
        <template #actions>
          <EditButton v-if="!editing" @click="startEdit" />
        </template>
        <!-- Editable only while blank: freshmen register before ISU issues
             them one. Once set it is fixed here, and the DB locks it for good
             once OSAS verifies the account. -->
        <ProfileField
          v-model="draft.studentId"
          label="Student ID"
          :readonly="!!academics.studentId"
          :editing="editing"
          :placeholder="editing ? 'YY-NNNN, e.g. 25-01234' : 'Not set'"
        />
        <ProfileField
          :model-value="draft.college"
          label="College"
          type="select"
          :options="collegeOptions"
          :editing="editing"
          @update:model-value="onCollegeChange"
        />
        <ProfileField
          v-model="draft.program"
          label="Program"
          type="select"
          :options="programOptions"
          :editing="editing"
        />
        <ProfileField
          v-model="draft.yearLevel"
          label="Year level"
          type="select"
          :options="yearOptions"
          :editing="editing"
        />
      </ProfileBlock>

      <ProfileBlock v-show="shows('ps-emergency')" id="ps-emergency" icon="lucide:phone-forwarded" title="Emergency contact">
        <template #actions>
          <EditButton v-if="!editing" @click="startEdit" />
        </template>
        <ProfileField v-model="draft.emergencyName" label="Name" :editing="editing" />
        <ProfileField v-model="draft.emergencyRelation" label="Relationship" :editing="editing" placeholder="Parent, guardian…" />
        <ProfileField v-model="draft.emergencyPhone" label="Phone" type="tel" :editing="editing" placeholder="+63…" />
      </ProfileBlock>

      <ProfileBlock v-show="shows('ps-verification')" id="ps-verification" icon="lucide:shield-check" title="Verification" :badge="pendingDocs > 0 ? `${pendingDocs} pending` : ''">
        <div v-if="documents.length">
          <div v-for="doc in documents" :key="doc.id" class="doc-row">
            <span class="doc-icon" :class="`doc-icon--${doc.tone}`">
              <IconifyIcon :icon="doc.icon" width="14" />
            </span>
            <div class="doc-info">
              <span class="doc-name">{{ doc.label }}</span>
              <span class="doc-when">{{ doc.when }}</span>
            </div>
            <span class="doc-tag" :class="`doc-tag--${doc.tone}`">{{ doc.statusLabel }}</span>
          </div>
        </div>
        <EmptyState v-else variant="compact" icon="lucide:file-text" title="No requirements yet" message="Requirements you submit to OSAS show up here." />
        <button class="row-link" @click="go('/student/support')">
          <IconifyIcon icon="lucide:arrow-right" width="16" />
          <span>Open OSAS verification</span>
        </button>
      </ProfileBlock>

      <ProfileBlock v-show="shows('ps-settings')" id="ps-settings" icon="lucide:settings" title="Settings">
        <button class="row-link" @click="go('/student/settings')">
          <IconifyIcon icon="lucide:sliders-horizontal" width="16" />
          <span>Notifications, security, appearance &amp; more</span>
        </button>
      </ProfileBlock>
    </template>

    <template #footer>
      Member since {{ memberSinceLabel || 'recently' }}
      <span v-if="updatedAt" class="updated">· Updated {{ ago(updatedAt) }}</span>
    </template>
  </ProfileCard>

  <!-- Edit bar -->
  <div v-if="editing" class="edit-bar">
    <button class="edit-btn-cancel" :disabled="saving" @click="cancelEdit">Cancel</button>
    <button class="edit-btn-save" :disabled="saving" @click="save">
      {{ saving ? 'Saving…' : 'Save changes' }}
    </button>
  </div>
  </div>
</template>

<script setup lang="ts">
// The profile's details half: what is still missing, the fields, documents
// and stay, and the edit bar.
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
import { collegeOptions, yearOptions } from '@/constants/academics'
import { isDesktop } from '@/utils/useTabletMode'
import { useStudentProfile } from './studentProfile'

const {
  saving,
  editing,
  me,
  academics,
  draft,
  updatedAt,
  documents,
  gaps,
  memberSinceLabel,
  pendingDocs,
  shows,
  programOptions,
  onCollegeChange,
  go,
  startEdit,
  cancelEdit,
  save,
} = useStudentProfile()
</script>

<style scoped>
.doc-row {
  display: flex;
  align-items: center;
  gap: 10px;
}
.doc-icon {
  flex: 0 0 28px;
  width: 28px;
  height: 28px;
  display: grid;
  place-items: center;
  border-radius: 999px;
}
.doc-icon--good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.doc-icon--idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.doc-icon--warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.doc-icon--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.doc-info {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
}
.doc-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--m-ink);
}
.doc-when {
  font-size: 11px;
  color: var(--m-muted);
}
.doc-tag {
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}
.doc-tag--good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.doc-tag--idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.doc-tag--warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.doc-tag--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.row-link {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  background: transparent;
  border: 0;
  cursor: pointer;
  font: inherit;
  text-align: left;
  color: var(--m-ink);
  transition: background 0.12s;
}
.row-link:hover {
  background: var(--m-bg);
}
.updated {
  color: var(--m-muted);
  opacity: 0.7;
}
.edit-bar {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 100;
  display: flex;
  gap: 8px;
  justify-content: flex-end;
  padding: 12px 16px;
  padding-bottom: calc(12px + env(safe-area-inset-bottom, 0px));
  background: var(--m-surface);
  border-top: 1px solid var(--m-border);
  box-shadow: 0 -6px 20px rgba(0,0,0,0.06);
  animation: slideUp 0.2s ease;
}
.edit-btn-cancel,
.edit-btn-save {
  padding: 8px 18px;
  border: 0;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.15s;
}
.edit-btn-cancel {
  background: transparent;
  color: var(--m-muted);
}
.edit-btn-cancel:hover {
  background: var(--m-bg);
}
.edit-btn-save {
  background: var(--m-primary);
  color: #fff;
}
.edit-btn-save:hover {
  background: var(--m-primary-dark);
}
.edit-btn-cancel:disabled,
.edit-btn-save:disabled {
  opacity: 0.5;
  pointer-events: none;
}
@media (prefers-reduced-motion: reduce) {
  .edit-bar {
      animation: none;
    }
}
@keyframes slideUp {
  from {
    transform: translateY(100%);
    opacity: 0;
  }
  to {
    transform: translateY(0);
    opacity: 1;
  }
}
</style>
