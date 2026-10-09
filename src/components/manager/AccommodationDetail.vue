<template>
  <q-page class="ad" :class="{ 'page-wide': split }">
    <!-- Desktop: the loaded shape — the way back above a card of two halves,
         photo and overview left, rooms right. -->
    <div v-if="loading && split" class="stack">
      <div class="desk-back-row">
        <button type="button" class="desk-panel-back" aria-label="Back to properties" @click="router.push('/manager/properties')">
          <IconifyIcon icon="lucide:arrow-left" width="20" />
        </button>
        <span class="desk-panel-title">Properties</span>
      </div>
      <div class="desk-card">
        <div class="desk-col">
          <q-skeleton type="rect" height="220px" square class="sk-hero" />
          <q-skeleton type="rect" height="90px" class="sk" />
        </div>
        <div class="desk-col">
          <q-skeleton v-for="n in 2" :key="n" type="rect" height="90px" class="sk" />
        </div>
      </div>
    </div>

    <div v-else-if="loading" class="stack">
      <q-skeleton type="rect" height="220px" square />
      <div class="tabs">
        <q-skeleton type="rect" width="88px" height="38px" class="m-sk-tab" />
        <q-skeleton type="rect" width="72px" height="38px" class="m-sk-tab" />
        <q-skeleton type="rect" width="80px" height="38px" class="m-sk-tab" />
      </div>
      <q-skeleton type="rect" height="90px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <ErrorCard title="Couldn't load this accommodation" :detail="error" :retry="load" />
    </div>

    <div v-else class="stack">
      <!-- Desktop keeps the plain app header, so the way back to Properties
           sits just above the card's left half. -->
      <div v-if="split" class="desk-back-row">
        <button type="button" class="desk-panel-back" aria-label="Back to properties" @click="router.push('/manager/properties')">
          <IconifyIcon icon="lucide:arrow-left" width="20" />
        </button>
        <span class="desk-panel-title">Properties</span>
      </div>
      <!-- Desktop: the two halves of a card — the photo, overview and settings
           on the left, rooms on the right, each scrolling on its own. On a phone
           .col-left is display: contents and nothing here changes. -->
      <div :class="split ? 'desk-card' : 'tabbed'">
        <div :class="split ? 'desk-col' : 'col-left'">
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

        <div v-if="!split" class="tabs">
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
        <component :is="panelsIs" v-bind="panelsProps" class="m-panels">
        <!-- OVERVIEW -->
        <component :is="panelIs" name="overview" class="sec">
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
            <button type="button" class="view-row view-row--tap" @click="openFieldDialog('genderPolicy')">
              <span class="view-label">Accepts</span>
              <span class="view-value">{{ GENDER_POLICY_LABEL[acc.genderPolicy] || '—' }}</span>
              <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
            </button>
            <button type="button" class="view-row view-row--tap" @click="openFieldDialog('purok')">
              <span class="view-label">Purok</span>
              <span class="view-value">{{ acc.purok || '—' }}</span>
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
            <!-- Counted from the floors on the Rooms tab (the database keeps
                 total_floors in step), so it can't disagree with them. -->
            <div class="view-row">
              <span class="view-label">Floors</span>
              <span class="view-value">{{ floorCount || '—' }}</span>
            </div>
            <button type="button" class="view-row view-row--tap view-row--block" @click="openFieldDialog('description')">
              <span class="view-row-head">
                <span class="view-label">Description</span>
                <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
              </span>
              <p class="view-text">{{ acc.description || 'No description yet.' }}</p>
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
        </component>

        <!-- ROOMS & FACILITIES, both floor-accurate. On desktop the content
             moves to the right half; the Teleport sits inside the panel so
             QTabPanels still finds a panel named "rooms" on a phone. -->
        <component :is="panelIs" name="rooms" class="sec" :class="{ 'sec--moved': split }">
          <Teleport :to="rightCol" :disabled="!split || !rightCol">
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
                  <span class="room-chip" :class="`room-chip--${ROOM_STATUS_TONE[r.status] || `grey`}`">
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
          </Teleport>
        </component>

        <!-- SETTINGS -->
        <component :is="panelIs" name="settings" class="sec">
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
        </component>
        </component>
        </div>
        </div>

        <div v-if="split" ref="rightCol" class="desk-col col-right" />
      </div>
    </div>

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
        <select v-if="editingField && FIELD_META[editingField].type === 'select'" v-model="fieldDraft" class="field-input app-select">
          <option value="">Select {{ FIELD_META[editingField].label.toLowerCase() }}</option>
          <option v-for="(label, key) in FIELD_META[editingField].options" :key="key" :value="key">{{ label }}</option>
        </select>
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

    <!-- ADD/EDIT ROOM -->
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

          <template v-else>
            <div class="field-row">
              <label class="field">
                <span class="field-label">Room number or name</span>
                <input v-model="roomForm.roomNumber" type="text" maxlength="20" class="field-input" :placeholder="previewRoomNumber" />
              </label>
              <label class="field">
                <span class="field-label">Floor</span>
                <select v-model.number="roomForm.floor" class="field-input app-select" @change="onRoomFloorChange">
                  <option v-for="f in floorOptions" :key="f" :value="f">{{ floorName(f) }}</option>
                </select>
              </label>
            </div>

            <div class="field-row">
              <label class="field">
                <span class="field-label">Room type</span>
                <select v-model="roomForm.roomType" class="field-input app-select" @change="onRoomTypeChange">
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
                Current tenants keep the terms they moved in with. Changes apply to new tenants.
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

    <!-- ADD / VIEW / EDIT FACILITY -->
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
              <select v-model="facilityForm.facilityType" class="field-input app-select">
                <option v-for="(meta, key) in facilityTypeOptions" :key="key" :value="key">{{ meta.label }}</option>
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
            <template v-if="facilityScope === 'shared'">
              <label class="field">
                <span class="field-label">Status</span>
                <select v-model="facilityForm.status" class="field-input app-select">
                  <option v-for="(label, key) in FACILITY_STATUS_LABEL" :key="key" :value="key">{{ label }}</option>
                </select>
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
import { useAuthStore } from '@/stores/auth'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { useDeskPanels } from '@/utils/useDeskPanels'
import { errorMessage } from '@/utils/errors'
import { formatPeso, to12Hour, to24Hour, splitTimeRange } from '@/utils/format'
import { since } from '@/utils/notifications'
import { useNotify } from '@/utils/notify'
import { uploadDocument, secureDocUrl } from '@/utils/upload'
import { resolveAsset, isPdf, CARD, COVER } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel, staticMapUrl, CAMPUS } from '@/utils/geo'
import UtilitiesFields from '@/components/manager/UtilitiesFields.vue'
import { UTILITIES, UTILITY_SELECT, emptyUtilities, utilitiesFromRow, utilityColumns, utilitiesProblem, utilityTermsLabel, type UtilityKey, type UtilityTerms, type UtilityColumns, AMENITY_META, AMENITY_KEYS, FACILITY_META, PRIVATE_ONLY_FACILITY_TYPES, RETIRED_FACILITY_TYPES, ROOM_TYPE_LABEL, ROOM_TYPE_DEFAULT_CAPACITY, BUILDING_TYPE_LABEL, GENDER_POLICY_LABEL, roomTypeLabel, ACCOMMODATION_STATUS_LABEL, ACCOMMODATION_STATUS_TONE } from '@/utils/listings'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import type { Database } from '@/types/database.gen'
import { capturePhoto } from '@/utils/camera'
import { POLICY_RULES } from '@/api/selects'
import ConfirmDeleteSheet from '@/components/shared/ConfirmDeleteSheet.vue'
import AccreditationCard from '@/components/manager/AccreditationCard.vue'
import PermitUploadSheet from '@/components/manager/PermitUploadSheet.vue'
import { permitDate, permitReplaceOpen } from '@/utils/permits'
import {
  CAPACITY_MAX, MONTHS_MAX, RENT_MAX,
  clampNum, clampOptional, partitionFacilities,
  nextFloorNumber as nextFloorNumberOf, nextRoomNumber as nextRoomNumberOf, sameRoomNumber,
} from '@/utils/roomInventory'
import { manilaToday } from '@/utils/payments'
import AppModal from '@/components/shared/AppModal.vue'

