<template>
  <q-page class="ad">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="120px" class="sk" />
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

          <div class="hero-content">
            <div class="head">
              <span class="head-name">{{ acc.name || 'Unnamed accommodation' }}</span>
              <span class="head-chip" :class="`head-chip--${STATUS_TONE[acc.status] || 'grey'}`">{{ STATUS_LABEL[acc.status] || acc.status }}</span>
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
          </div>
        </div>

        <div class="panel">
        <Transition name="tabslide" mode="out-in">
        <!-- OVERVIEW -->
        <section v-if="tab === 'overview'" key="overview" class="sec">
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
            <button type="button" class="view-row view-row--tap" @click="openFieldDialog('address')">
              <span class="view-label">Address</span>
              <span class="view-value">{{ acc.address || '—' }}</span>
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
            <button type="button" class="view-row view-row--tap" @click="openFieldDialog('totalRooms')">
              <span class="view-label">Total rooms</span>
              <span class="view-value">{{ acc.totalRooms ?? '—' }}</span>
              <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
            </button>
            <button type="button" class="view-row view-row--tap" @click="openFieldDialog('capacity')">
              <span class="view-label">Capacity</span>
              <span class="view-value">{{ acc.capacity ?? '—' }}</span>
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
        </section>

        <!-- ROOMS -->
        <section v-else-if="tab === 'rooms'" key="rooms" class="sec">
          <div class="sec-head">
            <h2 class="sec-title">Rooms ({{ rooms.length }})</h2>
            <button type="button" class="sec-link" @click="openRoomDialog(null)">Add room</button>
          </div>
          <div v-if="rooms.length" class="group">
            <button v-for="r in rooms" :key="r.id" type="button" class="room-row" @click="openRoomDialog(r)">
              <span class="room-shot" :class="{ 'room-shot--empty': !r.photoUrl }">
                <img v-if="r.photoUrl" :src="r.photoUrl" alt="" />
                <IconifyIcon v-else icon="lucide:image-off" width="18" />
              </span>
              <span class="room-body">
                <span class="room-name">{{ r.label || (r.roomNumber ? `Room ${r.roomNumber}` : 'Room') }}</span>
                <span class="room-sub">{{ roomTypeLabel(r.customRoomType || r.roomType) }} · {{ formatPeso(r.monthlyRent) }}/mo</span>
              </span>
              <span class="room-chip" :class="`room-chip--${ROOM_STATUS_TONE[r.status] || 'grey'}`">
                {{ r.currentPax }}/{{ r.capacity ?? '—' }}
              </span>
            </button>
          </div>
          <p v-else class="none">No rooms yet — add your first one.</p>
        </section>

        <!-- FACILITIES (shared only; private ones live inside each room) -->
        <section v-else-if="tab === 'facilities'" key="facilities" class="sec">
          <div class="sec-head">
            <h2 class="sec-title">Shared facilities ({{ sharedFacilities.length }})</h2>
            <button type="button" class="sec-link" @click="openFacilityDialog(null, 'shared', '')">Add facility</button>
          </div>
          <div v-if="sharedFacilities.length" class="group">
            <button
              v-for="f in sharedFacilities"
              :key="f.id"
              type="button"
              class="facility-row"
              @click="openFacilityDialog(f, 'shared', '')"
            >
              <span class="facility-icon"><IconifyIcon :icon="FACILITY_META[f.facilityType]?.icon || 'lucide:box'" width="16" /></span>
              <span class="facility-body">
                <span class="facility-name">{{ f.label || FACILITY_META[f.facilityType]?.label || f.facilityType }}</span>
                <span v-if="f.description" class="facility-sub">{{ f.description }}</span>
              </span>
            </button>
          </div>
          <p v-else class="none">No shared facilities yet — add your first one.</p>
        </section>

        <!-- SETTINGS -->
        <section v-else key="settings" class="sec">
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
            <button type="button" class="view-row view-row--tap" @click="openFieldDialog('advanceMonths')">
              <span class="view-label">Advance (months)</span>
              <span class="view-value">{{ rules.advanceMonths ?? '—' }}</span>
              <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
            </button>
            <button type="button" class="view-row view-row--tap" @click="openFieldDialog('depositMonths')">
              <span class="view-label">Deposit (months)</span>
              <span class="view-value">{{ rules.depositMonths ?? '—' }}</span>
              <IconifyIcon icon="lucide:chevron-right" width="14" class="view-chevron" />
            </button>
            <button type="button" class="view-row view-row--tap" @click="openFieldDialog('minStay')">
              <span class="view-label">Min. stay (months)</span>
              <span class="view-value">{{ rules.minStay ?? '—' }}</span>
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
          <p class="sec-hint">Accreditation depends on these staying current.</p>
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
              <label class="doc-upload">
                <IconifyIcon icon="lucide:upload" width="15" />
                <input type="file" accept="image/*,application/pdf" class="doc-file" @change="onDocSelected($event, d.type)" />
              </label>
            </div>
          </div>
          <span v-if="uploadingDoc" class="sec-hint">Uploading…</span>

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
        </section>
        </Transition>
        </div>
      </div>
    </div>

    <!-- COVER PHOTOS -->
    <q-dialog v-model="coverSheetOpen" position="bottom">
      <q-card class="room-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon icon="lucide:camera" width="18" /></span>
          <h3 class="room-sheet-title">Property photos</h3>
        </div>
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
      </q-card>
    </q-dialog>

    <!-- EDIT ONE FIELD (Overview + Settings both use this) -->
    <q-dialog v-model="fieldDialogOpen" position="bottom">
      <q-card class="room-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon icon="lucide:pencil" width="18" /></span>
          <h3 class="room-sheet-title">{{ editingField ? FIELD_META[editingField].label : '' }}</h3>
        </div>

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
        <input v-else v-model="fieldDraft" type="text" class="field-input" />

        <q-btn unelevated rounded no-caps color="primary" class="save-btn" :loading="savingField" label="Save" @click="saveField" />
      </q-card>
    </q-dialog>

    <!-- AMENITIES -->
    <q-dialog v-model="amenitiesDialogOpen" position="bottom">
      <q-card class="room-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon icon="lucide:sparkles" width="18" /></span>
          <h3 class="room-sheet-title">Amenities</h3>
        </div>
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
        <q-btn unelevated rounded no-caps color="primary" class="save-btn" :loading="savingAmenities" label="Save" @click="saveAmenities" />
      </q-card>
    </q-dialog>

    <!-- ADD/EDIT ROOM -->
    <q-dialog v-model="roomOpen" position="bottom">
      <q-card class="room-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon icon="lucide:bed-double" width="18" /></span>
          <h3 class="room-sheet-title">{{ editingRoomId ? 'Edit room' : 'Add room' }}</h3>
        </div>

        <label class="field">
          <span class="field-label">Label</span>
          <input v-model="roomForm.label" type="text" class="field-input" placeholder="e.g. Room 201" />
        </label>
        <div class="field-row">
          <label class="field">
            <span class="field-label">Room type</span>
            <select v-model="roomForm.roomType" class="field-input">
              <option v-for="(label, key) in ROOM_TYPE_LABEL" :key="key" :value="key">{{ label }}</option>
              <option value="custom">Custom</option>
            </select>
          </label>
          <label v-if="roomForm.roomType === 'custom'" class="field">
            <span class="field-label">Custom type name</span>
            <input v-model="roomForm.customRoomType" type="text" class="field-input" />
          </label>
        </div>
        <div class="field-row">
          <label class="field">
            <span class="field-label">Floor</span>
            <input v-model.number="roomForm.floor" type="number" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">Capacity</span>
            <input v-model.number="roomForm.capacity" type="number" min="1" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">Monthly rent</span>
            <div class="field-prefixed">
              <span class="field-prefix">₱</span>
              <input v-model.number="roomForm.monthlyRent" type="number" min="0" step="0.01" class="field-input field-input--prefixed" />
            </div>
          </label>
        </div>

        <template v-if="editingRoomId">
          <div class="sheet-section">
            <span class="field-label">Photos</span>
            <input type="file" accept="image/*" multiple class="file-input" @change="onRoomPhotosSelected" />
            <span v-if="uploadingRoomPhoto" class="sec-hint">Uploading…</span>
            <div v-if="roomImages.length" class="thumbs">
              <div v-for="img in roomImages" :key="img.id" class="thumb">
                <img :src="img.url" alt="" />
                <button type="button" class="thumb-x" :disabled="deletingRoomImage === img.id" @click="deleteRoomImage(img.id)">
                  <IconifyIcon icon="lucide:x" width="12" />
                </button>
              </div>
            </div>
          </div>

          <div class="sheet-section">
            <div class="sec-head">
              <span class="field-label">Private facilities</span>
              <button type="button" class="sec-link" @click="openFacilityDialog(null, 'private', editingRoomId)">Add</button>
            </div>
            <div v-if="currentRoomFacilities.length" class="group">
              <button
                v-for="f in currentRoomFacilities"
                :key="f.id"
                type="button"
                class="facility-row"
                @click="openFacilityDialog(f, 'private', editingRoomId)"
              >
                <span class="facility-icon"><IconifyIcon :icon="FACILITY_META[f.facilityType]?.icon || 'lucide:box'" width="16" /></span>
                <span class="facility-body">
                  <span class="facility-name">{{ f.label || FACILITY_META[f.facilityType]?.label || f.facilityType }}</span>
                  <span v-if="f.description" class="facility-sub">{{ f.description }}</span>
                </span>
              </button>
            </div>
            <p v-else class="none">No private facilities for this room yet.</p>
          </div>
        </template>

        <div class="room-sheet-actions">
          <button v-if="editingRoomId" type="button" class="room-del" :disabled="savingRoom" @click="deleteRoom">Delete</button>
          <q-btn unelevated rounded no-caps color="primary" class="save-btn" :loading="savingRoom" label="Save room" @click="saveRoom" />
        </div>
      </q-card>
    </q-dialog>

    <!-- ADD/EDIT FACILITY -->
    <q-dialog v-model="facilityOpen" position="bottom">
      <q-card class="room-sheet">
        <span class="sheet-grip" aria-hidden="true" />
        <div class="sheet-header">
          <span class="sheet-header-icon"><IconifyIcon :icon="FACILITY_META[facilityForm.facilityType]?.icon || 'lucide:box'" width="18" /></span>
          <h3 class="room-sheet-title">{{ editingFacilityId ? 'Edit facility' : 'Add facility' }}</h3>
        </div>

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
        <div class="room-sheet-actions">
          <button v-if="editingFacilityId" type="button" class="room-del" :disabled="savingFacility" @click="deleteFacility">Delete</button>
          <q-btn unelevated rounded no-caps color="primary" class="save-btn" :loading="savingFacility" label="Save facility" @click="saveFacility" />
        </div>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { reactive, ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatPeso } from '@/utils/format'
