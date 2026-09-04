<template>
  <q-page class="wiz">
    <div class="steps">
      <span v-for="n in 4" :key="n" class="step-dot" :class="{ 'step-dot--on': n <= step }" />
    </div>

    <div class="stack">
      <section v-if="step === 1" class="sec">
        <h2 class="sec-title">Details</h2>
        <label class="field">
          <span class="field-label">Name</span>
          <input v-model="form.name" type="text" class="field-input" placeholder="e.g. Torres Student Home" />
        </label>
        <label class="field">
          <span class="field-label">Type</span>
          <select v-model="form.accommodationType" class="field-input">
            <option value="">Select type</option>
            <option v-for="(label, key) in BUILDING_TYPE_LABEL" :key="key" :value="key">{{ label }}</option>
          </select>
        </label>
        <label class="field">
          <span class="field-label">Address</span>
          <input v-model="form.address" type="text" class="field-input" placeholder="Street, building number" />
        </label>
        <div class="field-row">
          <label class="field">
            <span class="field-label">Barangay</span>
            <input v-model="form.barangay" type="text" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">City</span>
            <input v-model="form.city" type="text" class="field-input" />
          </label>
        </div>
        <div class="field-row">
          <label class="field">
            <span class="field-label">Floors</span>
            <input v-model.number="form.totalFloors" type="number" min="0" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">Total rooms</span>
            <input v-model.number="form.totalRooms" type="number" min="0" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">Capacity</span>
            <input v-model.number="form.capacity" type="number" min="0" class="field-input" />
          </label>
        </div>
        <label class="field">
          <span class="field-label">Description</span>
          <textarea v-model="form.description" class="field-input field-textarea" rows="4" placeholder="What makes this place worth staying at?" />
        </label>
      </section>

      <section v-else-if="step === 2" class="sec">
        <h2 class="sec-title">Amenities</h2>
        <div class="chips">
          <button
            v-for="key in AMENITY_KEYS"
            :key="key"
            type="button"
            class="chip"
            :class="{ 'chip--on': form.amenities.includes(key) }"
            @click="toggle(form.amenities, key)"
          >
            <IconifyIcon :icon="AMENITY_META[key]?.icon || 'lucide:dot'" width="14" />
            {{ AMENITY_META[key]?.label || key }}
          </button>
        </div>

        <h2 class="sec-title">House rules</h2>
        <label class="field">
          <span class="field-label">Curfew</span>
          <input v-model="form.curfewTime" type="text" class="field-input" placeholder="e.g. 10:00 PM" />
        </label>
        <label class="field">
          <span class="field-label">Quiet hours</span>
          <input v-model="form.quietHours" type="text" class="field-input" placeholder="e.g. 10:00 PM – 6:00 AM" />
        </label>
        <label class="field">
          <span class="field-label">Visitor policy</span>
          <input v-model="form.visitorPolicy" type="text" class="field-input" placeholder="e.g. Visitors allowed until 8 PM" />
        </label>
        <div class="field-row">
          <label class="field">
            <span class="field-label">Advance (months)</span>
            <input v-model.number="form.advanceMonths" type="number" min="0" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">Deposit (months)</span>
            <input v-model.number="form.depositMonths" type="number" min="0" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">Min. stay (months)</span>
            <input v-model.number="form.minStay" type="number" min="0" class="field-input" />
          </label>
        </div>
        <div class="toggles">
          <label v-for="t in RULE_TOGGLES" :key="t.key" class="toggle-row">
            <span>{{ t.label }}</span>
            <q-toggle v-model="form[t.key]" color="primary" dense />
          </label>
        </div>
      </section>

      <section v-else-if="step === 3" class="sec">
        <h2 class="sec-title">Exterior photos</h2>
        <p class="sec-hint">Students see these first. Add a few if you have them — you can add more later.</p>
        <input type="file" accept="image/*" multiple class="file-input" @change="onPhotosSelected" />
        <div v-if="photos.length" class="thumbs">
          <div v-for="(p, i) in photos" :key="p.url" class="thumb">
            <img :src="p.url" alt="" />
            <button type="button" class="thumb-x" @click="photos.splice(i, 1)">
              <IconifyIcon icon="lucide:x" width="12" />
            </button>
          </div>
        </div>
        <span v-if="uploadingPhotos" class="sec-hint">Uploading…</span>

        <h2 class="sec-title">Permits (optional)</h2>
        <p class="sec-hint">OSAS reviews these before your listing goes live. You can also add them later from OSAS compliance.</p>
        <div class="permits">
          <label v-for="d in DOC_TYPES" :key="d.key" class="permit-row">
            <span class="permit-label">{{ d.label }}</span>
            <span v-if="permits[d.key]" class="permit-status">Attached ✓</span>
            <span v-else class="permit-status permit-status--muted">Not attached</span>
            <input type="file" accept="image/*,application/pdf" class="permit-file" @change="onPermitSelected($event, d.key)" />
          </label>
        </div>
      </section>

      <section v-else class="sec">
        <h2 class="sec-title">Review</h2>
        <div class="group">
          <div class="rule"><span class="rule-label">Name</span><span class="rule-value">{{ form.name || '—' }}</span></div>
          <div class="rule"><span class="rule-label">Type</span><span class="rule-value">{{ BUILDING_TYPE_LABEL[form.accommodationType] || '—' }}</span></div>
          <div class="rule"><span class="rule-label">Address</span><span class="rule-value">{{ form.address || '—' }}</span></div>
          <div class="rule"><span class="rule-label">Amenities</span><span class="rule-value">{{ form.amenities.length || 'None' }}</span></div>
          <div class="rule"><span class="rule-label">Photos</span><span class="rule-value">{{ photos.length }}</span></div>
        </div>
        <p class="sec-hint">
          Your listing starts as pending — OSAS reviews it before students can see or apply to it.
        </p>
      </section>
    </div>

    <div class="nav">
      <button v-if="step > 1" type="button" class="nav-btn nav-btn--ghost" @click="step--">Back</button>
      <button
        v-if="step < 4"
        type="button"
        class="nav-btn"
        :disabled="step === 1 && !form.name.trim()"
        @click="step++"
      >
        Next
      </button>
      <button v-else type="button" class="nav-btn" :disabled="submitting" @click="submit">
        {{ submitting ? 'Creating…' : 'Create accommodation' }}
      </button>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { uploadDocument } from '@/utils/upload'