// Loaded on demand — mapbox-gl (pulled in only by this component) is by far
// the heaviest dependency in the app, and the picker is opened rarely.
const LocationPicker = defineAsyncComponent(() => import('@/components/manager/LocationPicker.vue'))

type AmenityKey = Database['public']['Enums']['amenity']

const STATUS_LABEL = ACCOMMODATION_STATUS_LABEL
const STATUS_TONE = ACCOMMODATION_STATUS_TONE
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
  /** How this room's water, electricity and Wi-Fi are paid. */
  utilities: Record<UtilityKey, UtilityTerms>
  status: string
  images: Img[]
  photoUrl: string
}
interface Img {
  id: string
  url: string
}
type FacilityStatus = 'available' | 'under_repair'

interface Facility {
  id: string
  facilityType: string
  label: string
  description: string
  roomId: string | null
  floor: number | null
  status: FacilityStatus
  /** Rooms that share it; only a shared facility has any. */
  roomIds: string[]
  images: Img[]
}

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const notify = useNotify()

const id = String(route.params.id || '')

const loading = ref(true)
const error = ref('')
const tab = ref<(typeof TABS)[number]['key']>('overview')
// Desktop lays the tabs out as the halves of a card instead (useDeskPanels).
const { split, panelsIs, panelIs, panelsProps } = useDeskPanels(tab)
const rightCol = ref<HTMLElement | null>(null)
const savingAmenities = ref(false)
const delisting = ref(false)
const amenitiesDialogOpen = ref(false)
const fieldDialogOpen = ref(false)
const savingField = ref(false)
const editingField = ref<FieldKey | null>(null)
const fieldDraft = ref('')
// Second half of a time range (quiet hours "until"); unused by other types.
const fieldDraftTo = ref('')

