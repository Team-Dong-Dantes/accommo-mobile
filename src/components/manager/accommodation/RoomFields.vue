<template>
  <div class="field-row">
    <label class="field">
      <span class="field-label">Room number or name</span>
      <input v-model="roomForm.roomNumber" type="text" maxlength="20" class="field-input" :placeholder="previewRoomNumber" />
    </label>
    <label class="field">
      <span class="field-label">Floor</span>
      <AppSelect
        v-model="roomForm.floor"
        :options="floorOptions.map((f) => ({ label: floorName(f), value: f }))"
        class="field-input"
        @update:model-value="onRoomFloorChange"
      />
    </label>
  </div>

  <div class="field-row">
    <label class="field">
      <span class="field-label">Room type</span>
      <AppSelect
        v-model="roomForm.roomType"
        :options="{ ...ROOM_TYPE_LABEL, custom: 'Custom' }"
        class="field-input"
        @update:model-value="onRoomTypeChange"
      />
    </label>
    <label v-if="roomForm.roomType === 'custom'" class="field">
      <span class="field-label">Custom type name</span>
      <input v-model="roomForm.customRoomType" type="text" class="field-input" />
    </label>
  </div>

  <label class="field">
    <span class="field-label">Capacity</span>
    <input
      v-model.number="roomForm.capacity"
      type="number"
      min="1"
      :max="CAPACITY_MAX"
      class="field-input"
      :disabled="roomForm.roomType in ROOM_TYPE_DEFAULT_CAPACITY"
      @blur="roomForm.capacity = clampNum(roomForm.capacity, 1, CAPACITY_MAX)"
    />
  </label>
  <p v-if="roomForm.roomType in ROOM_TYPE_DEFAULT_CAPACITY" class="sec-hint">
    Capacity is fixed at {{ roomForm.capacity }} for {{ ROOM_TYPE_LABEL[roomForm.roomType] }} rooms.
  </p>

  <div class="field-row">
    <div v-if="roomForm.capacity > 1" class="field">
      <span class="field-label">Rent is for</span>
      <div class="m-chips">
        <button
          type="button"
          class="m-chip"
          :class="{ 'm-chip--on': roomForm.rentBasis === 'room' }"
          @click="roomForm.rentBasis = 'room'"
        >
          Whole room
        </button>
        <button
          type="button"
          class="m-chip"
          :class="{ 'm-chip--on': roomForm.rentBasis === 'person' }"
          @click="roomForm.rentBasis = 'person'"
        >
          Per person
        </button>
      </div>
    </div>
    <label class="field">
      <span class="field-label">Monthly rent</span>
      <div class="field-prefixed">
        <span class="field-prefix">₱</span>
        <input
          v-model.number="roomForm.monthlyRent"
          type="number"
          min="0"
          :max="RENT_MAX"
          step="0.01"
          class="field-input field-input--prefixed"
          @blur="roomForm.monthlyRent = clampNum(roomForm.monthlyRent, 0, RENT_MAX)"
        />
      </div>
    </label>
  </div>
  <p v-if="rentBasisHint" class="sec-hint">{{ rentBasisHint }}</p>

  <div class="field-row">
    <label class="field">
      <span class="field-label">Advance (months)</span>
      <input
        v-model.number="roomForm.advanceMonths"
        type="number"
        min="0"
        :max="MONTHS_MAX"
        class="field-input"
        @blur="roomForm.advanceMonths = clampOptional(roomForm.advanceMonths, 0, MONTHS_MAX)"
      />
    </label>
    <label class="field">
      <span class="field-label">Deposit (months)</span>
      <input
        v-model.number="roomForm.depositMonths"
        type="number"
        min="0"
        :max="MONTHS_MAX"
        class="field-input"
        @blur="roomForm.depositMonths = clampOptional(roomForm.depositMonths, 0, MONTHS_MAX)"
      />
    </label>
  </div>

  <div class="sheet-section">
    <span class="field-label">Utilities</span>
    <p v-if="activeRoomTenants > 0" class="sec-hint">
      Current boarders keep the terms they moved in with. Changes apply to new boarders.
    </p>
    <UtilitiesFields v-model="roomForm.utilities" />
  </div>

  <template v-if="roomDialogMode === 'create'">
    <label class="field">
      <span class="field-label">How many rooms like this?</span>
      <input
        v-model.number="roomForm.count"
        type="number"
        min="1"
        :max="BULK_MAX"
        class="field-input"
        @blur="roomForm.count = clampNum(roomForm.count, 1, BULK_MAX)"
      />
    </label>
    <p v-if="roomForm.count > 1" class="sec-hint">
      Adds {{ bulkNumbers.length }} identical rooms: {{ bulkNumbers.join(', ') }}. Add photos to each one afterwards.
    </p>
  </template>
</template>

<script setup lang="ts">
// The room form's editable fields: step 1 of adding a room, or an
// existing room in edit mode.
import AppSelect from '@/components/shared/AppSelect.vue'
import UtilitiesFields from '@/components/manager/UtilitiesFields.vue'
import { CAPACITY_MAX, MONTHS_MAX, RENT_MAX, clampNum, clampOptional } from '@/utils/roomInventory'
import { BULK_MAX } from './rooms'
import { ROOM_TYPE_LABEL, ROOM_TYPE_DEFAULT_CAPACITY } from '@/utils/listings'
import { useAccommodationDetail } from './detail'

const {
  activeRoomTenants,
  bulkNumbers,
  floorName,
  floorOptions,
  onRoomFloorChange,
  onRoomTypeChange,
  previewRoomNumber,
  rentBasisHint,
  roomDialogMode,
  roomForm,
} = useAccommodationDetail()
</script>

<style scoped src="./rows.css"></style>
<style scoped src="./sheets.css"></style>

<style scoped>
.field-prefixed {
  position: relative;
  display: flex;
  width: 100%;
  align-items: center;
}
.field-prefix {
  position: absolute;
  left: 12px;
  color: var(--m-muted);
  font-size: 14px;
  font-weight: 700;
  pointer-events: none;
}
.field-input--prefixed {
  padding-left: 28px;
}
</style>
