<template>
  <q-page class="lp">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="180px" class="sk" />
      <q-skeleton type="rect" height="90px" class="sk" />
      <q-skeleton type="rect" height="140px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load this listing</p>
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
      <!-- Photos, or a monogram band when there are none -->
      <div v-if="images.length" class="gal">
        <img v-for="(src, i) in images" :key="i" :src="src" :alt="listing.name" class="gal-img" />
      </div>
      <div v-else class="gal-none">
        <span class="gal-mono">{{ monogram }}</span>
      </div>

      <div class="head">
        <h1 class="head-name">{{ listing.name }}</h1>
        <p class="head-where">{{ listing.address }}</p>
        <div class="head-tags">
          <span v-if="buildingType" class="tag">{{ buildingType }}</span>
          <span v-if="distance" class="tag tag--soft">
            <IconifyIcon icon="lucide:map-pin" width="11" />{{ distance }}
          </span>
          <span class="tag" :class="vacancies ? 'tag--ok' : 'tag--none'">
            {{ vacancies ? `${vacancies} room${vacancies === 1 ? '' : 's'} free` : 'Currently full' }}
          </span>
        </div>
      </div>

      <p v-if="listing.description" class="desc">{{ listing.description }}</p>

      <!-- Rooms -->
      <section class="sec">
        <h2 class="sec-title">Rooms</h2>
        <div class="group">
          <div v-for="room in rooms" :key="room.id" class="room" :class="{ 'room--taken': !room.free }">
            <span class="room-body">
              <span class="room-name">{{ room.label }}</span>
              <span class="room-meta">{{ room.meta }}</span>
            </span>
            <span class="room-side">
              <span v-if="room.rent" class="room-rent">{{ formatPeso(room.rent) }}<span class="room-per">/mo</span></span>
              <span v-else class="room-rent room-rent--none">On request</span>
              <span class="room-tag" :class="room.free ? 'room-tag--ok' : 'room-tag--none'">
                {{ room.free ? 'Available' : 'Taken' }}
              </span>
            </span>
          </div>
          <p v-if="!rooms.length" class="none">This listing hasn't published any rooms yet</p>
        </div>
      </section>

      <!-- Amenities -->
      <section v-if="amenities.length" class="sec">
        <h2 class="sec-title">What's here</h2>
        <div class="ams">
          <span v-for="a in amenities" :key="a" class="am">
            <IconifyIcon :icon="AMENITY_META[a]?.icon || 'lucide:dot'" width="14" />
            {{ AMENITY_META[a]?.label || a }}
          </span>
        </div>
      </section>

      <!-- House rules -->
      <section v-if="rules.length" class="sec">
        <h2 class="sec-title">House rules</h2>
        <div class="group">
          <div v-for="rule in rules" :key="rule.label" class="rule">
            <span class="rule-label">{{ rule.label }}</span>
            <span class="rule-value">{{ rule.value }}</span>
          </div>
        </div>
      </section>

      <!-- Where it is, relative to school -->
      <section v-if="mapUrl" class="sec">
        <h2 class="sec-title">Where it is</h2>
        <div class="map">
          <img :src="mapUrl" :alt="`Map showing ${listing.name} and ${CAMPUS.label}`" loading="lazy" />
          <p class="map-note">
            <IconifyIcon icon="lucide:school" width="12" />
            {{ distance || 'Distance unknown' }} · {{ CAMPUS.label }}
          </p>
        </div>
      </section>

      <!-- The person to ask -->
      <section v-if="manager.id" class="sec">
        <h2 class="sec-title">Managed by</h2>
        <div class="mgr">
          <span class="mgr-avatar">{{ manager.initials }}</span>
          <span class="mgr-body">
            <span class="mgr-name">{{ manager.name }}</span>
            <span class="mgr-sub">
              {{ manager.replyMinutes ? `Replies in ~${manager.replyMinutes} min` : 'Accommodation manager' }}
            </span>
          </span>
        </div>
      </section>

      <div class="tail" />
    </div>

    <!-- Enquiry hand-off: the conversation is where applying happens -->
    <div v-if="!loading && !error && manager.id" class="cta">
      <span class="cta-price">
        <template v-if="minRent !== null">
          {{ formatPeso(minRent) }}<span class="cta-per">/mo</span>
        </template>
        <template v-else>Rent on request</template>
      </span>
      <button type="button" class="cta-btn" @click="messageManager">
        <IconifyIcon icon="lucide:message-circle" width="17" />
        Message manager
      </button>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatPeso, initialsOf } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel, staticMapUrl, CAMPUS } from '@/utils/geo'
