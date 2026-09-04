<template>
<q-page class="profile-page">
  <main class="profile-content">
    <div v-if="loading" class="profile-state" role="status" aria-live="polite">
      <q-spinner color="primary" size="32px" />
      <span>Loading profile…</span>
    </div>
    <div v-else-if="error" class="profile-state profile-state--error" role="alert">
      <IconifyIcon icon="lucide:circle-alert" width="24" />
      <strong>We couldn’t load your profile.</strong>
      <span>{{ error }}</span>
      <q-btn outline no-caps color="primary" label="Try again" class="profile-state-action" @click="loadProfile" />
    </div>

    <template v-else>
      <!-- Identity -->
      <section class="surface-card identity-card" aria-label="Your details">
        <button type="button" class="identity-edit" aria-label="Edit profile" @click="openEdit">
          <IconifyIcon icon="lucide:pencil" width="16" />
        </button>
        <div class="identity-main">
          <q-avatar size="72px" class="identity-avatar text-white" @click="openEdit">
            <img v-if="profileImageUrl" :src="profileImageUrl" :alt="`${profile.fullName} profile photo`" />
            <span v-else>{{ profile.initials }}</span>
          </q-avatar>
          <div class="identity-copy">
            <h1 class="identity-name">{{ profile.fullName }}</h1>
            <p class="identity-sub">Manager · member since {{ profile.memberSince }}</p>
          </div>
        </div>
      </section>

      <!-- QR scanner (top utility, same place the student QR sits) -->
      <section class="surface-card qr-tool" aria-label="Student QR scanner">
        <span class="qr-tool-icon"><IconifyIcon icon="lucide:qr-code" width="22" /></span>
        <div class="qr-tool-copy">
          <h2>Student QR scanner</h2>
          <p>Verify a student before check-in</p>
        </div>
        <q-btn unelevated no-caps color="primary" label="Open scanner" class="qr-tool-btn" @click="openScanner" />
      </section>


      <!-- Your rating -->
      <section v-if="ratingData && ratingData.show" class="rating-kpi surface-card" aria-label="Your rating">
        <div class="rk-label">{{ ratingData.label }}</div>
        <div class="rk-main">
          <strong class="rk-value">{{ ratingData.value }}</strong>
          <span class="rk-stars" aria-hidden="true">
            <IconifyIcon v-for="n in 5" :key="n" icon="lucide:star" width="15" :class="{ 'rk-on': ratingData.stars >= n }" />
          </span>
        </div>
        <div class="rk-sub">{{ ratingData.countLabel }}</div>
      </section>


      <!-- Properties -->
      <nav class="list-group" aria-label="Properties">
        <p class="list-eyebrow">Properties</p>
        <div class="surface-card list-card">
          <button type="button" class="list-row" @click="openProperties">
            <span class="list-icon list-icon--primary"><IconifyIcon icon="lucide:building-2" width="19" /></span>
            <span class="list-copy"><strong>My properties</strong><small>{{ propertiesRowSub }}</small></span>
            <span class="list-chevron"><IconifyIcon icon="lucide:chevron-right" width="18" /></span>
          </button>
          <span class="list-divider" role="separator" />
          <button type="button" class="list-row" :disabled="!reviews.length" @click="openReviews">
            <span class="list-icon list-icon--warning"><IconifyIcon icon="lucide:star" width="19" /></span>
            <span class="list-copy"><strong>Recent reviews</strong><small>{{ reviewsRowSub }}</small></span>
            <span class="list-chevron"><IconifyIcon icon="lucide:chevron-right" width="18" /></span>
          </button>
        </div>
      </nav>

      <!-- Contact -->
      <nav class="list-group" aria-label="Contact">
        <p class="list-eyebrow">Contact</p>
        <div class="surface-card list-card">
          <button type="button" class="list-row" @click="openContact">
            <span class="list-icon list-icon--neutral"><IconifyIcon icon="lucide:map-pin" width="19" /></span>
            <span class="list-copy"><strong>Business contact</strong><small>{{ contactRowSub }}</small></span>
            <span class="list-chevron"><IconifyIcon icon="lucide:chevron-right" width="18" /></span>
          </button>
        </div>
      </nav>
      <!-- Settings -->
      <nav class="list-group" aria-label="Settings" role="navigation" data-bottom>
        <p class="list-eyebrow">Settings</p>
        <div class="surface-card list-card">
          <button type="button" class="list-row" @click="goToSettings">
            <span class="list-icon list-icon--neutral"><IconifyIcon icon="lucide:settings" width="19" /></span>
            <span class="list-copy"><strong>Settings</strong><small>Notifications and security</small></span>
            <span class="list-chevron"><IconifyIcon icon="lucide:chevron-right" width="18" /></span>
          </button>
          <span class="list-divider" role="separator" />
          <button type="button" class="list-row list-row--danger" @click="handleLogout">
            <span class="list-icon list-icon--danger"><IconifyIcon icon="lucide:log-out" width="19" /></span>
            <span class="list-copy"><strong>Log out</strong><small>Sign out of this device</small></span>
          </button>
        </div>
      </nav>

    </template>
  </main>

  <!-- Sheet: My properties -->
  <q-dialog v-model="propertiesSheet" position="bottom">
    <q-card class="sheet-card full-width pb-safe housesheet">
      <div class="sheet-header sheet-header--fixed">
        <span class="sheet-grip sheet-grip--inline" aria-hidden="true" />
        <h2 class="sheet-title">My properties</h2>
        <q-chip v-if="activeProperties" dense square color="primary" text-color="white" class="count-chip">{{ activeProperties }} active</q-chip>
      </div>
      <div class="sheet-body sheet-body--scroll">
        <p v-if="!properties.length" class="empty-note">You haven’t listed any properties yet.</p>
        <div v-else class="prop-list">
          <button v-for="property in properties" :key="property.id" type="button" class="prop-row" @click="openProperty(property.id)">
            <span class="prop-avatar"><IconifyIcon icon="lucide:building-2" width="18" /></span>
            <span class="prop-copy">
              <strong>{{ property.name }}</strong>
              <small>{{ property.address }}</small>
              <span class="prop-meta">
                <span class="prop-rating"><IconifyIcon icon="lucide:star" width="13" /> {{ property.rating.toFixed(1) }}</span>
                <span class="prop-occ">{{ property.occupied }}/{{ property.total }} occupied</span>
              </span>
              <span class="prop-progress"><span :style="{ width: property.total ? `${Math.min(100, (property.occupied / property.total) * 100)}%` : '0%' }" /></span>
            </span>
            <span class="list-chevron"><IconifyIcon icon="lucide:chevron-right" width="18" /></span>
          </button>
        </div>
      </div>
    </q-card>
  </q-dialog>

  <!-- Sheet: Recent reviews -->
  <q-dialog v-model="reviewsSheet" position="bottom">
    <q-card class="sheet-card full-width pb-safe housesheet">
      <div class="sheet-header sheet-header--fixed">
        <span class="sheet-grip sheet-grip--inline" aria-hidden="true" />
        <h2 class="sheet-title">Recent reviews</h2>
      </div>
      <div class="sheet-body sheet-body--scroll">
        <p v-if="!reviews.length" class="empty-note">No reviews yet. Students can review after longer stays.</p>
        <div v-else class="review-list">
          <div v-for="review in reviews" :key="review.id" class="review-row">
            <q-avatar size="38px" class="review-avatar"><span>{{ review.initials }}</span></q-avatar>
            <div class="review-copy">
              <div class="review-head">
                <strong>{{ review.author }}</strong>
                <span>{{ review.date }}</span>
              </div>
              <div class="review-stars">
                <IconifyIcon v-for="starN in 5" :key="starN" icon="lucide:star" :class="{ 'star--on': starN <= review.rating }" width="14" />
              </div>
              <p v-if="review.comment">{{ review.comment }}</p>
            </div>
          </div>
        </div>
      </div>
    </q-card>
  </q-dialog>

  <!-- Sheet: Business contact -->
  <q-dialog v-model="contactSheet" position="bottom">
    <q-card class="sheet-card full-width pb-safe">
      <div class="sheet-header">
        <span class="sheet-grip" aria-hidden="true" />
        <h2 class="sheet-title">Business contact</h2>
      </div>
      <div class="sheet-body">
        <div class="fact-row"><span><IconifyIcon icon="lucide:mail" width="16" /> Email</span><strong>{{ profile.email }}</strong></div>
        <div class="fact-row"><span><IconifyIcon icon="lucide:phone" width="16" /> Phone</span><strong>{{ profile.contact }}</strong></div>
        <div class="fact-row"><span><IconifyIcon icon="lucide:map-pin" width="16" /> Area</span><strong>{{ profile.area }}</strong></div>
        <div class="fact-row"><span><IconifyIcon icon="lucide:calendar" width="16" /> Joined</span><strong>{{ profile.joined }}</strong></div>
        <q-btn unelevated no-caps color="primary" label="Done" class="sheet-cta" v-close-popup />
      </div>
    </q-card>
  </q-dialog>

  <!-- Sheet: Edit profile -->
  <q-dialog v-model="editDialog" position="bottom">
    <q-card class="sheet-card full-width pb-safe">
      <div class="sheet-header">
        <span class="sheet-grip" aria-hidden="true" />
        <h2 class="sheet-title">Edit profile</h2>
      </div>
      <div class="sheet-body">
        <button type="button" class="edit-avatar" aria-label="Change profile photo" @click="avatarInputRef.pickFiles()">
          <span class="edit-avatar__preview">
            <template v-if="avatarPreview || profileImageUrl">
              <img :src="(avatarPreview || profileImageUrl) || ''" alt="Profile photo preview" />
              <span class="edit-avatar__cam"><IconifyIcon icon="lucide:camera" width="14" /></span>
            </template>
            <IconifyIcon v-else icon="lucide:image-plus" width="26" class="edit-avatar__ph" />
          </span>
          <span class="edit-avatar__copy">
            <strong>Profile photo</strong>
            <small>{{ avatarFile || profileImageUrl ? 'Tap to change' : 'Tap to add a photo' }}</small>
          </span>
        </button>
        <q-file ref="avatarInputRef" v-model="avatarFile" style="display:none" accept="image/jpeg,image/png,image/webp" @update:model-value="onAvatarChosen" />
        <button type="button" class="edit-sync-google" :disabled="savingProfile" @click="useGooglePhoto">
          <IconifyIcon icon="lucide:user-round" width="15" />
          <span>Use my Google photo</span>
        </button>

        <label class="field-label">Full name</label>
        <q-input v-model="editForm.fullName" outlined dense class="field-input" placeholder="Your full name" />
        <label class="field-label">Email</label>
        <q-input v-model="editForm.email" outlined dense class="field-input" readonly hint="Email is managed by your sign-in provider." />
        <q-btn unelevated no-caps color="primary" label="Save changes" class="sheet-cta" :loading="savingProfile" @click="saveEdit" />
      </div>
    </q-card>
  </q-dialog>