import { since } from '@/utils/notifications'
import { useNotify } from '@/utils/notify'
import { uploadDocument } from '@/utils/upload'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { AMENITY_META, AMENITY_KEYS, FACILITY_META, ROOM_TYPE_LABEL, BUILDING_TYPE_LABEL, roomTypeLabel } from '@/utils/listings'
import type { Database } from '@/types/database.gen'

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
  { key: 'facilities', label: 'Facilities' },
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
}

const route = useRoute()
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
const fieldDraftNum = ref<number | null>(null)

const acc = reactive({
  name: '',
  accommodationType: '',
  address: '',
  barangay: '',
  city: '',
  totalFloors: null as number | null,
  totalRooms: null as number | null,
  capacity: null as number | null,
  description: '',
  status: 'pending',
})
const rules = reactive({
  amenities: [] as string[],
  curfewTime: '',
  quietHours: '',
  visitorPolicy: '',
  advanceMonths: null as number | null,
  depositMonths: null as number | null,
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
const docRows = ref<{ doc_type: string; expires_at: string | null; uploaded_at: string; version: number }[]>([])
const uploadingDoc = ref(false)

const coverUrl = computed(() => (images.value[0]?.url ? resolveAsset(images.value[0].url) : ''))
const sharedFacilities = computed(() => facilities.value.filter((f) => !f.roomId))
const currentRoomFacilities = computed(() => facilities.value.filter((f) => f.roomId === editingRoomId.value))
const docs = computed(() =>
  DOC_TYPES.map((type) => {
    const row = docRows.value.find((d) => d.doc_type === type)
    if (!row) {
      return { type, statusLabel: 'Not submitted', tone: 'idle', icon: 'lucide:circle-dashed', when: '' }
    }
    if (!row.expires_at) {
      return { type, statusLabel: 'On file', tone: 'good', icon: 'lucide:check', when: `Uploaded ${since(row.uploaded_at)}` }
    }
    const now = Date.now()
    const soon = now + 30 * 24 * 60 * 60 * 1000
    const t = new Date(row.expires_at).getTime()
    if (t < now) return { type, statusLabel: 'Expired', tone: 'danger', icon: 'lucide:file-warning', when: `Expired ${since(row.expires_at)}` }
    if (t < soon) return { type, statusLabel: 'Expiring soon', tone: 'warn', icon: 'lucide:calendar-clock', when: `Expires ${since(row.expires_at)}` }
    return { type, statusLabel: 'Valid', tone: 'good', icon: 'lucide:check', when: `Expires ${since(row.expires_at)}` }
  }),
)

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
        'name,accommodation_type,address,barangay,city,total_floors,total_rooms,capacity,description,status,accommodation_amenities(amenity),accommodation_policies(advance_months,deposit_months,min_stay,curfew_time,quiet_hours,visitor_policy,cooking,laundry,pets),accommodation_images(id,url,sort_order),accommodation_facilities(id,facility_type,access_scope,label,description,room_id),rooms(id,label,room_number,room_type,custom_room_type,floor,capacity,current_pax,monthly_rent,status,room_images(id,url,sort_order))',
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
    acc.totalRooms = data.total_rooms
    acc.capacity = data.capacity
    acc.description = data.description || ''
    acc.status = data.status

    rules.amenities = ((data.accommodation_amenities ?? []) as { amenity: string }[]).map((a) => a.amenity)

    const policyRows = data.accommodation_policies as unknown
    const policy = (Array.isArray(policyRows) ? policyRows[0] : policyRows) as
      | {
          advance_months: number | null
          deposit_months: number | null
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
      rules.advanceMonths = policy.advance_months
      rules.depositMonths = policy.deposit_months
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
    }[]).map((f) => ({
      id: f.id,
      facilityType: f.facility_type,
      label: f.label || '',
      description: f.description || '',
      roomId: f.room_id,
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
        status: r.status,
        images: imgs,
        photoUrl: imgs[0]?.url ? resolveAsset(imgs[0].url) : '',
      }
    })

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
    .select('doc_type, expires_at, uploaded_at, version')
    .eq('accommodation_id', id)
    .order('version', { ascending: false })
  if (docError) throw docError

  const seen = new Set<string>()
  docRows.value = (data ?? []).filter((d) => {
    if (seen.has(d.doc_type)) return false
    seen.add(d.doc_type)
    return true
  })
}