const acc = reactive({
  name: '',
  accommodationType: '',
  genderPolicy: '',
  address: '',
  purok: '',
  barangay: '',
  city: '',
  description: '',
  status: 'pending',
  lat: null as number | null,
  lng: null as number | null,
  appealUsed: false,
  accreditationExpiresAt: null as string | null,
})
const rules = reactive({
  amenities: [] as string[],
  curfewTime: '',
  quietHours: '',
  visitorPolicy: '',
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
const coverUrl = computed(() => (images.value[0]?.url ? resolveAsset(images.value[0].url, COVER) : ''))
// Occupancy must come from actual leases, not rooms.status/current_pax —
// this project's own data notes flag those columns as unreliable.
const occupiedRoomIds = ref<string[]>([])
const occupiedRoomCount = computed(() => occupiedRoomIds.value.length)
const vacantRoomCount = computed(() => Math.max(rooms.value.length - occupiedRoomCount.value, 0))
// What a draft still needs before submit_accommodation() will take it — the
// same list the database checks, worded the way its error reads.
const draftMissing = computed(() => {
  const missing: string[] = []
  if (!acc.accommodationType || !acc.genderPolicy) missing.push('type and who it accepts')
  if (acc.lat === null || acc.lng === null || !acc.barangay || !acc.city) missing.push('location')
  if (rooms.value.some((r) => utilitiesProblem(r.utilities))) missing.push('utilities on every room')
  if (!rules.curfewTime || !rules.quietHours || !rules.visitorPolicy) missing.push('house rules')
  if (!images.value.length) missing.push('an exterior photo')
  const docs = new Set(docRows.value.map((d) => d.doc_type))
  if (!['sanitary_permit', 'fire_safety', 'business_permit', 'building_permit'].every((t) => docs.has(t))) {
    missing.push('all four permits')
  } else {
    if (docRows.value.some((d) => !d.expires_at)) missing.push('an expiry date on every permit')
    const today = manilaToday()
    if (docRows.value.some((d) => d.expires_at && d.expires_at < today)) missing.push('permits that have not expired')
  }
  return missing
})
const submittingDraft = ref(false)
async function submitDraft() {
  if (submittingDraft.value) return
  submittingDraft.value = true
  try {
    const { error: submitError } = await supabase.rpc('submit_accommodation', { p_id: id })
    if (submitError) throw submitError
    acc.status = 'pending'
    notify.success('Submitted — it now awaits OSAS review.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not submit this accommodation.'))
  } finally {
    submittingDraft.value = false
  }
}

// Rooms, facilities and floors come after accreditation, and only while the
// listing is live — the database refuses the insert otherwise
// (20261003000000), as it does for an unverified landlord/landlady.
const canAddInventory = computed(() => acc.status === 'accredited' && auth.isVerifiedLandlord)
const inventoryClosedHint = computed(() => {
  if (!auth.isVerifiedLandlord) return 'You can add rooms, facilities and floors once OSAS verifies your account.'
  if (acc.status === 'delisted') return 'This accommodation is delisted — reactivate it to add rooms, facilities, or floors.'
  if (acc.status === 'expired') return 'Accreditation has ended — renew it to add rooms, facilities, or floors.'
  if (acc.status === 'suspended') return 'OSAS suspended this accommodation, so rooms, facilities and floors can’t be added.'
  return 'You can add rooms, facilities and floors once OSAS accredits this accommodation.'
})
const distance = computed(() => campusDistanceLabel(acc.lat, acc.lng))
const mapUrl = computed(() => staticMapUrl(acc.lat, acc.lng))
const locationPickerOpen = ref(false)

// The picker no longer guesses a street address — barangay and city are what
// it fills. Address stays editable on its own row here.
async function onLocationConfirmed(payload: { lat: number; lng: number; barangay: string; city: string }) {
  const fields: Database['public']['Tables']['accommodations']['Update'] = { lat: payload.lat, lng: payload.lng }
  if (!acc.barangay && payload.barangay) fields.barangay = payload.barangay
  if (!acc.city && payload.city) fields.city = payload.city
  const review = fieldReview('barangay')
  if (review === 'locked') {
    notify.error('The location can’t change while OSAS is reviewing the listing or it is not accredited.')
    return
  }
  if (review === 'request') {
    await requestChange(fields as Record<string, unknown>)
    return
  }
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

const sharedFacilities = computed(() => partitionFacilities(facilities.value, editingRoomId.value).shared)
const currentRoomFacilities = computed(() => partitionFacilities(facilities.value, editingRoomId.value).privateToRoom)

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
  status: 'available' as FacilityStatus,
  roomIds: [] as string[],
})

// Air-con and the like belong to a room; the shared picker leaves them out.
// Retired types (parking, now an amenity) are offered by neither.
const facilityTypeOptions = computed(() =>
  Object.fromEntries(
    Object.entries(FACILITY_META).filter(
      ([k]) => !RETIRED_FACILITY_TYPES.includes(k) && (facilityScope.value !== 'shared' || !PRIVATE_ONLY_FACILITY_TYPES.includes(k)),
    ),
  ),
)
const FACILITY_STATUS_LABEL: Record<FacilityStatus, string> = { available: 'Available', under_repair: 'Under repair' }
const roomTitle = (r: Room) => (r.roomNumber ? `Room ${r.roomNumber}` : 'Room')
const roomOptions = computed(() => rooms.value.map((r) => ({ label: roomTitle(r), value: r.id })))
// Filtered through the live room list, so a deleted room drops out.
const roomNames = (ids: string[]) => rooms.value.filter((r) => ids.includes(r.id)).map(roomTitle).join(', ')
function sharedFacilitySub(f: Facility): string {
  const n = rooms.value.filter((r) => f.roomIds.includes(r.id)).length
  const shared = n ? `Shared by ${n} room${n === 1 ? '' : 's'}` : 'Shared facility'
  return f.status === 'under_repair' ? `${shared} · Under repair` : shared
}

