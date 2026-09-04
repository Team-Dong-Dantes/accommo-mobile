<template>
  <q-page class="rp">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="180px" class="sk" />
      <q-skeleton type="rect" height="90px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load this room</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn
          unelevated
          rounded
          no-caps
          dense
          color="primary"
          label="Try again"
          class="q-mt-sm q-px-md"
          @click="load"
        />
      </q-card>
    </div>

    <div v-else class="stack">
      <div v-if="images.length" class="gal">
        <img v-for="(src, i) in images" :key="i" :src="src" :alt="room.label" class="gal-img" />
        <span v-if="images.length > 1" class="gal-count">
          <IconifyIcon icon="lucide:image" width="11" />{{ images.length }}
        </span>
      </div>
      <div v-else class="gal-none">
        <span class="gal-mono">{{ monogram }}</span>
      </div>

      <div class="head">
        <h1 class="head-name">{{ room.label }}</h1>
        <button type="button" class="head-where" @click="router.push(`/student/listing/${room.propertyId}`)">
          <IconifyIcon icon="lucide:building-2" width="12" />
          {{ room.propertyName }}
        </button>
        <span class="badge">
          <IconifyIcon icon="lucide:shield-check" width="11" />OSAS Accredited
        </span>
        <p v-if="room.rent" class="head-price">
          {{ formatPeso(room.rent) }}<span class="head-price-per">/mo</span>
        </p>
        <p v-else class="head-price head-price--none">Rent on request</p>
        <div class="head-tags">
          <span v-if="typeLabel" class="tag">{{ typeLabel }}</span>
          <span v-if="room.capacity" class="tag tag--soft">Sleeps {{ room.capacity }}</span>
          <span v-if="room.floor" class="tag tag--soft">Floor {{ room.floor }}</span>
          <span v-if="distance" class="tag tag--soft">
            <IconifyIcon icon="lucide:map-pin" width="11" />{{ distance }}
          </span>
          <span class="tag" :class="room.free ? 'tag--ok' : 'tag--none'">
            {{ room.free ? 'Available' : 'Taken' }}
          </span>
        </div>
      </div>

      <!-- What it costs to move in -->
      <section v-if="moveIn" class="sec">
        <h2 class="sec-title">Move-in cost</h2>
        <div class="group">
          <div v-if="moveIn.advance" class="rule">
            <span class="rule-label">Advance ({{ moveIn.advanceMonths }} mo)</span>
            <span class="rule-value">{{ formatPeso(moveIn.advance) }}</span>
          </div>
          <div v-if="moveIn.deposit" class="rule">
            <span class="rule-label">Deposit ({{ moveIn.depositMonths }} mo)</span>
            <span class="rule-value">{{ formatPeso(moveIn.deposit) }}</span>
          </div>
          <div class="rule rule--total">
            <span class="rule-label">Total due at signing</span>
            <span class="rule-value">{{ formatPeso(moveIn.total) }}</span>
          </div>
        </div>
      </section>

      <!-- What's in this room specifically, if anything was published -->
      <section v-if="facilities.length" class="sec">
        <h2 class="sec-title">In this room</h2>
        <div class="ams">
          <span v-for="f in facilities" :key="f.type + f.label" class="am">
            <IconifyIcon :icon="FACILITY_META[f.type]?.icon || 'lucide:dot'" width="14" />
            {{ f.label || FACILITY_META[f.type]?.label || f.type }}
          </span>
        </div>
      </section>

      <!-- Amenities are property-level; a room has no set of its own -->
      <section v-if="amenities.length" class="sec">
        <h2 class="sec-title">What's here</h2>
        <div class="ams">
          <span v-for="a in amenities" :key="a" class="am">
            <IconifyIcon :icon="AMENITY_META[a]?.icon || 'lucide:dot'" width="14" />
            {{ AMENITY_META[a]?.label || a }}
          </span>
        </div>
      </section>

      <!-- The person to ask -->
      <section v-if="manager.id" class="sec">
        <h2 class="sec-title">Managed by</h2>
        <button type="button" class="mgr" @click="router.push(`/student/manager/${manager.id}`)">
          <span class="mgr-avatar">{{ manager.initials }}</span>
          <span class="mgr-body">
            <span class="mgr-name">{{ manager.name }}</span>
            <span class="mgr-sub">
              {{ manager.replyMinutes ? `Replies in ~${manager.replyMinutes} min` : 'Accommodation manager' }}
            </span>
          </span>
        </button>
      </section>

      <div class="tail" />
    </div>

    <div v-if="!loading && !error && manager.id" class="cta">
      <button type="button" class="cta-btn cta-btn--ghost" @click="router.push(`/student/messages?to=${manager.id}`)">
        <IconifyIcon icon="lucide:message-circle" width="17" />
        Message
      </button>
      <button v-if="room.free && !myLease.hasAny" type="button" class="cta-btn" @click="openApply">
        <IconifyIcon icon="lucide:file-check-2" width="17" />
        Apply for this room
      </button>
      <span v-else-if="myLease.onThisRoom" class="cta-note">Applied — awaiting response</span>
      <span v-else-if="myLease.hasAny" class="cta-note">You already have a stay</span>
      <span v-else class="cta-note">This room is taken</span>
    </div>

    <q-dialog v-model="applyOpen" position="bottom">
      <q-card class="apply-sheet">
        <h3 class="apply-title">Apply for {{ room.label }}</h3>
        <label class="apply-field">
          <span class="apply-label">Move-in date</span>
          <input v-model="applyForm.startDate" type="date" class="apply-date" :min="todayStr()" />
        </label>
        <div class="group">
          <div class="rule">
            <span class="rule-label">Lease term ends</span>
            <span class="rule-value">{{ applyEndDate }}</span>
          </div>
          <div class="rule">
            <span class="rule-label">Monthly rent</span>
            <span class="rule-value">{{ formatPeso(room.rent) }}</span>
          </div>
        </div>
        <q-btn
          unelevated
          rounded
          no-caps
          color="primary"
          class="apply-submit"
          :loading="applying"
          label="Submit application"
          @click="submitApplication"
        />
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useNotify } from '@/utils/notify'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatPeso, initialsOf } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel } from '@/utils/geo'
import { AMENITY_META, FACILITY_META, roomTypeLabel, listingMonogram } from '@/utils/listings'
import { createNotification } from '@/boot/notify'