async function onDocSelected(event: Event, docType: string) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  uploadingDoc.value = true
  try {
    const url = await uploadDocument(file, '', docType)
    const existing = docRows.value.find((d) => d.doc_type === docType)
    const { error: insertError } = await supabase.from('accommodation_documents').insert({
      accommodation_id: id,
      doc_type: docType,
      file_url: url,
      version: existing ? existing.version + 1 : 1,
    })
    if (insertError) throw insertError

    await loadDocs()
    notify.success('Uploaded.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload this document.'))
  } finally {
    uploadingDoc.value = false
    input.value = ''
  }
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
  | 'name' | 'accommodationType' | 'address' | 'barangay' | 'city' | 'totalFloors' | 'totalRooms' | 'capacity' | 'description'
  | 'curfewTime' | 'quietHours' | 'visitorPolicy' | 'advanceMonths' | 'depositMonths' | 'minStay'

const FIELD_META: Record<FieldKey, { label: string; type: 'text' | 'select' | 'number' | 'textarea'; table: 'accommodations' | 'accommodation_policies'; column: string }> = {
  name: { label: 'Name', type: 'text', table: 'accommodations', column: 'name' },
  accommodationType: { label: 'Type', type: 'select', table: 'accommodations', column: 'accommodation_type' },
  address: { label: 'Address', type: 'text', table: 'accommodations', column: 'address' },
  barangay: { label: 'Barangay', type: 'text', table: 'accommodations', column: 'barangay' },
  city: { label: 'City', type: 'text', table: 'accommodations', column: 'city' },
  totalFloors: { label: 'Floors', type: 'number', table: 'accommodations', column: 'total_floors' },
  totalRooms: { label: 'Total rooms', type: 'number', table: 'accommodations', column: 'total_rooms' },
  capacity: { label: 'Capacity', type: 'number', table: 'accommodations', column: 'capacity' },
  description: { label: 'Description', type: 'textarea', table: 'accommodations', column: 'description' },
  curfewTime: { label: 'Curfew', type: 'text', table: 'accommodation_policies', column: 'curfew_time' },
  quietHours: { label: 'Quiet hours', type: 'text', table: 'accommodation_policies', column: 'quiet_hours' },
  visitorPolicy: { label: 'Visitor policy', type: 'text', table: 'accommodation_policies', column: 'visitor_policy' },
  advanceMonths: { label: 'Advance (months)', type: 'number', table: 'accommodation_policies', column: 'advance_months' },
  depositMonths: { label: 'Deposit (months)', type: 'number', table: 'accommodation_policies', column: 'deposit_months' },
  minStay: { label: 'Min. stay (months)', type: 'number', table: 'accommodation_policies', column: 'min_stay' },
}

