<template>
  <AppModal
    v-model="facilityOpen"
    :title="facilityDialogMode === 'edit' ? (facilityForm.label || FACILITY_META[facilityForm.facilityType]?.label || 'Facility') : 'Add facility'"
    :icon="FACILITY_META[facilityForm.facilityType]?.icon || 'lucide:box'"
    tall
  >
    <div class="room-sheet-scroll">
      <div v-if="facilityDialogMode === 'create'" class="steps steps--sheet">
        <span v-for="n in 2" :key="n" class="step-dot" :class="{ 'step-dot--on': n <= facilityStep }" />
      </div>

      <!-- Basics: step 1 (create), or always shown in view/edit -->
      <template v-if="facilityDialogMode === 'create' ? facilityStep === 1 : true">
        <div v-if="facilityDialogMode === 'edit' && facilityViewMode === 'view'" class="view-group">
          <div class="view-row">
            <span class="view-label">Type</span>
            <span class="view-value">{{ FACILITY_META[facilityForm.facilityType]?.label || facilityForm.facilityType }}</span>
          </div>
          <div class="view-row">
            <span class="view-label">Label</span>
            <span class="view-value">{{ facilityForm.label || '—' }}</span>
          </div>
          <div class="view-row">
            <span class="view-label">Description</span>
            <span class="view-value">{{ facilityForm.description || '—' }}</span>
          </div>
          <template v-if="facilityScope === 'shared'">
            <div class="view-row">
              <span class="view-label">Status</span>
              <span class="view-value">{{ FACILITY_STATUS_LABEL[facilityForm.status] }}</span>
            </div>
            <div class="view-row">
              <span class="view-label">Shared by</span>
              <span class="view-value">{{ roomNames(facilityForm.roomIds) || '—' }}</span>
            </div>
          </template>
        </div>
        <template v-else>
          <label class="field">
            <span class="field-label">Type</span>
            <AppSelect v-model="facilityForm.facilityType" :options="facilityTypeOptions" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">Label (optional)</span>
            <input v-model="facilityForm.label" type="text" class="field-input" placeholder="e.g. Rooftop lounge" />
          </label>
          <label class="field">
            <span class="field-label">Description (optional)</span>
            <input v-model="facilityForm.description" type="text" class="field-input" />
          </label>
          <template v-if="facilityScope === 'shared'">
            <label class="field">
              <span class="field-label">Status</span>
              <AppSelect v-model="facilityForm.status" :options="FACILITY_STATUS_LABEL" class="field-input" />
            </label>
            <div class="field">
              <span class="field-label">Shared by</span>
              <q-option-group v-if="rooms.length" v-model="facilityForm.roomIds" :options="roomOptions" type="checkbox" color="primary" dense />
              <p v-else class="none">Add rooms first, then pick which ones share this facility.</p>
            </div>
          </template>
        </template>
      </template>

      <!-- Photos: step 2 (create), or always shown in view/edit -->
      <template v-if="facilityDialogMode === 'create' ? facilityStep === 2 : true">
        <div class="sheet-section">
          <span class="field-label">Photos</span>
          <span v-if="uploadingFacilityId === activeFacilityId" class="sec-hint">Uploading…</span>
          <div v-if="activeFacilityImages.length" class="thumbs">
            <div v-for="img in activeFacilityImages" :key="img.id" class="thumb">
              <img :src="img.url" alt="" />
              <q-spinner v-if="img.pending" class="thumb-wait" size="20px" />
              <button
                v-else-if="facilityDialogMode === 'create' || facilityViewMode === 'edit'"
                type="button"
                class="thumb-x"
                :disabled="deletingFacilityImageId === img.id"
                @click="deleteFacilityPhotoInDialog(img.id)"
              >
                <IconifyIcon icon="lucide:x" width="12" />
              </button>
            </div>
          </div>
          <p v-else class="none">No photos yet.</p>
        </div>
      </template>
    </div>

    <div
      v-if="facilityDialogMode === 'create' ? facilityStep === 2 : facilityViewMode === 'edit'"
      class="photo-actions photo-actions--pinned"
    >
      <button type="button" class="photo-action-btn" @click="takeFacilityPhoto(activeFacilityId)">
        <IconifyIcon icon="lucide:camera" width="15" />
        Take photo
      </button>
      <label class="photo-action-btn">
        <IconifyIcon icon="lucide:image-plus" width="15" />
        Upload
        <input type="file" accept="image/*" multiple class="file-input-hidden" @change="uploadFacilityPhoto($event, activeFacilityId)" />
      </label>
    </div>
    <template #footer>
      <div v-if="facilityDialogMode === 'edit' && facilityViewMode === 'view'" class="wizard-nav">
        <q-btn unelevated rounded no-caps color="primary" class="save-btn" label="Edit" @click="facilityViewMode = 'edit'" />
      </div>
      <div v-else-if="facilityDialogMode === 'edit'" class="room-sheet-actions">
        <button type="button" class="room-del" :disabled="savingFacility" @click="deleteFacilityDirect">Delete</button>
        <q-btn unelevated rounded no-caps color="primary" class="save-btn" :loading="savingFacility" label="Save facility" @click="saveFacilityEdits" />
      </div>
      <div v-else class="wizard-nav">
        <button v-if="facilityStep > 1" type="button" class="ghost-btn" @click="facilityStep--">Back</button>
        <q-btn
          v-if="facilityStep === 1"
          unelevated
          rounded
          no-caps
          color="primary"
          class="save-btn"
          label="Next"
          :loading="savingFacility"
          @click="confirmFacilityBasics"
        />
        <q-btn v-else unelevated rounded no-caps color="primary" class="save-btn" label="Done" @click="facilityOpen = false" />
      </div>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
// Add, view or edit one facility (shared on a floor, or private to a room).
import { Icon as IconifyIcon } from '@iconify/vue'
import AppModal from '@/components/shared/AppModal.vue'
import AppSelect from '@/components/shared/AppSelect.vue'
import { FACILITY_META } from '@/utils/listings'
import { FACILITY_STATUS_LABEL } from './model'
import { useAccommodationDetail } from './detail'

const {
  activeFacilityId,
  activeFacilityImages,
  confirmFacilityBasics,
  deleteFacilityDirect,
  deleteFacilityPhotoInDialog,
  deletingFacilityImageId,
  facilityDialogMode,
  facilityForm,
  facilityOpen,
  facilityScope,
  facilityStep,
  facilityTypeOptions,
  facilityViewMode,
  roomNames,
  roomOptions,
  rooms,
  saveFacilityEdits,
  savingFacility,
  takeFacilityPhoto,
  uploadFacilityPhoto,
  uploadingFacilityId,
} = useAccommodationDetail()
</script>

<style scoped src="./rows.css"></style>
<style scoped src="./sheets.css"></style>
