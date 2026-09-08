<template>
  <q-page class="wiz">
    <div class="steps">
      <span v-for="n in 5" :key="n" class="step-dot" :class="{ 'step-dot--on': n <= step }" />
    </div>

    <div class="stack">
      <section v-if="step === 1" class="sec">
        <h2 class="sec-title">Details</h2>
        <label class="field">
          <span class="field-label">Name <span class="req">*</span></span>
          <input v-model="form.name" type="text" class="field-input" placeholder="e.g. Torres Student Home" />
        </label>
        <label class="field">
          <span class="field-label">Type <span class="req">*</span></span>
          <select v-model="form.accommodationType" class="field-input">
            <option value="">Select type</option>
            <option v-for="(label, key) in BUILDING_TYPE_LABEL" :key="key" :value="key">{{ label }}</option>
          </select>
        </label>
        <!-- Location leads: picking on the map fills the two fields below it,
             so they're a check-and-correct rather than something to type out. -->
        <span class="field-label">Location <span class="req">*</span></span>
        <div class="location-row">
          <img v-if="locationPreviewUrl" :src="locationPreviewUrl" alt="Picked location preview" class="location-preview" />
          <button type="button" class="location-btn" @click="locationPickerOpen = true">
            <IconifyIcon icon="lucide:map-pin" width="15" />
            {{ form.lat != null ? 'Change location on map' : 'Set location on map' }}
          </button>
        </div>

        <div class="field-row">
          <label class="field">
            <span class="field-label">Barangay <span class="req">*</span></span>
            <input v-model="form.barangay" type="text" class="field-input" placeholder="e.g. San Fabian" />
          </label>
          <label class="field">
            <span class="field-label">City / Municipality <span class="req">*</span></span>
            <input v-model="form.city" type="text" class="field-input" placeholder="e.g. Echague" />
          </label>
        </div>

        <label class="field">
          <span class="field-label">Description</span>
          <textarea v-model="form.description" class="field-input field-textarea" rows="4" placeholder="What makes this place worth staying at?" />
        </label>
      </section>

      <section v-else-if="step === 2" class="sec">
        <h2 class="sec-title">Amenities <span class="req">*</span></h2>
        <p class="sec-hint">Pick at least one — students filter by these.</p>
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

        <h2 class="sec-title">House rules <span class="req">*</span></h2>
        <label class="field">
          <span class="field-label">Curfew <span class="req">*</span></span>
          <input v-model="form.curfewTime" type="time" class="field-input" />
        </label>
        <div class="field-row">
          <label class="field">
            <span class="field-label">Quiet hours from <span class="req">*</span></span>
            <input v-model="form.quietFrom" type="time" class="field-input" />
          </label>
          <label class="field">
            <span class="field-label">until <span class="req">*</span></span>
            <input v-model="form.quietTo" type="time" class="field-input" />
          </label>
        </div>
        <p v-if="quietHoursLabel" class="sec-hint">Students will see “{{ quietHoursLabel }}”.</p>
        <label class="field">
          <span class="field-label">Visitor policy <span class="req">*</span></span>
          <input v-model="form.visitorPolicy" type="text" class="field-input" placeholder="e.g. Visitors allowed until 8 PM" />
        </label>
        <p class="sec-hint">Advance and deposit are set per room once you add rooms.</p>
        <div class="toggles">
          <label v-for="t in RULE_TOGGLES" :key="t.key" class="toggle-row">
            <span>{{ t.label }}</span>
            <q-toggle v-model="form[t.key]" color="primary" dense />
          </label>
        </div>
      </section>

      <section v-else-if="step === 3" class="sec sec--pinned-actions">
        <h2 class="sec-title">Exterior photos <span class="req">*</span></h2>
        <p class="sec-hint">Students see these first. At least one is required — you can add more later.</p>


        <div v-if="photos.length" class="thumbs">
          <div v-for="(p, i) in photos" :key="p.url" class="thumb">
            <img :src="p.url" alt="" />
            <button type="button" class="thumb-x" @click="photos.splice(i, 1)">
              <IconifyIcon icon="lucide:x" width="12" />
            </button>
          </div>
        </div>
        <span v-if="uploadingPhotos" class="sec-hint">Uploading…</span>
        <p v-else-if="photos.length" class="sec-hint">{{ photos.length }} photo{{ photos.length === 1 ? '' : 's' }} added.</p>
      </section>

      <section v-else-if="step === 4" class="sec">
        <h2 class="sec-title">Permits <span class="req">*</span></h2>
        <p class="sec-hint">
          OSAS reviews these before your listing goes live. All four are required to submit.
        </p>

        <div class="permit-progress">
          <span class="permit-progress-bar"><span :style="{ width: `${(attachedPermits / DOC_TYPES.length) * 100}%` }" /></span>
          <span class="permit-progress-text">{{ attachedPermits }} of {{ DOC_TYPES.length }} attached</span>
        </div>

        <div class="permits">
          <div v-for="d in DOC_TYPES" :key="d.key" class="permit-row" :class="{ 'permit-row--done': permits[d.key] }">
            <span class="permit-icon">
              <IconifyIcon :icon="permits[d.key] ? 'lucide:check' : 'lucide:paperclip'" width="15" />
            </span>
            <span class="permit-body">
              <span class="permit-label">{{ d.label }}</span>
              <span class="permit-status" :class="{ 'permit-status--muted': !permits[d.key] }">
                {{ permits[d.key] ? 'Attached' : 'Required' }}
              </span>
            </span>
            <IconifyIcon v-if="uploadingPermit === d.key" icon="lucide:loader" width="15" class="permit-spin" />
            <template v-else>
              <button
                type="button"
                class="permit-act"
                :aria-label="`Take a photo of your ${d.label}`"
                @click="takePermitPhoto(d.key)"
              >
                <IconifyIcon icon="lucide:camera" width="15" />
              </button>
              <label class="permit-act" :aria-label="`Upload your ${d.label}`">
                <IconifyIcon icon="lucide:upload" width="15" />
                <input type="file" accept="image/*,application/pdf" class="file-input-hidden" @change="onPermitSelected($event, d.key)" />
              </label>
            </template>
          </div>
        </div>
      </section>

      <section v-else class="sec">
        <h2 class="sec-title">Review</h2>

        <!-- Leads with what the student will actually see, so mistakes in the
             photo or the name are obvious before this goes to OSAS. -->
        <div class="rv-card">
          <span class="rv-shot" :class="{ 'rv-shot--empty': !photos.length }">
            <img v-if="photos.length" :src="photos[0]!.url" alt="" />
            <IconifyIcon v-else icon="lucide:image-off" width="20" />
          </span>
          <span class="rv-head">
            <strong class="rv-name">{{ form.name }}</strong>
            <span class="rv-type">{{ BUILDING_TYPE_LABEL[form.accommodationType] }}</span>
            <span class="rv-where">
              <IconifyIcon icon="lucide:map-pin" width="11" />
              {{ locationSummary }}
            </span>
          </span>
        </div>

        <button type="button" class="rv-block rv-block--tap" @click="step = 2">
          <span class="rv-block-head">
            <IconifyIcon icon="lucide:sparkles" width="14" />
            Amenities
            <span class="rv-count">{{ form.amenities.length }}</span>
            <IconifyIcon icon="lucide:pencil" width="13" class="rv-edit" />
          </span>
          <span class="rv-chips">
            <span v-for="key in form.amenities" :key="key" class="rv-chip">
              {{ AMENITY_META[key]?.label || key }}
            </span>
          </span>
        </button>

        <button type="button" class="rv-block rv-block--tap" @click="step = 2">
          <span class="rv-block-head">
            <IconifyIcon icon="lucide:scroll-text" width="14" />
            House rules
            <IconifyIcon icon="lucide:pencil" width="13" class="rv-edit" />
          </span>
          <span class="rv-line"><span>Curfew</span><strong>{{ to12Hour(form.curfewTime) }}</strong></span>
          <span class="rv-line"><span>Quiet hours</span><strong>{{ quietHoursLabel }}</strong></span>
          <span class="rv-line"><span>Visitors</span><strong>{{ form.visitorPolicy }}</strong></span>
          <span class="rv-chips">
            <span v-for="t in RULE_TOGGLES" :key="t.key" class="rv-chip" :class="{ 'rv-chip--off': !form[t.key] }">
              {{ form[t.key] ? '' : 'No ' }}{{ t.label.replace(' allowed', '') }}
            </span>
          </span>
        </button>

        <button type="button" class="rv-block rv-block--tap" @click="step = 3">
          <span class="rv-block-head">
            <IconifyIcon icon="lucide:images" width="14" />
            Photos
            <span class="rv-count">{{ photos.length }}</span>
            <IconifyIcon icon="lucide:pencil" width="13" class="rv-edit" />
          </span>
          <span class="rv-strip">
            <img v-for="p in photos.slice(0, 6)" :key="p.url" :src="p.url" alt="" class="rv-thumb" />
            <span v-if="photos.length > 6" class="rv-more">+{{ photos.length - 6 }}</span>
          </span>
        </button>

        <button type="button" class="rv-block rv-block--tap" @click="step = 4">
          <span class="rv-block-head">
            <IconifyIcon icon="lucide:shield-check" width="14" />
            Permits
            <span class="rv-count">{{ attachedPermits }}/{{ DOC_TYPES.length }}</span>
            <IconifyIcon icon="lucide:pencil" width="13" class="rv-edit" />
          </span>
          <span v-for="d in DOC_TYPES" :key="d.key" class="rv-line rv-line--check">
            <IconifyIcon icon="lucide:check" width="13" class="rv-check" />
            <span>{{ d.label }}</span>
          </span>
        </button>

        <p class="sec-hint">
          Your listing starts as pending — OSAS reviews it before students can see or apply to it.
        </p>
      </section>
    </div>

    <!-- Camera / upload sit just above the footer, the way the room photo
         sheet does it, so they stay reachable however far the list scrolls. -->
    <div v-if="step === 3" class="photo-actions photo-actions--pinned">
      <button type="button" class="photo-action-btn" @click="takeExteriorPhoto">
        <IconifyIcon icon="lucide:camera" width="15" />
        Take photo
      </button>
      <label class="photo-action-btn">
        <IconifyIcon icon="lucide:image-plus" width="15" />
        Upload
        <input type="file" accept="image/*" multiple class="file-input-hidden" @change="onPhotosSelected" />
      </label>
    </div>

    <p v-if="blockReason" class="block-hint" :class="{ 'block-hint--above-actions': step === 3 }">
      <IconifyIcon icon="lucide:info" width="13" />
      {{ blockReason }}
    </p>

    <div class="nav">
      <button v-if="step > 1" type="button" class="nav-btn nav-btn--ghost" @click="step--">Back</button>
      <button
        v-if="step < 5"
        type="button"
        class="nav-btn"
        :disabled="nextBlocked"
        @click="step++"
      >
        Next
      </button>
      <button v-else type="button" class="nav-btn" :disabled="submitting" @click="submit">
        {{ submitting ? 'Creating…' : 'Create accommodation' }}
      </button>
    </div>

    <LocationPicker
      v-if="locationPickerOpen"
      v-model="locationPickerOpen"
      :initial-lat="form.lat"
      :initial-lng="form.lng"
      @confirm="onLocationConfirmed"
    />
  </q-page>
