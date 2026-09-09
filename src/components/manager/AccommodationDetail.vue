<template>
  <q-page class="ad">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="220px" square />
      <div class="tabs">
        <q-skeleton type="rect" width="88px" height="38px" class="sk-tab" />
        <q-skeleton type="rect" width="72px" height="38px" class="sk-tab" />
        <q-skeleton type="rect" width="80px" height="38px" class="sk-tab" />
      </div>
      <q-skeleton type="rect" height="90px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load this accommodation</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <div v-else class="stack">
      <div class="tabbed">
        <div class="hero">
          <div class="hero-media" :class="{ 'hero-media--empty': !coverUrl }">
            <img v-if="coverUrl" :src="coverUrl" alt="" class="hero-img" />
            <span v-else class="shot-empty hero-empty">
              <IconifyIcon icon="lucide:image-off" width="28" />
              <span class="shot-empty-label">No photo</span>
            </span>
            <div class="hero-scrim" />
          </div>
          <button type="button" class="hero-edit" aria-label="Manage property photos" @click="coverSheetOpen = true">
            <IconifyIcon icon="lucide:camera" width="16" />
          </button>
          <div class="head">
            <span class="head-name">{{ acc.name || 'Unnamed accommodation' }}</span>
            <span class="head-chip" :class="`head-chip--${STATUS_TONE[acc.status] || 'grey'}`">{{ STATUS_LABEL[acc.status] || acc.status }}</span>
          </div>
        </div>

        <div class="tabs">
          <button
            v-for="t in TABS"
            :key="t.key"
            type="button"
            class="tab"
            :class="{ 'tab--on': tab === t.key }"
            @click="tab = t.key"
          >
            {{ t.label }}
          </button>
        </div>

        <div class="panel">
        <q-tab-panels v-model="tab" animated swipeable class="panels">
        <!-- OVERVIEW -->
        <q-tab-panel name="overview" class="sec">
          <div class="group">
            <div class="quick-stats">
              <div class="stat-block">
                <span class="stat-badge"><IconifyIcon icon="lucide:door-open" width="16" /></span>
                <div>
                  <span class="stat-number">{{ rooms.length }}</span>
                  <span class="stat-label">Rooms</span>
                </div>
              </div>
              <div class="stat-divider" />
              <div class="stat-block">
                <span class="stat-badge"><IconifyIcon icon="lucide:user-check" width="16" /></span>
                <div>
                  <span class="stat-number">{{ occupiedRoomCount }}</span>
                  <span class="stat-label">Occupied</span>
                </div>
              </div>
              <div class="stat-divider" />
              <div class="stat-block">
                <span class="stat-badge"><IconifyIcon icon="lucide:door-closed" width="16" /></span>
                <div>
                  <span class="stat-number">{{ vacantRoomCount }}</span>
                  <span class="stat-label">Vacant</span>
                </div>
              </div>
            </div>
          </div>

          <div class="sec-head">
            <h2 class="sec-title">Details</h2>
          </div>
          <div class="view-group">
            <button type="button" class="view-row view-row--tap" @click="openFieldDialog('name')">
              <span class="view-label">Name</span>
              <span class="view-value">{{ acc.name || '—' }}</span>
              <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
            </button>
            <button type="button" class="view-row view-row--tap" @click="openFieldDialog('accommodationType')">
              <span class="view-label">Type</span>
              <span class="view-value">{{ BUILDING_TYPE_LABEL[acc.accommodationType] || '—' }}</span>
              <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
            </button>
            <button type="button" class="view-row view-row--tap" @click="openFieldDialog('barangay')">
              <span class="view-label">Barangay</span>
              <span class="view-value">{{ acc.barangay || '—' }}</span>
              <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
            </button>
            <button type="button" class="view-row view-row--tap" @click="openFieldDialog('city')">
              <span class="view-label">City</span>
              <span class="view-value">{{ acc.city || '—' }}</span>
              <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
            </button>
            <button type="button" class="view-row view-row--tap" @click="openFieldDialog('totalFloors')">
              <span class="view-label">Floors</span>
              <span class="view-value">{{ acc.totalFloors ?? '—' }}</span>
              <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
            </button>
            <button type="button" class="view-row view-row--tap view-row--block" @click="openFieldDialog('description')">
              <span class="view-row-head">
                <span class="view-label">Description</span>
                <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
              </span>
              <p class="view-text">{{ acc.description || 'No description yet.' }}</p>
            </button>
            <button type="button" class="view-row view-row--tap" @click="amenitiesDialogOpen = true">
              <span class="view-label">Amenities</span>
              <span class="view-value">{{ rules.amenities.length ? `${rules.amenities.length} selected` : 'None yet' }}</span>
              <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
            </button>
          </div>

          <div class="sec-head">
            <h2 class="sec-title">Location</h2>
            <button type="button" class="sec-link" @click="locationPickerOpen = true">
              {{ mapUrl ? 'Change location' : 'Set location' }}
            </button>
          </div>
          <div v-if="mapUrl" class="map">
            <img :src="mapUrl" :alt="`Map showing ${acc.name || 'this accommodation'} and ${CAMPUS.label}`" loading="lazy" />
            <p class="map-note">
              <IconifyIcon icon="lucide:school" width="12" />
              {{ distance || 'Distance unknown' }} · {{ CAMPUS.label }}
            </p>
          </div>
          <p v-else class="none">Location not set yet.</p>
        </q-tab-panel>

        <!-- ROOMS & FACILITIES, both floor-accurate -->
        <q-tab-panel name="rooms" class="sec">
          <p v-if="!canAddInventory" class="sec-hint">This accommodation is delisted — reactivate it to add rooms, facilities, or floors.</p>
          <template v-if="roomsByFloor.length">
            <div v-for="grp in roomsByFloor" :key="grp.floor ?? 'none'" class="floor-group">
              <div class="sec-head">
                <h3 class="floor-title">{{ grp.label }} ({{ grp.rooms.length + grp.facilities.length }})</h3>
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
                  <span class="room-shot" :class="{ 'room-shot--empty': !r.photoUrl }">
                    <img v-if="r.photoUrl" :src="r.photoUrl" alt="" />
                    <IconifyIcon v-else icon="lucide:image-off" width="18" />
                  </span>
                  <span class="room-body">
                    <span class="room-name">{{ r.roomNumber ? `Room ${r.roomNumber}` : 'Room' }}</span>
                    <span class="room-sub">
                      {{ roomTypeLabel(r.customRoomType || r.roomType) }} · {{ formatPeso(r.monthlyRent) }}/mo{{ r.rentBasis === 'person' && (r.capacity ?? 0) > 1 ? ' · per person' : '' }}
                    </span>
                  </span>
                  <span class="room-chip" :class="`room-chip--${ROOM_STATUS_TONE[r.status] || 'grey'}`">
                    {{ r.currentPax }}/{{ r.capacity ?? '—' }}
                  </span>
                </button>
              </div>
              <p v-else class="none">No rooms on this floor yet.</p>

              <div v-if="grp.facilities.length" class="group">
                <button v-for="f in grp.facilities" :key="f.id" type="button" class="room-row" @click="openFacilityDetails(f)">
                  <span class="room-shot" :class="{ 'room-shot--empty': !f.images.length }">
                    <img v-if="f.images[0]" :src="f.images[0].url" alt="" />
                    <IconifyIcon v-else :icon="FACILITY_META[f.facilityType]?.icon || 'lucide:box'" width="18" />
                  </span>
                  <span class="room-body">
                    <span class="room-name">{{ f.label || FACILITY_META[f.facilityType]?.label || f.facilityType }}</span>
                    <span v-if="uploadingFacilityId === f.id" class="room-sub">Uploading…</span>
                    <span v-else-if="f.description" class="room-sub">{{ f.description }}</span>
                    <span v-else class="room-sub">{{ f.images.length ? `${f.images.length} photo${f.images.length === 1 ? '' : 's'}` : 'Shared facility' }}</span>
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
            title="No floors yet"
            message="Add a floor to start adding rooms and facilities."
          >
            <template #actions>
              <q-btn unelevated rounded no-caps color="primary" label="Add floor" :loading="addingFloor" :disable="!canAddInventory" @click="addFloor" />
            </template>
          </EmptyState>
        </q-tab-panel>

        <!-- SETTINGS -->
        <q-tab-panel name="settings" class="sec">
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
          <p class="sec-hint">Accreditation depends on these staying current. Manage uploads from OSAS.</p>
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
            </div>
          </div>

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
          <template v-else-if="acc.status === 'rejected'">
            <h2 class="sec-title">Listing status</h2>
            <div class="status-box">
              <p class="status-text">OSAS rejected this accommodation. It's hidden from students and can't be resubmitted here — delete it and start a new listing if needed.</p>
              <button type="button" class="status-btn status-btn--danger" @click="confirmDeleteAccommodationOpen = true">
                Delete this accommodation
              </button>
            </div>
          </template>
        </q-tab-panel>
        </q-tab-panels>
        </div>
      </div>
    </div>

    <!-- COVER PHOTOS -->
    <q-dialog v-model="coverSheetOpen" position="bottom">
      <q-card class="room-sheet room-sheet--paged room-sheet--wizard">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon icon="lucide:camera" width="18" /></span>
          <h3 class="room-sheet-title">Property photos</h3>
        </div>
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
      </q-card>
    </q-dialog>

    <!-- PERMIT FILE PREVIEW (view-only — uploads happen on OSAS) -->
    <q-dialog v-model="docPreviewOpen" position="bottom">
      <q-card class="room-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon icon="lucide:file-text" width="18" /></span>
          <h3 class="room-sheet-title">Permit file</h3>
        </div>
        <div class="room-sheet-scroll">
          <img v-if="docPreviewUrl && !isPdf(docPreviewUrl)" :src="resolveAsset(docPreviewUrl)" alt="" class="doc-preview-img" />
          <a v-else-if="docPreviewUrl" :href="resolveAsset(docPreviewUrl)" target="_blank" rel="noopener" class="doc-preview-file">
            <IconifyIcon icon="lucide:external-link" width="18" />
            <span>Open file</span>
          </a>
        </div>
      </q-card>
    </q-dialog>

    <!-- EDIT ONE FIELD (Overview + Settings both use this) -->
    <q-dialog v-model="fieldDialogOpen" position="bottom">
      <q-card class="room-sheet room-sheet--paged room-sheet--wizard">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon icon="lucide:pencil" width="18" /></span>
          <h3 class="room-sheet-title">{{ editingField ? FIELD_META[editingField].label : '' }}</h3>
        </div>

        <div class="room-sheet-scroll">
          <select v-if="editingField && FIELD_META[editingField].type === 'select'" v-model="fieldDraft" class="field-input">
            <option value="">Select type</option>
            <option v-for="(label, key) in BUILDING_TYPE_LABEL" :key="key" :value="key">{{ label }}</option>
          </select>
          <input
            v-else-if="editingField && FIELD_META[editingField].type === 'number'"
            v-model.number="fieldDraftNum"
            type="number"
            min="0"
            class="field-input"
          />
          <textarea
            v-else-if="editingField && FIELD_META[editingField].type === 'textarea'"
            v-model="fieldDraft"
            class="field-input field-textarea"
            rows="4"
          />
          <input
            v-else-if="editingField && FIELD_META[editingField].type === 'time'"
            v-model="fieldDraft"
            type="time"
            class="field-input"
          />
          <!-- Quiet hours is a range, so it takes two pickers and is stored
               back as one "10:00 PM – 6:00 AM" string. -->
          <div v-else-if="editingField && FIELD_META[editingField].type === 'timerange'" class="field-row">
            <label class="field">
              <span class="field-label">From</span>
              <input v-model="fieldDraft" type="time" class="field-input" />
            </label>
            <label class="field">
              <span class="field-label">Until</span>
              <input v-model="fieldDraftTo" type="time" class="field-input" />
            </label>
          </div>
          <input v-else v-model="fieldDraft" type="text" class="field-input" />
        </div>

        <div class="room-sheet-actions">
          <q-btn unelevated rounded no-caps color="primary" class="save-btn" :loading="savingField" label="Save" @click="saveField" />
        </div>
      </q-card>
    </q-dialog>

    <!-- AMENITIES -->
    <q-dialog v-model="amenitiesDialogOpen" position="bottom">
      <q-card class="room-sheet room-sheet--paged room-sheet--wizard">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon icon="lucide:sparkles" width="18" /></span>
          <h3 class="room-sheet-title">Amenities</h3>
        </div>
        <div class="room-sheet-scroll">
          <div class="chips">
            <button
              v-for="key in AMENITY_KEYS"
              :key="key"
              type="button"
              class="chip"
              :class="{ 'chip--on': rules.amenities.includes(key) }"
              @click="toggle(rules.amenities, key)"
            >
              <IconifyIcon :icon="AMENITY_META[key]?.icon || 'lucide:dot'" width="14" />
              {{ AMENITY_META[key]?.label || key }}
            </button>
          </div>
        </div>
        <div class="room-sheet-actions">
          <q-btn unelevated rounded no-caps color="primary" class="save-btn" :loading="savingAmenities" label="Save" @click="saveAmenities" />
        </div>
      </q-card>
    </q-dialog>

    <!-- ADD/EDIT ROOM -->
    <q-dialog v-model="roomOpen" position="bottom">
      <q-card class="room-sheet room-sheet--paged room-sheet--wizard">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon icon="lucide:bed-double" width="18" /></span>
          <h3 class="room-sheet-title">{{ roomDialogMode === 'edit' ? 'Edit room' : 'Add room' }}</h3>
        </div>

        <div class="room-sheet-scroll">
          <div v-if="roomDialogMode === 'create'" class="steps steps--sheet">
            <span v-for="n in 4" :key="n" class="step-dot" :class="{ 'step-dot--on': n <= roomStep }" />
          </div>

          <!-- STEP 1 / edit mode: basics -->
          <template v-if="roomDialogMode === 'edit' || roomStep === 1">
            <div v-if="editingRoomId" class="room-name-static">
              <span class="room-name-static-label">Room {{ activeRoomNumber || '—' }}</span>
              <span class="room-name-static-floor">Floor {{ roomForm.floor }}</span>
            </div>
            <div v-else class="room-name-static">
              <span class="room-name-static-label">Floor {{ roomForm.floor }}</span>
              <span class="room-name-static-floor">Will be named Room {{ previewRoomNumber }}</span>
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
            </div>

            <template v-else>
              <div class="field-row">
                <label class="field">
                  <span class="field-label">Room type</span>
                  <select v-model="roomForm.roomType" class="field-input" @change="onRoomTypeChange">
                    <option v-for="(label, key) in ROOM_TYPE_LABEL" :key="key" :value="key">{{ label }}</option>
                    <option value="custom">Custom</option>
                  </select>
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
                  class="field-input"
                  :disabled="roomForm.roomType in ROOM_TYPE_DEFAULT_CAPACITY"
                />
              </label>
              <p v-if="roomForm.roomType in ROOM_TYPE_DEFAULT_CAPACITY" class="sec-hint">
                Capacity is fixed at {{ roomForm.capacity }} for {{ ROOM_TYPE_LABEL[roomForm.roomType] }} rooms.
              </p>

              <div class="field-row">
                <div v-if="roomForm.capacity > 1" class="field">
                  <span class="field-label">Rent is for</span>
                  <div class="chips">
                    <button
                      type="button"
                      class="chip"
                      :class="{ 'chip--on': roomForm.rentBasis === 'room' }"
                      @click="roomForm.rentBasis = 'room'"
                    >
                      Whole room
                    </button>
                    <button
                      type="button"
                      class="chip"
                      :class="{ 'chip--on': roomForm.rentBasis === 'person' }"
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
                    <input v-model.number="roomForm.monthlyRent" type="number" min="0" step="0.01" class="field-input field-input--prefixed" />
                  </div>
                </label>
              </div>
              <p v-if="rentBasisHint" class="sec-hint">{{ rentBasisHint }}</p>

              <div class="field-row">
                <label class="field">
                  <span class="field-label">Advance (months)</span>
                  <input v-model.number="roomForm.advanceMonths" type="number" min="0" class="field-input" />
                </label>
                <label class="field">
                  <span class="field-label">Deposit (months)</span>
                  <input v-model.number="roomForm.depositMonths" type="number" min="0" class="field-input" />
                </label>
              </div>
            </template>
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
                  <span class="room-shot" :class="{ 'room-shot--empty': !f.images.length }">
                    <img v-if="f.images[0]" :src="f.images[0].url" alt="" />
                    <IconifyIcon v-else :icon="FACILITY_META[f.facilityType]?.icon || 'lucide:box'" width="18" />
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
                  <span class="rule-value">Room {{ activeRoomNumber || '—' }} · Floor {{ roomForm.floor }}</span>
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

        <div v-if="roomDialogMode === 'edit' && roomViewMode === 'view'" class="wizard-nav">
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
            label="Next"
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
            @click="roomOpen = false"
          />
        </div>
      </q-card>
    </q-dialog>

    <!-- CONFIRM DELETE ACCOMMODATION -->
    <q-dialog v-model="confirmDeleteAccommodationOpen" position="bottom">
      <q-card class="room-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon icon="lucide:triangle-alert" width="18" /></span>
          <h3 class="room-sheet-title">Delete this accommodation?</h3>
        </div>
        <p class="sec-hint">
          This permanently deletes it, along with its rooms, facilities, photos, and documents. This can't be undone.
        </p>
        <div class="room-sheet-actions">
          <button type="button" class="ghost-btn" :disabled="deletingAccommodation" @click="confirmDeleteAccommodationOpen = false">
            Cancel
          </button>
          <button type="button" class="room-del" :disabled="deletingAccommodation" @click="deleteAccommodation">
            {{ deletingAccommodation ? 'Deleting…' : 'Delete accommodation' }}
          </button>
        </div>
      </q-card>
    </q-dialog>

    <!-- CONFIRM DELETE FLOOR -->
    <q-dialog v-model="confirmDeleteFloorOpen" position="bottom">
      <q-card class="room-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon icon="lucide:triangle-alert" width="18" /></span>
          <h3 class="room-sheet-title">Delete Floor {{ floorPendingDelete }}?</h3>
        </div>
        <p class="sec-hint">
          This permanently deletes every room on this floor, along with their photos and private facilities. This
          can't be undone.
        </p>
        <div class="room-sheet-actions">
          <button type="button" class="ghost-btn" :disabled="deletingFloor !== null" @click="confirmDeleteFloorOpen = false">
            Cancel
          </button>
          <button type="button" class="room-del" :disabled="deletingFloor !== null" @click="confirmDeleteFloor">
            {{ deletingFloor !== null ? 'Deleting…' : 'Delete floor' }}
          </button>
        </div>
      </q-card>
    </q-dialog>

    <!-- CONFIRM DELETE ROOM -->
    <q-dialog v-model="confirmDeleteRoomOpen" position="bottom">
      <q-card class="room-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon icon="lucide:triangle-alert" width="18" /></span>
          <h3 class="room-sheet-title">Delete Room {{ activeRoomNumber }}?</h3>
        </div>
        <p class="sec-hint">This permanently deletes this room, along with its photos and private facilities. This can't be undone.</p>
        <div class="room-sheet-actions">
          <button type="button" class="ghost-btn" :disabled="savingRoom" @click="confirmDeleteRoomOpen = false">Cancel</button>
          <button type="button" class="room-del" :disabled="savingRoom" @click="deleteRoom">
            {{ savingRoom ? 'Deleting…' : 'Delete room' }}
          </button>
        </div>
      </q-card>
    </q-dialog>

    <!-- ADD ROOM OR FACILITY -->
    <q-dialog v-model="addChoiceOpen" position="bottom">
      <q-card class="room-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon icon="lucide:plus" width="18" /></span>
          <h3 class="room-sheet-title">Add to Floor {{ addChoiceFloor }}</h3>
        </div>
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
      </q-card>
    </q-dialog>

    <!-- ADD / VIEW / EDIT FACILITY -->
    <q-dialog v-model="facilityOpen" position="bottom">
      <q-card class="room-sheet room-sheet--paged room-sheet--wizard">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon :icon="FACILITY_META[facilityForm.facilityType]?.icon || 'lucide:box'" width="18" /></span>
          <h3 class="room-sheet-title">{{ facilityDialogMode === 'edit' ? (facilityForm.label || FACILITY_META[facilityForm.facilityType]?.label || 'Facility') : 'Add facility' }}</h3>
        </div>

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
            </div>
            <template v-else>
              <label class="field">
                <span class="field-label">Type</span>
                <select v-model="facilityForm.facilityType" class="field-input">
                  <option v-for="(meta, key) in FACILITY_META" :key="key" :value="key">{{ meta.label }}</option>
                </select>
              </label>
              <label class="field">
                <span class="field-label">Label (optional)</span>
                <input v-model="facilityForm.label" type="text" class="field-input" placeholder="e.g. Rooftop lounge" />
              </label>
              <label class="field">
                <span class="field-label">Description (optional)</span>
                <input v-model="facilityForm.description" type="text" class="field-input" />
              </label>
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
                  <button
                    v-if="facilityDialogMode === 'create' || facilityViewMode === 'edit'"
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
      </q-card>
    </q-dialog>

    <LocationPicker
      v-if="locationPickerOpen"
      v-model="locationPickerOpen"
      :initial-lat="acc.lat"
      :initial-lng="acc.lng"
      @confirm="onLocationConfirmed"
    />
  </q-page>