/** Replaces a facility's room links with `after`, touching only what changed. */
async function syncFacilityRooms(facilityId: string, before: string[], after: string[]) {
  const removed = before.filter((r) => !after.includes(r))
  const added = after.filter((r) => !before.includes(r))
  if (removed.length) {
    const { error: e } = await supabase.from('accommodation_facility_rooms').delete().eq('facility_id', facilityId).in('room_id', removed)
    if (e) throw e
  }
  if (added.length) {
    const { error: e } = await supabase.from('accommodation_facility_rooms').insert(added.map((room_id) => ({ facility_id: facilityId, room_id })))
    if (e) throw e
  }
}
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
  facilityForm.status = 'available'
  facilityForm.roomIds = []
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
  facilityForm.status = f.status
  facilityForm.roomIds = [...f.roomIds]
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
      status: facilityForm.status,
    }
    const { error: updateError } = await supabase
      .from('accommodation_facilities')
      .update(payload)
      .eq('id', activeFacilityId.value)
    if (updateError) throw updateError
    const row = facilities.value.find((f) => f.id === activeFacilityId.value)
    if (row && !row.roomId) await syncFacilityRooms(row.id, row.roomIds, facilityForm.roomIds)
    if (row) Object.assign(row, { facilityType: payload.facility_type, label: payload.label || '', description: payload.description || '', status: payload.status, roomIds: row.roomId ? [] : [...facilityForm.roomIds] })
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
      status: facilityForm.status,
    }
    const { data: created, error: insertError } = await supabase
      .from('accommodation_facilities')
      .insert({ ...payload, accommodation_id: id, sort_order: facilities.value.length })
      .select('id')
      .single()
    if (insertError) throw insertError
    const roomIds = facilityScope.value === 'shared' ? [...facilityForm.roomIds] : []
    await syncFacilityRooms(created.id, [], roomIds)
    facilities.value.push({
      id: created.id,
      facilityType: payload.facility_type,
      label: payload.label || '',
      description: payload.description || '',
      roomId: payload.room_id,
      floor: payload.floor,
      status: payload.status,
      roomIds,
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
      return { type, statusLabel: 'Not submitted', tone: 'idle', icon: 'lucide:circle-dashed', when: '', fileUrl: '', canReplace: true }
    }
    const flagged = Boolean(accreditationCard.value?.flagged.some((f) => f.type === type && !f.replaced))
    const canReplace = permitReplaceOpen(acc.status, row.expires_at, flagged)
    return { ...docStatus(row, flagged), type, fileUrl: row.file_url, canReplace }
  }),
)

function docStatus(row: { expires_at: string | null; uploaded_at: string }, flagged: boolean) {
  // OSAS's verdict outranks the date: a flagged permit is not "Valid" just
  // because it hasn't expired.
  if (flagged) {
    return { statusLabel: 'Needs resubmission', tone: 'danger', icon: 'lucide:file-warning', when: 'OSAS asked for a new file' }
  }
  if (!row.expires_at) {
    // Expiry is required on upload now, so a null one only happens on a
    // legacy row from before that — flag it rather than reading as settled.
    return { statusLabel: 'No expiration set', tone: 'warn', icon: 'lucide:calendar-x', when: `Uploaded ${since(row.uploaded_at)}` }
  }
  const now = Date.now()
  const soon = now + 30 * 24 * 60 * 60 * 1000
  const t = new Date(row.expires_at).getTime()
  if (t < now) return { statusLabel: 'Expired', tone: 'danger', icon: 'lucide:file-warning', when: `Expired ${permitDate(row.expires_at)}` }
  if (t < soon) return { statusLabel: 'Expiring soon', tone: 'warn', icon: 'lucide:calendar-clock', when: `Expires ${permitDate(row.expires_at)}` }
  return { statusLabel: 'Valid', tone: 'good', icon: 'lucide:check', when: `Expires ${permitDate(row.expires_at)}` }
}

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
        `name,accommodation_type,gender_policy,address,purok,barangay,city,description,status,lat,lng,appeal_used,accreditation_expires_at,accommodation_amenities(amenity),accommodation_policies(${POLICY_RULES}),accommodation_images(id,url,sort_order),accommodation_facilities(id,facility_type,access_scope,label,description,room_id,floor,status,accommodation_facility_rooms(room_id),accommodation_facility_images(id,url,sort_order)),accommodation_floors(floor_number,label),rooms(id,label,room_number,room_type,custom_room_type,floor,capacity,current_pax,monthly_rent,advance_months,deposit_months,rent_basis,status,${UTILITY_SELECT},room_images(id,url,sort_order))`,
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
    acc.genderPolicy = data.gender_policy || ''
    acc.address = data.address || ''
    acc.purok = data.purok || ''
    acc.barangay = data.barangay || ''
    acc.city = data.city || ''
    acc.description = data.description || ''
    acc.status = data.status
    acc.lat = data.lat
    acc.lng = data.lng
    acc.appealUsed = data.appeal_used
    acc.accreditationExpiresAt = data.accreditation_expires_at

    rules.amenities = ((data.accommodation_amenities ?? []) as { amenity: string }[]).map((a) => a.amenity).filter((a) => a in AMENITY_META)

    const policyRows = data.accommodation_policies as unknown
    const policy = (Array.isArray(policyRows) ? policyRows[0] : policyRows) as
      | {
          curfew_time: string | null
          quiet_hours: string | null
          visitor_policy: string | null
          cooking: boolean | null
          laundry: boolean | null
          pets: boolean | null
        }
      | null
    if (policy) {
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
      status: string
      accommodation_facility_rooms: { room_id: string }[] | null
      accommodation_facility_images: { id: string; url: string; sort_order: number | null }[] | null
    }[]).map((f) => ({
      id: f.id,
      facilityType: f.facility_type,
      label: f.label || '',
      description: f.description || '',
      roomId: f.room_id,
      floor: f.floor,
      status: f.status === 'under_repair' ? 'under_repair' : 'available',
      roomIds: (f.accommodation_facility_rooms ?? []).map((l) => l.room_id),
      images: [...(f.accommodation_facility_images ?? [])]
        .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
        .map((i) => ({ id: i.id, url: i.url })),
    }))

    rooms.value = ((data.rooms ?? []) as ({
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
    } & Partial<UtilityColumns>)[]).map((r) => {
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
        utilities: utilitiesFromRow(r),
        status: r.status,
        images: imgs,
        photoUrl: imgs[0]?.url ? resolveAsset(imgs[0].url, CARD) : '',
      }
    })

    const floorRows = (data.accommodation_floors ?? []) as { floor_number: number; label: string | null }[]
    trackedFloors.value = floorRows.map((f) => f.floor_number)
    floorLabels.value = Object.fromEntries(floorRows.filter((f) => f.label).map((f) => [f.floor_number, f.label as string]))

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
  | 'name' | 'accommodationType' | 'genderPolicy' | 'purok' | 'barangay' | 'city' | 'description'
  | 'curfewTime' | 'quietHours' | 'visitorPolicy'

