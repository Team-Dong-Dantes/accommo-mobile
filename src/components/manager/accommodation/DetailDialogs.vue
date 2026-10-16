<template>
  <!-- COVER PHOTOS -->
  <AppModal v-model="coverSheetOpen" title="Property photos" icon="lucide:camera" tall>
    <div class="room-sheet-scroll">
      <input type="file" accept="image/*" multiple class="file-input" @change="onCoverPhotosSelected" />
      <span v-if="uploadingCover" class="sec-hint">Uploading…</span>
      <div v-if="images.length" class="thumbs">
        <div v-for="img in images" :key="img.id" class="thumb">
          <img :src="img.url" alt="" />
          <button type="button" class="thumb-x" :disabled="deletingImage === img.id" @click="deleteImage(img.id)">
            <IconifyIcon icon="lucide:x" width="12" />
          </button>
        </div>
      </div>
      <p v-else class="none">No photos yet.</p>
    </div>
  </AppModal>

  <PermitUploadSheet
    v-model="permitSheetOpen"
    :accommodation-id="id"
    :doc-type="permitSheetType"
    :replacing="docRows.some((d) => d.doc_type === permitSheetType)"
    @saved="accreditationCard?.permitReplaced(); loadDocs()"
  />

  <!-- PERMIT FILE PREVIEW -->
  <AppModal v-model="docPreviewOpen" title="Permit file" icon="lucide:file-text">
    <div class="room-sheet-scroll">
      <img v-if="docPreviewUrl && !isPdf(docPreviewUrl)" :src="resolveAsset(docPreviewUrl)" alt="" class="doc-preview-img" />
      <a v-else-if="docPreviewUrl" :href="resolveAsset(docPreviewUrl)" target="_blank" rel="noopener" class="doc-preview-file">
        <IconifyIcon icon="lucide:external-link" width="18" />
        <span>Open file</span>
      </a>
    </div>
  </AppModal>

  <!-- EDIT ONE FIELD (Overview + Settings both use this) -->
  <AppModal v-model="fieldDialogOpen" :title="editingField ? FIELD_META[editingField].label : ''" icon="lucide:pencil" tall>
    <div class="room-sheet-scroll">
      <p v-if="editingField && fieldReview(editingField) !== 'free'" class="sec-hint">
        {{ fieldReview(editingField) === 'request'
          ? 'OSAS checked this. Your change goes to OSAS, and students keep seeing the current value until it is approved.'
          : 'OSAS checked this, and it can’t change while OSAS is reviewing the listing or it is not accredited.' }}
      </p>
      <AppSelect
        v-if="editingField && FIELD_META[editingField].type === 'select'"
        v-model="fieldDraft"
        :options="FIELD_META[editingField].options ?? {}"
        :placeholder="`Select ${FIELD_META[editingField].label.toLowerCase()}`"
        class="field-input"
      />
      <textarea
        v-else-if="editingField && FIELD_META[editingField].type === 'textarea'"
        v-model="fieldDraft"
        class="field-input field-textarea"
        rows="4"
      />
      <DateTimeField
        v-else-if="editingField && FIELD_META[editingField].type === 'time'"
        v-model="fieldDraft"
        mode="time"
        class="field-input"
      />
      <!-- Quiet hours is a range, so it takes two pickers and is stored
           back as one "10:00 PM – 6:00 AM" string. -->
      <div v-else-if="editingField && FIELD_META[editingField].type === 'timerange'" class="field-row">
        <label class="field">
          <span class="field-label">From</span>
          <DateTimeField v-model="fieldDraft" mode="time" class="field-input" />
        </label>
        <label class="field">
          <span class="field-label">Until</span>
          <DateTimeField v-model="fieldDraftTo" mode="time" class="field-input" />
        </label>
      </div>
      <input v-else v-model="fieldDraft" type="text" class="field-input" />
    </div>
    <template #footer>
      <div class="room-sheet-actions">
        <q-btn
          unelevated
          rounded
          no-caps
          color="primary"
          class="save-btn"
          :loading="savingField"
          :disabled="!!editingField && fieldReview(editingField) === 'locked'"
          :label="editingField && fieldReview(editingField) === 'request' ? 'Send to OSAS' : 'Save'"
          @click="saveField"
        />
      </div>
    </template>
  </AppModal>

  <!-- AMENITIES -->
  <AppModal v-model="amenitiesDialogOpen" title="Amenities" icon="lucide:sparkles" tall>
    <div class="room-sheet-scroll">
      <div class="m-chips">
        <button
          v-for="key in AMENITY_KEYS"
          :key="key"
          type="button"
          class="m-chip"
          :class="{ 'm-chip--on': rules.amenities.includes(key) }"
          @click="toggle(rules.amenities, key)"
        >
          <IconifyIcon :icon="AMENITY_META[key]?.icon || 'lucide:dot'" width="14" />
          {{ AMENITY_META[key]?.label || key }}
        </button>
      </div>
    </div>
    <template #footer>
      <div class="room-sheet-actions">
        <q-btn unelevated rounded no-caps color="primary" class="save-btn" :loading="savingAmenities" label="Save" @click="saveAmenities" />
      </div>
    </template>
  </AppModal>

  <!-- RENAME FLOOR -->
  <AppModal v-model="floorNameOpen" :title="`Name Floor ${floorNameFor}`" icon="lucide:layers">
    <label class="field">
      <span class="field-label">Floor name</span>
      <input v-model="floorNameDraft" type="text" maxlength="30" class="field-input" :placeholder="`Floor ${floorNameFor}`" />
    </label>
    <p class="sec-hint">e.g. Ground floor, Annex. Leave it blank to use the number.</p>
    <template #footer>
      <div class="room-sheet-actions">
        <q-btn unelevated rounded no-caps color="primary" class="save-btn" :loading="savingFloorName" label="Save" @click="saveFloorName" />
      </div>
    </template>
  </AppModal>

  <!-- Three near-identical destructive confirms, one component. Deleting a
       floor takes its rooms with it, so the wording matters and should not
       be maintained in triplicate. -->
  <ConfirmDeleteSheet
    v-model="confirmDeleteAccommodationOpen"
    title="Delete this accommodation?"
    body="This permanently deletes it, along with its rooms, facilities, photos, and permits. This can't be undone."
    confirm-label="Delete accommodation"
    :busy="deletingAccommodation"
    @confirm="deleteAccommodation"
  />

  <ConfirmDeleteSheet
    v-model="confirmDeleteFloorOpen"
    :title="`Delete Floor ${floorPendingDelete}?`"
    body="This permanently deletes every room on this floor, along with their photos and private facilities. This can't be undone."
    confirm-label="Delete floor"
    :busy="deletingFloor !== null"
    @confirm="confirmDeleteFloor"
  />

  <ConfirmDeleteSheet
    v-model="confirmDeleteRoomOpen"
    :title="`Delete Room ${activeRoomNumber}?`"
    body="This permanently deletes this room, along with its photos and private facilities. This can't be undone."
    confirm-label="Delete room"
    :busy="savingRoom"
    @confirm="deleteRoom"
  />
  <!-- ADD ROOM OR FACILITY -->
  <AppModal v-model="addChoiceOpen" :title="`Add to Floor ${addChoiceFloor}`" icon="lucide:plus">
    <div class="group">
      <button type="button" class="facility-row" @click="chooseAddRoom">
        <span class="facility-icon"><IconifyIcon icon="lucide:bed-double" width="16" /></span>
        <span class="facility-body">
          <span class="facility-name">Room</span>
          <span class="facility-sub">A leasable room on this floor</span>
        </span>
      </button>
      <button type="button" class="facility-row" @click="chooseAddFacility">
        <span class="facility-icon"><IconifyIcon icon="lucide:sparkles" width="16" /></span>
        <span class="facility-body">
          <span class="facility-name">Facility</span>
          <span class="facility-sub">A shared amenity on this floor</span>
        </span>
      </button>
    </div>
  </AppModal>

  <LocationPicker
    v-if="locationPickerOpen"
    v-model="locationPickerOpen"
    :initial-lat="acc.lat"
    :initial-lng="acc.lng"
    @confirm="onLocationConfirmed"
  />
