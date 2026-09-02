<template>
  <q-page class="property-page">
    <main class="property-shell">
      <section v-if="loading" class="surface loading-card" aria-busy="true">
        <div v-for="index in 5" :key="index" class="skeleton" aria-hidden="true" />
        <span class="sr-only">Loading accommodation</span>
      </section>

      <section v-else-if="error" class="surface state-panel state-panel--error" role="alert">
        <span class="state-icon">
          <IconifyIcon icon="lucide:cloud-alert" width="24" />
        </span>
        <h2>Unable to load this accommodation</h2>
        <p>{{ error }}</p>
        <button type="button" class="primary-action" @click="loadProperty">
          <IconifyIcon icon="lucide:refresh-cw" width="17" /> Retry
        </button>
      </section>

      <template v-else-if="property">
        <section
          class="property-gallery"
          :class="{ 'property-gallery--with-photo': images.length }"
          aria-label="Accommodation photos"
        >
          <img
            v-if="images.length"
            :src="images[activeImageIndex]"
            :alt="`${property.name} photo ${activeImageIndex + 1}`"
          />
          <div v-else class="gallery-placeholder">
            <IconifyIcon icon="lucide:building-2" width="32" />
            <span>No exterior photos yet</span>
          </div>
          <div v-if="images.length > 1" class="gallery-controls">
            <button
              v-for="(_, index) in images"
              :key="index"
              type="button"
              :class="{ active: index === activeImageIndex }"
              :aria-label="`Show photo ${index + 1}`"
              @click="activeImageIndex = index"
            />
          </div>
        </section>

        <section class="tab-workspace" aria-label="Accommodation sections">
          <q-tabs
            v-model="activeTab"
            dense
            no-caps
            align="left"
            class="folder-tabs"
          >
            <q-tab
              v-for="tab in tabs"
              :key="tab.value"
              :name="tab.value"
              :label="tab.label"
              class="folder-tab"
            />
          </q-tabs>

        <q-tab-panels v-model="activeTab" animated class="tab-card">
          <q-tab-panel name="overview" class="q-pa-none">
            <section class="content-stack">
              <section class="overview-hero">
                <div class="hero-copy">
                  <div>
                    <span class="eyebrow">{{ property.accommodationType || 'Accommodation' }}</span>
                    <h2>{{ property.name }}</h2>
                    <p>
                      <IconifyIcon icon="lucide:map-pin" width="15" />
                      {{ property.address || 'Address not set' }}
                    </p>
                  </div>
                </div>
              </section>

              <section class="occupancy-card" aria-label="Occupancy overview">
                <div class="occupancy-card__heading">
                  <div>
                    <span>Occupancy</span>
                    <strong>{{ occupiedSpaces }} <small>/ {{ totalCapacity }} residents</small></strong>
                  </div>
                  <span class="availability-count">{{ availableSpaces }} available</span>
                </div>
                <div class="occupancy-meter" aria-hidden="true">
                  <span :style="{ width: `${occupancyPercent}%` }" />
                </div>
                <div class="occupancy-card__footer">
                  <span>{{ rooms.length }} {{ rooms.length === 1 ? 'room' : 'rooms' }} configured</span>
                  <button type="button" @click="activeTab = 'rooms'">Manage rooms</button>
                </div>
              </section>

              <section v-if="!roomManagementUnlocked" class="setup-callout">
                <span><IconifyIcon icon="lucide:shield-check" width="19" /></span>
                <div>
                  <strong>Rooms unlock after OSAS approval</strong>
                  <p>
                    Your accommodation is awaiting verification. You can still update listing details
                    while OSAS reviews your permits.
                  </p>
                </div>
              </section>

              <section v-else-if="rooms.length === 0" class="setup-callout">
                <span><IconifyIcon icon="lucide:circle-alert" width="19" /></span>
                <div>
                  <strong>Add rentable rooms</strong>
                  <p>Students cannot apply until at least one room is available.</p>
                </div>
                <button type="button" @click="openRoomDialog()">Add room</button>
              </section>

              <section class="overview-section">
                <div class="section-heading">
                  <div>
                    <h2>At a glance</h2>
                    <p>The essentials students see before applying.</p>
                  </div>
                </div>
                <dl class="overview-details">
                  <div v-for="row in listingRows" :key="row.label">
                    <dt>{{ row.label }}</dt>
                    <dd>
                      <span
                        v-if="row.badgeTone"
                        class="status-badge"
                        :class="`status-badge--${row.badgeTone}`"
                      >
                        {{ row.value }}
                      </span>
                      <template v-else>{{ row.value }}</template>
                    </dd>
                  </div>
                </dl>
                <p v-if="property.description" class="description-copy">{{ property.description }}</p>
              </section>

              <section class="overview-section">
                <div class="section-heading">
                  <div>
                    <h2>Amenities</h2>
                    <p>Included in the accommodation.</p>
                  </div>
                </div>
                <div v-if="property.amenities.length" class="chip-list">
                  <span v-for="amenity in property.amenities" :key="amenity">{{ amenity }}</span>
                </div>
                <p v-else class="empty-copy">No amenities listed.</p>
              </section>

            </section>
          </q-tab-panel>

          <q-tab-panel name="rooms" class="q-pa-none">
            <section class="content-stack">
              <section v-if="!roomManagementUnlocked" class="surface state-panel room-lock-panel">
                <span class="state-icon"><IconifyIcon icon="lucide:lock-keyhole" width="24" /></span>
                <h2>Room setup is locked</h2>
                <p>
                  OSAS must verify this accommodation first. After approval, you can add room photos,
                  prices, and private facilities.
                </p>
                <span class="status-badge" :class="`status-badge--${property.statusTone}`">
                  {{ property.statusLabel }}
                </span>
              </section>

              <template v-else>
                <div class="section-heading">
                  <div>
                    <h2>Rooms</h2>
                    <p>Availability, rent, and private amenities by room.</p>
                  </div>
                  <button type="button" class="primary-action" @click="openRoomDialog()">
                    <IconifyIcon icon="lucide:plus" width="17" /> Add room
                  </button>
                </div>

                <div v-if="rooms.length" class="surface room-list">
                  <article v-for="room in rooms" :key="room.id" class="room-row">
                    <span class="room-icon" :class="`room-icon--${roomTone(room)}`">
                      <IconifyIcon icon="lucide:door-open" width="20" />
                    </span>
                    <div class="room-copy">
                      <strong>{{ roomName(room) }}</strong>
                      <span>
                        {{ roomTypeLabel(room) }} - {{ room.currentPax }} of {{ room.capacity }} spaces occupied
                      </span>
                      <small>
                        {{ room.monthlyRent === null ? 'Rent not set' : `${formatPeso(room.monthlyRent)} / month` }}
                        <template v-if="roomFacilities(room.id).length">
                          - {{ roomFacilities(room.id).map(facilityLabel).join(', ') }}
                        </template>
                      </small>
                    </div>
                    <div class="room-side">
                      <span class="status-badge" :class="`status-badge--${roomTone(room)}`">
                        {{ roomStatus(room) }}
                      </span>
                      <button type="button" :aria-label="`Edit ${roomName(room)}`" @click="openRoomDialog(room)">
                        Edit
                      </button>
                    </div>
                  </article>
                </div>

                <section v-else class="surface state-panel">
                  <span class="state-icon"><IconifyIcon icon="lucide:door-open" width="24" /></span>
                  <h2>No rooms configured</h2>
                  <p>Add the rooms students can rent, including photos and private facilities.</p>
                  <button type="button" class="primary-action" @click="openRoomDialog()">
                    <IconifyIcon icon="lucide:plus" width="17" /> Add room
                  </button>
                </section>

                <section class="shared-spaces-section">
                  <div class="section-heading">
                    <div>
                      <h2>Shared spaces</h2>
                      <p>Facilities every resident can use.</p>
                    </div>
                    <button type="button" class="secondary-action" @click="openSharedFacilitiesDialog">
                      <IconifyIcon icon="lucide:lamp-desk" width="16" /> Manage
                    </button>
                  </div>
                  <div v-if="sharedFacilities.length" class="shared-spaces-list">
                    <span v-for="facility in sharedFacilities" :key="facility.id">{{ facilityLabel(facility) }}</span>
                  </div>
                  <button v-else type="button" class="shared-spaces-empty" @click="openSharedFacilitiesDialog">
                    <IconifyIcon icon="lucide:plus" width="17" /> Add shared facilities
                  </button>
                </section>
              </template>
            </section>
          </q-tab-panel>

          <q-tab-panel name="settings" class="q-pa-none">
            <section class="content-stack">
              <div class="section-heading">
                <div>
                  <h2>Accommodation settings</h2>
                  <p>Keep your listing accurate and ready for students.</p>
                </div>
              </div>

              <section class="settings-group" aria-labelledby="listing-settings">
                <h3 id="listing-settings">Listing</h3>
                <button type="button" class="settings-row" @click="openSettingsDialog">
                  <span class="settings-row__icon"><IconifyIcon icon="lucide:building-2" width="19" /></span>
                  <span class="settings-row__content">
                    <strong>Listing profile</strong>
                    <small>{{ property.name }} · {{ property.accommodationType || 'Type not set' }}</small>
                  </span>
                  <IconifyIcon class="settings-row__arrow" icon="lucide:chevron-right" width="19" />
                </button>
                <button type="button" class="settings-row" @click="openSettingsDialog">
                  <span class="settings-row__icon settings-row__icon--people"><IconifyIcon icon="lucide:users-round" width="19" /></span>
                  <span class="settings-row__content">
                    <strong>Resident eligibility</strong>
                    <small>{{ genderLabel(property.genderPolicy) }}</small>
                  </span>
                  <IconifyIcon class="settings-row__arrow" icon="lucide:chevron-right" width="19" />
                </button>
              </section>

              <section class="settings-group" aria-labelledby="location-settings">
                <h3 id="location-settings">Location</h3>
                <button type="button" class="settings-row" @click="openSettingsDialog">
                  <span class="settings-row__icon settings-row__icon--location"><IconifyIcon icon="lucide:map-pin" width="19" /></span>
                  <span class="settings-row__content">
                    <strong>Address and map pin</strong>
                    <small>{{ property.address || 'Location not set' }}</small>
                  </span>
                  <IconifyIcon class="settings-row__arrow" icon="lucide:chevron-right" width="19" />
                </button>
              </section>

              <section class="settings-group" aria-labelledby="listing-status-settings">
                <h3 id="listing-status-settings">Listing status</h3>
                <div class="settings-row settings-row--static">
                  <span class="settings-row__icon settings-row__icon--status"><IconifyIcon icon="lucide:shield-check" width="19" /></span>
                  <span class="settings-row__content">
                    <strong>OSAS verification</strong>
                    <small>Room setup unlocks after accreditation.</small>
                  </span>
                  <span class="status-badge" :class="`status-badge--${property.statusTone}`">{{ property.statusLabel }}</span>
                </div>
              </section>
            </section>
          </q-tab-panel>
        </q-tab-panels>
        </section>
      </template>
    </main>

    <q-dialog v-model="roomDialog" position="bottom">
      <q-card class="sheet-card sheet-card--scroll">
        <q-card-section class="sheet-heading">
          <div>
            <h2>{{ editingRoomId ? 'Edit room' : 'Add room' }}</h2>
            <p>Set up everything students need to see for this room.</p>
          </div>
          <q-btn flat round dense icon="close" aria-label="Close room form" @click="closeRoomDialog" />
        </q-card-section>

        <q-card-section class="sheet-form">
          <label>
            Room name <span>*</span>
            <q-input
              v-model="roomForm.label"
              outlined
              dense
              placeholder="e.g. Room 101"
              :error="!!roomError"
              :error-message="roomError"
            />
          </label>

          <label>
            Room type <span>*</span>
            <q-select
              v-model="roomForm.roomType"
              :options="roomTypeOptions"
              outlined
              dense
              emit-value
              map-options
              @update:model-value="syncRoomCapacity"
            />
          </label>

          <label v-if="roomForm.roomType === 'custom'">
            Describe the room type <span>*</span>
            <q-input v-model="roomForm.customRoomType" outlined dense placeholder="e.g. Loft room" />
          </label>

          <div class="form-grid">
            <label v-if="needsManualCapacity(roomForm.roomType)">
              Capacity <span>*</span>
              <q-input v-model.number="roomForm.capacity" type="number" min="1" outlined dense />
            </label>

            <div v-else class="capacity-note">
              <IconifyIcon icon="lucide:users-round" width="17" />
              <span>
                <strong>{{ roomForm.capacity }}</strong>
                {{ roomForm.capacity === 1 ? 'tenant' : 'tenants' }} based on room type.
              </span>
            </div>

            <label>
              Monthly rent <span>*</span>
              <q-input v-model.number="roomForm.monthlyRent" type="number" min="0" prefix="P" outlined dense />
            </label>
          </div>

          <label>
            Status <span>*</span>
            <q-select
              v-model="roomForm.status"
              :options="roomStatusOptions"
              outlined
              dense
              emit-value
              map-options
            />
          </label>

          <section class="form-subsection">
            <div>
              <h3>Room photos</h3>
              <p>Show the sleeping area and room condition.</p>
            </div>
            <PhotoPicker
              label="Add room photos"
              hint="JPG, PNG, or WebP. Up to 5 MB each."
              :photos="roomForm.images"
              @select="selectPhotos($event, roomForm.images)"
              @remove="removePhoto(roomForm.images, $event)"
            />
          </section>

          <section class="form-subsection">
            <div class="subsection-heading">
              <div>
                <h3>Private facilities</h3>
                <p>Only spaces exclusive to this room.</p>
              </div>
              <button type="button" class="text-action" @click="addRoomFacility">
                <IconifyIcon icon="lucide:plus" width="16" /> Add
              </button>
            </div>

            <article
              v-for="(facility, index) in roomForm.privateFacilities"
              :key="facility.id"
              class="draft-facility"
            >
              <div class="subsection-heading">
                <strong>Private facility {{ index + 1 }}</strong>
                <button
                  type="button"
                  class="remove-action"
                  :aria-label="`Remove private facility ${index + 1}`"
                  @click="removeDraftFacility(roomForm.privateFacilities, index)"
                >
                  <IconifyIcon icon="lucide:trash-2" width="16" />
                </button>
              </div>

              <label>
                Facility type <span>*</span>
                <q-select
                  v-model="facility.type"
                  :options="facilityTypes"
                  outlined
                  dense
                  emit-value
                  map-options
                />
              </label>

              <label>
                Label <span class="optional">Optional</span>
                <q-input v-model="facility.label" outlined dense placeholder="e.g. Private bathroom" />
              </label>

              <label>
                Description <span class="optional">Optional</span>
                <q-input v-model="facility.description" outlined dense type="textarea" rows="2" />
              </label>

              <PhotoPicker
                label="Facility photos"
                hint="Photos are optional."
                :photos="facility.images"
                @select="selectPhotos($event, facility.images)"
                @remove="removePhoto(facility.images, $event)"
              />
            </article>
          </section>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" @click="closeRoomDialog" />
          <q-btn
            no-caps
            unelevated
            class="primary-action"
            :loading="savingRoom"
            :label="editingRoomId ? 'Save room' : 'Add room'"
            @click="saveRoom"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="sharedFacilitiesDialog" position="bottom">
      <q-card class="sheet-card sheet-card--scroll">
        <q-card-section class="sheet-heading">
          <div>
            <h2>Shared facilities</h2>
            <p>List spaces available to every resident.</p>
          </div>
          <q-btn flat round dense icon="close" aria-label="Close shared facilities" @click="closeSharedFacilitiesDialog" />
        </q-card-section>
        <q-card-section class="sheet-form">
          <section class="form-subsection form-subsection--first">
            <div class="subsection-heading">
              <div>
                <h3>Resident spaces</h3>
                <p>Add photos and details that help students understand the property.</p>
              </div>
              <button type="button" class="text-action" @click="addSharedFacility"><IconifyIcon icon="lucide:plus" width="16" /> Add</button>
            </div>
            <article v-for="(facility, index) in sharedFacilitiesForm" :key="facility.id" class="draft-facility">
              <div class="subsection-heading">
                <strong>Shared facility {{ index + 1 }}</strong>
                <button type="button" class="remove-action" :aria-label="`Remove shared facility ${index + 1}`" @click="removeDraftFacility(sharedFacilitiesForm, index)"><IconifyIcon icon="lucide:trash-2" width="16" /></button>
              </div>
              <label>Facility type <span>*</span><q-select v-model="facility.type" :options="facilityTypes" outlined dense emit-value map-options /></label>
              <label>Label <span class="optional">Optional</span><q-input v-model="facility.label" outlined dense placeholder="e.g. Ground-floor kitchen" /></label>
              <label>Description <span class="optional">Optional</span><q-input v-model="facility.description" outlined dense type="textarea" rows="2" /></label>
              <PhotoPicker label="Facility photos" hint="Photos are optional." :photos="facility.images" @select="selectPhotos($event, facility.images)" @remove="removePhoto(facility.images, $event)" />
            </article>
            <p v-if="!sharedFacilitiesForm.length" class="empty-copy">No shared facilities listed yet.</p>
          </section>
        </q-card-section>
        <q-card-actions align="right"><q-btn flat no-caps label="Cancel" @click="closeSharedFacilitiesDialog" /><q-btn no-caps unelevated class="primary-action" :loading="savingSharedFacilities" label="Save facilities" @click="saveSharedFacilities" /></q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="settingsDialog" position="bottom" @hide="teardownLocationMap">
      <q-card class="sheet-card sheet-card--scroll">
        <q-card-section class="sheet-heading">
          <div>
            <h2>Edit accommodation</h2>
            <p>Update listing details, eligibility, and location.</p>
          </div>
          <q-btn
            flat
            round
            dense
            icon="close"
            aria-label="Close accommodation form"
            @click="closeSettingsDialog"
          />
        </q-card-section>

        <q-card-section class="sheet-form">
          <label>
            Accommodation name <span>*</span>
            <q-input v-model="settingsForm.name" outlined dense />
          </label>

          <label>
            Description
            <q-input v-model="settingsForm.description" type="textarea" rows="3" outlined />
          </label>

          <label>
            Accommodation type
            <q-select v-model="settingsForm.accommodationType" :options="accommodationTypeOptions" outlined dense />
          </label>

          <label>
            Who can stay
            <q-select
              v-model="settingsForm.genderPolicy"
              :options="genderOptions"
              outlined
              dense
              emit-value
              map-options
            />
          </label>

          <section class="form-subsection">
            <div>
              <h3>Location</h3>
              <p>Search the address, then place the pin on the accommodation.</p>
            </div>
            <label>Address <q-input v-model="settingsForm.address" outlined dense placeholder="Search address or landmark" @update:model-value="searchLocation" /></label>
            <div v-if="locationSearchLoading" class="map-status">Searching Mapbox...</div>
            <div v-else-if="locationResults.length" class="location-results">
              <button v-for="result in locationResults" :key="result.id" type="button" @click="selectLocation(result)"><IconifyIcon icon="lucide:map-pin" width="16" /><span><strong>{{ result.name }}</strong><small>{{ result.address }}</small></span></button>
            </div>
            <div ref="locationMap" class="location-map" aria-label="Map used to set the accommodation location" />
            <p class="map-hint">Tap the map to adjust the pin precisely.</p>
          </section>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" @click="closeSettingsDialog" />
          <q-btn
            no-caps
            unelevated
            class="primary-action"
            :loading="savingSettings"
            label="Save changes"
            @click="saveSettings"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useQuasar } from 'quasar'