/**
 * The location OSAS checked when it reviewed the listing (the map pin and the
 * address it fills). The database locks these once a listing leaves draft
 * (lock_verification_columns): free while it is a draft or sent back for
 * changes, a request to OSAS while it is live, and fixed otherwise. Everything
 * else — name, type, who it accepts, rooms, rent, photos, amenities, house
 * rules, the description — stays the landlord/landlady's to change. Permits go
 * through their own replacement rule (utils/permits.ts).
 */
const OSAS_CHECKED: ReadonlySet<FieldKey> = new Set(['purok', 'barangay', 'city'])
function fieldReview(key: FieldKey): 'free' | 'request' | 'locked' {
  if (!OSAS_CHECKED.has(key)) return 'free'
  if (acc.status === 'draft' || acc.status === 'needs_revision') return 'free'
  if (acc.status === 'accredited' || acc.status === 'delisted') return 'request'
  return 'locked'
}

const accreditationCard = ref<InstanceType<typeof AccreditationCard> | null>(null)

/** Sends a change to what OSAS checked; the listing keeps its values meanwhile. */
async function requestChange(changes: Record<string, unknown>): Promise<boolean> {
  const { error: requestError } = await supabase.rpc('request_details_change', {
    p_id: id,
    p_changes: changes as Database['public']['Functions']['request_details_change']['Args']['p_changes'],
  })
  if (requestError) {
    notify.error(errorMessage(requestError, 'Could not send this change to OSAS.'))
    return false
  }
  notify.success('Sent to OSAS. The listing shows the change once it is approved.')
  void accreditationCard.value?.reload()
  return true
}

/** Status and term only, after the card acts — not the whole page. */
async function refreshAccreditation() {
  const { data } = await supabase
    .from('accommodations')
    .select('status, appeal_used, accreditation_expires_at')
    .eq('id', id)
    .maybeSingle()
  if (!data) return
  acc.status = data.status
  acc.appealUsed = data.appeal_used
  acc.accreditationExpiresAt = data.accreditation_expires_at
}

const permitSheetOpen = ref(false)
const permitSheetType = ref('')
function openPermitSheet(type: string) {
  permitSheetType.value = type
  permitSheetOpen.value = true
}

// `options` is what a 'select' field offers; the sheet renders straight from it,
// so a second select needs an entry here rather than another branch in the template.
const FIELD_META: Record<FieldKey, { label: string; type: 'text' | 'select' | 'textarea' | 'time' | 'timerange'; table: 'accommodations' | 'accommodation_policies'; column: string; options?: Record<string, string> }> = {
  name: { label: 'Name', type: 'text', table: 'accommodations', column: 'name' },
  accommodationType: { label: 'Type', type: 'select', table: 'accommodations', column: 'accommodation_type', options: BUILDING_TYPE_LABEL },
  genderPolicy: { label: 'Accepts', type: 'select', table: 'accommodations', column: 'gender_policy', options: GENDER_POLICY_LABEL },
  purok: { label: 'Purok', type: 'text', table: 'accommodations', column: 'purok' },
  barangay: { label: 'Barangay', type: 'text', table: 'accommodations', column: 'barangay' },
  city: { label: 'City', type: 'text', table: 'accommodations', column: 'city' },
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
  if (meta.type === 'time') {
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
    let value: string | null
    if (meta.type === 'select') value = fieldDraft.value || null
    else if (meta.type === 'time') value = to12Hour(fieldDraft.value) || null
    else if (meta.type === 'timerange') {
      value =
        fieldDraft.value && fieldDraftTo.value
          ? `${to12Hour(fieldDraft.value)} – ${to12Hour(fieldDraftTo.value)}`
          : null
    } else value = fieldDraft.value.trim() || null

    const review = fieldReview(key)
    if (review === 'locked') return
    if (review === 'request') {
      if (await requestChange({ [meta.column]: value })) fieldDialogOpen.value = false
      return
    }

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
      case 'genderPolicy': acc.genderPolicy = String(value ?? ''); break
      case 'purok': acc.purok = String(value ?? ''); break
      case 'barangay': acc.barangay = String(value ?? ''); break
      case 'city': acc.city = String(value ?? ''); break
      case 'description': acc.description = String(value ?? ''); break
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
  roomNumber: '',
  /** Create only: how many identical rooms to add at once. */
  count: 1,
  roomType: 'solo',
  customRoomType: '',
  floor: null as number | null,
  capacity: 1,
  monthlyRent: 0,
  advanceMonths: null as number | null,
  depositMonths: null as number | null,
  rentBasis: 'room' as 'room' | 'person',
  utilities: emptyUtilities(),
})