</template>

<script setup lang="ts">
import { reactive, ref, computed, onMounted, defineAsyncComponent } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatPeso, to12Hour, to24Hour, splitTimeRange } from '@/utils/format'
import { since } from '@/utils/notifications'
import { useNotify } from '@/utils/notify'
import { uploadDocument, secureDocUrl } from '@/utils/upload'
import { resolveAsset, isPdf } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel, staticMapUrl, CAMPUS } from '@/utils/geo'
import { AMENITY_META, AMENITY_KEYS, FACILITY_META, ROOM_TYPE_LABEL, ROOM_TYPE_DEFAULT_CAPACITY, BUILDING_TYPE_LABEL, roomTypeLabel } from '@/utils/listings'
import EmptyState from '@/components/shared/EmptyState.vue'
import type { Database } from '@/types/database.gen'
import { capturePhoto } from '@/utils/camera'

// Loaded on demand — mapbox-gl (pulled in only by this component) is by far
// the heaviest dependency in the app, and the picker is opened rarely.
const LocationPicker = defineAsyncComponent(() => import('@/components/manager/LocationPicker.vue'))

type AmenityKey = Database['public']['Enums']['amenity']

const STATUS_LABEL: Record<string, string> = {
  pending: 'Pending review',
  reviewing: 'Reviewing',
  accredited: 'Accredited',
  rejected: 'Rejected',
  delisted: 'Delisted',
}
const STATUS_TONE: Record<string, string> = {
  pending: 'amber',
  reviewing: 'amber',
  accredited: 'green',
  rejected: 'red',
  delisted: 'grey',
}
const ROOM_STATUS_TONE: Record<string, string> = {
  available: 'green',
  occupied: 'amber',
  maintenance: 'grey',
}

