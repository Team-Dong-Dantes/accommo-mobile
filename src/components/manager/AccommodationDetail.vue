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

      <!-- OVERVIEW -->
      <section v-if="tab === 'overview'" class="sec">
        <label class="field">
          <span class="field-label">Name</span>
          <input v-model="acc.name" type="text" class="field-input" />
        </label>
        <label class="field">
          <span class="field-label">Type</span>
          <select v-model="acc.accommodationType" class="field-input">
            <option value="">Select type</option>
            <option v-for="(label, key) in BUILDING_TYPE_LABEL" :key="key" :value="key">{{ label }}</option>
          </select>
        </label>
        <label class="field">
          <span class="field-label">Address</span>
          <input v-model="acc.address" type="text" class="field-input" />
        </label>
        <div class="field-row">
          <label class="field">
            <span class="field-label">Barangay</span>
            <input v-model="acc.barangay" type="text" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">City</span>
            <input v-model="acc.city" type="text" class="field-input" />
          </label>
        </div>
        <div class="field-row">
          <label class="field">
            <span class="field-label">Floors</span>
            <input v-model.number="acc.totalFloors" type="number" min="0" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">Total rooms</span>
            <input v-model.number="acc.totalRooms" type="number" min="0" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">Capacity</span>
            <input v-model.number="acc.capacity" type="number" min="0" class="field-input" />
          </label>
        </div>
        <label class="field">
          <span class="field-label">Description</span>
          <textarea v-model="acc.description" class="field-input field-textarea" rows="4" />
        </label>
        <q-btn unelevated rounded no-caps color="primary" class="save-btn" :loading="savingOverview" label="Save changes" @click="saveOverview" />
      </section>

      <!-- ROOMS -->
      <section v-else-if="tab === 'rooms'" class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Rooms ({{ rooms.length }})</h2>
          <button type="button" class="sec-link" @click="openRoomDialog(null)">Add room</button>
        </div>
        <div v-if="rooms.length" class="group">
          <button v-for="r in rooms" :key="r.id" type="button" class="room-row" @click="openRoomDialog(r)">
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

      <!-- AMENITIES & RULES -->
      <section v-else-if="tab === 'rules'" class="sec">
        <h2 class="sec-title">Amenities</h2>
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

        <h2 class="sec-title">House rules</h2>
        <label class="field">
          <span class="field-label">Curfew</span>
          <input v-model="rules.curfewTime" type="text" class="field-input" />
        </label>
        <label class="field">
          <span class="field-label">Quiet hours</span>
          <input v-model="rules.quietHours" type="text" class="field-input" />
        </label>
        <label class="field">
          <span class="field-label">Visitor policy</span>
          <input v-model="rules.visitorPolicy" type="text" class="field-input" />
        </label>
        <div class="field-row">
          <label class="field">
            <span class="field-label">Advance (months)</span>
            <input v-model.number="rules.advanceMonths" type="number" min="0" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">Deposit (months)</span>
            <input v-model.number="rules.depositMonths" type="number" min="0" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">Min. stay (months)</span>
            <input v-model.number="rules.minStay" type="number" min="0" class="field-input" />
          </label>
        </div>
        <div class="toggles">
          <label v-for="t in RULE_TOGGLES" :key="t.key" class="toggle-row">
            <span>{{ t.label }}</span>
            <q-toggle v-model="rules[t.key]" color="primary" dense />
          </label>
        </div>
        <q-btn unelevated rounded no-caps color="primary" class="save-btn" :loading="savingRules" label="Save changes" @click="saveRules" />
      </section>

      <!-- PHOTOS -->
      <section v-else class="sec">
        <h2 class="sec-title">Photos</h2>
        <input type="file" accept="image/*" multiple class="file-input" @change="onPhotosSelected" />
        <span v-if="uploadingPhotos" class="sec-hint">Uploading…</span>
        <div v-if="images.length" class="thumbs">
          <div v-for="img in images" :key="img.id" class="thumb">
            <img :src="img.url" alt="" />
            <button type="button" class="thumb-x" :disabled="deletingImage === img.id" @click="deleteImage(img.id)">
              <IconifyIcon icon="lucide:x" width="12" />
            </button>
          </div>
        </div>
        <p v-else class="none">No photos yet.</p>
      </section>

      <div class="tail" />
    </div>

    <q-dialog v-model="roomOpen" position="bottom">
      <q-card class="room-sheet">
        <h3 class="room-sheet-title">{{ editingRoomId ? 'Edit room' : 'Add room' }}</h3>
        <label class="field">
          <span class="field-label">Label</span>
          <input v-model="roomForm.label" type="text" class="field-input" placeholder="e.g. Room 201" />
        </label>
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
        <div class="field-row">
          <label class="field">
            <span class="field-label">Floor</span>
            <input v-model.number="roomForm.floor" type="number" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">Capacity</span>
            <input v-model.number="roomForm.capacity" type="number" min="1" class="field-input" />
          </label>
        </div>
        <label class="field">
          <span class="field-label">Monthly rent</span>
          <input v-model.number="roomForm.monthlyRent" type="number" min="0" step="0.01" class="field-input" />
        </label>

        <div class="room-sheet-actions">
          <button v-if="editingRoomId" type="button" class="room-del" :disabled="savingRoom" @click="deleteRoom">Delete</button>
          <q-btn unelevated rounded no-caps color="primary" class="save-btn" :loading="savingRoom" label="Save room" @click="saveRoom" />
        </div>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { reactive, ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatPeso } from '@/utils/format'