</template>

<script setup lang="ts">
import { reactive, ref, computed, defineAsyncComponent } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { uploadDocument, uploadPrivateDocument } from '@/utils/upload'
import { AMENITY_META, AMENITY_KEYS, BUILDING_TYPE_LABEL } from '@/utils/listings'
import { staticMapUrl } from '@/utils/geo'
import { to12Hour } from '@/utils/format'
import { capturePhoto } from '@/utils/camera'
import type { Database } from '@/types/database.gen'

// Loaded on demand — mapbox-gl (pulled in only by this component) is by far
// the heaviest dependency in the app, and the picker is opened rarely.
const LocationPicker = defineAsyncComponent(() => import('@/components/manager/LocationPicker.vue'))

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
const uploadingPermit = ref('')

const attachedPermits = computed(() => DOC_TYPES.filter((d) => permits[d.key]).length)
const permitsComplete = computed(() => attachedPermits.value === DOC_TYPES.length)

/** What's still missing on the current step, or '' when it's complete. Every
 * step has to be satisfied before moving on — OSAS can't review a listing
 * that's missing its type, location, photos or permits, so there's no point
 * letting one reach the review step half-filled. Shown to the user rather
 * than only disabling Next, which otherwise gives no clue what's wrong. */
const blockReason = computed(() => {
  if (step.value === 1) {
    if (!form.name.trim()) return 'Give your accommodation a name.'
    if (!form.accommodationType) return 'Choose what type of place this is.'
    if (form.lat === null || form.lng === null) return 'Set the location on the map.'
    // Normally filled by the map pick, but a reverse-geocode can come back
    // empty, so they still have to be confirmed rather than silently blank.
    if (!form.barangay.trim()) return 'Add the barangay.'
    if (!form.city.trim()) return 'Add the city or municipality.'
  }
  if (step.value === 2) {
    if (!form.amenities.length) return 'Pick at least one amenity.'
    if (!form.curfewTime) return 'Set a curfew time.'
    if (!form.quietFrom || !form.quietTo) return 'Set both ends of quiet hours.'
    if (!form.visitorPolicy.trim()) return 'Describe your visitor policy.'
  }
  if (step.value === 3 && !photos.value.length) return 'Add at least one exterior photo.'
  if (step.value === 4 && !permitsComplete.value) {
    return `Attach all ${DOC_TYPES.length} permits (${attachedPermits.value} so far).`
  }
  return ''
})
const nextBlocked = computed(() => blockReason.value !== '')