// Bounds for the room form. A boarding-house room is not ₱1,000,000/month and
// does not sleep 400 people — an extra keystroke used to save either without a
// word, and the absurd figure then showed up in discovery and on the student's
// application summary.

/**
 * `max` on <input type="number"> is only a spinner and validity hint — a typed
 * or pasted value ignores it completely — so the ceiling has to be applied in
 * script. Done on blur (so the correction is visible while editing) and again in
 * the save payload, which is the path every write actually takes.
 */


const rentBasisHint = computed(() => {
  const rent = roomForm.monthlyRent || 0
  const cap = roomForm.capacity || 1
  if (cap <= 1) return ''
  return roomForm.rentBasis === 'person'
    ? `≈ ${formatPeso(rent * cap)}/mo total for the room`
    : `≈ ${formatPeso(rent / cap)}/mo per person`
})

// Floors a landlord/landlady has explicitly added, tracked independently of rooms
// (accommodation_floors) so an empty floor with no rooms yet still survives
// a reload instead of only existing while this page happens to be open.
const trackedFloors = ref<number[]>([])
/** Names landlords gave their floors ("Ground", "Annex"); the number is still the key. */
const floorLabels = ref<Record<number, string>>({})
function floorName(floor: number | null): string {
  if (floor === null) return 'No floor set'
  return floorLabels.value[floor] || `Floor ${floor}`
}

const floorNameOpen = ref(false)
const floorNameFor = ref<number | null>(null)
const floorNameDraft = ref('')
const savingFloorName = ref(false)
function openFloorName(floor: number) {
  floorNameFor.value = floor
  floorNameDraft.value = floorLabels.value[floor] || ''
  floorNameOpen.value = true
}
async function saveFloorName() {
  const floor = floorNameFor.value
  if (floor === null || savingFloorName.value) return
  const label = floorNameDraft.value.trim() || null
  savingFloorName.value = true
  try {
    // Upsert: a floor that only exists through its rooms has no row yet.
    const { error: saveError } = await supabase
      .from('accommodation_floors')
      .upsert({ accommodation_id: id, floor_number: floor, label }, { onConflict: 'accommodation_id,floor_number' })
    if (saveError) throw saveError
    if (!trackedFloors.value.includes(floor)) trackedFloors.value.push(floor)
    const next = { ...floorLabels.value }
    if (label) next[floor] = label
    else delete next[floor]
    floorLabels.value = next
    floorNameOpen.value = false
  } catch (e) {
    notify.error(errorMessage(e, 'Could not rename this floor.'))
  } finally {
    savingFloorName.value = false
  }
}

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
      label: floorName(floor),
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
  return nextRoomNumberOf(rooms.value, floor)
}
function nextFloorNumber(): number {
  return nextFloorNumberOf(rooms.value, trackedFloors.value)
}
const previewRoomNumber = computed(() => nextRoomNumber(roomForm.floor))
const activeRoomTenants = computed(() => rooms.value.find((r) => r.id === editingRoomId.value)?.currentPax ?? 0)

// Rooms added in one go. Ceiling keeps a typo (60 for 6) from flooding a floor.
const BULK_MAX = 20

/** The floors a room can go on: every floor shown on the Rooms tab. */
const floorOptions = computed(() => {
  const floors = roomsByFloor.value.map((g) => g.floor).filter((f): f is number => f !== null)
  if (roomForm.floor !== null && !floors.includes(roomForm.floor)) floors.push(roomForm.floor)
  return floors.sort((a, b) => a - b)
})

/**
 * The numbers a bulk add will use: the one in the form first, then the next
 * free ones on that floor, each counted as taken before the next is picked.
 */
const bulkNumbers = computed(() => {
  const count = clampNum(roomForm.count, 1, BULK_MAX)
  const taken: { floor: number | null; roomNumber: string | null }[] = [...rooms.value]
  const numbers: string[] = []
  for (let i = 0; i < count; i++) {
    const n = i === 0 && roomForm.roomNumber.trim() ? roomForm.roomNumber.trim() : nextRoomNumberOf(taken, roomForm.floor)
    numbers.push(n)
    taken.push({ floor: roomForm.floor, roomNumber: n })
  }
  return numbers
})

// A room's number follows its floor while it is still the auto kind ("204"):
// moving 104 to floor 2 makes it the next free 2xx, and moving it back
// restores 104. A hand-typed name ("A", "Annex 1") is left alone.
let numberBeforeEdit = ''
let floorBeforeEdit: number | null = null
function onRoomFloorChange() {
  if (roomDialogMode.value === 'edit' && roomForm.floor === floorBeforeEdit) {
    roomForm.roomNumber = numberBeforeEdit
    return
  }
  const others = rooms.value.filter((r) => r.id !== editingRoomId.value)
  if (!roomForm.roomNumber.trim() || /^\d{3,}$/.test(roomForm.roomNumber.trim())) {
    roomForm.roomNumber = nextRoomNumberOf(others, roomForm.floor)
  }
}

