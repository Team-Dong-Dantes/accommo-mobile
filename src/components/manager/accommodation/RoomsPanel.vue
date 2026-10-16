<template>
  <div class="sec-body">
  <p v-if="!canAddInventory && roomsByFloor.length" class="sec-hint">{{ inventoryClosedHint }}</p>
  <template v-if="roomsByFloor.length">
    <div v-for="grp in roomsByFloor" :key="grp.floor ?? 'none'" class="floor-group">
      <div class="sec-head">
        <h3 class="floor-title">
          {{ grp.label }} ({{ grp.rooms.length + grp.facilities.length }})
          <button
            v-if="grp.floor !== null"
            type="button"
            class="floor-rename"
            aria-label="Rename this floor"
            @click="openFloorName(grp.floor)"
          >
            <IconifyIcon icon="lucide:pencil" width="13" />
          </button>
        </h3>
        <div v-if="grp.floor !== null" class="floor-actions">
          <button type="button" class="sec-link" :disabled="!canAddInventory" @click="openAddChoice(grp.floor)">Add room/facility</button>
          <button
            type="button"
            class="floor-del"
            :disabled="deletingFloor === grp.floor"
            aria-label="Delete this floor"
            @click="promptDeleteFloor(grp.floor)"
          >
            <IconifyIcon icon="lucide:trash-2" width="14" />
          </button>
        </div>
      </div>
      <div v-if="grp.rooms.length" class="group">
        <button v-for="r in grp.rooms" :key="r.id" type="button" class="room-row" @click="openRoomDialog(r)">
          <span class="room-shot">
            <img v-if="r.photoUrl" :src="r.photoUrl" alt="" />
            <PhotoEmpty v-else />
          </span>
          <span class="room-body">
            <span class="room-name">{{ r.roomNumber ? `Room ${r.roomNumber}` : 'Room' }}</span>
            <span class="room-sub">
              {{ roomTypeLabel(r.customRoomType || r.roomType) }} · {{ formatPeso(r.monthlyRent) }}/mo{{ r.rentBasis === 'person' && (r.capacity ?? 0) > 1 ? ' · per person' : '' }}
            </span>
          </span>
          <span class="room-chip" :class="`room-chip--${ROOM_STATUS_TONE[r.status] || `grey`}`">
            {{ r.currentPax }}/{{ r.capacity ?? '—' }}
          </span>
        </button>
      </div>
      <p v-else class="none">No rooms on this floor yet.</p>

      <div v-if="grp.facilities.length" class="group">
        <button v-for="f in grp.facilities" :key="f.id" type="button" class="room-row" @click="openFacilityDetails(f)">
          <span class="room-shot">
            <img v-if="f.images[0]" :src="f.images[0].url" alt="" />
            <PhotoEmpty v-else />
          </span>
          <span class="room-body">
            <span class="room-name">{{ f.label || FACILITY_META[f.facilityType]?.label || f.facilityType }}</span>
            <span v-if="uploadingFacilityId === f.id" class="room-sub">Uploading…</span>
            <span v-else class="room-sub">{{ sharedFacilitySub(f) }}</span>
          </span>
        </button>
      </div>
    </div>
    <button
      v-if="floorCount < MAX_FLOORS"
      type="button"
      class="sec-link add-floor-link"
      :disabled="addingFloor || !canAddInventory"
      @click="addFloor"
    >
      Add floor
    </button>
    <p v-else class="sec-hint">Maximum of {{ MAX_FLOORS }} floors reached.</p>
  </template>
  <EmptyState
    v-else
    variant="compact"
    icon="lucide:layers"
    title="No rooms yet"
    :message="canAddInventory ? 'Add your first room — Floor 1 is created for you.' : inventoryClosedHint"
  >
    <template v-if="canAddInventory" #actions>
      <q-btn unelevated rounded no-caps color="primary" label="Add room" :loading="addingFloor" :disable="!canAddInventory" @click="addFirstRoom" />
    </template>
  </EmptyState>
  </div>
</template>

<script setup lang="ts">
// The Rooms tab: every floor with its rooms and shared facilities. On
// desktop the page teleports this into the card's right half.
import { Icon as IconifyIcon } from '@iconify/vue'
import PhotoEmpty from '@/components/shared/PhotoEmpty.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import { formatPeso } from '@/utils/format'
import { FACILITY_META, roomTypeLabel } from '@/utils/listings'
import { MAX_FLOORS, ROOM_STATUS_TONE } from './model'
import { useAccommodationDetail } from './detail'

const {
  addFirstRoom,
  addFloor,
  addingFloor,
  canAddInventory,
  deletingFloor,
  floorCount,
  inventoryClosedHint,
  openAddChoice,
  openFacilityDetails,
  openFloorName,
  openRoomDialog,
  promptDeleteFloor,
  roomsByFloor,
  sharedFacilitySub,
  uploadingFacilityId,
} = useAccommodationDetail()
</script>

<style scoped src="./detail.css"></style>

<style scoped>
.room-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.room-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.room-chip--amber {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.room-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.floor-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.floor-rename {
  display: inline-flex;
  margin-left: 4px;
  padding: 2px;
  border: 0;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
  vertical-align: middle;
}
.floor-title {
  margin: 4px 0 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.floor-group:first-child .floor-title {
  margin-top: 0;
}
.add-floor-link {
  align-self: flex-start;
  margin-top: 2px;
  padding: 4px 2px;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.add-floor-link:disabled {
  opacity: 0.6;
}
.floor-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}
.floor-del {
  display: grid;
  width: 22px;
  height: 22px;
  place-items: center;
  border: 0;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.floor-del:disabled {
  opacity: 0.5;
}
.col-right .sec-body {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
</style>