const DOC_TYPES = ['sanitary_permit', 'fire_safety', 'business_permit', 'building_permit'] as const
const DOC_TYPE_LABEL: Record<string, string> = {
  sanitary_permit: 'Sanitary permit',
  fire_safety: 'Fire safety certificate',
  business_permit: 'Business permit',
  building_permit: 'Building permit',
}

const TABS = [
  { key: 'overview', label: 'Overview' },
  { key: 'rooms', label: 'Rooms' },
  { key: 'settings', label: 'Settings' },
] as const

const RULE_TOGGLES = [
  { key: 'cooking' as const, label: 'Cooking allowed' },
  { key: 'laundry' as const, label: 'Laundry allowed' },
  { key: 'pets' as const, label: 'Pets allowed' },
]

interface Room {
  id: string
  label: string | null
  roomNumber: string | null
  roomType: string | null
  customRoomType: string | null
  floor: number | null
  capacity: number | null
  currentPax: number
  monthlyRent: number
  advanceMonths: number | null
  depositMonths: number | null
  rentBasis: 'room' | 'person'
  status: string
  images: Img[]
  photoUrl: string
}
interface Img {
  id: string
  url: string
}
interface Facility {
  id: string
  facilityType: string
  label: string
  description: string
  roomId: string | null
  floor: number | null
  images: Img[]
}

const route = useRoute()
const router = useRouter()
const notify = useNotify()

const id = String(route.params.id || '')

const loading = ref(true)
const error = ref('')
const tab = ref<(typeof TABS)[number]['key']>('overview')
const savingAmenities = ref(false)
const delisting = ref(false)
const amenitiesDialogOpen = ref(false)
const fieldDialogOpen = ref(false)
const savingField = ref(false)
const editingField = ref<FieldKey | null>(null)
const fieldDraft = ref('')
// Second half of a time range (quiet hours "until"); unused by other types.
const fieldDraftTo = ref('')
const fieldDraftNum = ref<number | null>(null)

const acc = reactive({
  name: '',
  accommodationType: '',
  address: '',
  barangay: '',
  city: '',
  totalFloors: null as number | null,
  description: '',
  status: 'pending',
  lat: null as number | null,
  lng: null as number | null,
})
const rules = reactive({
  amenities: [] as string[],
  curfewTime: '',
  quietHours: '',
  visitorPolicy: '',
  minStay: null as number | null,
  cooking: true,
  laundry: true,
  pets: false,
})
const rooms = ref<Room[]>([])
const images = ref<Img[]>([])
const uploadingCover = ref(false)
const deletingImage = ref('')
const coverSheetOpen = ref(false)
const facilities = ref<Facility[]>([])
const docRows = ref<{ doc_type: string; file_url: string; expires_at: string | null; uploaded_at: string; version: number }[]>([])
const coverUrl = computed(() => (images.value[0]?.url ? resolveAsset(images.value[0].url) : ''))
// Occupancy must come from actual leases, not rooms.status/current_pax —
// this project's own data notes flag those columns as unreliable.
const occupiedRoomIds = ref<string[]>([])
const occupiedRoomCount = computed(() => occupiedRoomIds.value.length)
const vacantRoomCount = computed(() => Math.max(rooms.value.length - occupiedRoomCount.value, 0))
// Delisted accommodations are hidden from students — don't let managers keep
// building out inventory (rooms, facilities, floors) behind a dead listing.
const canAddInventory = computed(() => acc.status !== 'delisted')
const distance = computed(() => campusDistanceLabel(acc.lat, acc.lng))
const mapUrl = computed(() => staticMapUrl(acc.lat, acc.lng))
const locationPickerOpen = ref(false)

// The picker no longer guesses a street address — barangay and city are what
// it fills. Address stays editable on its own row here.
async function onLocationConfirmed(payload: { lat: number; lng: number; barangay: string; city: string }) {
  const fields: Database['public']['Tables']['accommodations']['Update'] = { lat: payload.lat, lng: payload.lng }
  if (!acc.barangay && payload.barangay) fields.barangay = payload.barangay
  if (!acc.city && payload.city) fields.city = payload.city
  try {
    const { error: updateError } = await supabase.from('accommodations').update(fields).eq('id', id)
    if (updateError) throw updateError
    acc.lat = payload.lat
    acc.lng = payload.lng
    if (fields.barangay) acc.barangay = fields.barangay as string
    if (fields.city) acc.city = fields.city as string
    notify.success('Location saved.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not save this location.'))
  }
}

const sharedFacilities = computed(() => facilities.value.filter((f) => !f.roomId))
const currentRoomFacilities = computed(() => facilities.value.filter((f) => f.roomId === editingRoomId.value))