import { AMENITY_META, AMENITY_KEYS, BUILDING_TYPE_LABEL } from '@/utils/listings'
import type { Database } from '@/types/database.gen'

type AmenityKey = Database['public']['Enums']['amenity']

const RULE_TOGGLES = [
  { key: 'cooking' as const, label: 'Cooking allowed' },
  { key: 'laundry' as const, label: 'Laundry allowed' },
  { key: 'pets' as const, label: 'Pets allowed' },
  { key: 'smoking' as const, label: 'Smoking allowed' },
]

const DOC_TYPES = [
  { key: 'sanitary_permit' as const, label: 'Sanitary permit' },
  { key: 'fire_safety' as const, label: 'Fire safety certificate' },
  { key: 'business_permit' as const, label: 'Business permit' },
  { key: 'building_permit' as const, label: 'Building permit' },
]

const router = useRouter()
const notify = useNotify()

const step = ref(1)
const submitting = ref(false)
const uploadingPhotos = ref(false)
const photos = ref<{ url: string }[]>([])
const permits = reactive<Record<string, string>>({})

const form = reactive({
  name: '',
  accommodationType: '',
  address: '',
  barangay: '',
  city: '',
  totalFloors: null as number | null,
  totalRooms: null as number | null,
  capacity: null as number | null,
  description: '',
  amenities: [] as string[],
  curfewTime: '',
  quietHours: '',
  visitorPolicy: '',
  advanceMonths: 1,
  depositMonths: 1,
  minStay: 1,
  cooking: true,
  laundry: true,
  pets: false,
  smoking: false,
})

function toggle(list: string[], value: string) {
  const i = list.indexOf(value)
  if (i === -1) list.push(value)
  else list.splice(i, 1)
}

async function onPhotosSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files ?? [])
  if (!files.length) return
  uploadingPhotos.value = true
  try {
    for (const file of files) {
      const url = await uploadDocument(file, '', 'accommodation_photo')
      photos.value.push({ url })
    }
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload one of your photos.'))
  } finally {
    uploadingPhotos.value = false
    input.value = ''
  }
}