function openFieldDialog(key: FieldKey) {
  editingField.value = key
  const meta = FIELD_META[key]
  if (meta.type === 'number') {
    fieldDraftNum.value = (key in acc ? acc[key as keyof typeof acc] : rules[key as keyof typeof rules]) as number | null
  } else {
    const raw = key in acc ? acc[key as keyof typeof acc] : rules[key as keyof typeof rules]
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
    else value = fieldDraft.value.trim() || null

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
      case 'address': acc.address = String(value ?? ''); break
      case 'barangay': acc.barangay = String(value ?? ''); break
      case 'city': acc.city = String(value ?? ''); break
      case 'description': acc.description = String(value ?? ''); break
      case 'totalFloors': acc.totalFloors = value as number | null; break
      case 'totalRooms': acc.totalRooms = value as number | null; break
      case 'capacity': acc.capacity = value as number | null; break
      case 'curfewTime': rules.curfewTime = String(value ?? ''); break
      case 'quietHours': rules.quietHours = String(value ?? ''); break
      case 'visitorPolicy': rules.visitorPolicy = String(value ?? ''); break
      case 'advanceMonths': rules.advanceMonths = value as number | null; break
      case 'depositMonths': rules.depositMonths = value as number | null; break
      case 'minStay': rules.minStay = value as number | null; break
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
const savingRoom = ref(false)
const editingRoomId = ref('')
const roomImages = ref<Img[]>([])
const uploadingRoomPhoto = ref(false)
const deletingRoomImage = ref('')
const roomForm = reactive({
  label: '',
  roomType: 'solo',
  customRoomType: '',
  floor: null as number | null,
  capacity: 1,
  monthlyRent: 0,
})

function openRoomDialog(room: Room | null) {
  if (room) {
    editingRoomId.value = room.id
    roomForm.label = room.label || ''
    roomForm.roomType = room.roomType || 'solo'
    roomForm.customRoomType = room.customRoomType || ''
    roomForm.floor = room.floor
    roomForm.capacity = room.capacity ?? 1
    roomForm.monthlyRent = room.monthlyRent
    roomImages.value = [...room.images]
  } else {
    editingRoomId.value = ''
    roomForm.label = ''
    roomForm.roomType = 'solo'
    roomForm.customRoomType = ''
    roomForm.floor = null
    roomForm.capacity = 1
    roomForm.monthlyRent = 0
    roomImages.value = []
  }
  roomOpen.value = true
}

async function onRoomPhotosSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files ?? [])
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
    input.value = ''
  }
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