</q-page>

</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useQuasar } from 'quasar'
import { useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'
import { uploadToCloudinary } from '@/shared/utils/upload'
import { restoreGooglePhoto } from '@/shared/utils/avatar'

interface ProfileState {
  initials: string
  fullName: string
  managerCode: string
  memberSince: string
  email: string
  contact: string
  area: string
  joined: string
  verified: boolean
}

interface UserProfileRow {
  full_name: string | null
  initials: string | null
  email: string | null
  phone: string | null
  created_at: string | null
  status: string | null
}

interface AccommodationRow {
  id: string
  name: string | null
  address: string | null
  city: string | null
  total_rooms: number | null
  rating_avg: number | null
  accreditation_status: string | null
  accreditation_expires_at: string | null
}

interface RoomRow { id: string; accommodation_id: string }
interface LeaseRoomRow { room_id: string }
interface ReviewRow { id: string; student_id: string; rating: number; comment: string | null; created_at: string }
interface ReviewerRow { id: string; full_name: string; initials: string }

interface StatItem {
  label: string
  value: string
  note: string
  icon: string
  iconClass: string
  noteClass: string
}

interface PropertyItem { id: string; name: string; address: string; rating: number; occupied: number; total: number }
interface ComplianceItem { id: string; name: string; date: string; status: string; tone: 'valid' | 'warning' | 'danger' }
interface ReviewItem { id: string; initials: string; author: string; rating: number; date: string; comment: string }

const router = useRouter()
const $q = useQuasar()
const loading = ref(true)
const error = ref<string | null>(null)
const profileImageUrl = ref<string | null>(null)
const avatarInputRef = ref<any>(null)
const avatarFile = ref<File | null>(null)
const avatarPreview = ref<string | null>(null)
const savingProfile = ref(false)
const editDialog = ref(false)
const editForm = ref({ fullName: '', email: '' })

const profile = ref<ProfileState>({
  initials: 'AM', fullName: 'Accommodation Manager', managerCode: '—', memberSince: '—',
  email: '—', contact: '—', area: '—', joined: '—', verified: false,
})
const stats = ref<StatItem[]>([])
const properties = ref<PropertyItem[]>([])
const compliance = ref<ComplianceItem[]>([])
const reviews = ref<ReviewItem[]>([])
const ratingData = ref<{ show: boolean; value: string; stars: number; label: string; countLabel: string }>({
  show: false, value: '—', stars: 0,
  label: 'Accommodation rating', countLabel: '',
})

// ---------- Redesign: list + sheet presentation helpers ----------
const complianceSheet = ref(false);
const propertiesSheet = ref(false);
const reviewsSheet = ref(false);
const contactSheet = ref(false);

const hasArea = computed(() => Boolean(profile.value.area) && profile.value.area !== '—');
const accreditationCount = computed(() => compliance.value.length);
const complianceRowSub = computed(() => {
  if (!compliance.value.length) return 'No records yet';
  const active = compliance.value.filter((c) => c.tone === 'valid').length;
  if (active === compliance.value.length) return `${active} accredit${active === 1 ? 'ation' : 'ations'} active`;
  if (active > 0) return `${active} of ${compliance.value.length} active`;
  return 'Needs attention';
});
const propertiesRowSub = computed(() => {
  if (!properties.value.length) return 'No listings yet';
  const n = properties.value.length;
  return `${n} listing${n === 1 ? '' : 's'} · ${activeProperties.value} active`;
});
const reviewsRowSub = computed(() => (reviewsAverage.value === '—'
  ? 'No reviews yet'
  : `${reviews.value.length} review${reviews.value.length === 1 ? '' : 's'} · ${reviewsAverage.value} avg`));
const contactRowSub = computed(() => {
  if (hasArea.value) return profile.value.area;
  const email = profile.value.email;
  return email && email !== '—' ? email : 'Business contact';
});

function complianceIcon(tone: 'valid' | 'warning' | 'danger') {
  if (tone === 'valid') return 'lucide:shield-check';
  if (tone === 'danger') return 'lucide:circle-alert';
  return 'lucide:clock-3';
}
function complianceChipColor(tone: 'valid' | 'warning' | 'danger') {
  return tone === 'valid' ? 'teal-1' : tone === 'danger' ? 'red-1' : 'amber-1';
}
function complianceChipText(tone: 'valid' | 'warning' | 'danger') {
  return tone === 'valid' ? 'teal-8' : tone === 'danger' ? 'red-7' : 'orange-9';
}
function openCompliance() { complianceSheet.value = true; }
function openProperties() { propertiesSheet.value = true; }
function openReviews() { reviewsSheet.value = true; }
function openContact() { contactSheet.value = true; }
const activeProperties = computed(() => properties.value.length)
const reviewsAverage = computed(() => {
  if (!reviews.value.length) return '—'
  return (reviews.value.reduce((sum, review) => sum + review.rating, 0) / reviews.value.length).toFixed(1)
})
const details = computed(() => [
  { label: 'EMAIL', value: profile.value.email, icon: 'mail_outline' },
  { label: 'CONTACT', value: profile.value.contact, icon: 'phone' },
  { label: 'AREA', value: profile.value.area, icon: 'location_on' },
  { label: 'JOINED', value: profile.value.joined, icon: 'calendar_today' },
])

function initialsOf(name: string) {
  const parts = name.trim().split(' ').filter(Boolean)
  if (parts.length >= 2) return `${parts[0]?.[0] ?? ''}${parts.at(-1)?.[0] ?? ''}`.toUpperCase()
  return parts.length === 1 ? (parts[0] ?? '').slice(0, 2).toUpperCase() : 'AM'
}

function formatDate(value: string | null, options: Intl.DateTimeFormatOptions) {
  if (!value) return '—'
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '—' : date.toLocaleDateString('en-US', options)
}

function compliancePresentation(status: string | null) {
  switch (status) {
    case 'accredited': return { status: 'Active', tone: 'valid' as const }
    case 'rejected':
    case 'delisted': return { status: status === 'rejected' ? 'Rejected' : 'Delisted', tone: 'danger' as const }
    case 'expired': return { status: 'Expired', tone: 'danger' as const }
    case 'reviewing': return { status: 'Reviewing', tone: 'warning' as const }
    default: return { status: status || 'Pending', tone: 'warning' as const }
  }
}

async function loadProfile() {
  loading.value = true
  error.value = null
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { void router.push('/login'); return }

    const metadata = user.user_metadata as Record<string, unknown> | undefined
    const picture = typeof metadata?.avatar_url === 'string' ? metadata.avatar_url : typeof metadata?.picture === 'string' ? metadata.picture : ''
    profileImageUrl.value = picture || null

    const { data: me, error: userError } = await supabase
      .from('users')
      .select('full_name, initials, email, phone, created_at, status')
      .eq('id', user.id)
      .maybeSingle()
    if (userError) throw userError

    const userRow = me as UserProfileRow | null
    const metadataName = typeof metadata?.full_name === 'string' ? metadata.full_name : ''
    const fullName = userRow?.full_name || metadataName || 'Accommodation Manager'
    const createdAt = userRow?.created_at ?? null
    profile.value = {
      initials: userRow?.initials || initialsOf(fullName),
      fullName,
      managerCode: user.id,
      memberSince: formatDate(createdAt, { month: 'short', year: 'numeric' }),
      email: userRow?.email || user.email || '—',
      contact: userRow?.phone || '—',
      area: '—',
      joined: formatDate(createdAt, { month: 'long', year: 'numeric' }),
      verified: userRow?.status === 'verified',
    }

    // The deployed backend uses the accommodations compatibility table while
    // the generated schema still exposes its predecessor as properties.
    const { data: accommodationData, error: accommodationError } = await supabase
      .from('accommodations' as never)
      .select('id, name, address, city, total_rooms, rating_avg, accreditation_status, accreditation_expires_at')
      .eq('accommodation_manager_id', user.id)
      .order('name')
    if (accommodationError) throw accommodationError
    const accommodationRows = (accommodationData ?? []) as unknown as AccommodationRow[]
    if (accommodationRows[0]?.city) profile.value.area = accommodationRows[0].city

    const occupiedByAccommodation = new Map<string, number>()
    const accommodationIds = accommodationRows.map((item) => item.id)
    if (accommodationIds.length) {
      const { data: roomData, error: roomError } = await supabase
        .from('rooms')
        .select('id, accommodation_id')
        .in('accommodation_id', accommodationIds)
      if (roomError) throw roomError
      const roomRows = (roomData ?? []) as unknown as RoomRow[]
      const roomIds = roomRows.map((room) => room.id)
      if (roomIds.length) {
        const { data: leaseData, error: leaseError } = await supabase.from('leases').select('room_id').in('room_id', roomIds).eq('status', 'active')
        if (leaseError) throw leaseError
        const roomToAccommodation = new Map(roomRows.map((room) => [room.id, room.accommodation_id]))
        for (const lease of (leaseData ?? []) as unknown as LeaseRoomRow[]) {
          const accommodationId = roomToAccommodation.get(lease.room_id)
          if (accommodationId) occupiedByAccommodation.set(accommodationId, (occupiedByAccommodation.get(accommodationId) ?? 0) + 1)
        }
      }
    }

    properties.value = accommodationRows.map((item) => ({
      id: item.id,
      name: item.name || 'Boarding House',
      address: item.address || '—',
      rating: Number(item.rating_avg) || 0,
      occupied: occupiedByAccommodation.get(item.id) ?? 0,
      total: Number(item.total_rooms) || 0,
    }))
    compliance.value = accommodationRows.map((item) => {
      const presentation = compliancePresentation(item.accreditation_status)
      const expiry = formatDate(item.accreditation_expires_at, { day: 'numeric', month: 'short', year: 'numeric' })
      return { id: item.id, name: item.name || 'Boarding House', date: `Valid until ${expiry}`, ...presentation }
    })

    const totalTenants = Array.from(occupiedByAccommodation.values()).reduce((sum, count) => sum + count, 0)
    const totalRooms = accommodationRows.reduce((sum, item) => sum + (Number(item.total_rooms) || 0), 0)
    const averageRating = accommodationRows.length
      ? accommodationRows.reduce((sum, item) => sum + (Number(item.rating_avg) || 0), 0) / accommodationRows.length
      : 0
    stats.value = [
      { label: 'Properties', value: String(accommodationRows.length), note: 'Active', icon: 'domain', iconClass: 'bg-teal-1 text-teal-8', noteClass: 'text-teal-8' },
      { label: 'Tenants', value: String(totalTenants), note: 'Current', icon: 'groups', iconClass: 'bg-indigo-1 text-indigo-5', noteClass: 'text-indigo-5' },
      { label: 'Rating', value: accommodationRows.length ? averageRating.toFixed(1) : '—', note: 'Average', icon: 'star_outline', iconClass: 'bg-orange-1 text-orange-4', noteClass: 'text-orange-5' },
      { label: 'Occupancy', value: totalRooms ? `${Math.round((totalTenants / totalRooms) * 100)}%` : '0%', note: 'Capacity', icon: 'bed', iconClass: 'bg-blue-1 text-blue-6', noteClass: 'text-blue-6' },
    ]

    const { data: reviewData, error: reviewError } = await (supabase as any)
      .from('accommodation_manager_reviews')
      .select('id, student_id, rating, comment, created_at')
      .eq('accommodation_manager_id', user.id)
      .order('created_at', { ascending: false })
      .limit(5)
    if (reviewError) throw reviewError
    const reviewRows = (reviewData ?? []) as ReviewRow[]
    const reviewerIds = [...new Set(reviewRows.map((review) => review.student_id))]
    const reviewerMap = new Map<string, ReviewerRow>()
    if (reviewerIds.length) {
      const { data: reviewerData, error: reviewerError } = await supabase.from('users').select('id, full_name, initials').in('id', reviewerIds)
      if (reviewerError) throw reviewerError
      for (const reviewer of (reviewerData ?? []) as ReviewerRow[]) reviewerMap.set(reviewer.id, reviewer)
    }
    reviews.value = reviewRows.map((review) => {
      const reviewer = reviewerMap.get(review.student_id)
      const author = reviewer?.full_name || 'Student'
      return {
        id: review.id,
        initials: reviewer?.initials || initialsOf(author),
        author,
        rating: review.rating,
        date: formatDate(review.created_at, { month: 'short', day: 'numeric', year: 'numeric' }),
        comment: review.comment || '',
      }
    })

    // Single rating KPI: average of ALL reviews of this manager.
    try {
      const ratingResult = await (supabase as any).from('accommodation_manager_reviews').select('rating').eq('accommodation_manager_id', user.id)
      const managerRatings = ((ratingResult?.data ?? []) as Array<{ rating: number }>)
      if (managerRatings.length) {
        const average = managerRatings.reduce((s2, r) => s2 + r.rating, 0) / managerRatings.length
        ratingData.value = { show: true, value: average.toFixed(1), stars: Math.round(average), label: 'Accommodation manager rating', countLabel: `${managerRatings.length} student review${managerRatings.length === 1 ? '' : 's'}` }
      } else {
        ratingData.value = { show: true, value: '—', stars: 0, label: 'Accommodation manager rating', countLabel: 'No reviews yet' }
      }
    } catch {
      /* rating KPI is non-critical */
    }
  } catch (caught) {
    console.error('loadProfile error:', caught)
    error.value = caught instanceof Error ? caught.message : 'Failed to load profile'
  } finally {
    loading.value = false
  }
}