</template>

<script setup lang="ts">
// The page's smaller sheets: cover photos, a permit's file and its
// replacement, one field, amenities, a floor's name, the three delete
// confirms, the floor's add choice, and the map picker.
import { Icon as IconifyIcon } from '@iconify/vue'
import AppModal from '@/components/shared/AppModal.vue'
import AppSelect from '@/components/shared/AppSelect.vue'
import DateTimeField from '@/components/shared/DateTimeField.vue'
import ConfirmDeleteSheet from '@/components/shared/ConfirmDeleteSheet.vue'
import PermitUploadSheet from '@/components/manager/PermitUploadSheet.vue'
import { resolveAsset, isPdf } from '@/utils/cloudinaryUrl'
import { AMENITY_META, AMENITY_KEYS } from '@/utils/listings'
import { FIELD_META } from './model'
import { defineAsyncComponent } from 'vue'
import { useAccommodationDetail } from './detail'

const {
  acc,
  accreditationCard,
  activeRoomNumber,
  addChoiceFloor,
  addChoiceOpen,
  amenitiesDialogOpen,
  chooseAddFacility,
  chooseAddRoom,
  confirmDeleteAccommodationOpen,
  confirmDeleteFloor,
  confirmDeleteFloorOpen,
  confirmDeleteRoomOpen,
  coverSheetOpen,
  deleteAccommodation,
  deleteImage,
  deleteRoom,
  deletingAccommodation,
  deletingFloor,
  deletingImage,
  docPreviewOpen,
  docPreviewUrl,
  docRows,
  editingField,
  fieldDialogOpen,
  fieldDraft,
  fieldDraftTo,
  fieldReview,
  floorNameDraft,
  floorNameFor,
  floorNameOpen,
  floorPendingDelete,
  id,
  images,
  loadDocs,
  locationPickerOpen,
  onCoverPhotosSelected,
  onLocationConfirmed,
  permitSheetOpen,
  permitSheetType,
  rules,
  saveAmenities,
  saveField,
  saveFloorName,
  savingAmenities,
  savingField,
  savingFloorName,
  savingRoom,
  toggle,
  uploadingCover,
} = useAccommodationDetail()
// Loaded on demand — mapbox-gl (pulled in only by this component) is by far
// the heaviest dependency in the app, and the picker is opened rarely.
const LocationPicker = defineAsyncComponent(() => import('@/components/manager/LocationPicker.vue'))
</script>

<style scoped src="./rows.css"></style>
<style scoped src="./sheets.css"></style>

<style scoped>
.field-textarea {
  min-height: 90px;
  padding: 10px 12px;
  resize: vertical;
}
.facility-row {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.group > .facility-row:first-child {
  border-top: 0;
}
.facility-icon {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.facility-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
}
.facility-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.facility-sub {
  color: var(--m-muted);
  font-size: 11.5px;
}
.doc-preview-img {
  width: 100%;
  max-height: 320px;
  border-radius: var(--m-radius-sm);
  object-fit: contain;
}
.doc-preview-file {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  min-height: 44px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 700;
  text-decoration: none;
}
.file-input {
  font-size: 13px;
}
</style>