async function saveRoom() {
  if (savingRoom.value) return
  savingRoom.value = true
  try {
    const payload = {
      label: roomForm.label.trim() || null,
      room_type: roomForm.roomType,
      custom_room_type: roomForm.roomType === 'custom' ? roomForm.customRoomType.trim() || null : null,
      floor: roomForm.floor,
      capacity: roomForm.capacity,
      monthly_rent: roomForm.monthlyRent,
    }

    if (editingRoomId.value) {
      const { error: updateError } = await supabase.from('rooms').update(payload).eq('id', editingRoomId.value)
      if (updateError) throw updateError
      const row = rooms.value.find((r) => r.id === editingRoomId.value)
      if (row) Object.assign(row, {
        label: payload.label,
        roomType: payload.room_type,
        customRoomType: payload.custom_room_type,
        floor: payload.floor,
        capacity: payload.capacity,
        monthlyRent: payload.monthly_rent,
      })
    } else {
      const { data: created, error: insertError } = await supabase
        .from('rooms')
        .insert({ ...payload, accommodation_id: id, status: 'available' })
        .select('id,current_pax,status')
        .single()
      if (insertError) throw insertError
      rooms.value.push({
        id: created.id,
        label: payload.label,
        roomNumber: null,
        roomType: payload.room_type,
        customRoomType: payload.custom_room_type,
        floor: payload.floor,
        capacity: payload.capacity,
        currentPax: created.current_pax ?? 0,
        monthlyRent: payload.monthly_rent,
        status: created.status,
        images: [],
        photoUrl: '',
      })
    }

    roomOpen.value = false
    notify.success('Room saved.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not save this room.'))
  } finally {
    savingRoom.value = false
  }
}