function openEdit() {
  editForm.value = { fullName: profile.value.fullName, email: profile.value.email === '—' ? '' : profile.value.email }
  avatarFile.value = null
  avatarPreview.value = null
  editDialog.value = true
}

function onAvatarChosen() {
  const file = avatarFile.value
  if (!file) { avatarPreview.value = null; return }
  if (avatarPreview.value) URL.revokeObjectURL(avatarPreview.value)
  avatarPreview.value = URL.createObjectURL(file)
}

async function useGooglePhoto() {
  const url = await restoreGooglePhoto()
  if (!url) {
    $q.notify({ message: 'No Google photo to use.', color: 'warning', position: 'top' })
    return
  }
  if (avatarPreview.value) URL.revokeObjectURL(avatarPreview.value)
  avatarPreview.value = null
  avatarFile.value = null
  profileImageUrl.value = url
  try {
    const evt = new CustomEvent('accommo:avatar-change', { detail: { url } })
    window.dispatchEvent(evt)
  } catch { /* noop */ }
  $q.notify({ message: 'Profile photo synced with Google.', color: 'teal-8', position: 'top' })
}

async function saveEdit() {
  const fullName = editForm.value.fullName.trim()
  if (!fullName) {
    $q.notify({ message: 'Full name is required.', color: 'warning', position: 'top' })
    return
  }
  savingProfile.value = true
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { void router.push('/login'); return }
    const { error: updateError } = await supabase.from('users').update({ full_name: fullName, initials: initialsOf(fullName) }).eq('id', user.id)
    if (updateError) throw updateError

    if (avatarFile.value) {
      const [uploaded] = await uploadToCloudinary([avatarFile.value])
      const newAvatarUrl = uploaded?.url ?? null
      if (newAvatarUrl) {
        const { error: metaError } = await supabase.auth.updateUser({ data: { avatar_url: newAvatarUrl } })
        if (!metaError) {
          profileImageUrl.value = newAvatarUrl
          const evt = new CustomEvent('accommo:avatar-change', { detail: { url: newAvatarUrl } })
          window.dispatchEvent(evt)
        }
      }
    }
    if (avatarPreview.value) URL.revokeObjectURL(avatarPreview.value)
    avatarFile.value = null
    avatarPreview.value = null

    editDialog.value = false
    $q.notify({ message: 'Profile updated.', color: 'teal-8', position: 'top', icon: 'check_circle' })
    await loadProfile()
  } catch (caught) {
    $q.notify({ message: caught instanceof Error ? caught.message : 'Failed to update profile', color: 'negative', position: 'top' })
  } finally {
    savingProfile.value = false
  }
}