// Adding a facility follows the same shape as adding a room: a paged sheet
// (Basics → Photos) that creates the row after step 1, then a Photos step
// that operates on the now-real facility — kept as its own dialog since a
// facility isn't a room, but built to look and behave the same way.
const facilityOpen = ref(false)
const facilityDialogMode = ref<'create' | 'edit'>('create')
const facilityViewMode = ref<'view' | 'edit'>('view')
const facilityStep = ref(1)
const savingFacility = ref(false)
const facilityScope = ref<'shared' | 'private'>('shared')
const facilityRoomId = ref('')
const facilityFloor = ref<number | null>(null)
const activeFacilityId = ref('')
const facilityForm = reactive({
  facilityType: 'bathroom',
  label: '',
  description: '',
})
const activeFacilityImages = computed(() => facilities.value.find((f) => f.id === activeFacilityId.value)?.images ?? [])

const addChoiceOpen = ref(false)
const addChoiceFloor = ref<number | null>(null)

function openAddChoice(floor: number) {
  addChoiceFloor.value = floor
  addChoiceOpen.value = true
}
function chooseAddRoom() {
  addChoiceOpen.value = false
  if (addChoiceFloor.value !== null) openRoomDialog(null, addChoiceFloor.value)
}
function chooseAddFacility() {
  addChoiceOpen.value = false
  if (addChoiceFloor.value !== null) openFacilityAddDialog('shared', '', addChoiceFloor.value)
}

function openFacilityAddDialog(scope: 'shared' | 'private', roomId: string, floor: number | null = null) {
  facilityDialogMode.value = 'create'
  facilityStep.value = 1
  facilityScope.value = scope
  facilityRoomId.value = roomId
  facilityFloor.value = floor
  activeFacilityId.value = ''
  facilityForm.facilityType = 'bathroom'
  facilityForm.label = ''
  facilityForm.description = ''
  facilityOpen.value = true
}

function openFacilityDetails(f: Facility) {
  facilityDialogMode.value = 'edit'
  facilityViewMode.value = 'view'
  facilityScope.value = f.roomId ? 'private' : 'shared'
  facilityRoomId.value = f.roomId || ''
  facilityFloor.value = f.floor
  activeFacilityId.value = f.id
  facilityForm.facilityType = f.facilityType
  facilityForm.label = f.label
  facilityForm.description = f.description
  facilityOpen.value = true
}

async function saveFacilityEdits() {
  if (savingFacility.value || !activeFacilityId.value) return
  savingFacility.value = true
  try {
    const payload = {
      facility_type: facilityForm.facilityType,
      label: facilityForm.label.trim() || null,
      description: facilityForm.description.trim() || null,
    }
    const { error: updateError } = await supabase
      .from('accommodation_facilities')
      .update(payload)
      .eq('id', activeFacilityId.value)
    if (updateError) throw updateError
    const row = facilities.value.find((f) => f.id === activeFacilityId.value)
    if (row) Object.assign(row, { facilityType: payload.facility_type, label: payload.label || '', description: payload.description || '' })
    facilityOpen.value = false
    notify.success('Facility saved.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not save this facility.'))
  } finally {
    savingFacility.value = false
  }
}

async function deleteFacilityDirect() {
  if (savingFacility.value || !activeFacilityId.value) return
  savingFacility.value = true
  try {
    const { error: deleteError } = await supabase.from('accommodation_facilities').delete().eq('id', activeFacilityId.value)
    if (deleteError) throw deleteError
    facilities.value = facilities.value.filter((f) => f.id !== activeFacilityId.value)
    facilityOpen.value = false
    notify.success('Facility removed.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not remove this facility.'))
  } finally {
    savingFacility.value = false
  }
}

async function confirmFacilityBasics() {
  if (savingFacility.value) return
  savingFacility.value = true
  try {
    const payload = {
      facility_type: facilityForm.facilityType,
      access_scope: facilityScope.value,
      label: facilityForm.label.trim() || null,
      description: facilityForm.description.trim() || null,
      room_id: facilityScope.value === 'private' ? facilityRoomId.value : null,
      floor: facilityScope.value === 'shared' ? facilityFloor.value : null,
    }
    const { data: created, error: insertError } = await supabase
      .from('accommodation_facilities')
      .insert({ ...payload, accommodation_id: id, sort_order: facilities.value.length })
      .select('id')
      .single()
    if (insertError) throw insertError
    facilities.value.push({
      id: created.id,
      facilityType: payload.facility_type,
      label: payload.label || '',
      description: payload.description || '',
      roomId: payload.room_id,
      floor: payload.floor,
      images: [],
    })
    activeFacilityId.value = created.id
    facilityStep.value = 2
  } catch (e) {
    notify.error(errorMessage(e, 'Could not save this facility.'))
  } finally {
    savingFacility.value = false
  }
}

const deletingFacilityImageId = ref('')

async function deleteFacilityPhotoInDialog(imageId: string) {
  if (deletingFacilityImageId.value) return
  deletingFacilityImageId.value = imageId
  try {
    const { error: deleteError } = await supabase.from('accommodation_facility_images').delete().eq('id', imageId)
    if (deleteError) throw deleteError
    const row = facilities.value.find((f) => f.id === activeFacilityId.value)
    if (row) row.images = row.images.filter((i) => i.id !== imageId)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not remove this photo.'))
  } finally {
    deletingFacilityImageId.value = ''
  }
}

const uploadingFacilityId = ref('')

async function addFacilityPhotos(files: File[], facilityId: string) {
  if (!files.length) return
  uploadingFacilityId.value = facilityId
  try {
    const row = facilities.value.find((f) => f.id === facilityId)
    for (const file of files) {
      const url = await uploadDocument(file, '', 'facility_photo')
      const { data: created, error: insertError } = await supabase
        .from('accommodation_facility_images')
        .insert({ facility_id: facilityId, url, sort_order: row?.images.length ?? 0 })
        .select('id,url')
        .single()
      if (insertError) throw insertError
      row?.images.push({ id: created.id, url: created.url })
    }
  } catch (e) {
    notify.error(errorMessage(e, "Could not upload this facility's photo."))
  } finally {
    uploadingFacilityId.value = ''
  }
}

async function uploadFacilityPhoto(event: Event, facilityId: string) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files ?? [])
  await addFacilityPhotos(files, facilityId)
  input.value = ''
}

async function takeFacilityPhoto(facilityId: string) {
  const { file, error } = await capturePhoto()
  if (error) notify.error(error)
  if (file) await addFacilityPhotos([file], facilityId)
}

const docs = computed(() =>
  DOC_TYPES.map((type) => {
    const row = docRows.value.find((d) => d.doc_type === type)
    if (!row) {
      return { type, statusLabel: 'Not submitted', tone: 'idle', icon: 'lucide:circle-dashed', when: '', fileUrl: '' }
    }
    if (!row.expires_at) {
      // Expiry is required on upload now, so a null one only happens on a
      // legacy row from before that — flag it rather than reading as settled.
      return { type, statusLabel: 'No expiration set', tone: 'warn', icon: 'lucide:calendar-x', when: `Uploaded ${since(row.uploaded_at)}`, fileUrl: row.file_url }
    }
    const now = Date.now()
    const soon = now + 30 * 24 * 60 * 60 * 1000
    const t = new Date(row.expires_at).getTime()
    if (t < now) return { type, statusLabel: 'Expired', tone: 'danger', icon: 'lucide:file-warning', when: `Expired ${since(row.expires_at)}`, fileUrl: row.file_url }
    if (t < soon) return { type, statusLabel: 'Expiring soon', tone: 'warn', icon: 'lucide:calendar-clock', when: `Expires ${since(row.expires_at)}`, fileUrl: row.file_url }
    return { type, statusLabel: 'Valid', tone: 'good', icon: 'lucide:check', when: `Expires ${since(row.expires_at)}`, fileUrl: row.file_url }
  }),
)

/** Cosmetic extension check — good enough to pick "image preview" vs "open file". */

const docPreviewOpen = ref(false)
const docPreviewUrl = ref('')
function viewDoc(url: string) {
  docPreviewUrl.value = url
  docPreviewOpen.value = true
}