import { useRoute, useRouter } from 'vue-router'
import mapboxgl from 'mapbox-gl'
import 'mapbox-gl/dist/mapbox-gl.css'
import { supabase } from '@/shared/utils/supabase'
import { formatPeso } from '@/shared/utils/format'
import { uploadDocument } from '@/shared/utils/upload'
import PhotoPicker from '@/modules/landlord/components/AccommodationPhotoPicker.vue'

type Tab = 'overview' | 'rooms' | 'settings'
type Tone = 'success' | 'warning' | 'danger' | 'neutral'

interface Room {
  id: string
  roomNumber: string | null
  label: string | null
  roomType: string | null
  customRoomType: string | null
  capacity: number
  currentPax: number
  monthlyRent: number | null
  status: string
}

interface Facility {
  id: string
  roomId: string | null
  type: string
  label: string | null
  description: string | null
  images: string[]
}

interface StoredImage {
  id: string
  roomId?: string
  facilityId?: string
  url: string
}

interface DraftPhoto {
  file: File | null
  preview: string
  id?: string
}

interface DraftFacility {
  id: string
  type: string
  label: string
  description: string
  images: DraftPhoto[]
}

interface LocationResult {
  id: string
  name: string
  address: string
  longitude: number
  latitude: number
}

interface Property {
  id: string
  name: string
  address: string
  latitude: number | null
  longitude: number | null
  description: string
  accommodationType: string
  genderPolicy: string
  amenities: string[]
  rules: string[]
  statusLabel: string
  statusTone: Tone
  roomManagementUnlocked: boolean
}