function openCamera() {
  $q.notify({ message: 'Camera opened (mock)', color: 'teal-9', position: 'top' })
}
function openScanner() { void router.push('/manager/profile/qr-scanner') }
function openProperty(id: string) { void router.push(`/manager/properties/${id}`) }
function goToSettings() { void router.push('/manager/settings') }
async function handleLogout() { await supabase.auth.signOut(); void router.push('/login') }

onMounted(() => { void loadProfile() })
</script>

<style scoped>
.profile-page { min-height: 100vh; background: var(--m-bg); color: var(--m-text); }
.profile-content { width: min(100%, 760px); margin: 0 auto; padding: max(var(--m-space-3), env(safe-area-inset-top)) max(var(--m-page-gutter), env(safe-area-inset-right)) calc(var(--m-space-8) + env(safe-area-inset-bottom)) max(var(--m-page-gutter), env(safe-area-inset-left)); }

/* ---------- Identity ---------- */
.identity-card { position: relative; margin-bottom: var(--m-space-3); padding: var(--m-space-5) var(--m-space-5) var(--m-space-4); }
.identity-edit { position: absolute; top: var(--m-space-3); right: var(--m-space-3); display: grid; width: 32px; height: 32px; place-items: center; border: 1px solid var(--m-border); border-radius: 8px; background: var(--m-surface); color: var(--m-muted); cursor: pointer; }
.identity-edit:hover { border-color: var(--m-primary); color: var(--m-primary-dark); }
.identity-main { display: flex; align-items: flex-start; gap: var(--m-space-4); padding-right: 44px; }
.identity-avatar { flex: 0 0 auto; background: linear-gradient(135deg, var(--m-primary-dark), var(--m-primary)); font-size: 26px; font-weight: 800; cursor: pointer; }
.identity-copy { min-width: 0; flex: 1; }
.identity-name { margin: 0; color: var(--m-ink); font-family: var(--m-font-display); font-size: 21px; font-weight: 700; line-height: 1.2; overflow-wrap: anywhere; }
.identity-sub { margin: 3px 0 10px; color: var(--m-muted); font-size: 12px; }
.status-pill { display: inline-flex; min-height: 26px; align-items: center; gap: 6px; padding: 0 10px; border: 1px solid transparent; border-radius: 999px; font-size: 11px; font-weight: 750; }
.status-pill--verified { border-color: color-mix(in srgb, var(--m-success) 26%, transparent); background: var(--m-success-soft); color: var(--m-success); }
.status-pill--unverified { border-color: var(--m-border); background: var(--m-bg); color: var(--m-muted); }
.identity-note { margin: var(--m-space-4) 0 0; padding: var(--m-space-3); border: 1px solid color-mix(in srgb, var(--m-warning) 26%, transparent); border-radius: var(--m-radius-sm); background: var(--m-warning-soft); color: var(--m-warning); font-size: 12px; line-height: 1.45; }