import { useNotify } from '@/utils/notify'
import { uploadDocument } from '@/utils/upload'
import { AMENITY_META, AMENITY_KEYS, ROOM_TYPE_LABEL, BUILDING_TYPE_LABEL, roomTypeLabel } from '@/utils/listings'
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

const TABS = [
  { key: 'overview', label: 'Overview' },
  { key: 'rooms', label: 'Rooms' },
  { key: 'rules', label: 'Amenities' },
  { key: 'photos', label: 'Photos' },
] as const

const RULE_TOGGLES = [
  { key: 'cooking' as const, label: 'Cooking allowed' },
  { key: 'laundry' as const, label: 'Laundry allowed' },
  { key: 'pets' as const, label: 'Pets allowed' },
  { key: 'smoking' as const, label: 'Smoking allowed' },
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
}
interface Img {
  id: string
  url: string
}

const route = useRoute()
const notify = useNotify()

const id = String(route.params.id || '')

const loading = ref(true)
const error = ref('')
const tab = ref<(typeof TABS)[number]['key']>('overview')
const savingOverview = ref(false)
const savingRules = ref(false)

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
  smoking: false,
})
const rooms = ref<Room[]>([])
const images = ref<Img[]>([])
const uploadingPhotos = ref(false)
const deletingImage = ref('')

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
        'name,accommodation_type,address,barangay,city,total_floors,total_rooms,capacity,description,status,accommodation_amenities(amenity),accommodation_policies(advance_months,deposit_months,min_stay,curfew_time,quiet_hours,visitor_policy,cooking,laundry,pets,smoking),accommodation_images(id,url,sort_order),rooms(id,label,room_number,room_type,custom_room_type,floor,capacity,current_pax,monthly_rent,status)',
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
          smoking: boolean | null
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
      rules.smoking = policy.smoking ?? false
    }

    images.value = [...((data.accommodation_images ?? []) as { id: string; url: string; sort_order: number | null }[])]
      .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
      .map((i) => ({ id: i.id, url: i.url }))

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
    }[]).map((r) => ({
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
    }))
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

async function saveOverview() {
  savingOverview.value = true
  try {
    const { error: updateError } = await supabase
      .from('accommodations')
      .update({
        name: acc.name.trim(),
        accommodation_type: acc.accommodationType || null,
        address: acc.address.trim() || null,
        barangay: acc.barangay.trim() || null,
        city: acc.city.trim() || null,
        total_floors: acc.totalFloors,
        total_rooms: acc.totalRooms,
        capacity: acc.capacity,
        description: acc.description.trim() || null,
      })
      .eq('id', id)
    if (updateError) throw updateError
    notify.success('Saved.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not save your changes.'))
  } finally {
    savingOverview.value = false
  }
}

async function saveRules() {
  savingRules.value = true
  try {
    await supabase.from('accommodation_amenities').delete().eq('accommodation_id', id)
    if (rules.amenities.length) {
      const { error: amenityError } = await supabase
        .from('accommodation_amenities')
        .insert(rules.amenities.map((amenity) => ({ accommodation_id: id, amenity: amenity as AmenityKey })))
      if (amenityError) throw amenityError
    }

    const { error: policyError } = await supabase.from('accommodation_policies').upsert(
      {
        accommodation_id: id,
        advance_months: rules.advanceMonths,
        deposit_months: rules.depositMonths,
        min_stay: rules.minStay,
        curfew_time: rules.curfewTime.trim() || null,
        quiet_hours: rules.quietHours.trim() || null,
        visitor_policy: rules.visitorPolicy.trim() || null,
        cooking: rules.cooking,
        laundry: rules.laundry,
        pets: rules.pets,
        smoking: rules.smoking,
      },
      { onConflict: 'accommodation_id' },
    )
    if (policyError) throw policyError

    notify.success('Saved.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not save your changes.'))
  } finally {
    savingRules.value = false
  }
}

async function onPhotosSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files ?? [])
  if (!files.length) return
  uploadingPhotos.value = true
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
    uploadingPhotos.value = false
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
  } else {
    editingRoomId.value = ''
    roomForm.label = ''
    roomForm.roomType = 'solo'
    roomForm.customRoomType = ''
    roomForm.floor = null
    roomForm.capacity = 1
    roomForm.monthlyRent = 0
  }
  roomOpen.value = true
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

onMounted(load)
</script>

<style scoped>
.ad {
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 8px var(--m-page-gutter) 24px;
}
.sk {
  border-radius: var(--m-radius);
}
.tail {
  height: 12px;
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

.head {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 2px;
}
.head-name {
  min-width: 0;
  overflow: hidden;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
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

.tabs {
  display: flex;
  gap: 6px;
  border-bottom: 1px solid var(--m-border);
}
.tab {
  padding: 8px 4px;
  border: 0;
  border-bottom: 2px solid transparent;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.tab--on {
  border-bottom-color: var(--m-primary);
  color: var(--m-primary-dark);
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
  justify-content: space-between;
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
.room-body {
  display: flex;
  min-width: 0;
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
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.room-sheet-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
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