const tabs: { label: string; value: Tab }[] = [
  { label: 'Overview', value: 'overview' },
  { label: 'Rooms', value: 'rooms' },
  { label: 'Settings', value: 'settings' },
]

const roomStatusOptions = [
  { label: 'Available', value: 'available' },
  { label: 'Occupied', value: 'occupied' },
  { label: 'Maintenance', value: 'maintenance' },
]

const roomTypeOptions = [
  { label: 'Solo room', value: 'solo' },
  { label: 'Duo room', value: 'duo' },
  { label: 'Triple room', value: 'triple' },
  { label: 'Bedspace', value: 'bedspace' },
  { label: 'Studio', value: 'studio' },
  { label: 'Other', value: 'custom' },
]

const accommodationTypeOptions = [
  'boarding_house',
  'residence_hall',
  'apartment_building',
  'apartment_unit',
  'house',
  'condominium_unit',
  'bedspace_facility',
]

const genderOptions = [
  { label: 'Boys only', value: 'boys' },
  { label: 'Girls only', value: 'girls' },
  { label: 'Co-ed', value: 'coed' },
]

const facilityTypes = [
  { label: 'Bathroom / CR', value: 'bathroom' },
  { label: 'Kitchen / kitchenette', value: 'kitchen' },
  { label: 'Laundry area', value: 'laundry' },
  { label: 'Balcony', value: 'balcony' },
  { label: 'Common area', value: 'common_area' },
  { label: 'Study area', value: 'study_area' },
  { label: 'Parking', value: 'parking' },
  { label: 'Other', value: 'other' },
]

const fixedRoomCapacity: Record<string, number> = {
  solo: 1,
  duo: 2,
  triple: 3,
}

const $q = useQuasar()
const route = useRoute()
const router = useRouter()

const loading = ref(true)
const error = ref<string | null>(null)
const property = ref<Property | null>(null)
const rooms = ref<Room[]>([])
const facilities = ref<Facility[]>([])
const images = ref<string[]>([])
const roomImages = ref<StoredImage[]>([])
const facilityImages = ref<StoredImage[]>([])

const activeImageIndex = ref(0)
const activeTab = ref<Tab>('overview')

const roomDialog = ref(false)
const settingsDialog = ref(false)
const sharedFacilitiesDialog = ref(false)
const savingRoom = ref(false)
const savingSettings = ref(false)
const savingSharedFacilities = ref(false)
const editingRoomId = ref<string | null>(null)
const roomError = ref('')
const sharedFacilitiesForm = ref<DraftFacility[]>([])
const locationMap = ref<HTMLElement | null>(null)
const locationResults = ref<LocationResult[]>([])
const locationSearchLoading = ref(false)
let map: mapboxgl.Map | null = null
let locationMarker: mapboxgl.Marker | null = null
let locationSearchTimer: ReturnType<typeof setTimeout> | undefined

const roomForm = ref({
  label: '',
  roomType: '',
  customRoomType: '',
  capacity: 0,
  monthlyRent: 0,
  status: 'available',
  images: [] as DraftPhoto[],
  privateFacilities: [] as DraftFacility[],
})

const settingsForm = ref({
  name: '',
  address: '',
  description: '',
  accommodationType: '',
  genderPolicy: '',
  latitude: null as number | null,
  longitude: null as number | null,
})