import { AMENITY_META, roomTypeLabel, buildingTypeLabel, listingMonogram } from '@/utils/listings'

interface RoomRow {
  id: string
  label: string
  meta: string
  rent: number
  free: boolean
}

const route = useRoute()
const router = useRouter()

const loading = ref(true)
const error = ref('')
const listing = reactive({
  name: '',
  address: '',
  description: '',
  type: '' as string | null,
  lat: null as number | null,
  lng: null as number | null,
})
const images = ref<string[]>([])
const rooms = ref<RoomRow[]>([])
const amenities = ref<string[]>([])
const rules = ref<{ label: string; value: string }[]>([])
const manager = reactive({ id: '', name: '', initials: '?', replyMinutes: null as number | null })

const id = computed(() => String(route.params.id || ''))
const monogram = computed(() => listingMonogram(listing.name))
const buildingType = computed(() => buildingTypeLabel(listing.type))
const distance = computed(() => campusDistanceLabel(listing.lat, listing.lng))
const mapUrl = computed(() => staticMapUrl(listing.lat, listing.lng))
const vacancies = computed(() => rooms.value.filter((r) => r.free).length)
const minRent = computed(() => {
  const priced = rooms.value.map((r) => r.rent).filter((n) => n > 0)
  return priced.length ? Math.min(...priced) : null
})

function messageManager() {
  void router.push(`/student/messages?to=${manager.id}`)
}