/** What stops this room being saved, or ''. */
function roomProblem(): string {
  const number = roomForm.roomNumber.trim()
  if (!number) return 'Give the room a number or name.'
  const clash = rooms.value.find((r) => r.id !== editingRoomId.value && sameRoomNumber(r.roomNumber, number))
  if (clash) return `Room ${number} already exists in this accommodation.`
  if (roomForm.roomType === 'custom' && !roomForm.customRoomType.trim()) return 'Name the custom room type.'
  if (!(Number(roomForm.monthlyRent) > 0)) return 'Enter the monthly rent.'
  return utilitiesProblem(roomForm.utilities)
}

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
    roomForm.roomNumber = room.roomNumber || ''
    numberBeforeEdit = roomForm.roomNumber
    floorBeforeEdit = room.floor
    roomForm.count = 1
    roomForm.roomType = room.roomType || 'solo'
    roomForm.customRoomType = room.customRoomType || ''
    roomForm.floor = room.floor
    roomForm.capacity = room.capacity ?? 1
    roomForm.monthlyRent = room.monthlyRent
    roomForm.advanceMonths = room.advanceMonths
    roomForm.depositMonths = room.depositMonths
    roomForm.rentBasis = room.rentBasis
    roomForm.utilities = utilitiesFromRow(utilityColumns(room.utilities))
    roomImages.value = [...room.images]
  } else {
    roomDialogMode.value = 'create'
    editingRoomId.value = ''
    activeRoomNumber.value = ''
    roomForm.roomType = 'solo'
    roomForm.customRoomType = ''
    roomForm.floor = floor ?? nextFloorNumber()
    roomForm.roomNumber = nextRoomNumber(roomForm.floor)
    roomForm.count = 1
    roomForm.capacity = 1
    roomForm.monthlyRent = 0
    roomForm.advanceMonths = null
    roomForm.depositMonths = null
    roomForm.rentBasis = 'room'
    roomForm.utilities = emptyUtilities()
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
      row.photoUrl = roomImages.value[0]?.url ? resolveAsset(roomImages.value[0].url, CARD) : ''
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
      row.photoUrl = roomImages.value[0]?.url ? resolveAsset(roomImages.value[0].url, CARD) : ''
    }
  } catch (e) {
    notify.error(errorMessage(e, 'Could not remove this photo.'))
  } finally {
    deletingRoomImage.value = ''
  }
}

async function confirmRoomBasics() {
  if (savingRoom.value) return
  const problem = roomProblem()
  if (problem) {
    notify.error(problem)
    return
  }
  savingRoom.value = true
  try {
    // Clamped here as well as on blur: a paste, an autofill, or a value typed
    // and submitted without the field ever losing focus all reach this line
    // without having passed the blur handler.
    const capacity = clampNum(roomForm.capacity, 1, CAPACITY_MAX)
    const payload = {
      label: null,
      room_number: roomForm.roomNumber.trim(),
      room_type: roomForm.roomType,
      custom_room_type: roomForm.roomType === 'custom' ? roomForm.customRoomType.trim() || null : null,
      floor: roomForm.floor,
      capacity,
      monthly_rent: clampNum(roomForm.monthlyRent, 0, RENT_MAX),
      advance_months: clampOptional(roomForm.advanceMonths, 0, MONTHS_MAX),
      deposit_months: clampOptional(roomForm.depositMonths, 0, MONTHS_MAX),
      rent_basis: capacity > 1 ? roomForm.rentBasis : ('room' as const),
      ...utilityColumns(roomForm.utilities),
    }

    if (editingRoomId.value) {
      const { error: updateError } = await supabase.from('rooms').update(payload).eq('id', editingRoomId.value)
      if (updateError) throw updateError
      const row = rooms.value.find((r) => r.id === editingRoomId.value)
      if (row) Object.assign(row, {
        roomNumber: payload.room_number,
        roomType: payload.room_type,
        customRoomType: payload.custom_room_type,
        floor: payload.floor,
        capacity: payload.capacity,
        monthlyRent: payload.monthly_rent,
        advanceMonths: payload.advance_months,
        depositMonths: payload.deposit_months,
        rentBasis: payload.rent_basis,
        utilities: utilitiesFromRow(payload),
      })
      activeRoomNumber.value = payload.room_number
      if (roomDialogMode.value === 'edit') {
        roomOpen.value = false
        notify.success('Room saved.')
      } else {
        roomStep.value = 2
      }
      return
    }

    // Several identical rooms: all created at once and open straight away —
    // there is no per-room photo step to finish first.
    const numbers = bulkNumbers.value
    if (numbers.length > 1) {
      const { data: created, error: insertError } = await supabase
        .from('rooms')
        .insert(numbers.map((n) => ({ ...payload, room_number: n, accommodation_id: id, status: 'available' as const })))
        .select('id,current_pax,status,room_number')
      if (insertError) throw insertError
      for (const c of created ?? []) rooms.value.push(roomFromPayload(payload, c))
      roomOpen.value = false
      notify.success(`${numbers.length} rooms added. Open each one to add its photos.`)
      return
    }

    // One room walks on through photos and facilities. It is saved now, so
    // photos have something to attach to, but stays unavailable — hidden from
    // students — until Done, rather than going live half-described.
    const { data: created, error: insertError } = await supabase
      .from('rooms')
      .insert({ ...payload, accommodation_id: id, status: 'maintenance' })
      .select('id,current_pax,status,room_number')
      .single()
    if (insertError) throw insertError
    rooms.value.push(roomFromPayload(payload, created))
    editingRoomId.value = created.id
    activeRoomNumber.value = created.room_number ?? payload.room_number
    activeRoomStatus.value = 'maintenance'
    roomImages.value = []
    roomStep.value = 2
  } catch (e) {
    const code = (e as { code?: string } | null)?.code
    notify.error(code === '23505' ? 'That room number is already used in this accommodation.' : errorMessage(e, 'Could not save this room.'))
  } finally {
    savingRoom.value = false
  }
}