async function deleteRoom() {
  if (savingRoom.value || !editingRoomId.value) return
  savingRoom.value = true
  try {
    // leases.room_id (and payments/concerns/tickets hanging off those leases)
    // cascade-delete with the room — block if this room has ANY lease history,
    // past or present, rather than silently wiping a tenant's records.
    const { count, error: countError } = await supabase
      .from('leases')
      .select('id', { count: 'exact', head: true })
      .eq('room_id', editingRoomId.value)
    if (countError) throw countError
    if (count) {
      notify.error('This room has lease history and can\'t be deleted. Consider renaming or repurposing it instead.')
      return
    }

    const { error: deleteError } = await supabase.from('rooms').delete().eq('id', editingRoomId.value)
    if (deleteError) throw deleteError
    rooms.value = rooms.value.filter((r) => r.id !== editingRoomId.value)
    roomOpen.value = false
    notify.success('Room removed.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not remove this room.'))
  } finally {
    savingRoom.value = false
  }
}

const facilityOpen = ref(false)
const savingFacility = ref(false)
const editingFacilityId = ref('')
const facilityScope = ref<'shared' | 'private'>('shared')
const facilityRoomId = ref('')
const facilityForm = reactive({
  facilityType: 'bathroom',
  label: '',
  description: '',
})

function openFacilityDialog(f: Facility | null, scope: 'shared' | 'private', roomId: string) {
  facilityScope.value = scope
  facilityRoomId.value = roomId
  if (f) {
    editingFacilityId.value = f.id
    facilityForm.facilityType = f.facilityType
    facilityForm.label = f.label
    facilityForm.description = f.description
  } else {
    editingFacilityId.value = ''
    facilityForm.facilityType = 'bathroom'
    facilityForm.label = ''
    facilityForm.description = ''
  }
  facilityOpen.value = true
}