const totalCapacity = computed(() => rooms.value.reduce((sum, room) => sum + room.capacity, 0))
const occupiedSpaces = computed(() => rooms.value.reduce((sum, room) => sum + room.currentPax, 0))
const availableSpaces = computed(() => Math.max(totalCapacity.value - occupiedSpaces.value, 0))
const occupancyPercent = computed(() => totalCapacity.value ? Math.round((occupiedSpaces.value / totalCapacity.value) * 100) : 0)
const sharedFacilities = computed(() => facilities.value.filter((facility) => !facility.roomId))
const roomManagementUnlocked = computed(() => property.value?.roomManagementUnlocked === true)

const listingRows = computed(() => [
  { label: 'Who can stay', value: genderLabel(property.value?.genderPolicy || ''), badgeTone: null as Tone | null },
  { label: 'Accreditation', value: property.value?.statusLabel || 'Not set', badgeTone: property.value?.statusTone || 'neutral' },
])

function statusPresentation(status: string | null, accreditation: string | null): { label: string; tone: Tone } {
  const accreditationValue = (accreditation || '').toLowerCase()
  const statusValue = (status || '').toLowerCase()

  if (
    ['rejected', 'delisted', 'expired'].includes(accreditationValue)
    || ['rejected', 'delisted'].includes(statusValue)
  ) {
    return {
      label: accreditationValue === 'delisted' || statusValue === 'delisted' ? 'Delisted' : 'Rejected',
      tone: 'danger',
    }
  }

  if (
    ['pending', 'reviewing', 'submitted'].includes(accreditationValue)
    || ['pending', 'reviewing'].includes(statusValue)
  ) {
    return {
      label: accreditationValue === 'reviewing' || statusValue === 'reviewing' ? 'In review' : 'Pending',
      tone: 'warning',
    }
  }

  if (
    ['accredited', 'approved', 'active'].includes(accreditationValue)
    || ['active', 'accredited'].includes(statusValue)
  ) {
    return { label: 'Active', tone: 'success' }
  }

  return { label: 'Not set', tone: 'neutral' }
}