const form = reactive({
  name: '',
  accommodationType: '',
  barangay: '',
  city: '',
  description: '',
  lat: null as number | null,
  lng: null as number | null,
  amenities: [] as string[],
  // Times come from <input type="time">, so they're always "HH:MM" (24h)
  // here and get formatted for storage — the columns are free text and the
  // handful of existing rows disagree with each other ("10:00PM" vs
  // "10:00 PM", "10PM - 6AM"), so the picker is what makes them consistent.
  curfewTime: '',
  quietFrom: '',
  quietTo: '',
  visitorPolicy: '',
  cooking: true,
  laundry: true,
  pets: false,
  smoking: false,
})

const quietHoursLabel = computed(() =>
  form.quietFrom && form.quietTo ? `${to12Hour(form.quietFrom)} – ${to12Hour(form.quietTo)}` : '',
)

const locationPickerOpen = ref(false)
const locationPreviewUrl = computed(() => staticMapUrl(form.lat, form.lng, 160, 90))
const locationSummary = computed(
  () => [form.barangay.trim(), form.city.trim()].filter(Boolean).join(', ') || (form.lat != null ? 'Pinned on map' : '—'),
)

// The map is the source of truth here, so a fresh pick overwrites the two
// fields rather than only filling blanks — otherwise correcting a wrong pin
// leaves the old barangay/city stranded next to the new coordinates.
function onLocationConfirmed(payload: { lat: number; lng: number; barangay: string; city: string }) {
  form.lat = payload.lat
  form.lng = payload.lng
  if (payload.barangay) form.barangay = payload.barangay
  if (payload.city) form.city = payload.city
}

