<template>
  <AppModal
    v-model="roomOpen"
    :title="roomDialogMode === 'edit' ? 'Edit room' : 'Add room'"
    icon="lucide:bed-double"
    tall
    @hide="onRoomDialogHide"
  >
    <div class="room-sheet-scroll">
      <div v-if="roomDialogMode === 'create'" class="steps steps--sheet">
        <span v-for="n in 4" :key="n" class="step-dot" :class="{ 'step-dot--on': n <= roomStep }" />
      </div>

      <!-- STEP 1 / edit mode: basics -->
      <template v-if="roomDialogMode === 'edit' || roomStep === 1">
        <div v-if="editingRoomId" class="room-name-static">
          <span class="room-name-static-label">Room {{ activeRoomNumber || '—' }}</span>
          <span class="room-name-static-floor">{{ floorName(roomForm.floor) }}</span>
        </div>
        <div v-else-if="roomStep > 1" class="room-name-static">
          <span class="room-name-static-label">Room {{ activeRoomNumber }}</span>
          <span class="room-name-static-floor">{{ floorName(roomForm.floor) }}</span>
        </div>

        <div v-if="roomDialogMode === 'edit'" class="status-box">
          <p class="status-text">
            {{
              activeRoomStatus === 'occupied'
                ? 'This room is currently occupied.'
                : activeRoomStatus === 'maintenance'
                  ? 'Marked unavailable — hidden from new applicants until reopened.'
                  : 'Available and visible to students.'
            }}
          </p>
          <button
            v-if="activeRoomStatus !== 'occupied'"
            type="button"
            class="status-btn"
            :class="{ 'status-btn--danger': activeRoomStatus === 'available' }"
            :disabled="togglingRoomStatus"
            @click="toggleRoomStatus"
          >
            {{ activeRoomStatus === 'maintenance' ? 'Mark as available' : 'Mark as unavailable' }}
          </button>
        </div>

        <!-- Read-only recap once a room already exists; "Edit" swaps this for the editable fields below. -->
        <div v-if="roomDialogMode === 'edit' && roomViewMode === 'view'" class="view-group">
          <div class="view-row">
            <span class="view-label">Type</span>
            <span class="view-value">{{ roomTypeLabel(roomForm.roomType === 'custom' ? roomForm.customRoomType : roomForm.roomType) }}</span>
          </div>
          <div class="view-row">
            <span class="view-label">Capacity</span>
            <span class="view-value">{{ roomForm.capacity }}</span>
          </div>
          <div class="view-row">
            <span class="view-label">Rent</span>
            <span class="view-value">
              {{ formatPeso(roomForm.monthlyRent) }}/mo{{ roomForm.capacity > 1 ? (roomForm.rentBasis === 'person' ? ' per person' : ' whole room') : '' }}
            </span>
          </div>
          <div class="view-row">
            <span class="view-label">Advance</span>
            <span class="view-value">{{ roomForm.advanceMonths ?? '—' }} mo</span>
          </div>
          <div class="view-row">
            <span class="view-label">Deposit</span>
            <span class="view-value">{{ roomForm.depositMonths ?? '—' }} mo</span>
          </div>
          <div v-for="u in UTILITIES" :key="u.key" class="view-row">
            <span class="view-label">{{ u.label }}</span>
            <span class="view-value">{{ utilityTermsLabel(roomForm.utilities[u.key]) }}</span>
          </div>
        </div>

    <RoomFields v-else />
      </template>

      <!-- STEP 2 / edit mode: photos (shown in both view and edit) -->
      <template v-if="roomDialogMode === 'edit' || roomStep === 2">
        <div class="sheet-section">
          <span class="field-label">Photos</span>
          <span v-if="uploadingRoomPhoto" class="sec-hint">Uploading…</span>
          <div v-if="roomImages.length" class="thumbs">
            <div v-for="img in roomImages" :key="img.id" class="thumb">
              <img :src="img.url" alt="" />
              <button
                v-if="roomDialogMode === 'create' || roomViewMode === 'edit'"
                type="button"
                class="thumb-x"
                :disabled="deletingRoomImage === img.id"
                @click="deleteRoomImage(img.id)"
              >
                <IconifyIcon icon="lucide:x" width="12" />
              </button>
            </div>
          </div>
          <p v-else class="none">No photos yet.</p>
        </div>
      </template>

      <!-- STEP 3 / edit mode: private facilities -->
      <template v-if="roomDialogMode === 'edit' || roomStep === 3">
        <div class="sheet-section">
          <div class="sec-head">
            <span class="field-label">Private facilities</span>
            <button
              v-if="roomDialogMode === 'create' || roomViewMode === 'edit'"
              type="button"
              class="sec-link"
              :disabled="!canAddInventory"
              @click="openFacilityAddDialog('private', editingRoomId)"
            >
              Add
            </button>
          </div>
          <div v-if="currentRoomFacilities.length" class="group">
            <button v-for="f in currentRoomFacilities" :key="f.id" type="button" class="room-row" @click="openFacilityDetails(f)">
              <span class="room-shot">
                <img v-if="f.images[0]" :src="f.images[0].url" alt="" />
                <PhotoEmpty v-else />
              </span>
              <span class="room-body">
                <span class="room-name">{{ f.label || FACILITY_META[f.facilityType]?.label || f.facilityType }}</span>
                <span v-if="uploadingFacilityId === f.id" class="room-sub">Uploading…</span>
                <span v-else-if="f.description" class="room-sub">{{ f.description }}</span>
                <span v-else class="room-sub">{{ f.images.length ? `${f.images.length} photo${f.images.length === 1 ? '' : 's'}` : 'Private facility' }}</span>
              </span>
            </button>
          </div>
          <p v-else class="none">No private facilities for this room yet.</p>
        </div>
      </template>

      <!-- STEP 4 (create only): summary -->
      <template v-if="roomDialogMode === 'create' && roomStep === 4">
        <div class="sheet-section">
          <span class="field-label">Summary</span>
          <div class="group">
            <div class="rule">
              <span class="rule-label">Room</span>
              <span class="rule-value">Room {{ activeRoomNumber || '—' }} · {{ floorName(roomForm.floor) }}</span>
            </div>
            <div class="rule">
              <span class="rule-label">Type</span>
              <span class="rule-value">{{ roomTypeLabel(roomForm.roomType === 'custom' ? roomForm.customRoomType : roomForm.roomType) }}</span>
            </div>
            <div class="rule">
              <span class="rule-label">Capacity</span>
              <span class="rule-value">{{ roomForm.capacity }}</span>
            </div>
            <div class="rule">
              <span class="rule-label">Rent</span>
              <span class="rule-value">
                {{ formatPeso(roomForm.monthlyRent) }}/mo{{ roomForm.capacity > 1 ? (roomForm.rentBasis === 'person' ? ' per person' : ' whole room') : '' }}
              </span>
            </div>
            <div v-if="roomForm.advanceMonths || roomForm.depositMonths" class="rule">
              <span class="rule-label">Advance / Deposit</span>
              <span class="rule-value">{{ roomForm.advanceMonths ?? 0 }} / {{ roomForm.depositMonths ?? 0 }} mo</span>
            </div>
            <div v-for="u in UTILITIES" :key="u.key" class="rule">
              <span class="rule-label">{{ u.label }}</span>
              <span class="rule-value">{{ utilityTermsLabel(roomForm.utilities[u.key]) }}</span>
            </div>
            <div class="rule">
              <span class="rule-label">Photos</span>
              <span class="rule-value">{{ roomImages.length }}</span>
            </div>
            <div class="rule">
              <span class="rule-label">Private facilities</span>
              <span class="rule-value">
                {{
                  currentRoomFacilities.length
                    ? currentRoomFacilities.map((f) => f.label || FACILITY_META[f.facilityType]?.label || f.facilityType).join(', ')
                    : 'None'
                }}
              </span>
            </div>
          </div>
        </div>
      </template>
    </div>

    <div v-if="roomDialogMode === 'create' ? roomStep === 2 : roomViewMode === 'edit'" class="photo-actions photo-actions--pinned">
      <button type="button" class="photo-action-btn" @click="takeRoomPhoto">
        <IconifyIcon icon="lucide:camera" width="15" />
        Take photo
      </button>
      <label class="photo-action-btn">
        <IconifyIcon icon="lucide:image-plus" width="15" />
        Upload
        <input type="file" accept="image/*" multiple class="file-input-hidden" @change="onRoomPhotosSelected" />
      </label>
    </div>
    <template #footer>
      <div v-if="roomDialogMode === 'edit' && roomViewMode === 'view'" class="wizard-nav">
        <button type="button" class="ghost-btn" :disabled="savingRoom || !canAddInventory" @click="duplicateRoom">Duplicate</button>
        <q-btn unelevated rounded no-caps color="primary" class="save-btn" label="Edit" @click="roomViewMode = 'edit'" />
      </div>
      <div v-else-if="roomDialogMode === 'edit'" class="room-sheet-actions">
        <button type="button" class="room-del" :disabled="savingRoom" @click="confirmDeleteRoomOpen = true">Delete</button>
        <q-btn unelevated rounded no-caps color="primary" class="save-btn" :loading="savingRoom" label="Save room" @click="confirmRoomBasics" />
      </div>
      <div v-else class="wizard-nav">
        <button v-if="roomStep > 1" type="button" class="ghost-btn" @click="roomStep--">Back</button>
        <q-btn
          v-if="roomStep === 1"
          unelevated
          rounded
          no-caps
          color="primary"
          class="save-btn"
          :label="roomForm.count > 1 ? `Add ${bulkNumbers.length} rooms` : 'Next'"
          :loading="savingRoom"
          @click="confirmRoomBasics"
        />
        <q-btn
          v-else-if="roomStep < 4"
          unelevated
          rounded
          no-caps
          color="primary"
          class="save-btn"
          label="Next"
          @click="roomStep++"
        />
        <q-btn
          v-else
          unelevated
          rounded
          no-caps
          color="primary"
          class="save-btn"
          label="Done"
          :loading="togglingRoomStatus"
          @click="finishNewRoom"
        />
      </div>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