const route = useRoute()
const router = useRouter()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const room = reactive({
  label: '',
  propertyId: '',
  propertyName: '',
  type: null as string | null,
  capacity: null as number | null,
  floor: null as number | null,
  rent: 0,
  free: false,
  lat: null as number | null,
  lng: null as number | null,
})
const images = ref<string[]>([])
const amenities = ref<string[]>([])
const facilities = ref<{ type: string; label: string | null }[]>([])
const policy = reactive({ advanceMonths: 0, depositMonths: 0, minStay: 0 })
const manager = reactive({ id: '', name: '', initials: '?', replyMinutes: null as number | null })
const myLease = reactive({ hasAny: false, onThisRoom: false })
const applyOpen = ref(false)
const applying = ref(false)
const applyForm = reactive({ startDate: todayStr() })

const id = computed(() => String(route.params.id || ''))
const monogram = computed(() => listingMonogram(room.propertyName))
const typeLabel = computed(() => (room.type ? roomTypeLabel(room.type) : ''))
const distance = computed(() => campusDistanceLabel(room.lat, room.lng))
const moveIn = computed(() => {
  if (!room.rent || (!policy.advanceMonths && !policy.depositMonths)) return null
  const advance = policy.advanceMonths * room.rent
  const deposit = policy.depositMonths * room.rent
  return {
    advanceMonths: policy.advanceMonths,
    depositMonths: policy.depositMonths,
    advance,
    deposit,
    total: advance + deposit,
  }
})

function todayStr(): string {
  return new Date().toISOString().slice(0, 10)
}

function addMonths(dateStr: string, months: number): string {
  const d = new Date(dateStr)
  d.setMonth(d.getMonth() + months)
  return d.toISOString().slice(0, 10)
}