type RoomPayload = UtilityColumns & {
  room_number: string
  room_type: string
  custom_room_type: string | null
  floor: number | null
  capacity: number
  monthly_rent: number
  advance_months: number | null
  deposit_months: number | null
  rent_basis: 'room' | 'person'
}

function roomFromPayload(
  payload: RoomPayload,
  created: { id: string; current_pax: number | null; status: string; room_number: string | null },
  images: Img[] = [],
): Room {
  return {
    id: created.id,
    label: null,
    roomNumber: created.room_number ?? payload.room_number,
    roomType: payload.room_type,
    customRoomType: payload.custom_room_type,
    floor: payload.floor,
    capacity: payload.capacity,
    currentPax: created.current_pax ?? 0,
    monthlyRent: payload.monthly_rent,
    advanceMonths: payload.advance_months,
    depositMonths: payload.deposit_months,
    rentBasis: payload.rent_basis,
    utilities: utilitiesFromRow(payload),
    status: created.status,
    images,
    photoUrl: images[0]?.url ? resolveAsset(images[0].url, CARD) : '',
  }
}

/** Done on a new room: it goes live now that it has been described. */
async function finishNewRoom() {
  if (editingRoomId.value && activeRoomStatus.value === 'maintenance') {
    togglingRoomStatus.value = true
    try {
      const { error: updateError } = await supabase.from('rooms').update({ status: 'available' }).eq('id', editingRoomId.value)
      if (updateError) throw updateError
      activeRoomStatus.value = 'available'
      const row = rooms.value.find((r) => r.id === editingRoomId.value)
      if (row) row.status = 'available'
    } catch (e) {
      notify.error(errorMessage(e, 'Could not open this room to students.'))
      return
    } finally {
      togglingRoomStatus.value = false
    }
  }
  roomOpen.value = false
  notify.success('Room added.')
}

// A new room closed before Done is kept, just not live — say so, or it looks
// like it vanished from Discover for no reason.
function onRoomDialogHide() {
  if (roomDialogMode.value === 'create' && editingRoomId.value && activeRoomStatus.value === 'maintenance') {
    notify.warning(`Room ${activeRoomNumber.value} was saved as unavailable. Open it and mark it available when it's ready.`)
  }
}

/** A copy of the open room on the same floor: next free number, same photos. */
async function duplicateRoom() {
  const source = rooms.value.find((r) => r.id === editingRoomId.value)
  if (!source || savingRoom.value) return
  savingRoom.value = true
  try {
    const payload: RoomPayload = {
      room_number: nextRoomNumber(source.floor),
      room_type: source.roomType || 'solo',
      custom_room_type: source.customRoomType,
      floor: source.floor,
      capacity: source.capacity ?? 1,
      monthly_rent: source.monthlyRent,
      advance_months: source.advanceMonths,
      deposit_months: source.depositMonths,
      rent_basis: source.rentBasis,
      ...utilityColumns(source.utilities),
    }
    const { data: created, error: insertError } = await supabase
      .from('rooms')
      .insert({ ...payload, label: null, accommodation_id: id, status: 'available' })
      .select('id,current_pax,status,room_number')
      .single()
    if (insertError) throw insertError

    let images: Img[] = []
    if (source.images.length) {
      const { data: imageRows, error: imagesError } = await supabase
        .from('room_images')
        .insert(source.images.map((img, i) => ({ room_id: created.id, url: img.url, sort_order: i })))
        .select('id,url')
      if (imagesError) throw imagesError
      images = imageRows ?? []
    }

    // Its private facilities (own bath, air-con) come along, photos included.
    for (const f of currentRoomFacilities.value) {
      const { data: fac, error: facError } = await supabase
        .from('accommodation_facilities')
        .insert({
          accommodation_id: id,
          facility_type: f.facilityType,
          access_scope: 'private',
          label: f.label || null,
          description: f.description || null,
          room_id: created.id,
          floor: null,
          status: f.status,
          sort_order: facilities.value.length,
        })
        .select('id')
        .single()
      if (facError) throw facError
      let facImages: Img[] = []
      if (f.images.length) {
        const { data: imgRows, error: imgError } = await supabase
          .from('accommodation_facility_images')
          .insert(f.images.map((img, i) => ({ facility_id: fac.id, url: img.url, sort_order: i })))
          .select('id,url')
        if (imgError) throw imgError
        facImages = imgRows ?? []
      }
      facilities.value.push({ ...f, id: fac.id, roomId: created.id, roomIds: [], images: facImages })
    }

    const copy = roomFromPayload(payload, created, images)
    rooms.value.push(copy)
    openRoomDialog(copy)
    notify.success(`Room ${copy.roomNumber} added as a copy.`)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not duplicate this room.'))
  } finally {
    savingRoom.value = false
  }
}

/** First room on an empty accommodation: make Floor 1, then open the form on it. */
async function addFirstRoom() {
  await addFloor()
  const floor = trackedFloors.value[trackedFloors.value.length - 1]
  if (floor !== undefined) openRoomDialog(null, floor)
}

// Occupied is set elsewhere (when a lease is active) and isn't something a
// landlord/landlady flips by hand here — this only toggles between the two states
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

<style scoped src="./AccommodationDetail.css"></style>