// Add or edit one room: a four-step wizard for a new room, a view/edit
// sheet for an existing one.
import { Icon as IconifyIcon } from '@iconify/vue'
import PhotoEmpty from '@/components/shared/PhotoEmpty.vue'
import AppModal from '@/components/shared/AppModal.vue'
import { formatPeso } from '@/utils/format'
import { UTILITIES, utilityTermsLabel, FACILITY_META, roomTypeLabel } from '@/utils/listings'
import RoomFields from './RoomFields.vue'
import { useAccommodationDetail } from './detail'

const {
  activeRoomNumber,
  activeRoomStatus,
  bulkNumbers,
  canAddInventory,
  confirmDeleteRoomOpen,
  confirmRoomBasics,
  currentRoomFacilities,
  deleteRoomImage,
  deletingRoomImage,
  duplicateRoom,
  editingRoomId,
  finishNewRoom,
  floorName,
  onRoomDialogHide,
  onRoomPhotosSelected,
  openFacilityAddDialog,
  openFacilityDetails,
  roomDialogMode,
  roomForm,
  roomImages,
  roomOpen,
  roomStep,
  roomViewMode,
  savingRoom,
  takeRoomPhoto,
  toggleRoomStatus,
  togglingRoomStatus,
  uploadingFacilityId,
  uploadingRoomPhoto,
} = useAccommodationDetail()
</script>

<style scoped src="./rows.css"></style>
<style scoped src="./sheets.css"></style>

<style scoped>
.rule {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .rule:first-child {
  border-top: 0;
}
.rule-label {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.rule-value {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
  text-align: right;
}
.room-name-static {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
}
.room-name-static-label {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.room-name-static-floor {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}
</style>