async function onPermitSelected(event: Event, docType: string) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  try {
    permits[docType] = await uploadDocument(file, '', docType)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload that permit.'))
  } finally {
    input.value = ''
  }
}

async function submit() {
  if (submitting.value) return
  if (!form.name.trim()) {
    step.value = 1
    notify.error('Give your accommodation a name.')
    return
  }
  submitting.value = true
  try {
    const { data: authData } = await supabase.auth.getUser()
    const user = authData?.user
    if (!user) throw new Error('Not signed in.')

    const { data: accommodation, error: insertError } = await supabase
      .from('accommodations')
      .insert({
        accommodation_manager_id: user.id,
        name: form.name.trim(),
        accommodation_type: form.accommodationType || null,
        address: form.address.trim() || null,
        barangay: form.barangay.trim() || null,
        city: form.city.trim() || null,
        total_floors: form.totalFloors,
        total_rooms: form.totalRooms,
        capacity: form.capacity,
        description: form.description.trim() || null,
        status: 'pending',
      })
      .select('id')
      .single()
    if (insertError) throw insertError
    const accommodationId = accommodation.id

    if (form.amenities.length) {
      const { error: amenityError } = await supabase
        .from('accommodation_amenities')
        .insert(form.amenities.map((amenity) => ({ accommodation_id: accommodationId, amenity: amenity as AmenityKey })))
      if (amenityError) throw amenityError
    }

    const { error: policyError } = await supabase.from('accommodation_policies').insert({
      accommodation_id: accommodationId,
      advance_months: form.advanceMonths || null,
      deposit_months: form.depositMonths || null,
      min_stay: form.minStay || null,
      curfew_time: form.curfewTime.trim() || null,
      quiet_hours: form.quietHours.trim() || null,
      visitor_policy: form.visitorPolicy.trim() || null,
      cooking: form.cooking,
      laundry: form.laundry,
      pets: form.pets,
      smoking: form.smoking,
    })
    if (policyError) throw policyError

    if (photos.value.length) {
      const { error: imagesError } = await supabase
        .from('accommodation_images')
        .insert(photos.value.map((p, i) => ({ accommodation_id: accommodationId, url: p.url, sort_order: i })))
      if (imagesError) throw imagesError
    }

    const docEntries = Object.entries(permits).filter(([, url]) => url)
    if (docEntries.length) {
      const { error: docsError } = await supabase
        .from('accommodation_documents')
        .insert(docEntries.map(([doc_type, file_url]) => ({ accommodation_id: accommodationId, doc_type, file_url })))
      if (docsError) throw docsError
    }

    notify.success('Accommodation created — it now awaits OSAS review.')
    void router.replace(`/manager/properties/${accommodationId}`)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not create this accommodation.'))
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
.wiz {
  background: var(--m-bg);
}
.steps {
  display: flex;
  justify-content: center;
  gap: 6px;
  padding: 10px 0 4px;
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
.stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 6px var(--m-page-gutter) 100px;
}
.sec {
  display: flex;
  flex-direction: column;
  gap: 10px;
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
.sec-hint {
  margin: -4px 0 0;
  padding: 0 2px;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.5;
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
  width: 72px;
  height: 72px;
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

.permits {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.permit-row {
  position: relative;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  border-top: 1px solid var(--m-border);
  cursor: pointer;
}
.permits > .permit-row:first-child {
  border-top: 0;
}
.permit-label {
  flex: 1;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
}
.permit-status {
  color: var(--m-success);
  font-size: 11.5px;
  font-weight: 700;
}
.permit-status--muted {
  color: var(--m-muted);
  font-weight: 600;
}
.permit-file {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  cursor: pointer;
}

.group {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
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

.nav {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 5;
  display: flex;
  gap: 8px;
  padding: 10px var(--m-page-gutter) calc(10px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.nav-btn {
  flex: 1;
  min-height: 46px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.nav-btn:disabled {
  opacity: 0.5;
}
.nav-btn--ghost {
  flex: 0 0 auto;
  padding: 0 20px;
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}
</style>