function toggle(list: string[], value: string) {
  const i = list.indexOf(value)
  if (i === -1) list.push(value)
  else list.splice(i, 1)
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data, error: loadError } = await supabase
      .from('accommodations')
      .select(
        'name,accommodation_type,address,barangay,city,total_floors,description,status,lat,lng,accommodation_amenities(amenity),accommodation_policies(min_stay,curfew_time,quiet_hours,visitor_policy,cooking,laundry,pets),accommodation_images(id,url,sort_order),accommodation_facilities(id,facility_type,access_scope,label,description,room_id,floor,accommodation_facility_images(id,url,sort_order)),accommodation_floors(floor_number),rooms(id,label,room_number,room_type,custom_room_type,floor,capacity,current_pax,monthly_rent,advance_months,deposit_months,rent_basis,status,room_images(id,url,sort_order))',
      )
      .eq('id', id)
      .maybeSingle()
    if (loadError) throw loadError
    if (!data) {
      error.value = 'This accommodation could not be found.'
      return
    }

    acc.name = data.name || ''
    acc.accommodationType = data.accommodation_type || ''
    acc.address = data.address || ''
    acc.barangay = data.barangay || ''
    acc.city = data.city || ''
    acc.totalFloors = data.total_floors
    acc.description = data.description || ''
    acc.status = data.status
    acc.lat = data.lat
    acc.lng = data.lng

    rules.amenities = ((data.accommodation_amenities ?? []) as { amenity: string }[]).map((a) => a.amenity)

    const policyRows = data.accommodation_policies as unknown
    const policy = (Array.isArray(policyRows) ? policyRows[0] : policyRows) as
      | {
          min_stay: number | null
          curfew_time: string | null
          quiet_hours: string | null
          visitor_policy: string | null
          cooking: boolean | null
          laundry: boolean | null
          pets: boolean | null
        }
      | null
    if (policy) {
      rules.minStay = policy.min_stay
      rules.curfewTime = policy.curfew_time || ''
      rules.quietHours = policy.quiet_hours || ''
      rules.visitorPolicy = policy.visitor_policy || ''
      rules.cooking = policy.cooking ?? true
      rules.laundry = policy.laundry ?? true
      rules.pets = policy.pets ?? false
    }

    images.value = [...((data.accommodation_images ?? []) as { id: string; url: string; sort_order: number | null }[])]
      .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
      .map((i) => ({ id: i.id, url: i.url }))

    facilities.value = ((data.accommodation_facilities ?? []) as {
      id: string
      facility_type: string
      access_scope: string
      label: string | null
      description: string | null
      room_id: string | null
      floor: number | null
      accommodation_facility_images: { id: string; url: string; sort_order: number | null }[] | null
    }[]).map((f) => ({
      id: f.id,
      facilityType: f.facility_type,
      label: f.label || '',
      description: f.description || '',
      roomId: f.room_id,
      floor: f.floor,
      images: [...(f.accommodation_facility_images ?? [])]
        .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
        .map((i) => ({ id: i.id, url: i.url })),
    }))

    rooms.value = ((data.rooms ?? []) as {
      id: string
      label: string | null
      room_number: string | null
      room_type: string | null
      custom_room_type: string | null
      floor: number | null
      capacity: number | null
      current_pax: number | null
      monthly_rent: number | null
      advance_months: number | null
      deposit_months: number | null
      rent_basis: string | null
      status: string
      room_images: { id: string; url: string; sort_order: number | null }[] | null
    }[]).map((r) => {
      const imgs = [...(r.room_images ?? [])]
        .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
        .map((i) => ({ id: i.id, url: i.url }))
      return {
        id: r.id,
        label: r.label,
        roomNumber: r.room_number,
        roomType: r.room_type,
        customRoomType: r.custom_room_type,
        floor: r.floor,
        capacity: r.capacity,
        currentPax: r.current_pax ?? 0,
        monthlyRent: Number(r.monthly_rent ?? 0),
        advanceMonths: r.advance_months,
        depositMonths: r.deposit_months,
        rentBasis: r.rent_basis === 'person' ? 'person' : 'room',
        status: r.status,
        images: imgs,
        photoUrl: imgs[0]?.url ? resolveAsset(imgs[0].url) : '',
      }
    })

    trackedFloors.value = ((data.accommodation_floors ?? []) as { floor_number: number }[]).map(
      (f) => f.floor_number,
    )

    if (rooms.value.length) {
      const { data: activeLeases, error: leaseError } = await supabase
        .from('leases')
        .select('room_id')
        .in('room_id', rooms.value.map((r) => r.id))
        .in('status', ['active', 'leave_requested'])
      if (leaseError) throw leaseError
      occupiedRoomIds.value = [...new Set((activeLeases ?? []).map((l) => l.room_id))]
    } else {
      occupiedRoomIds.value = []
    }

    await loadDocs()
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

async function loadDocs() {
  const { data, error: docError } = await supabase
    .from('accommodation_documents')
    .select('id, doc_type, file_url, expires_at, uploaded_at, version')
    .eq('accommodation_id', id)
    .order('version', { ascending: false })
  if (docError) throw docError

  const seen = new Set<string>()
  const latest = (data ?? []).filter((d) => {
    if (seen.has(d.doc_type)) return false
    seen.add(d.doc_type)
    return true
  })
  // Permits use Cloudinary authenticated delivery: file_url holds a ref, so each
  // one is signed for this viewer.
  docRows.value = await Promise.all(
    latest.map(async (d) => ({ ...d, file_url: await secureDocUrl('accommodation_documents', d.id) })),
  )
}

async function saveAmenities() {
  savingAmenities.value = true
  try {
    await supabase.from('accommodation_amenities').delete().eq('accommodation_id', id)
    if (rules.amenities.length) {
      const { error: amenityError } = await supabase
        .from('accommodation_amenities')
        .insert(rules.amenities.map((amenity) => ({ accommodation_id: id, amenity: amenity as AmenityKey })))
      if (amenityError) throw amenityError
    }
    amenitiesDialogOpen.value = false
    notify.success('Saved.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not save your changes.'))
  } finally {
    savingAmenities.value = false
  }
}

async function saveToggle(key: 'cooking' | 'laundry' | 'pets') {
  try {
    const payload = { accommodation_id: id, [key]: rules[key] } as Database['public']['Tables']['accommodation_policies']['Insert']
    const { error: updateError } = await supabase
      .from('accommodation_policies')
      .upsert(payload, { onConflict: 'accommodation_id' })
    if (updateError) throw updateError
  } catch (e) {
    notify.error(errorMessage(e, 'Could not save this setting.'))
  }
}

type FieldKey =
  | 'name' | 'accommodationType' | 'barangay' | 'city' | 'totalFloors' | 'description'
  | 'curfewTime' | 'quietHours' | 'visitorPolicy'

const FIELD_META: Record<FieldKey, { label: string; type: 'text' | 'select' | 'number' | 'textarea' | 'time' | 'timerange'; table: 'accommodations' | 'accommodation_policies'; column: string }> = {
  name: { label: 'Name', type: 'text', table: 'accommodations', column: 'name' },
  accommodationType: { label: 'Type', type: 'select', table: 'accommodations', column: 'accommodation_type' },
  barangay: { label: 'Barangay', type: 'text', table: 'accommodations', column: 'barangay' },
  city: { label: 'City', type: 'text', table: 'accommodations', column: 'city' },
  totalFloors: { label: 'Floors', type: 'number', table: 'accommodations', column: 'total_floors' },
  description: { label: 'Description', type: 'textarea', table: 'accommodations', column: 'description' },
  curfewTime: { label: 'Curfew', type: 'time', table: 'accommodation_policies', column: 'curfew_time' },
  quietHours: { label: 'Quiet hours', type: 'timerange', table: 'accommodation_policies', column: 'quiet_hours' },
  visitorPolicy: { label: 'Visitor policy', type: 'text', table: 'accommodation_policies', column: 'visitor_policy' },
}

function openFieldDialog(key: FieldKey) {
  editingField.value = key
  const meta = FIELD_META[key]
  const raw = key in acc ? acc[key as keyof typeof acc] : rules[key as keyof typeof rules]
  fieldDraftTo.value = ''
  if (meta.type === 'number') {
    fieldDraftNum.value = raw as number | null
  } else if (meta.type === 'time') {
    // Seed the picker from whatever's stored, including older hand-typed
    // values like "10PM"; anything unparseable just starts blank.
    fieldDraft.value = to24Hour(String(raw ?? ''))
  } else if (meta.type === 'timerange') {
    const [from, to] = splitTimeRange(String(raw ?? ''))
    fieldDraft.value = from
    fieldDraftTo.value = to
  } else {
    fieldDraft.value = String(raw ?? '')
  }
  fieldDialogOpen.value = true
}

async function saveField() {
  const key = editingField.value
  if (!key) return
  const meta = FIELD_META[key]
  savingField.value = true
  try {
    let value: string | number | null
    if (meta.type === 'number') value = fieldDraftNum.value
    else if (meta.type === 'select') value = fieldDraft.value || null
    else if (meta.type === 'time') value = to12Hour(fieldDraft.value) || null
    else if (meta.type === 'timerange') {
      value =
        fieldDraft.value && fieldDraftTo.value
          ? `${to12Hour(fieldDraft.value)} – ${to12Hour(fieldDraftTo.value)}`
          : null
    } else value = fieldDraft.value.trim() || null

    if (meta.table === 'accommodations') {
      const payload = { [meta.column]: value } as Database['public']['Tables']['accommodations']['Update']
      const { error: updateError } = await supabase.from('accommodations').update(payload).eq('id', id)
      if (updateError) throw updateError
    } else {
      const payload = { accommodation_id: id, [meta.column]: value } as Database['public']['Tables']['accommodation_policies']['Insert']
      const { error: updateError } = await supabase
        .from('accommodation_policies')
        .upsert(payload, { onConflict: 'accommodation_id' })
      if (updateError) throw updateError
    }

    switch (key) {
      case 'name': acc.name = String(value ?? ''); break
      case 'accommodationType': acc.accommodationType = String(value ?? ''); break
      case 'barangay': acc.barangay = String(value ?? ''); break
      case 'city': acc.city = String(value ?? ''); break
      case 'description': acc.description = String(value ?? ''); break
      case 'totalFloors': acc.totalFloors = value as number | null; break
      case 'curfewTime': rules.curfewTime = String(value ?? ''); break
      case 'quietHours': rules.quietHours = String(value ?? ''); break
      case 'visitorPolicy': rules.visitorPolicy = String(value ?? ''); break
    }

    fieldDialogOpen.value = false
    notify.success('Saved.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not save your changes.'))
  } finally {
    savingField.value = false
  }
}

async function delistAccommodation() {
  if (delisting.value) return
  delisting.value = true
  try {
    const { error: updateError } = await supabase.from('accommodations').update({ status: 'delisted' }).eq('id', id)
    if (updateError) throw updateError
    acc.status = 'delisted'
    notify.success('Accommodation delisted.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not delist this accommodation.'))
  } finally {
    delisting.value = false
  }
}