function createId(): string {
  return globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`
}

function genderLabel(value: string): string {
  return genderOptions.find((option) => option.value === value)?.label || 'Not set'
}

function facilityLabel(facility: Pick<Facility | DraftFacility, 'type' | 'label'>): string {
  return facility.label
    || facility.type.replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function roomFacilities(roomId: string): Facility[] {
  return facilities.value.filter((facility) => facility.roomId === roomId)
}

function roomTypeLabel(room: Room): string {
  if (room.roomType === 'custom') return room.customRoomType || 'Other room'
  if (!room.roomType) return 'Type not set'
  const suffix = room.roomType === 'bedspace' ? '' : ' room'
  return room.roomType.replace(/\b\w/g, (letter) => letter.toUpperCase()) + suffix
}

function roomName(room: Room): string {
  return room.label || (room.roomNumber ? `Room ${room.roomNumber}` : 'Unnamed room')
}

function roomTone(room: Room): Tone {
  if (room.status === 'maintenance') return 'danger'
  if (room.status === 'available' && room.currentPax < room.capacity) return 'success'
  if (room.status === 'occupied' || room.currentPax >= room.capacity) return 'warning'
  return 'neutral'
}

function roomStatus(room: Room): string {
  if (room.status === 'maintenance') return 'Maintenance'
  if (room.currentPax >= room.capacity && room.capacity > 0) return 'Full'
  if (room.status === 'available') return 'Available'
  return room.status ? room.status.charAt(0).toUpperCase() + room.status.slice(1) : 'Not set'
}

function newDraftFacility(): DraftFacility {
  return { id: createId(), type: '', label: '', description: '', images: [] }
}

function needsManualCapacity(roomType: string): boolean {
  return ['bedspace', 'studio', 'custom'].includes(roomType)
}

function syncRoomCapacity(roomType: string): void {
  roomForm.value.capacity = fixedRoomCapacity[roomType] ?? 0
  if (roomType !== 'custom') roomForm.value.customRoomType = ''
}

function selectPhotos(event: Event, target: DraftPhoto[]): void {
  const input = event.target as HTMLInputElement

  for (const file of Array.from(input.files || [])) {
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type) || file.size > 5 * 1024 * 1024) {
      $q.notify({
        type: 'negative',
        message: 'Use JPG, PNG, or WebP images up to 5 MB.',
        position: 'top',
      })
      continue
    }

    target.push({ file, preview: URL.createObjectURL(file) })
  }

  input.value = ''
}

function removePhoto(target: DraftPhoto[], index: number): void {
  const [photo] = target.splice(index, 1)
  if (photo?.file) URL.revokeObjectURL(photo.preview)
}

function clearDraftPhotos(photos: DraftPhoto[]): void {
  photos.filter((photo) => photo.file).forEach((photo) => URL.revokeObjectURL(photo.preview))
}

function removeDraftFacility(target: DraftFacility[], index: number): void {
  const [facility] = target.splice(index, 1)
  if (facility) clearDraftPhotos(facility.images)
}

function closeRoomDialog(): void {
  clearDraftPhotos(roomForm.value.images)
  roomForm.value.privateFacilities.forEach((facility) => clearDraftPhotos(facility.images))
  roomDialog.value = false
}

function closeSettingsDialog(): void {
  locationResults.value = []
  settingsDialog.value = false
}

function teardownLocationMap(): void {
  map?.remove()
  map = null
  locationMarker = null
}

function addRoomFacility(): void {
  roomForm.value.privateFacilities.push(newDraftFacility())
}

function addSharedFacility(): void {
  sharedFacilitiesForm.value.push(newDraftFacility())
}

function storedPhotos(source: StoredImage[], key: 'roomId' | 'facilityId', id: string): DraftPhoto[] {
  return source
    .filter((image) => image[key] === id)
    .map((image) => ({ id: image.id, file: null, preview: image.url }))
}

async function loadProperty(): Promise<void> {
  loading.value = true
  error.value = null

  try {
    const id = String(route.params.id)
    const { data: authData, error: authError } = await supabase.auth.getUser()
    if (authError) throw authError

    if (!authData.user) {
      void router.push('/login')
      return
    }

    const { data: propertyRow, error: propertyError } = await (supabase as any)
      .from('accommodations')
      .select('id, name, business_name, address, description, accommodation_type, status, accreditation_status, lat, lng')
      .eq('id', id)
      .eq('accommodation_manager_id', authData.user.id)
      .maybeSingle()

    if (propertyError) throw propertyError
    if (!propertyRow) throw new Error('Accommodation not found or you do not have access to it.')

    const [roomResult, amenityResult, policyResult, imageResult, facilityResult] = await Promise.all([
      (supabase as any)
        .from('rooms')
        .select('id, room_number, label, room_type, custom_room_type, capacity, current_pax, monthly_rent, status')
        .eq('accommodation_id', id)
        .order('room_number'),
      (supabase as any).from('accommodation_amenities').select('amenity').eq('accommodation_id', id),
      (supabase as any)
        .from('accommodation_policies')
        .select('house_rules_json')
        .eq('accommodation_id', id)
        .maybeSingle(),
      (supabase as any)
        .from('accommodation_images')
        .select('url, sort_order')
        .eq('accommodation_id', id)
        .order('sort_order'),
      (supabase as any)
        .from('accommodation_facilities')
        .select('id, room_id, facility_type, label, description')
        .eq('accommodation_id', id),
    ])

    if (roomResult.error) throw roomResult.error
    if (amenityResult.error) throw amenityResult.error
    if (policyResult.error) throw policyResult.error
    if (imageResult.error) throw imageResult.error
    if (facilityResult.error) throw facilityResult.error

    const roomRows = roomResult.data ?? []
    const roomIds = roomRows.map((room: any) => room.id)
    const facilityRows = facilityResult.data ?? []
    const facilityIds = facilityRows.map((facility: any) => facility.id)

    const [roomImageResult, facilityImageResult] = await Promise.all([
      roomIds.length
        ? (supabase as any)
          .from('room_images')
          .select('id, room_id, url, sort_order')
          .in('room_id', roomIds)
          .order('sort_order')
        : Promise.resolve({ data: [], error: null }),
      facilityIds.length
        ? (supabase as any)
          .from('accommodation_facility_images')
          .select('id, facility_id, url, sort_order')
          .in('facility_id', facilityIds)
          .order('sort_order')
        : Promise.resolve({ data: [], error: null }),
    ])

    if (roomImageResult.error) throw roomImageResult.error
    if (facilityImageResult.error) throw facilityImageResult.error

    const policy =
      policyResult.data?.house_rules_json && typeof policyResult.data.house_rules_json === 'object'
        ? policyResult.data.house_rules_json
        : {}

    const status = statusPresentation(propertyRow.status, propertyRow.accreditation_status)

    property.value = {
      id,
      name: propertyRow.business_name || propertyRow.name || 'Unnamed accommodation',
      address: propertyRow.address || '',
      latitude: propertyRow.lat ?? null,
      longitude: propertyRow.lng ?? null,
      description: propertyRow.description || '',
      accommodationType: propertyRow.accommodation_type || '',
      genderPolicy: (policy as any).gender_policy || '',
      amenities: (amenityResult.data ?? []).map((item: any) => item.amenity),
      rules: Array.isArray((policy as any).rules) ? (policy as any).rules : [],
      statusLabel: status.label,
      statusTone: status.tone,
      roomManagementUnlocked: propertyRow.status === 'accredited',
    }

    rooms.value = roomRows.map((room: any) => ({
      id: room.id,
      roomNumber: room.room_number,
      label: room.label,
      roomType: room.room_type,
      customRoomType: room.custom_room_type,
      capacity: Number(room.capacity) || 0,
      currentPax: Number(room.current_pax) || 0,
      monthlyRent: room.monthly_rent === null ? null : Number(room.monthly_rent),
      status: room.status || '',
    }))

    images.value = (imageResult.data ?? []).map((image: any) => image.url)
    facilities.value = facilityRows.map((facility: any) => ({
      id: facility.id,
      roomId: facility.room_id,
      type: facility.facility_type,
      label: facility.label,
      description: facility.description,
      images: (facilityImageResult.data ?? [])
        .filter((image: any) => image.facility_id === facility.id)
        .map((image: any) => image.url),
    }))

    roomImages.value = (roomImageResult.data ?? []).map((image: any) => ({
      id: image.id,
      roomId: image.room_id,
      url: image.url,
    }))

    facilityImages.value = (facilityImageResult.data ?? []).map((image: any) => ({
      id: image.id,
      facilityId: image.facility_id,
      url: image.url,
    }))

    if (activeImageIndex.value >= images.value.length) activeImageIndex.value = 0
  } catch (reason) {
    error.value = reason instanceof Error ? reason.message : 'Unable to load the accommodation.'
  } finally {
    loading.value = false
  }
}

function openRoomDialog(room?: Room): void {
  if (!roomManagementUnlocked.value) {
    $q.notify({
      type: 'warning',
      message: 'Rooms unlock after OSAS approves this accommodation.',
      position: 'top',
    })
    return
  }

  roomError.value = ''
  editingRoomId.value = room?.id || null

  roomForm.value = room
    ? {
      label: room.label || room.roomNumber || '',
      roomType: room.roomType || '',
      customRoomType: room.customRoomType || '',
      capacity: room.capacity || 0,
      monthlyRent: room.monthlyRent || 0,
      status: room.status || 'available',
      images: storedPhotos(roomImages.value, 'roomId', room.id),
      privateFacilities: roomFacilities(room.id).map((facility) => ({
        id: facility.id,
        type: facility.type,
        label: facility.label || '',
        description: facility.description || '',
        images: storedPhotos(facilityImages.value, 'facilityId', facility.id),
      })),
    }
    : {
      label: '',
      roomType: '',
      customRoomType: '',
      capacity: 0,
      monthlyRent: 0,
      status: 'available',
      images: [],
      privateFacilities: [],
    }

  roomDialog.value = true
}

async function syncTotals(): Promise<void> {
  if (!property.value) return

  const { data, error: roomFetchError } = await (supabase as any)
    .from('rooms')
    .select('capacity')
    .eq('accommodation_id', property.value.id)

  if (roomFetchError) throw roomFetchError

  const rows = data ?? []
  const { error: updateError } = await (supabase as any)
    .from('accommodations')
    .update({
      total_rooms: rows.length,
      capacity: rows.reduce((sum: number, room: any) => sum + (Number(room.capacity) || 0), 0) || null,
    })
    .eq('id', property.value.id)

  if (updateError) throw updateError
}

async function saveDraftFacilities(
  drafts: DraftFacility[],
  roomId: string | null,
  scope: 'shared' | 'private',
): Promise<void> {
  if (!property.value) return

  const { data: authData } = await supabase.auth.getUser()
  if (!authData.user) throw new Error('Your session has expired.')

  const existing = facilities.value.filter((facility) => facility.roomId === roomId)
  const retainedIds = new Set(
    drafts
      .filter((draft) => existing.some((facility) => facility.id === draft.id))
      .map((draft) => draft.id),
  )

  const deletedIds = existing
    .filter((facility) => !retainedIds.has(facility.id))
    .map((facility) => facility.id)

  if (deletedIds.length) {
    const { error: deleteError } = await (supabase as any)
      .from('accommodation_facilities')
      .delete()
      .in('id', deletedIds)

    if (deleteError) throw deleteError
  }

  for (let index = 0; index < drafts.length; index += 1) {
    const draft = drafts[index]
    if (!draft) continue

    if (!draft.type || (draft.type === 'other' && !draft.label.trim())) {
      throw new Error('Choose a type for every facility. Other facilities need a label.')
    }

    let facilityId = draft.id
    const exists = existing.some((facility) => facility.id === draft.id)

    if (exists) {
      const { error: updateError } = await (supabase as any)
        .from('accommodation_facilities')
        .update({
          facility_type: draft.type,
          label: draft.label.trim() || null,
          description: draft.description.trim() || null,
          sort_order: index,
        })
        .eq('id', draft.id)

      if (updateError) throw updateError
    } else {
      const { data, error: insertError } = await (supabase as any)
        .from('accommodation_facilities')
        .insert({
          accommodation_id: property.value.id,
          room_id: roomId,
          facility_type: draft.type,
          access_scope: scope,
          label: draft.label.trim() || null,
          description: draft.description.trim() || null,
          sort_order: index,
        })
        .select('id')
        .single()

      if (insertError) throw insertError
      facilityId = data.id
    }

    const keptImageIds = new Set(
      draft.images.map((photo) => photo.id).filter((id): id is string => Boolean(id)),
    )

    const staleImageIds = facilityImages.value
      .filter((image) => image.facilityId === facilityId && !keptImageIds.has(image.id))
      .map((image) => image.id)

    if (staleImageIds.length) {
      const { error: deleteImageError } = await (supabase as any)
        .from('accommodation_facility_images')
        .delete()
        .in('id', staleImageIds)

      if (deleteImageError) throw deleteImageError
    }

    for (let photoIndex = 0; photoIndex < draft.images.length; photoIndex += 1) {
      const photo = draft.images[photoIndex]
      if (!photo?.file) continue

      const url = await uploadDocument(
        photo.file,
        authData.user.id,
        `${scope}_facility_${index + 1}_${photoIndex + 1}`,
      )

      const { error: imageError } = await (supabase as any)
        .from('accommodation_facility_images')
        .insert({
          facility_id: facilityId,
          url,
          sort_order: photoIndex,
        })

      if (imageError) throw imageError
    }
  }
}

async function saveRoom(): Promise<void> {
  if (!property.value) return

  if (!roomManagementUnlocked.value) {
    roomError.value = 'OSAS approval is required before rooms can be changed.'
    return
  }

  const type = roomForm.value.roomType
  const enforcedCapacity = fixedRoomCapacity[type] ?? Number(roomForm.value.capacity)

  if (
    !roomForm.value.label.trim()
    || !type
    || (type === 'custom' && !roomForm.value.customRoomType.trim())
    || !Number.isFinite(enforcedCapacity)
    || enforcedCapacity < 1
    || !Number.isFinite(roomForm.value.monthlyRent)
    || roomForm.value.monthlyRent < 0
  ) {
    roomError.value = 'Enter a room name, type, capacity of at least 1, and a valid monthly rent.'
    return
  }

  savingRoom.value = true
  roomError.value = ''

  try {
    const payload = {
      label: roomForm.value.label.trim(),
      room_number: roomForm.value.label.trim(),
      room_type: type,
      custom_room_type: type === 'custom' ? roomForm.value.customRoomType.trim() : null,
      capacity: enforcedCapacity,
      monthly_rent: Number(roomForm.value.monthlyRent),
      status: roomForm.value.status,
    }

    const result = editingRoomId.value
      ? await (supabase as any).from('rooms').update(payload).eq('id', editingRoomId.value).select('id').single()
      : await (supabase as any)
        .from('rooms')
        .insert({ ...payload, accommodation_id: property.value.id, current_pax: 0 })
        .select('id')
        .single()

    if (result.error) throw result.error
    const roomId = result.data.id

    const { data: authData } = await supabase.auth.getUser()
    if (!authData.user) throw new Error('Your session has expired.')

    const keptImageIds = new Set(
      roomForm.value.images.map((photo) => photo.id).filter((id): id is string => Boolean(id)),
    )

    const staleImageIds = roomImages.value
      .filter((image) => image.roomId === roomId && !keptImageIds.has(image.id))
      .map((image) => image.id)

    if (staleImageIds.length) {
      const { error: deleteImageError } = await (supabase as any)
        .from('room_images')
        .delete()
        .in('id', staleImageIds)

      if (deleteImageError) throw deleteImageError
    }

    for (let index = 0; index < roomForm.value.images.length; index += 1) {
      const photo = roomForm.value.images[index]
      if (!photo?.file) continue

      const url = await uploadDocument(photo.file, authData.user.id, `room_${index + 1}`)
      const { error: imageError } = await (supabase as any)
        .from('room_images')
        .insert({ room_id: roomId, url, sort_order: index })

      if (imageError) throw imageError
    }

    await saveDraftFacilities(roomForm.value.privateFacilities, roomId, 'private')
    await syncTotals()
    roomDialog.value = false

    $q.notify({
      type: 'positive',
      message: editingRoomId.value ? 'Room updated.' : 'Room added.',
      position: 'top',
    })

    await loadProperty()
  } catch (reason) {
    roomError.value = reason instanceof Error ? reason.message : 'Unable to save room.'
  } finally {
    savingRoom.value = false
  }
}

function openSettingsDialog(): void {
  if (!property.value) return

  settingsForm.value = {
    name: property.value.name,
    address: property.value.address,
    description: property.value.description,
    accommodationType: property.value.accommodationType,
    genderPolicy: property.value.genderPolicy,
    latitude: property.value.latitude,
    longitude: property.value.longitude,
  }

  settingsDialog.value = true
  void nextTick(() => initializeLocationMap())
}

function openSharedFacilitiesDialog(): void {
  if (!roomManagementUnlocked.value) return

  sharedFacilitiesForm.value = sharedFacilities.value.map((facility) => ({
      id: facility.id,
      type: facility.type,
      label: facility.label || '',
      description: facility.description || '',
      images: storedPhotos(facilityImages.value, 'facilityId', facility.id),
    }))

  sharedFacilitiesDialog.value = true
}

function setLocationPin(longitude: number, latitude: number, zoom = 16): void {
  settingsForm.value.longitude = longitude
  settingsForm.value.latitude = latitude

  if (!map) return
  if (!locationMarker) locationMarker = new mapboxgl.Marker({ color: '#00897b' })
  locationMarker.setLngLat([longitude, latitude]).addTo(map)
  map.flyTo({ center: [longitude, latitude], zoom, essential: true })
}

function initializeLocationMap(): void {
  if (!locationMap.value || map) return

  mapboxgl.accessToken = import.meta.env.VITE_MAPBOX_TOKEN || ''
  if (!mapboxgl.accessToken) return

  const longitude = settingsForm.value.longitude ?? 121.720
  const latitude = settingsForm.value.latitude ?? 16.710
  map = new mapboxgl.Map({
    container: locationMap.value,
    style: 'mapbox://styles/mapbox/streets-v12',
    center: [longitude, latitude],
    zoom: settingsForm.value.longitude == null ? 13 : 16,
  })
  map.addControl(new mapboxgl.NavigationControl({ showCompass: false }), 'top-right')
  map.on('load', () => {
    if (settingsForm.value.longitude != null && settingsForm.value.latitude != null) {
      setLocationPin(settingsForm.value.longitude, settingsForm.value.latitude)
    }
  })
  map.on('click', (event: mapboxgl.MapMouseEvent) => setLocationPin(event.lngLat.lng, event.lngLat.lat))
}

function searchLocation(): void {
  if (locationSearchTimer) clearTimeout(locationSearchTimer)
  const query = settingsForm.value.address.trim()
  locationResults.value = []
  if (query.length < 3 || !import.meta.env.VITE_MAPBOX_TOKEN) return

  locationSearchTimer = setTimeout(async () => {
    locationSearchLoading.value = true
    try {
      const response = await fetch(
        `https://api.mapbox.com/search/geocode/v6/forward?q=${encodeURIComponent(query)}&limit=4&access_token=${import.meta.env.VITE_MAPBOX_TOKEN}`,
      )
      if (!response.ok) throw new Error('Mapbox search failed.')
      const payload = await response.json()
      locationResults.value = (payload.features ?? []).flatMap((feature: any) => {
        const coordinates = feature.geometry?.coordinates
        if (!Array.isArray(coordinates) || coordinates.length < 2) return []
        return [{
          id: feature.id,
          name: feature.properties?.name || feature.place_formatted || 'Selected location',
          address: feature.place_formatted || feature.properties?.full_address || '',
          longitude: coordinates[0],
          latitude: coordinates[1],
        }]
      })
    } catch {
      locationResults.value = []
    } finally {
      locationSearchLoading.value = false
    }
  }, 350)
}