async function saveFacility() {
  if (savingFacility.value) return
  savingFacility.value = true
  try {
    const roomId = facilityScope.value === 'private' ? facilityRoomId.value : null
    const payload = {
      facility_type: facilityForm.facilityType,
      access_scope: facilityScope.value,
      label: facilityForm.label.trim() || null,
      description: facilityForm.description.trim() || null,
      room_id: roomId,
    }

    if (editingFacilityId.value) {
      const { error: updateError } = await supabase
        .from('accommodation_facilities')
        .update(payload)
        .eq('id', editingFacilityId.value)
      if (updateError) throw updateError
      const row = facilities.value.find((f) => f.id === editingFacilityId.value)
      if (row) Object.assign(row, {
        facilityType: payload.facility_type,
        label: payload.label || '',
        description: payload.description || '',
        roomId: payload.room_id,
      })
    } else {
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
      })
    }

    facilityOpen.value = false
    notify.success('Facility saved.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not save this facility.'))
  } finally {
    savingFacility.value = false
  }
}

async function deleteFacility() {
  if (savingFacility.value || !editingFacilityId.value) return
  savingFacility.value = true
  try {
    const { error: deleteError } = await supabase.from('accommodation_facilities').delete().eq('id', editingFacilityId.value)
    if (deleteError) throw deleteError
    facilities.value = facilities.value.filter((f) => f.id !== editingFacilityId.value)
    facilityOpen.value = false
    notify.success('Facility removed.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not remove this facility.'))
  } finally {
    savingFacility.value = false
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

/* Cover hero */
.hero {
  position: sticky;
  top: 0;
  z-index: 10;
  flex: 0 0 auto;
  height: 300px;
  background: var(--m-bg);
}
/* Square, not rounded — the rounded "card" look lives on .panel below;
   the photo itself stays a plain full-bleed rectangle. Still needs its own
   clipping box (not .hero itself) so the tabs, which deliberately overflow
   1px past the bottom edge to touch the panel below, aren't clipped too. */
.hero-media {
  position: absolute;
  inset: 0;
  overflow: hidden;
  background: var(--m-primary-soft);
}
.hero-img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
.hero-media--empty { background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%); }
.hero-empty { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; }
.hero-scrim {
  position: absolute;
  inset: 0;
  background: linear-gradient(to bottom, rgba(0, 0, 0, 0.08) 0%, rgba(0, 0, 0, 0.6) 100%);
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
.hero-content {
  position: relative;
  z-index: 1;
  display: flex;
  height: 100%;
  flex-direction: column;
  justify-content: space-between;
  padding: 14px 0 0;
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
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 0 var(--m-page-gutter);
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
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
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
.tabs {
  display: flex;
  gap: 4px;
  padding: 0 var(--m-page-gutter);
}
.tab {
  min-height: 40px;
  padding: 0 16px;
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-bottom: none;
  border-radius: 10px 10px 0 0;
  background: rgba(23, 32, 42, 0.35);
  color: rgba(255, 255, 255, 0.85);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  transition: background-color 0.15s ease, color 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
.tab--on {
  border-color: var(--m-border);
  background: var(--m-surface);
  color: var(--m-primary-dark);
}

.panel {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  padding: 14px var(--m-page-gutter);
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}

.tabslide-enter-active,
.tabslide-leave-active {
  transition: transform 0.2s ease, opacity 0.2s ease;
}
.tabslide-enter-from {
  transform: translateX(18px);
  opacity: 0;
}
.tabslide-leave-to {
  transform: translateX(-18px);
  opacity: 0;
}

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
  flex: 1;
  min-width: 0;
  flex-direction: column;
  gap: 4px;
}
.field-row {
  display: flex;
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
.doc-upload {
  position: relative;
  display: grid;
  width: 30px;
  height: 30px;
  flex: 0 0 30px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  color: var(--m-primary-dark);
  cursor: pointer;
}
.doc-file {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  cursor: pointer;
}

.file-input {
  font-size: 13px;
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
</style>