async function reactivateAccommodation() {
  if (delisting.value) return
  delisting.value = true
  try {
    const { error: updateError } = await supabase.from('accommodations').update({ status: 'accredited' }).eq('id', id)
    if (updateError) throw updateError
    acc.status = 'accredited'
    notify.success('Accommodation reactivated.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not reactivate this accommodation.'))
  } finally {
    delisting.value = false
  }
}

const confirmDeleteAccommodationOpen = ref(false)
const deletingAccommodation = ref(false)

async function deleteAccommodation() {
  if (deletingAccommodation.value) return
  deletingAccommodation.value = true
  try {
    const roomIds = rooms.value.map((r) => r.id)
    if (roomIds.length) {
      const { count, error: countError } = await supabase
        .from('leases')
        .select('id', { count: 'exact', head: true })
        .in('room_id', roomIds)
      if (countError) throw countError
      if (count) {
        notify.error('This accommodation has rooms with lease history and can\'t be deleted.')
        return
      }
    }

    const { data: deleted, error: deleteError } = await supabase
      .from('accommodations')
      .delete()
      .eq('id', id)
      .select('id')
    if (deleteError) throw deleteError
    if (!deleted?.length) {
      notify.error('Could not remove this accommodation.')
      return
    }

    notify.success('Accommodation removed.')
    void router.replace('/manager/properties')
  } catch (e) {
    notify.error(
      isLeaseRestrictError(e)
        ? 'This accommodation has rooms with lease history and can\'t be deleted.'
        : errorMessage(e, 'Could not remove this accommodation.'),
    )
  } finally {
    deletingAccommodation.value = false
    confirmDeleteAccommodationOpen.value = false
  }
}

async function onCoverPhotosSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files ?? [])
  if (!files.length) return
  uploadingCover.value = true
  try {
    for (const file of files) {
      const url = await uploadDocument(file, '', 'accommodation_photo')
      const { data: created, error: insertError } = await supabase
        .from('accommodation_images')
        .insert({ accommodation_id: id, url, sort_order: images.value.length })
        .select('id,url')
        .single()
      if (insertError) throw insertError
      images.value.push({ id: created.id, url: created.url })
    }
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload one of your photos.'))
  } finally {
    uploadingCover.value = false
    input.value = ''
  }
}

async function deleteImage(imageId: string) {
  if (deletingImage.value) return
  deletingImage.value = imageId
  try {
    const { error: deleteError } = await supabase.from('accommodation_images').delete().eq('id', imageId)
    if (deleteError) throw deleteError
    images.value = images.value.filter((i) => i.id !== imageId)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not remove this photo.'))
  } finally {
    deletingImage.value = ''
  }
}

const roomOpen = ref(false)
const confirmDeleteRoomOpen = ref(false)
const roomDialogMode = ref<'create' | 'edit'>('create')
const roomViewMode = ref<'view' | 'edit'>('view')
const roomStep = ref(1)
const savingRoom = ref(false)
const editingRoomId = ref('')
const activeRoomNumber = ref('')
const activeRoomStatus = ref<'available' | 'occupied' | 'maintenance'>('available')
const togglingRoomStatus = ref(false)
const roomImages = ref<Img[]>([])
const uploadingRoomPhoto = ref(false)
const deletingRoomImage = ref('')
const roomForm = reactive({
  roomType: 'solo',
  customRoomType: '',
  floor: null as number | null,
  capacity: 1,
  monthlyRent: 0,
  advanceMonths: null as number | null,
  depositMonths: null as number | null,
  rentBasis: 'room' as 'room' | 'person',
})

const rentBasisHint = computed(() => {
  const rent = roomForm.monthlyRent || 0
  const cap = roomForm.capacity || 1
  if (cap <= 1) return ''
  return roomForm.rentBasis === 'person'
    ? `≈ ${formatPeso(rent * cap)}/mo total for the room`
    : `≈ ${formatPeso(rent / cap)}/mo per person`
})

// Floors a manager has explicitly added, tracked independently of rooms
// (accommodation_floors) so an empty floor with no rooms yet still survives
// a reload instead of only existing while this page happens to be open.
const trackedFloors = ref<number[]>([])

interface FloorGroup { floor: number | null; label: string; rooms: Room[]; facilities: Facility[] }
const roomsByFloor = computed<FloorGroup[]>(() => {
  const roomMap = new Map<number, Room[]>()
  const facilityMap = new Map<number, Facility[]>()
  for (const floor of trackedFloors.value) {
    if (!roomMap.has(floor)) roomMap.set(floor, [])
    if (!facilityMap.has(floor)) facilityMap.set(floor, [])
  }
  const noFloorRooms: Room[] = []
  for (const r of rooms.value) {
    if (r.floor === null) {
      noFloorRooms.push(r)
      continue
    }
    if (!roomMap.has(r.floor)) roomMap.set(r.floor, [])
    roomMap.get(r.floor)!.push(r)
  }
  const noFloorFacilities: Facility[] = []
  for (const f of sharedFacilities.value) {
    if (f.floor === null) {
      noFloorFacilities.push(f)
      continue
    }
    if (!facilityMap.has(f.floor)) facilityMap.set(f.floor, [])
    facilityMap.get(f.floor)!.push(f)
  }
  const floors = [...new Set([...roomMap.keys(), ...facilityMap.keys()])].sort((a, b) => a - b)
  const groups = floors.map(
    (floor): FloorGroup => ({
      floor,
      label: `Floor ${floor}`,
      rooms: roomMap.get(floor) ?? [],
      facilities: facilityMap.get(floor) ?? [],
    }),
  )
  if (noFloorRooms.length || noFloorFacilities.length) {
    groups.push({ floor: null, label: 'No floor set', rooms: noFloorRooms, facilities: noFloorFacilities })
  }
  return groups
})

const MAX_FLOORS = 6
const floorCount = computed(() => roomsByFloor.value.filter((g) => g.floor !== null).length)

// Room "names" are just their number — assigned once at creation from the
// floor + how many rooms already sit on it, never hand-typed or renamed.
function nextRoomNumber(floor: number | null): string {
  const f = floor ?? 0
  const onFloor = rooms.value.filter((r) => r.floor === floor).length
  return `${f}${String(onFloor + 1).padStart(2, '0')}`
}
function nextFloorNumber(): number {
  const floors = [
    ...rooms.value.map((r) => r.floor).filter((f): f is number => f !== null),
    ...trackedFloors.value,
  ]
  return floors.length ? Math.max(...floors) + 1 : 1
}
const previewRoomNumber = computed(() => nextRoomNumber(roomForm.floor))

// Fires only on an actual pick in the <select> — never during openRoomDialog's
// programmatic population — so an existing room's saved capacity is never
// silently overwritten just because its type happens to be Solo/Duo/Triple.
function onRoomTypeChange() {
  const fixed = ROOM_TYPE_DEFAULT_CAPACITY[roomForm.roomType]
  if (fixed !== undefined) roomForm.capacity = fixed
}

function openRoomDialog(room: Room | null, floor?: number) {
  roomStep.value = 1
  roomViewMode.value = 'view'
  if (room) {
    roomDialogMode.value = 'edit'
    editingRoomId.value = room.id
    activeRoomNumber.value = room.roomNumber || ''
    activeRoomStatus.value = room.status === 'occupied' || room.status === 'maintenance' ? room.status : 'available'
    roomForm.roomType = room.roomType || 'solo'
    roomForm.customRoomType = room.customRoomType || ''
    roomForm.floor = room.floor
    roomForm.capacity = room.capacity ?? 1
    roomForm.monthlyRent = room.monthlyRent
    roomForm.advanceMonths = room.advanceMonths
    roomForm.depositMonths = room.depositMonths
    roomForm.rentBasis = room.rentBasis
    roomImages.value = [...room.images]
  } else {
    roomDialogMode.value = 'create'
    editingRoomId.value = ''
    activeRoomNumber.value = ''
    roomForm.roomType = 'solo'
    roomForm.customRoomType = ''
    roomForm.floor = floor ?? nextFloorNumber()
    roomForm.capacity = 1
    roomForm.monthlyRent = 0
    roomForm.advanceMonths = null
    roomForm.depositMonths = null
    roomForm.rentBasis = 'room'
    roomImages.value = []
  }
  roomOpen.value = true
}

// Adding a floor doesn't mean adding a room — it just opens up a new,
// empty floor group to add rooms into (via that floor's own "Add room").
// Nothing is written to the database until an actual room is saved on it.
const addingFloor = ref(false)

async function addFloor() {
  if (addingFloor.value) return
  if (floorCount.value >= MAX_FLOORS) {
    notify.error(`This accommodation already has the maximum of ${MAX_FLOORS} floors.`)
    return
  }
  addingFloor.value = true
  const floor = nextFloorNumber()
  try {
    const { error: insertError } = await supabase
      .from('accommodation_floors')
      .insert({ accommodation_id: id, floor_number: floor })
    if (insertError) throw insertError
    trackedFloors.value.push(floor)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not add this floor.'))
  } finally {
    addingFloor.value = false
  }
}