function selectLocation(result: LocationResult): void {
  settingsForm.value.address = result.address || result.name
  locationResults.value = []
  setLocationPin(result.longitude, result.latitude)
}

function closeSharedFacilitiesDialog(): void {
  sharedFacilitiesForm.value.forEach((facility) => clearDraftPhotos(facility.images))
  sharedFacilitiesDialog.value = false
}

async function saveSharedFacilities(): Promise<void> {
  if (!property.value) return

  savingSharedFacilities.value = true
  try {
    await saveDraftFacilities(sharedFacilitiesForm.value, null, 'shared')
    sharedFacilitiesDialog.value = false
    $q.notify({ type: 'positive', message: 'Shared facilities saved.', position: 'top' })
    await loadProperty()
  } catch (reason) {
    $q.notify({ type: 'negative', message: reason instanceof Error ? reason.message : 'Unable to save shared facilities.', position: 'top' })
  } finally {
    savingSharedFacilities.value = false
  }
}

async function saveSettings(): Promise<void> {
  if (!property.value || !settingsForm.value.name.trim()) return

  savingSettings.value = true

  try {
    const { error: propertyError } = await (supabase as any)
      .from('accommodations')
      .update({
        name: settingsForm.value.name.trim(),
        address: settingsForm.value.address.trim() || null,
        lat: settingsForm.value.latitude,
        lng: settingsForm.value.longitude,
        description: settingsForm.value.description.trim() || null,
        accommodation_type: settingsForm.value.accommodationType || null,
      })
      .eq('id', property.value.id)

    if (propertyError) throw propertyError

    const { data: existingPolicy, error: policyReadError } = await (supabase as any)
      .from('accommodation_policies')
      .select('house_rules_json')
      .eq('accommodation_id', property.value.id)
      .maybeSingle()

    if (policyReadError) throw policyReadError

    const rawPolicy = existingPolicy?.house_rules_json
    const nextPolicy = {
      ...(rawPolicy && typeof rawPolicy === 'object' && !Array.isArray(rawPolicy) ? rawPolicy : {}),
      rules: property.value.rules,
      gender_policy: settingsForm.value.genderPolicy || null,
    }

    const policyResult = existingPolicy
      ? await (supabase as any)
        .from('accommodation_policies')
        .update({ house_rules_json: nextPolicy })
        .eq('accommodation_id', property.value.id)
      : await (supabase as any)
        .from('accommodation_policies')
        .insert({ accommodation_id: property.value.id, house_rules_json: nextPolicy })

    if (policyResult.error) throw policyResult.error

    settingsDialog.value = false
    $q.notify({ type: 'positive', message: 'Accommodation settings saved.', position: 'top' })

    await loadProperty()
  } catch (reason) {
    $q.notify({
      type: 'negative',
      message: reason instanceof Error ? reason.message : 'Unable to save accommodation settings.',
      position: 'top',
    })
  } finally {
    savingSettings.value = false
  }
}