function toggle(list: string[], value: string) {
  const i = list.indexOf(value)
  if (i === -1) list.push(value)
  else list.splice(i, 1)
}

async function addExteriorPhotos(files: File[]) {
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
  }
}

async function onPhotosSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files ?? [])
  input.value = ''
  await addExteriorPhotos(files)
}

async function takeExteriorPhoto() {
  const { file, error } = await capturePhoto()
  if (error) notify.error(error)
  if (file) await addExteriorPhotos([file])
}

async function takePermitPhoto(docType: string) {
  const { file, error } = await capturePhoto()
  if (error) notify.error(error)
  if (file) await uploadPermit(file, docType)
}

async function uploadPermit(file: File, docType: string) {
  uploadingPermit.value = docType
  try {
    // Permits are sensitive: private bucket, signed on read. The bucket policies
    // key off the first path segment, so it has to be the uploader's own id.
    const { data: authData } = await supabase.auth.getUser()
    const uid = authData?.user?.id
    if (!uid) throw new Error('Not signed in.')
    permits[docType] = await uploadPrivateDocument(file, uid, docType)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload that permit.'))
  } finally {
    uploadingPermit.value = ''
  }
}

async function onPermitSelected(event: Event, docType: string) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (file) await uploadPermit(file, docType)
}