const applyEndDate = computed(() => addMonths(applyForm.startDate || todayStr(), policy.minStay || 12))

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data, error: loadError } = await supabase
      .from('rooms')
      .select(
        'id,label,room_number,room_type,custom_room_type,capacity,floor,monthly_rent,status,room_images(url,sort_order),accommodation_facilities(facility_type,label),accommodations(id,name,address,city,barangay,lat,lng,accommodation_manager_id,status,accommodation_amenities(amenity),accommodation_images(url,sort_order),accommodation_policies(advance_months,deposit_months,min_stay))',
      )
      .eq('id', id.value)
      .maybeSingle()
    if (loadError) throw loadError

    const property = data?.accommodations as
      | {
          id: string
          name: string | null
          accommodation_manager_id: string | null
          status: string
          lat: number | null
          lng: number | null
          accommodation_amenities: { amenity: string }[] | null
          accommodation_images: { url: string; sort_order: number | null }[] | null
          accommodation_policies: unknown
        }
      | null
    if (!data || !property || property.status !== 'accredited') {
      error.value = 'This room is no longer available.'
      return
    }

    room.label = data.label || (data.room_number ? `Room ${data.room_number}` : 'Room')
    room.propertyId = property.id
    room.propertyName = property.name?.trim() || 'Unnamed accommodation'
    room.type = data.custom_room_type || data.room_type
    room.capacity = data.capacity
    room.floor = data.floor
    room.rent = Number(data.monthly_rent ?? 0)
    room.free = data.status === 'available'
    room.lat = property.lat
    room.lng = property.lng

    amenities.value = (property.accommodation_amenities ?? []).map((a) => a.amenity)

    facilities.value = ((data.accommodation_facilities ?? []) as { facility_type: string; label: string | null }[])
      .map((f) => ({ type: f.facility_type, label: f.label }))

    // accommodation_policies is one row per accommodation, but the embed
    // returns it as an array when the relationship is not marked one-to-one.
    const policyRows = property.accommodation_policies as unknown
    const policyRow = (Array.isArray(policyRows) ? policyRows[0] : policyRows) as
      | { advance_months: number | null; deposit_months: number | null; min_stay: number | null }
      | null
    policy.advanceMonths = policyRow?.advance_months ?? 0
    policy.depositMonths = policyRow?.deposit_months ?? 0
    policy.minStay = policyRow?.min_stay ?? 0

    // Most rooms have no photos of their own yet — fall back to the
    // property's photos rather than showing a bare monogram.
    const roomImages = [...((data.room_images ?? []) as { url: string; sort_order: number | null }[])].sort(
      (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
    )
    const sourceImages = roomImages.length
      ? roomImages
      : [...(property.accommodation_images ?? [])].sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
    images.value = sourceImages.map((i) => resolveAsset(i.url)).filter(Boolean)

    if (property.accommodation_manager_id) {
      const [{ data: person }, { data: profile }] = await Promise.all([
        supabase
          .from('users')
          .select('full_name,initials')
          .eq('id', property.accommodation_manager_id)
          .maybeSingle(),
        supabase
          .from('accommodation_manager_profiles')
          .select('avg_response_minutes')
          .eq('user_id', property.accommodation_manager_id)
          .maybeSingle(),
      ])
      manager.id = property.accommodation_manager_id
      manager.name = person?.full_name || 'Accommodation manager'
      manager.initials = person?.initials || initialsOf(manager.name)
      manager.replyMinutes = profile?.avg_response_minutes ?? null
    }

    const { data: authData } = await supabase.auth.getUser()
    const uid = authData?.user?.id
    if (uid) {
      const { data: mine } = await supabase
        .from('leases')
        .select('room_id,status')
        .eq('student_id', uid)
        .in('status', ['pending', 'active', 'leave_requested'])
      const list = mine ?? []
      myLease.hasAny = list.length > 0
      myLease.onThisRoom = list.some((l) => l.room_id === id.value)
    }
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

function openApply() {
  applyForm.startDate = todayStr()
  applyOpen.value = true
}

async function submitApplication() {
  if (applying.value) return
  applying.value = true
  try {
    const { data: authData } = await supabase.auth.getUser()
    const uid = authData?.user?.id
    if (!uid) {
      void router.push('/login')
      return
    }

    const [{ data: studentProfile }, { data: person }] = await Promise.all([
      supabase.from('student_profiles').select('osas_verified_at').eq('user_id', uid).maybeSingle(),
      supabase.from('users').select('full_name').eq('id', uid).maybeSingle(),
    ])
    if (!studentProfile?.osas_verified_at) {
      applyOpen.value = false
      notify.warning('Get OSAS-verified before applying for a room.')
      void router.push('/student/support')
      return
    }

    const { data: created, error: insertError } = await supabase
      .from('leases')
      .insert({
        room_id: id.value,
        student_id: uid,
        accommodation_manager_id: manager.id,
        start_date: applyForm.startDate,
        end_date: applyEndDate.value,
        monthly_rent: room.rent,
        status: 'pending',
      })
      .select('id')
      .single()
    if (insertError) throw insertError

    void createNotification(
      manager.id,
      'New application',
      `${person?.full_name || 'A student'} applied for ${room.label}`,
      'lease',
      `/manager/tenant/${created.id}`,
    )

    myLease.hasAny = true
    myLease.onThisRoom = true
    applyOpen.value = false
    notify.success('Application submitted.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not submit your application.'))
  } finally {
    applying.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.rp {
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 8px var(--m-page-gutter) 0;
}
.sk {
  border-radius: var(--m-radius);
}
.tail {
  height: 78px;
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

.gal {
  position: relative;
  display: flex;
  gap: 6px;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
}
.gal-img {
  width: 88%;
  height: 190px;
  flex: 0 0 auto;
  border-radius: var(--m-radius);
  object-fit: cover;
  scroll-snap-align: start;
}
.gal-count {
  position: absolute;
  top: 8px;
  right: 8px;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 8px;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.7);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
}
.gal-none {
  display: grid;
  height: 120px;
  place-items: center;
  border-radius: var(--m-radius);
  background: var(--m-primary-soft);
}
.gal-mono {
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 34px;
  font-weight: 800;
}

.head-name {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 21px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
}
.head-where {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin: 3px 0 0;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 600;
  -webkit-tap-highlight-color: transparent;
}
.badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin-top: 5px;
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-success-soft);
  color: var(--m-success);
  font-size: 11px;
  font-weight: 700;
}
.head-price {
  margin: 10px 0 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 24px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.head-price--none {
  color: var(--m-muted);
  font-family: var(--m-font-body);
  font-size: 14px;
  font-weight: 600;
}
.head-price-per {
  font-size: 13px;
  font-weight: 600;
  opacity: 0.7;
}
.head-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 8px;
}
.tag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 10px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 11.5px;
  font-weight: 700;
}
.tag--soft {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.tag--ok {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.tag--none {
  background: var(--m-bg);
  color: var(--m-muted);
}

.sec {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.sec-title {
  margin: 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
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
.rule--total .rule-label,
.rule--total .rule-value {
  color: var(--m-ink);
  font-weight: 700;
}

/* Amenities */
.ams {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.am {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 7px 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  font-size: 12.5px;
  font-weight: 600;
}

.mgr {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 11px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.mgr-avatar {
  display: grid;
  width: 40px;
  height: 40px;
  flex: 0 0 40px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 800;
}
.mgr-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
}
.mgr-name {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.mgr-sub {
  color: var(--m-muted);
  font-size: 11.5px;
}

.cta {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 5;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px var(--m-page-gutter) calc(10px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.cta-btn {
  display: inline-flex;
  flex: 1;
  align-items: center;
  justify-content: center;
  gap: 7px;
  min-height: 46px;
  padding: 0 16px;
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
.cta-btn--ghost {
  flex: 0 0 auto;
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}
.cta-note {
  flex: 1;
  padding: 0 8px;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
  text-align: center;
}

.apply-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.apply-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.apply-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.apply-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.apply-date {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.apply-submit {
  min-height: 48px;
  font-weight: 700;
}
</style>