onMounted(() => {
  void loadProperty()
})

onBeforeUnmount(() => {
  if (locationSearchTimer) clearTimeout(locationSearchTimer)
  map?.remove()
})
</script>

<style scoped>
.property-page {
  min-height: 100%;
  background: var(--m-bg);
  color: var(--m-text);
}

.property-shell {
  width: 100%;
  max-width: 760px;
  margin: 0 auto;
  padding: var(--m-space-3) var(--m-page-gutter)
    max(112px, calc(var(--m-space-8) + env(safe-area-inset-bottom)));
}

.property-gallery {
  position: relative;
  height: 280px;
  margin: calc(-1 * var(--m-space-3)) calc(-1 * var(--m-page-gutter)) var(--m-space-3);
  overflow: hidden;
  background: var(--m-surface-2, #eef1f3);
}

.property-gallery--with-photo::after {
  position: absolute;
  inset: 0;
  content: '';
  background: linear-gradient(to bottom, transparent 52%, rgba(8, 24, 31, 0.5));
  pointer-events: none;
}

.property-gallery img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.property-gallery .gallery-controls {
  z-index: 1;
  bottom: 22px;
}

.icon-button {
  display: grid;
  width: 44px;
  height: 44px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 12px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
}

.tab-workspace {
  position: relative;
  z-index: 0;
  margin-top: -72px;
  margin-right: calc(-1 * var(--m-page-gutter));
  margin-left: calc(-1 * var(--m-page-gutter));
}

.folder-tabs {
  position: relative;
  z-index: 1;
  min-height: 42px;
  padding: 0 8px;
  overflow: visible;
  background: transparent;
}

.folder-tabs :deep(.q-tabs__content) {
  justify-content: flex-start;
  flex-wrap: nowrap;
  overflow: visible;
}

.folder-tabs :deep(.folder-tab) {
  min-width: max-content;
  min-height: 42px;
  margin-right: 4px;
  padding: 0 16px;
  border: 1px solid var(--m-border);
  border-bottom: 0;
  border-radius: 11px 11px 0 0;
  background: var(--m-surface-2);
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 750;
}

.folder-tabs :deep(.folder-tab.q-tab--active) {
  z-index: 2;
  margin-bottom: -1px;
  border-bottom: 1px solid var(--m-surface);
  position: relative;
  background: var(--m-surface);
  color: var(--m-primary-dark);
}

/* Cover the card's top border underneath the selected folder tab. */
.folder-tabs :deep(.folder-tab.q-tab--active)::after {
  position: absolute;
  right: 0;
  bottom: -1px;
  left: 0;
  height: 2px;
  content: '';
  background: var(--m-surface);
}

.folder-tabs :deep(.q-tab__indicator) {
  display: none;
}

.tab-card {
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: 16px;
  background: var(--m-surface);
}

.tab-card :deep(.q-tab-panel) {
  padding: 16px;
}

.content-stack {
  display: grid;
  gap: 16px;
}

.surface {
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: 16px;
  background: var(--m-surface);
}

.overview-hero {
  padding-bottom: 4px;
}

.gallery-placeholder {
  display: flex;
  width: 100%;
  height: 100%;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  background: var(--m-surface-2, #eef1f3);
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 750;
}

.gallery-controls {
  position: absolute;
  right: 12px;
  bottom: 12px;
  display: flex;
  gap: 5px;
  padding: 7px;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.58);
}

.gallery-controls button {
  width: 7px;
  height: 7px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.56);
}

.gallery-controls button.active {
  background: #fff;
}

.hero-copy {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  padding: 0;
}

.eyebrow {
  display: block;
  margin-bottom: 4px;
  color: var(--m-primary-dark);
  font-size: 10px;
  font-weight: 850;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.hero-copy h2 {
  margin: 0;
  color: var(--m-ink);
  font-size: 20px;
  font-weight: 850;
}

.hero-copy p {
  display: flex;
  align-items: center;
  gap: 4px;
  margin: 5px 0 0;
  color: var(--m-muted);
  font-size: 11px;
}

.edit-link,
.text-action,
.remove-action {
  display: inline-flex;
  min-height: 36px;
  align-items: center;
  gap: 5px;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  font-size: 11px;
  font-weight: 850;
  white-space: nowrap;
}

.occupancy-card {
  padding: 16px;
  border-radius: 16px;
  background: var(--m-primary-dark);
  color: #fff;
}

.occupancy-card__heading,
.occupancy-card__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.occupancy-card__heading > div > span {
  display: block;
  margin-bottom: 4px;
  color: rgba(255, 255, 255, 0.72);
  font-size: 11px;
  font-weight: 750;
}

.occupancy-card__heading strong {
  display: block;
  font-size: 26px;
  font-weight: 850;
  line-height: 1;
}

.occupancy-card__heading strong small {
  color: rgba(255, 255, 255, 0.72);
  font-size: 12px;
  font-weight: 700;
}

.availability-count {
  padding: 5px 8px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.16);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
}

.occupancy-meter {
  height: 7px;
  margin: 16px 0 12px;
  overflow: hidden;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.22);
}

.occupancy-meter span {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: #8ee6db;
  transition: width 0.2s ease;
}

.occupancy-card__footer {
  color: rgba(255, 255, 255, 0.76);
  font-size: 11px;
  font-weight: 700;
}

.occupancy-card__footer button {
  min-height: 36px;
  padding: 0 10px;
  border: 1px solid rgba(255, 255, 255, 0.42);
  border-radius: 9px;
  background: transparent;
  color: #fff;
  font: inherit;
  font-weight: 800;
}

.setup-callout {
  display: grid;
  grid-template-columns: 28px minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px;
  padding: 13px;
  border: 1px solid #fed7aa;
  border-radius: 14px;
  background: var(--m-warning-soft);
}

.setup-callout > span {
  color: var(--m-warning);
}

.setup-callout strong {
  color: var(--m-ink);
  font-size: 12px;
  font-weight: 850;
}

.setup-callout p {
  margin: 3px 0 0;
  color: var(--m-text);
  font-size: 11px;
}

.setup-callout button {
  min-height: 38px;
  padding: 0 10px;
  border: 0;
  border-radius: 8px;
  background: var(--m-warning);
  color: #fff;
  font-size: 11px;
  font-weight: 850;
}

.overview-section {
  padding-top: 16px;
  border-top: 1px solid var(--m-border);
}

.section-heading,
.subsection-heading {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.section-heading h2,
.form-subsection h3 {
  margin: 0;
  color: var(--m-ink);
  font-size: 16px;
  font-weight: 850;
}

.section-heading p,
.form-subsection p {
  margin: 4px 0 0;
  color: var(--m-muted);
  font-size: 11px;
  line-height: 1.4;
}

.overview-details {
  display: grid;
  gap: 0;
  margin: 14px 0 0;
}

.overview-details div {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 11px 0;
  border-top: 1px solid var(--m-border);
}

.overview-details dt {
  color: var(--m-muted);
  font-size: 12px;
}

.overview-details dd {
  margin: 0;
  color: var(--m-ink);
  font-size: 12px;
  font-weight: 750;
  text-align: right;
}

.description-copy {
  margin: 12px 0 0;
  color: var(--m-text);
  font-size: 13px;
  line-height: 1.55;
}

.chip-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 14px;
}

.chip-list span {
  padding: 5px 8px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 11px;
  font-weight: 750;
}

.empty-copy {
  margin: 14px 0 0;
  color: var(--m-muted);
  font-size: 12px;
  font-style: italic;
}

.settings-group {
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: 16px;
  background: var(--m-surface);
}