function yesNo(value: boolean | null | undefined): string {
  if (value === null || value === undefined) return ''
  return value ? 'Allowed' : 'Not allowed'
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data, error: loadError } = await supabase
      .from('accommodations')
      .select(
        'id,name,address,city,barangay,description,accommodation_type,lat,lng,accommodation_manager_id,rooms(id,room_number,label,room_type,custom_room_type,capacity,monthly_rent,status),accommodation_amenities(amenity),accommodation_images(url,sort_order),accommodation_policies(curfew_time,quiet_hours,visitor_policy,cooking,laundry,pets,smoking,deposit_months,advance_months,min_stay,contract_type)',
      )
      .eq('id', id.value)
      .eq('status', 'accredited')
      .maybeSingle()
    if (loadError) throw loadError
    if (!data) {
      error.value = 'This listing is no longer available.'
      return
    }

    listing.name = data.name?.trim() || 'Unnamed accommodation'
    listing.address =
      data.address || [data.barangay, data.city].filter(Boolean).join(', ') || 'Address not given'
    listing.description = data.description || ''
    listing.type = data.accommodation_type
    listing.lat = data.lat
    listing.lng = data.lng

    images.value = [...((data.accommodation_images ?? []) as { url: string; sort_order: number | null }[])]
      .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
      .map((i) => resolveAsset(i.url))
      .filter(Boolean)

    rooms.value = ((data.rooms ?? []) as {
      id: string
      room_number: string | null
      label: string | null
      room_type: string | null
      custom_room_type: string | null
      capacity: number | null
      monthly_rent: number | null
      status: string
    }[])
      .map((r) => ({
        id: r.id,
        label: r.label || (r.room_number ? `Room ${r.room_number}` : 'Room'),
        meta: [
          roomTypeLabel(r.custom_room_type || r.room_type),
          r.capacity ? `sleeps ${r.capacity}` : '',
        ]
          .filter(Boolean)
          .join(' · '),
        rent: Number(r.monthly_rent ?? 0),
        free: r.status === 'available',
      }))
      .sort((a, b) => Number(b.free) - Number(a.free) || a.rent - b.rent)

    amenities.value = ((data.accommodation_amenities ?? []) as { amenity: string }[]).map(
      (a) => a.amenity,
    )

    // accommodation_policies is one row per accommodation, but the embed
    // returns it as an array when the relationship is not marked one-to-one.
    const policyRows = data.accommodation_policies as unknown
    const policy = (Array.isArray(policyRows) ? policyRows[0] : policyRows) as
      | Record<string, unknown>
      | null
    if (policy) {
      const built: { label: string; value: string }[] = [
        { label: 'Curfew', value: String(policy.curfew_time ?? '') },
        { label: 'Quiet hours', value: String(policy.quiet_hours ?? '') },
        { label: 'Visitors', value: String(policy.visitor_policy ?? '') },
        { label: 'Cooking', value: yesNo(policy.cooking as boolean | null) },
        { label: 'Laundry', value: yesNo(policy.laundry as boolean | null) },
        { label: 'Pets', value: yesNo(policy.pets as boolean | null) },
        { label: 'Smoking', value: yesNo(policy.smoking as boolean | null) },
        {
          label: 'Deposit',
          value: policy.deposit_months ? `${policy.deposit_months} month(s)` : '',
        },
        {
          label: 'Advance',
          value: policy.advance_months ? `${policy.advance_months} month(s)` : '',
        },
        { label: 'Minimum stay', value: policy.min_stay ? `${policy.min_stay} month(s)` : '' },
      ]
      rules.value = built.filter((r) => r.value)
    }

    if (data.accommodation_manager_id) {
      const [{ data: person }, { data: profile }] = await Promise.all([
        supabase
          .from('users')
          .select('full_name,initials')
          .eq('id', data.accommodation_manager_id)
          .maybeSingle(),
        supabase
          .from('accommodation_manager_profiles')
          .select('avg_response_minutes')
          .eq('user_id', data.accommodation_manager_id)
          .maybeSingle(),
      ])
      manager.id = data.accommodation_manager_id
      manager.name = person?.full_name || 'Accommodation manager'
      manager.initials = person?.initials || initialsOf(manager.name)
      manager.replyMinutes = profile?.avg_response_minutes ?? null
    }
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.lp {
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

/* Gallery */
.gal {
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
  margin: 3px 0 0;
  color: var(--m-muted);
  font-size: 13px;
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

.desc {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
  text-wrap: pretty;
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
.none {
  padding: 14px 12px;
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}

/* Rooms */
.room {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .room:first-child {
  border-top: 0;
}
.room--taken {
  opacity: 0.6;
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
.room-meta {
  color: var(--m-muted);
  font-size: 11.5px;
}
.room-side {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: flex-end;
  gap: 3px;
}
.room-rent {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 14.5px;
  font-weight: 700;
}
.room-rent--none {
  color: var(--m-muted);
  font-family: var(--m-font-body);
  font-size: 12px;
}
.room-per {
  font-size: 10.5px;
  font-weight: 600;
  opacity: 0.7;
}
.room-tag {
  padding: 1px 7px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}
.room-tag--ok {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.room-tag--none {
  background: var(--m-bg);
  color: var(--m-muted);
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

/* Rules */
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

/* Map */
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

/* Manager */
.mgr {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
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

/* Sticky enquiry bar */
.cta {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 5;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px var(--m-page-gutter) calc(10px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.cta-price {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.cta-per {
  font-size: 12px;
  font-weight: 600;
  opacity: 0.7;
}
.cta-btn {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-height: 46px;
  padding: 0 20px;
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
</style>