async function addRoomPhotos(files: File[]) {
  if (!files.length || !editingRoomId.value) return
  uploadingRoomPhoto.value = true
  try {
    for (const file of files) {
      const url = await uploadDocument(file, '', 'room_photo')
      const { data: created, error: insertError } = await supabase
        .from('room_images')
        .insert({ room_id: editingRoomId.value, url, sort_order: roomImages.value.length })
        .select('id,url')
        .single()
      if (insertError) throw insertError
      roomImages.value.push({ id: created.id, url: created.url })
    }
    const row = rooms.value.find((r) => r.id === editingRoomId.value)
    if (row) {
      row.images = [...roomImages.value]
      row.photoUrl = roomImages.value[0]?.url ? resolveAsset(roomImages.value[0].url) : ''
    }
  } catch (e) {
    notify.error(errorMessage(e, "Could not upload one of this room's photos."))
  } finally {
    uploadingRoomPhoto.value = false
  }
}

async function onRoomPhotosSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files ?? [])
  await addRoomPhotos(files)
  input.value = ''
}

async function takeRoomPhoto() {
  const { file, error } = await capturePhoto()
  if (error) notify.error(error)
  if (file) await addRoomPhotos([file])
}

async function deleteRoomImage(imageId: string) {
  if (deletingRoomImage.value) return
  deletingRoomImage.value = imageId
  try {
    const { error: deleteError } = await supabase.from('room_images').delete().eq('id', imageId)
    if (deleteError) throw deleteError
    roomImages.value = roomImages.value.filter((i) => i.id !== imageId)
    const row = rooms.value.find((r) => r.id === editingRoomId.value)
    if (row) {
      row.images = [...roomImages.value]
      row.photoUrl = roomImages.value[0]?.url ? resolveAsset(roomImages.value[0].url) : ''
    }
  } catch (e) {
    notify.error(errorMessage(e, 'Could not remove this photo.'))
  } finally {
    deletingRoomImage.value = ''
  }
}

async function confirmRoomBasics() {
  if (savingRoom.value) return
  savingRoom.value = true
  try {
    const payload = {
      label: null,
      room_type: roomForm.roomType,
      custom_room_type: roomForm.roomType === 'custom' ? roomForm.customRoomType.trim() || null : null,
      floor: roomForm.floor,
      capacity: roomForm.capacity,
      monthly_rent: roomForm.monthlyRent,
      advance_months: roomForm.advanceMonths,
      deposit_months: roomForm.depositMonths,
      rent_basis: roomForm.capacity > 1 ? roomForm.rentBasis : ('room' as const),
    }

    if (editingRoomId.value) {
      const { error: updateError } = await supabase.from('rooms').update(payload).eq('id', editingRoomId.value)
      if (updateError) throw updateError
      const row = rooms.value.find((r) => r.id === editingRoomId.value)
      if (row) Object.assign(row, {
        roomType: payload.room_type,
        customRoomType: payload.custom_room_type,
        capacity: payload.capacity,
        monthlyRent: payload.monthly_rent,
        advanceMonths: payload.advance_months,
        depositMonths: payload.deposit_months,
        rentBasis: payload.rent_basis,
      })
      if (roomDialogMode.value === 'edit') {
        roomOpen.value = false
        notify.success('Room saved.')
      } else {
        roomStep.value = 2
      }
    } else {
      const roomNumber = nextRoomNumber(roomForm.floor)
      const { data: created, error: insertError } = await supabase
        .from('rooms')
        .insert({ ...payload, room_number: roomNumber, accommodation_id: id, status: 'available' })
        .select('id,current_pax,status,room_number')
        .single()
      if (insertError) throw insertError
      rooms.value.push({
        id: created.id,
        label: null,
        roomNumber: created.room_number,
        roomType: payload.room_type,
        customRoomType: payload.custom_room_type,
        floor: payload.floor,
        capacity: payload.capacity,
        currentPax: created.current_pax ?? 0,
        monthlyRent: payload.monthly_rent,
        advanceMonths: payload.advance_months,
        depositMonths: payload.deposit_months,
        rentBasis: payload.rent_basis,
        status: created.status,
        images: [],
        photoUrl: '',
      })
      editingRoomId.value = created.id
      activeRoomNumber.value = created.room_number ?? roomNumber
      roomImages.value = []
      roomStep.value = 2
    }
  } catch (e) {
    notify.error(errorMessage(e, 'Could not save this room.'))
  } finally {
    savingRoom.value = false
  }
}

// Occupied is set elsewhere (when a lease is active) and isn't something a
// manager flips by hand here — this only toggles between the two states
// that ARE theirs to set: open for applicants, or taken out of service
// (renovation, damage, etc.) without deleting the room outright.
async function toggleRoomStatus() {
  if (togglingRoomStatus.value || !editingRoomId.value || activeRoomStatus.value === 'occupied') return
  const next = activeRoomStatus.value === 'maintenance' ? 'available' : 'maintenance'
  togglingRoomStatus.value = true
  try {
    const { error: updateError } = await supabase.from('rooms').update({ status: next }).eq('id', editingRoomId.value)
    if (updateError) throw updateError
    activeRoomStatus.value = next
    const row = rooms.value.find((r) => r.id === editingRoomId.value)
    if (row) row.status = next
    notify.success(next === 'maintenance' ? 'Room marked unavailable.' : 'Room marked available.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update this room.'))
  } finally {
    togglingRoomStatus.value = false
  }
}

// leases.room_id is ON DELETE RESTRICT at the database level (and leases
// cascade further to payments/concerns/tickets/reviews) — the count check
// below is just an early, friendly warning; the '23503' branch is what
// actually stops a delete if a lease slipped in between the check and here.
function isLeaseRestrictError(e: unknown): boolean {
  return typeof e === 'object' && e !== null && (e as { code?: string }).code === '23503'
}

async function deleteRoom() {
  if (savingRoom.value || !editingRoomId.value) return
  savingRoom.value = true
  try {
    const { count, error: countError } = await supabase
      .from('leases')
      .select('id', { count: 'exact', head: true })
      .eq('room_id', editingRoomId.value)
    if (countError) throw countError
    if (count) {
      notify.error('This room has lease history and can\'t be deleted. Consider renaming or repurposing it instead.')
      return
    }

    const { data: deleted, error: deleteError } = await supabase
      .from('rooms')
      .delete()
      .eq('id', editingRoomId.value)
      .select('id')
    if (deleteError) throw deleteError
    if (!deleted?.length) {
      notify.error('Could not remove this room.')
      return
    }
    rooms.value = rooms.value.filter((r) => r.id !== editingRoomId.value)
    roomOpen.value = false
    notify.success('Room removed.')
  } catch (e) {
    notify.error(
      isLeaseRestrictError(e)
        ? 'This room has lease history and can\'t be deleted.'
        : errorMessage(e, 'Could not remove this room.'),
    )
  } finally {
    savingRoom.value = false
    confirmDeleteRoomOpen.value = false
  }
}

const deletingFloor = ref<number | null>(null)
const confirmDeleteFloorOpen = ref(false)
const floorPendingDelete = ref<number | null>(null)

async function deleteTrackedFloorRow(floor: number) {
  const { error } = await supabase
    .from('accommodation_floors')
    .delete()
    .eq('accommodation_id', id)
    .eq('floor_number', floor)
  if (error) throw error
  trackedFloors.value = trackedFloors.value.filter((f) => f !== floor)
}

async function promptDeleteFloor(floor: number) {
  // An empty floor has no rooms to protect — just remove its own row.
  if (!rooms.value.some((r) => r.floor === floor)) {
    if (deletingFloor.value !== null) return
    deletingFloor.value = floor
    try {
      await deleteTrackedFloorRow(floor)
    } catch (e) {
      notify.error(errorMessage(e, 'Could not remove this floor.'))
    } finally {
      deletingFloor.value = null
    }
    return
  }
  floorPendingDelete.value = floor
  confirmDeleteFloorOpen.value = true
}

async function confirmDeleteFloor() {
  const floor = floorPendingDelete.value
  if (floor === null || deletingFloor.value !== null) return
  const roomIds = rooms.value.filter((r) => r.floor === floor).map((r) => r.id)
  if (!roomIds.length) {
    confirmDeleteFloorOpen.value = false
    return
  }
  deletingFloor.value = floor
  try {
    const { count, error: countError } = await supabase
      .from('leases')
      .select('id', { count: 'exact', head: true })
      .in('room_id', roomIds)
    if (countError) throw countError
    if (count) {
      notify.error('This floor has rooms with lease history and can\'t be deleted.')
      return
    }

    const { data: deleted, error: deleteError } = await supabase
      .from('rooms')
      .delete()
      .in('id', roomIds)
      .select('id')
    if (deleteError) throw deleteError
    if ((deleted ?? []).length !== roomIds.length) {
      notify.error("Some rooms on this floor couldn't be deleted — nothing was removed until this is resolved.")
      return
    }

    rooms.value = rooms.value.filter((r) => r.floor !== floor)
    facilities.value = facilities.value.filter((f) => !f.roomId || !roomIds.includes(f.roomId))
    if (trackedFloors.value.includes(floor)) {
      await deleteTrackedFloorRow(floor)
    }
    notify.success(`Floor ${floor} removed.`)
  } catch (e) {
    notify.error(
      isLeaseRestrictError(e)
        ? 'This floor has rooms with lease history and can\'t be deleted.'
        : errorMessage(e, 'Could not remove this floor.'),
    )
  } finally {
    deletingFloor.value = null
    confirmDeleteFloorOpen.value = false
  }
}


onMounted(load)
</script>

<style scoped>
.ad {
  display: flex;
  flex-direction: column;
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  gap: 14px;
  padding: 0 var(--m-page-gutter) 0;
}
.sk {
  border-radius: var(--m-radius);
}
.sk-tab {
  border-radius: 10px 10px 0 0;
}
.card {
  padding: 18px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}