.settings-group h3 {
  margin: 0;
  padding: 11px 14px 8px;
  color: var(--m-muted);
  font-size: 10px;
  font-weight: 850;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.settings-row {
  display: grid;
  width: 100%;
  min-height: 68px;
  grid-template-columns: 40px minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
  color: var(--m-ink);
  text-align: left;
}

.settings-row:not(.settings-row--static):active {
  background: var(--m-bg);
}

.settings-row__icon {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  border-radius: 11px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}

.settings-row__icon--people {
  background: var(--m-info-soft);
  color: var(--m-info);
}

.settings-row__icon--spaces {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}

.settings-row__icon--location {
  background: var(--m-info-soft);
  color: var(--m-info);
}

.settings-row__icon--status {
  background: var(--m-success-soft);
  color: var(--m-success);
}

.settings-row__content {
  min-width: 0;
}

.settings-row__content strong,
.settings-row__content small {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.settings-row__content strong {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 800;
}

.settings-row__content small {
  margin-top: 3px;
  color: var(--m-muted);
  font-size: 11px;
}

.settings-row__arrow {
  color: var(--m-muted);
}

.shared-spaces-section {
  padding-top: 16px;
  border-top: 1px solid var(--m-border);
}

.shared-spaces-list {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
  margin-top: 12px;
}

.shared-spaces-list span {
  padding: 6px 9px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 11px;
  font-weight: 750;
}

.shared-spaces-empty {
  display: flex;
  width: 100%;
  min-height: 48px;
  align-items: center;
  justify-content: center;
  gap: 7px;
  margin-top: 12px;
  border: 1px dashed var(--m-border);
  border-radius: 11px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  font-size: 12px;
  font-weight: 800;
}

.form-subsection--first {
  margin-top: 0;
}

.location-results {
  display: grid;
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: 11px;
  background: var(--m-surface);
}

.location-results button {
  display: grid;
  grid-template-columns: 20px minmax(0, 1fr);
  gap: 8px;
  padding: 10px;
  border: 0;
  border-bottom: 1px solid var(--m-border);
  background: transparent;
  color: var(--m-primary-dark);
  text-align: left;
}

.location-results button:last-child {
  border-bottom: 0;
}

.location-results strong,
.location-results small {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.location-results strong {
  color: var(--m-ink);
  font-size: 12px;
}

.location-results small,
.map-hint,
.map-status {
  color: var(--m-muted);
  font-size: 11px;
}

.location-map {
  height: 220px;
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: 12px;
  background: var(--m-bg);
}

.map-hint,
.map-status {
  margin: 0;
}

.facility-list {
  display: grid;
  gap: 8px;
  margin-top: 14px;
}

.facility-list article {
  display: grid;
  grid-template-columns: 36px minmax(0, 1fr);
  gap: 10px;
  padding: 10px 0;
  border-top: 1px solid var(--m-border);
}

.facility-icon,
.room-icon,
.state-icon {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border-radius: 10px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}

.facility-list strong {
  color: var(--m-ink);
  font-size: 12px;
  font-weight: 850;
}

.facility-list p,
.facility-list small {
  display: block;
  margin: 3px 0 0;
  color: var(--m-muted);
  font-size: 11px;
  line-height: 1.4;
}

.primary-action {
  min-height: 40px;
  padding: 0 12px;
  border: 0;
  border-radius: 10px;
  background: var(--m-primary-dark);
  color: #fff;
  font-size: 12px;
  font-weight: 850;
  white-space: nowrap;
}

.primary-action svg {
  margin-right: 4px;
  vertical-align: -3px;
}

.room-list {
  overflow: hidden;
}

.room-row {
  display: grid;
  min-height: 90px;
  grid-template-columns: 40px minmax(0, 1fr) auto;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border-bottom: 1px solid var(--m-border);
}

.room-row:last-child {
  border-bottom: 0;
}

.room-icon {
  width: 40px;
  height: 40px;
}

.room-icon--success {
  background: var(--m-success-soft);
  color: var(--m-success);
}

.room-icon--warning {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}

.room-icon--danger,
.state-panel--error .state-icon {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}

.room-copy {
  display: grid;
  min-width: 0;
  gap: 2px;
}

.room-copy strong,
.room-copy span,
.room-copy small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.room-copy strong {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 850;
}

.room-copy span,
.room-copy small {
  color: var(--m-muted);
  font-size: 11px;
}

.room-side {
  display: grid;
  justify-items: end;
  gap: 6px;
}

.room-side button {
  min-height: 28px;
  padding: 0 4px;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  font-size: 11px;
  font-weight: 850;
}

.status-badge {
  display: inline-flex;
  min-height: 23px;
  align-items: center;
  padding: 4px 7px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 850;
  white-space: nowrap;
}

.status-badge--success {
  background: var(--m-success-soft);
  color: var(--m-success);
}

.status-badge--warning {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}

.status-badge--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}

.status-badge--neutral {
  background: var(--m-bg);
  color: var(--m-text);
}

.state-panel {
  display: flex;
  min-height: 260px;
  flex-direction: column;
  align-items: flex-start;
  justify-content: center;
  padding: 24px;
}

.state-icon {
  width: 44px;
  height: 44px;
  margin-bottom: 16px;
}

.state-panel h2 {
  margin: 0;
  color: var(--m-ink);
  font-size: 18px;
  font-weight: 850;
}

.state-panel p {
  margin: 7px 0 18px;
  color: var(--m-muted);
  font-size: 13px;
  line-height: 1.5;
}

.sheet-card {
  width: 100%;
  max-width: 760px;
  max-height: calc(100vh - 72px);
  margin: 0 auto;
  border-radius: 18px 18px 0 0;
}

.sheet-card--scroll {
  display: flex;
  flex-direction: column;
}

.sheet-heading {
  display: flex;
  flex: 0 0 auto;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  border-bottom: 1px solid var(--m-border);
}

.sheet-heading h2 {
  margin: 0;
  color: var(--m-ink);
  font-size: 18px;
  font-weight: 850;
}

.sheet-heading p {
  margin: 4px 0 0;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.4;
}

.sheet-form {
  display: grid;
  gap: 14px;
  overflow: auto;
}

.sheet-form > label,
.draft-facility label {
  display: grid;
  gap: 6px;
  color: var(--m-text);
  font-size: 12px;
  font-weight: 800;
}

.sheet-form label > span,
.draft-facility label > span {
  color: var(--m-danger);
}

.sheet-form .optional {
  color: var(--m-muted);
  font-weight: 600;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.capacity-note {
  display: flex;
  align-items: center;
  gap: 8px;
  min-height: 40px;
  padding: 8px 10px;
  border-radius: 10px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 11px;
}

.form-subsection {
  display: grid;
  gap: 12px;
  padding-top: 16px;
  border-top: 1px solid var(--m-border);
}

.draft-facility {
  display: grid;
  gap: 12px;
  padding: 14px;
  border-radius: 12px;
  background: var(--m-bg);
}

.draft-facility strong {
  color: var(--m-ink);
  font-size: 12px;
  font-weight: 850;
}

.remove-action {
  min-height: 32px;
  color: var(--m-danger);
}

.sheet-card :deep(.q-card__actions) {
  flex: 0 0 auto;
  min-height: 62px;
  padding: 10px 16px max(10px, env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
}

.loading-card {
  padding: 12px;
}

.skeleton {
  height: 56px;
  margin-bottom: 12px;
  border-radius: 8px;
  background: #edf0f2;
  animation: pulse 1.4s ease infinite;
}

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
}

.icon-button:focus-visible,
.gallery-controls button:focus-visible,
.edit-link:focus-visible,
.text-action:focus-visible,
.remove-action:focus-visible,
.room-side button:focus-visible,
.setup-callout button:focus-visible {
  outline: 2px solid var(--m-primary);
  outline-offset: 2px;
}

@keyframes pulse {
  50% {
    opacity: 0.48;
  }
}

@media (max-width: 390px) {
  .gallery img {
    height: 100%;
  }

  .hero-copy {
    display: grid;
  }

  .edit-link {
    justify-self: start;
  }

  .form-grid,
  .setup-callout {
    grid-template-columns: 28px minmax(0, 1fr);
  }

  .setup-callout button {
    grid-column: 2;
    justify-self: start;
  }

  .room-side .status-badge {
    display: none;
  }
}
</style>