async function submit() {
  if (submitting.value) return
  // Walk back to the first incomplete step rather than only checking the last
  // one — the nav gates each step, but this stays correct if that ever slips.
  for (const s of [1, 2, 3, 4]) {
    step.value = s
    if (blockReason.value) {
      notify.error(blockReason.value)
      return
    }
  }
  step.value = 5
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
        // No address field any more — the student side already falls back to
        // "Barangay, City" when this is null.
        address: null,
        barangay: form.barangay.trim() || null,
        city: form.city.trim() || null,
        description: form.description.trim() || null,
        lat: form.lat,
        lng: form.lng,
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
      curfew_time: to12Hour(form.curfewTime) || null,
      quiet_hours: quietHoursLabel.value || null,
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
  /* Height of the fixed footer (10 + 46 button + 10 + its border), kept in
     one place so the pinned action bar and the scroll padding can't drift
     out of step with it. */
  --wiz-nav-h: calc(67px + env(safe-area-inset-bottom));
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

.location-row {
  display: flex;
  align-items: center;
  gap: 10px;
}
.location-preview {
  width: 56px;
  height: 40px;
  flex: 0 0 56px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  object-fit: cover;
}
.location-btn {
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
.permit-icon {
  display: grid;
  width: 28px;
  height: 28px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: 999px;
  background: var(--m-border);
  color: var(--m-muted);
}
.permit-row--done .permit-icon {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.permit-body {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 1px;
}
.permit-label {
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
.permit-spin {
  flex: 0 0 auto;
  color: var(--m-muted);
  animation: permit-spin 0.9s linear infinite;
}
@keyframes permit-spin {
  to { transform: rotate(360deg); }
}

/* Attach progress — the step can't be passed until this fills. */
.permit-progress {
  display: flex;
  align-items: center;
  gap: 8px;
}
.permit-progress-bar {
  position: relative;
  display: block;
  height: 6px;
  flex: 1 1 auto;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-border);
}
.permit-progress-bar > span {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: var(--m-primary);
  transition: width 200ms ease;
}
.permit-progress-text {
  flex: 0 0 auto;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
}

/* Camera / upload pair — same shape as the room photo actions. */
.photo-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.req {
  color: var(--m-negative, #c62828);
  font-weight: 800;
}

/* Review — a summary of what's actually being submitted, each block tapping
   back to the step that owns it. */
.rv-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.rv-shot {
  display: grid;
  width: 64px;
  height: 64px;
  flex: 0 0 auto;
  place-items: center;
  overflow: hidden;
  border-radius: var(--m-radius-sm, 10px);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.rv-shot img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.rv-shot--empty {
  background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%);
  color: var(--m-muted);
}
.rv-head {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
}
.rv-name {
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.rv-type {
  color: var(--m-primary-dark);
  font-size: 11.5px;
  font-weight: 700;
}
.rv-where {
  display: flex;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
  font-size: 11.5px;
}

.rv-block {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 6px;
  padding: 11px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  font: inherit;
  text-align: left;
}
.rv-block--tap {
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.rv-block-head {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--m-ink);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.rv-count {
  padding: 1px 7px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 10.5px;
  font-weight: 800;
}
.rv-edit {
  margin-left: auto;
  color: var(--m-muted);
}
.rv-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
}
.rv-chip {
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 11px;
  font-weight: 700;
}
.rv-chip--off {
  background: var(--m-border);
  color: var(--m-muted);
}
.rv-line {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  color: var(--m-muted);
  font-size: 12px;
}
.rv-line strong {
  color: var(--m-ink);
  font-weight: 700;
  text-align: right;
}
.rv-line--check {
  justify-content: flex-start;
  color: var(--m-ink);
}
.rv-check {
  flex: 0 0 auto;
  color: var(--m-success);
}
.rv-strip {
  display: flex;
  align-items: center;
  gap: 6px;
  overflow-x: auto;
}
.rv-thumb {
  width: 52px;
  height: 52px;
  flex: 0 0 auto;
  object-fit: cover;
  border-radius: var(--m-radius-sm, 8px);
}
.rv-more {
  display: grid;
  width: 52px;
  height: 52px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: var(--m-radius-sm, 8px);
  background: var(--m-border);
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 800;
}

/* Says what's still missing, since a disabled Next on its own gives no clue. */
.block-hint {
  position: fixed;
  right: 0;
  bottom: var(--wiz-nav-h);
  left: 0;
  z-index: 5;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin: 0;
  padding: 7px var(--m-page-gutter);
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
  text-align: center;
}
/* On the photos step the camera/upload bar already sits there, so stack above it. */
.block-hint--above-actions {
  bottom: calc(var(--wiz-nav-h) + 59px);
}

/* Clears the pinned action bar so the last thumbnail isn't hidden behind it. */
.sec--pinned-actions {
  padding-bottom: 58px;
}
.photo-actions--pinned {
  position: fixed;
  right: 0;
  bottom: var(--wiz-nav-h);
  left: 0;
  z-index: 5;
  padding: 10px var(--m-page-gutter);
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
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
/* Compact per-permit versions of the same two actions. */
.permit-act {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 auto;
  place-items: center;
  padding: 0;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.permit-status--muted {
  color: var(--m-muted);
  font-weight: 600;
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