.err-title {
  margin: 8px 0 0;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.err-sub {
  margin: 2px 0 0;
  color: var(--m-muted);
  font-size: 12px;
}

/* Cover hero — capped to a fixed height (the "limit"), image always fills
   it edge to edge (no letterbox margins), title overlaid on top. The tab
   strip below is pulled up over its bottom edge with a negative margin. */
.hero {
  position: relative;
  flex: 0 0 auto;
  height: 220px;
  overflow: hidden;
  background: var(--m-primary-soft);
}
.hero-media { position: absolute; inset: 0; overflow: hidden; }
.hero-img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
.hero-media--empty { background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%); }
.hero-empty { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; }
.hero-scrim {
  position: absolute;
  inset: 0;
  background: linear-gradient(to bottom, rgba(0, 0, 0, 0.5) 0%, rgba(0, 0, 0, 0) 45%);
}
.hero-edit {
  position: absolute;
  top: 10px;
  right: var(--m-page-gutter);
  z-index: 2;
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.55);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.shot-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
}
.shot-empty-label { font-size: 10.5px; font-weight: 700; letter-spacing: 0.02em; }

.head {
  position: absolute;
  left: var(--m-page-gutter);
  right: 54px;
  top: 14px;
  z-index: 1;
  display: flex;
  align-items: center;
  gap: 8px;
}
.head-name {
  min-width: 0;
  overflow: hidden;
  color: #fff;
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.35);
}
.head-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.head-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.head-chip--amber {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.head-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.head-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}

.tabbed {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  margin: 0 calc(var(--m-page-gutter) * -1);
}
/* Pulled up over the hero's bottom edge so the tab strip (and the card it
   feeds into) reads as one block rising out of the photo. */
.tabs {
  position: relative;
  z-index: 2;
  display: flex;
  gap: 4px;
  padding: 0 var(--m-page-gutter);
  margin-top: -56px;
  /* -2px (not -1px): at fractional device-pixel ratios (real phones, not
     desktop @1x) an exact 1px overlap can round the wrong way and leave a
     hairline gap of the page background between the active tab and the
     panel. The active tab's background already equals the panel's, so the
     extra 1px of overlap is invisible — it just guarantees full coverage. */
  margin-bottom: -2px;
}
/* Unselected tabs read as frosted glass over the photo behind them; the
   active tab turns opaque to fuse seamlessly into the card below. */
.tab {
  min-height: 40px;
  padding: 0 16px;
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-bottom: none;
  border-radius: 10px 10px 0 0;
  background: rgba(255, 255, 255, 0.14);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  color: rgba(255, 255, 255, 0.9);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.25);
  transition: background-color 0.15s ease, color 0.15s ease, backdrop-filter 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
.tab--on {
  border-color: var(--m-border);
  background: var(--m-surface);
  backdrop-filter: none;
  -webkit-backdrop-filter: none;
  color: var(--m-primary-dark);
  text-shadow: none;
}

/* Same border + background as the active tab, and no top radius where the
   two meet — one seam-free block from tab strip down through the card. */
.panel {
  display: flex;
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  padding: 14px var(--m-page-gutter);
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
.panels { background: transparent; }
.panels :deep(.q-tab-panel) { padding: 0; }

.sec {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.sec-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.sec-title {
  margin: 4px 0 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.sec-title:first-child {
  margin-top: 0;
}
.sec-link {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.sec-link:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.sec-hint {
  color: var(--m-muted);
  font-size: 12px;
}
.none {
  padding: 14px 12px;
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}

.field {
  display: flex;
  flex: 1 1 130px;
  min-width: 130px;
  flex-direction: column;
  gap: 4px;
}
.field-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.field-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.field-input {
  box-sizing: border-box;
  width: 100%;
  min-width: 0;
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.field-textarea {
  min-height: 90px;
  padding: 10px 12px;
  resize: vertical;
}
.save-btn {
  min-height: 46px;
  margin-top: 4px;
  font-weight: 700;
}
.view-group {
  display: flex;
  flex-direction: column;
}
.view-row {
  display: flex;
  width: 100%;
  min-height: 40px;
  align-items: center;
  gap: 8px;
  padding: 7px 2px;
  border: 0;
  border-bottom: 1px solid var(--m-border);
  background: transparent;
  font: inherit;
  text-align: left;
}
.view-group > .view-row:last-child { border-bottom: 0; }
.view-row--tap { cursor: pointer; -webkit-tap-highlight-color: transparent; }
.view-row--block { flex-direction: column; align-items: stretch; gap: 4px; }
.view-row-head { display: flex; width: 100%; align-items: center; justify-content: space-between; }
.view-chevron { flex: 0 0 auto; color: var(--m-muted); }
.view-label {
  flex: 0 0 auto;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.view-value {
  flex: 1 1 auto;
  min-width: 0;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 600;
  text-align: right;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.view-text {
  margin: 0;
  color: var(--m-ink);
  font-size: 13.5px;
  line-height: 1.4;
  text-wrap: pretty;
}

.map {
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.map img {
  display: block;
  width: 100%;
  height: 160px;
  object-fit: cover;
}
.map-note {
  display: flex;
  align-items: center;
  gap: 5px;
  margin: 0;
  padding: 8px 12px;
  border-top: 1px solid var(--m-border);
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}

.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 7px 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 600;
  -webkit-tap-highlight-color: transparent;
}
.chip--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}

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

.status-box {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
}
.status-text {
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
  line-height: 1.4;
}
.status-btn {
  align-self: flex-start;
  min-height: 42px;
  padding: 0 16px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.status-btn--danger {
  border-color: var(--m-danger);
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.status-btn:disabled {
  opacity: 0.6;
}

.group {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.quick-stats {
  display: flex;
  align-items: center;
  justify-content: space-around;
  padding: 14px 12px;
}
.stat-block {
  display: flex;
  align-items: center;
  gap: 8px;
}
.stat-badge {
  display: flex;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.stat-number {
  display: block;
  color: var(--m-ink);
  font-size: 18px;
  font-weight: 700;
  line-height: 1.2;
}
.stat-label {
  display: block;
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.03em;
  text-transform: uppercase;
}
.stat-divider {
  width: 1px;
  height: 30px;
  background: var(--m-border);
}
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
.room-row {
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
.group > .room-row:first-child {
  border-top: 0;
}
.room-shot {
  display: grid;
  width: 48px;
  height: 48px;
  flex: 0 0 48px;
  place-items: center;
  overflow: hidden;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-muted);
}
.room-shot img { width: 100%; height: 100%; object-fit: cover; }
.room-shot--empty { background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%); }
.room-body {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 1px;
}
.room-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.room-sub {
  color: var(--m-muted);
  font-size: 11.5px;
}
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
.photo-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.photo-action-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  min-height: 38px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.file-input-hidden {
  display: none;
}

.thumbs {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.thumb {
  position: relative;
  width: 84px;
  height: 84px;
  overflow: hidden;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
}
.thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.thumb-x {
  position: absolute;
  top: 3px;
  right: 3px;
  display: grid;
  width: 18px;
  height: 18px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.7);
  color: #fff;
  cursor: pointer;
}
.thumb-x:disabled {
  opacity: 0.6;
}

.room-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  max-height: 85vh;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
  overflow-y: auto;
}
.sheet-grip {
  display: block;
  width: 40px;
  height: 4px;
  margin: 0 auto;
  border-radius: 999px;
  background: var(--m-border);
}
.sheet-header {
  display: flex;
  align-items: center;
  gap: 10px;
}
.sheet-header-icon {
  display: grid;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.room-sheet-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
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
.sheet-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding-top: 10px;
  border-top: 1px solid var(--m-border);
}
.room-sheet-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
}
.room-del {
  flex: 0 0 auto;
  min-height: 46px;
  padding: 0 16px;
  border: 1px solid var(--m-danger);
  border-radius: 999px;
  background: var(--m-danger-soft);
  color: var(--m-danger);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.room-del:disabled {
  opacity: 0.6;
}
.steps--sheet {
  display: flex;
  justify-content: center;
  gap: 6px;
  padding: 2px 0;
}
.step-dot {
  width: 8px;
  height: 8px;
  border-radius: 999px;
  background: var(--m-border);
}
.step-dot--on {
  background: var(--m-primary);
}
.ghost-btn {
  flex: 0 0 auto;
  min-height: 46px;
  padding: 0 20px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
/* Every footer button — Back included — sits together at the right edge. */
.wizard-nav {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
}

/* One fixed height for every multi-step form (room, facility — create and
   edit alike) so they don't visibly resize between short steps (Photos)
   and long ones (Basics); overflow scrolls inside via .room-sheet-scroll. */
.room-sheet--wizard {
  height: min(660px, 85vh);
}

/* The room dialog scrolls its own content while the footer (Back/Next/Done,
   or Delete/Save) stays put — overrides the plain sheets' "everything
   scrolls together" layout with a dedicated scroll pane + a pinned footer. */
.room-sheet--paged {
  overflow: hidden;
}
.room-sheet-scroll {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  gap: 12px;
  overflow-y: auto;
}
.room-sheet--paged > .room-sheet-actions,
.room-sheet--paged > .wizard-nav {
  flex: 0 0 auto;
  padding-top: 12px;
  border-top: 1px solid var(--m-border);
}
.photo-actions--pinned {
  flex: 0 0 auto;
  padding-top: 12px;
  border-top: 1px solid var(--m-border);
}

.floor-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
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