/* ---------- Metrics ---------- */
.metrics-strip { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); margin-bottom: var(--m-space-4); padding: var(--m-space-1) 0; overflow: hidden; }
.metric { display: flex; min-width: 0; flex-direction: column; align-items: center; padding: var(--m-space-3); }
.metric + .metric { border-left: 1px solid var(--m-border); }
.metric strong { max-width: 100%; overflow: hidden; color: var(--m-ink); font-family: var(--m-font-display); font-size: 18px; font-weight: 800; letter-spacing: -0.01em; text-overflow: ellipsis; white-space: nowrap; }
.metric span { margin-top: 2px; color: var(--m-muted); font-size: 9px; font-weight: 800; letter-spacing: 0.04em; text-transform: uppercase; }
.rating-kpi { display: flex; align-items: center; flex-direction: column; margin-bottom: var(--m-space-4); padding: var(--m-space-4); text-align: center; }
/* QR scanner tool tile (prominent, mirrors where the student QR card sits) */
.qr-tool { display: flex; align-items: center; gap: var(--m-space-3); margin-bottom: var(--m-space-4); padding: var(--m-space-4); }
.qr-tool-icon { display: grid; width: 46px; height: 46px; flex: 0 0 auto; place-items: center; border-radius: 11px; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.qr-tool-copy { min-width: 0; flex: 1; }
.qr-tool-copy h2 { margin: 0; color: var(--m-ink); font-family: var(--m-font-display); font-size: 15px; font-weight: 700; line-height: 1.3; }
.qr-tool-copy p { margin: 3px 0 0; color: var(--m-muted); font-size: 12px; line-height: 1.4; }
.qr-tool-btn { flex: 0 0 auto; min-width: 118px; min-height: 44px; border-radius: var(--m-radius-sm); font-weight: 800; background: var(--m-primary-dark); }
.rating-kpi .rk-label { color: var(--m-muted); font-size: 10px; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase; }
.rating-kpi .rk-main { display: flex; align-items: center; gap: var(--m-space-3); margin-top: var(--m-space-2); }
.rating-kpi .rk-value { color: var(--m-ink); font-family: var(--m-font-display); font-size: 34px; font-weight: 800; letter-spacing: -0.03em; line-height: 1; }
.rating-kpi .rk-stars { display: inline-flex; gap: 2px; align-items: center; }
.rating-kpi .rk-stars svg { color: #d4d8de; }
.rating-kpi .rk-stars .rk-on { color:  var(--m-warning); }
.rating-kpi .rk-sub { margin-top: var(--m-space-2); color: var(--m-muted); font-size: 12px; }

/* ---------- Grouped list ---------- */
.list-group { margin-bottom: var(--m-space-4); }
.list-eyebrow { margin: 0 0 var(--m-space-2); padding: 0 var(--m-space-1); color: var(--m-muted); font-size: 10px; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase; }
.list-card { overflow: hidden; }
.list-row { display: flex; width: 100%; min-height: 64px; align-items: center; gap: var(--m-space-3); padding: var(--m-space-3) var(--m-space-4); border: 0; background: transparent; color: var(--m-ink); cursor: pointer; font: inherit; text-align: left; -webkit-tap-highlight-color: transparent; transition: background-color 0.12s ease; }
.list-row:active { background: color-mix(in srgb, var(--m-primary) 6%, transparent); }
.list-row:disabled { opacity: 0.5; cursor: default; }
.list-icon { display: grid; width: 36px; height: 36px; flex: 0 0 auto; place-items: center; border-radius: 9px; }
.list-icon--primary { background: var(--m-primary-soft); color: var(--m-primary-dark); }
.list-icon--warning { background: var(--m-warning-soft); color: var(--m-warning); }
.list-icon--neutral { background: var(--m-bg); color: var(--m-muted); }
.list-icon--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.list-copy { display: flex; min-width: 0; flex: 1; flex-direction: column; gap: 2px; }
.list-copy strong { color: var(--m-ink); font-size: 14px; font-weight: 700; line-height: 1.3; }
.list-copy small { overflow: hidden; color: var(--m-muted); font-size: 12px; line-height: 1.4; text-overflow: ellipsis; white-space: nowrap; }
.list-row--danger .list-copy strong { color: var(--m-danger); }
.list-chevron { flex: 0 0 auto; color: #c2c8d0; display: grid; place-items: center; }
.list-divider { display: block; height: 1px; margin: 0 var(--m-space-4); background: var(--m-border); }

/* ---------- States ---------- */
.profile-state { display: grid; min-height: 260px; align-content: center; justify-items: center; gap: var(--m-space-3); padding: var(--m-space-6); color: var(--m-muted); text-align: center; }
.profile-state--error { color: var(--m-danger); }
.profile-state-action { min-height: 44px; border-radius: var(--m-radius-sm); }

.surface-card { border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }

/* ---------- Sheets ---------- */
.sheet-card { grid-column: 1 / -1; border: 0; border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0; box-shadow: 0 -8px 30px rgba(15, 23, 42, 0.14); color: var(--m-text); }
.housesheet { display: flex; max-height: 82vh; flex-direction: column; }
.housesheet .sheet-body--scroll { min-height: 0; }
.sheet-header { display: flex; min-height: 52px; align-items: flex-start; justify-content: space-between; flex-wrap: wrap; column-gap: var(--m-space-2); padding: var(--m-space-2) var(--m-space-4) var(--m-space-2); box-sizing: border-box; }
.sheet-header--fixed { flex: 0 0 auto; border-bottom: 1px solid var(--m-border); }
.sheet-grip { order: -1; flex: 1 1 100%; display: flex; align-items: center; justify-content: center; width: auto; height: auto; margin: 0 0 2px; padding: 6px 0 2px; background: transparent; }
.sheet-grip::after { content: ''; width: 40px; height: 4px; border-radius: 999px; background: #d8dce2; }
.sheet-grip--inline { flex: 0 0 auto; }
.sheet-title { margin: 0; color: var(--m-ink); font-family: var(--m-font-display); font-size: 18px; font-weight: 700; letter-spacing: -0.01em; }
.sheet-body { padding: var(--m-space-2) var(--m-space-4) var(--m-space-5); }
.sheet-body--scroll { min-height: 0; overflow-y: auto; padding-top: var(--m-space-4); }
.sheet-body--center { display: flex; align-items: center; flex-direction: column; text-align: center; padding-top: var(--m-space-6); }
.empty-note { margin: var(--m-space-3) 0 var(--m-space-4); color: var(--m-muted); font-size: 13px; line-height: 1.5; text-align: center; }
.sheet-cta { width: 100%; min-height: 48px; margin-top: var(--m-space-4); border-radius: var(--m-radius-sm); font-weight: 800; }
.q-btn.sheet-cta { background: var(--m-primary-dark); }
.q-btn.sheet-cta.q-btn--disabled { opacity: 0.55; }
.count-chip { height: 24px; font-size: 11px; font-weight: 750; border-radius: 6px; }

/* ---------- Compliance list ---------- */
.compliance-row { display: flex; align-items: center; gap: var(--m-space-3); padding: var(--m-space-3) 0; }
.compliance-row + .compliance-row { border-top: 1px solid var(--m-border); }
.compliance-icon { display: grid; width: 36px; height: 36px; flex: 0 0 auto; place-items: center; border-radius: 9px; }
.compliance-icon--valid { background: var(--m-success-soft); color: var(--m-success); }
.compliance-icon--warning { background: var(--m-warning-soft); color: var(--m-warning); }
.compliance-icon--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.compliance-copy { display: flex; min-width: 0; flex: 1; flex-direction: column; gap: 2px; }
.compliance-copy strong { overflow: hidden; color: var(--m-ink); font-size: 14px; line-height: 1.3; text-overflow: ellipsis; white-space: nowrap; }
.compliance-copy small { color: var(--m-muted); font-size: 12px; line-height: 1.4; }
.compliance-chip { flex: 0 0 auto; min-height: 22px; font-size: 11px; font-weight: 750; }

/* ---------- Property rows ---------- */
.prop-row { display: flex; width: 100%; align-items: center; gap: var(--m-space-3); padding: var(--m-space-3) 0; border: 0; background: transparent; color: var(--m-ink); cursor: pointer; font: inherit; text-align: left; -webkit-tap-highlight-color: transparent; }
.prop-row + .prop-row { border-top: 1px solid var(--m-border); }
.prop-row:active { opacity: 0.7; }
.prop-avatar { display: grid; width: 40px; height: 40px; flex: 0 0 auto; place-items: center; border-radius: 9px; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.prop-copy { display: flex; min-width: 0; flex: 1; flex-direction: column; gap: 3px; }
.prop-copy > strong { color: var(--m-ink); font-size: 14px; font-weight: 700; line-height: 1.3; }
.prop-copy > small { overflow: hidden; color: var(--m-muted); font-size: 12px; line-height: 1.35; text-overflow: ellipsis; white-space: nowrap; }
.prop-meta { display: flex; align-items: center; gap: var(--m-space-3); margin-top: 1px; }
.prop-rating, .prop-occ { display: inline-flex; align-items: center; gap: 4px; color: var(--m-text); font-size: 11px; font-weight: 650; }
.prop-rating svg { color:  var(--m-warning); }
.prop-occ { color: var(--m-muted); }
.prop-progress { display: block; width: 100%; height: 5px; margin-top: 5px; overflow: hidden; border-radius: 999px; background: var(--m-bg); }
.prop-progress span { display: block; height: 100%; border-radius: 999px; background: var(--m-primary); transition: width 0.3s ease; }

/* ---------- Review rows ---------- */
.review-row { display: flex; align-items: flex-start; gap: var(--m-space-3); padding: var(--m-space-4) 0; }
.review-row + .review-row { border-top: 1px solid var(--m-border); }
.review-avatar { flex: 0 0 auto; background: var(--m-primary-soft); color: var(--m-primary-dark) !important; font-size: 12px; font-weight: 800; }
.review-copy { min-width: 0; flex: 1; }
.review-head { display: flex; align-items: center; justify-content: space-between; gap: var(--m-space-3); }
.review-head strong { overflow: hidden; color: var(--m-ink); font-size: 14px; font-weight: 700; text-overflow: ellipsis; white-space: nowrap; }
.review-head span { flex: 0 0 auto; color: var(--m-muted); font-size: 11px; }
.review-stars { display: flex; gap: 2px; margin: 6px 0 0; }
.review-stars svg { color: #d4d8de; }
.review-stars .star--on { color:  var(--m-warning); }
.review-copy p { margin: 0 0 0; color: var(--m-muted); font-size: 12px; line-height: 1.5; overflow-wrap: anywhere; }

/* ---------- Contact facts ---------- */
.fact-row { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--m-space-3); padding: var(--m-space-3) 0; }
.fact-row + .fact-row { border-top: 1px solid var(--m-border); }
.fact-row span { display: inline-flex; align-items: center; gap: 8px; color: var(--m-muted); font-size: 13px; white-space: nowrap; }
.fact-row span svg { color: var(--m-primary-dark); flex: 0 0 auto; }
.fact-row strong { max-width: 55%; color: var(--m-ink); font-size: 13px; font-weight: 650; text-align: right; overflow-wrap: anywhere; }

/* ---------- Fields ---------- */
.field-label { display: block; margin: 0 0 6px; color: var(--m-muted); font-size: 12px; font-weight: 650; }
.edit-avatar { display: flex; width: 100%; align-items: center; gap: var(--m-space-3); margin-bottom: var(--m-space-4); padding: var(--m-space-2); border: 0; background: transparent; color: var(--m-ink); cursor: pointer; font: inherit; text-align: left; -webkit-tap-highlight-color: transparent; }
.edit-avatar__preview { position: relative; display: grid; width: 72px; height: 72px; flex: 0 0 auto; place-items: center; overflow: hidden; border-radius: 50%; background: linear-gradient(135deg, var(--m-primary-dark), var(--m-primary)); color: #fff; font-size: 24px; font-weight: 800; }
.edit-avatar__preview img { width: 100%; height: 100%; object-fit: cover; }
.edit-avatar__ph { color: rgba(255, 255, 255, 0.95); }
.edit-avatar__cam { position: absolute; right: 1px; bottom: 1px; display: grid; width: 24px; height: 24px; place-items: center; border: 0; border-radius: 50%; background: var(--m-surface); color: var(--m-primary-dark); box-shadow: 0 0 0 1px var(--m-border); }
.edit-avatar__copy strong { display: block; font-size: 14px; font-weight: 700; }
.edit-avatar__copy small { color: var(--m-muted); font-size: 12px; }
.edit-sync-google { display: inline-flex; min-height: 40px; align-items: center; gap: 7px; padding: 0 4px; margin: -6px 0 14px; border: 0; background: transparent; color: var(--m-primary-dark); cursor: pointer; font: inherit; font-size: 13px; font-weight: 700; -webkit-tap-highlight-color: transparent; }
.edit-sync-google:disabled { opacity: 0.5; }
.field-input { width: 100%; margin-bottom: var(--m-space-4); }
.field-input :deep(.q-field__control) { min-height: 48px; border-radius: var(--m-radius-sm); }
.field-input :deep(.q-field__bottom) { padding-top: 4px; }
.field-input:last-of-type { margin-bottom: 0; }

.pb-safe { padding-bottom: calc(var(--m-space-5) + env(safe-area-inset-bottom)); }

@media (prefers-reduced-motion: reduce) {
  * { scroll-behavior: auto !important; transition-duration: 0.01ms !important; }
}
</style>
