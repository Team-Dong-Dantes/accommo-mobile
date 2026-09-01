<template>
  <q-page class="profile-page">
    <header class="profile-page-bar" aria-label="Profile navigation">
      <button type="button" class="profile-back-button" aria-label="Back to landlord dashboard" @click="goBack">
        <IconifyIcon icon="lucide:arrow-left" width="21" />
      </button>
    </header>

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
        <!-- Profile Header Card -->
        <q-card flat class="q-mx-md q-mb-lg border-radius-24 overflow-hidden shadow-soft">
          <div class="profile-gradient relative-position" style="height: 110px">
            <q-btn round flat class="absolute-top-right q-ma-sm text-white bg-white-20 shell-icon-button" aria-label="Edit profile" @click="openEdit">
              <IconifyIcon icon="lucide:pencil" width="19" />
            </q-btn>
          </div>

          <div class="q-px-md relative-position bg-white" style="padding-top: 50px; padding-bottom: 24px">
            <div class="absolute" style="top: -48px; left: 16px">
              <q-avatar size="96px" class="profile-avatar text-white font-size-32 text-weight-bold" @click="openEdit">
                <img v-if="profileImageUrl" :src="profileImageUrl" :alt="`${profile.fullName} profile photo`" />
                <span v-else>{{ profile.initials }}</span>
                <q-badge floating color="dark" class="camera-badge flex flex-center" rounded @click.stop="openCamera">
                  <IconifyIcon icon="lucide:camera" width="12" />
                </q-badge>
              </q-avatar>
            </div>

            <div class="absolute" style="top: 16px; right: 16px">
              <q-chip dense :color="profile.verified ? 'teal-1' : 'amber-1'" :text-color="profile.verified ? 'teal-8' : 'orange-9'" class="text-weight-bold q-px-sm" style="font-size: 11px">
                <q-icon name="circle" size="8px" class="q-mr-xs" />
                {{ profile.verified ? 'Verified' : 'Pending Verification' }}
              </q-chip>
            </div>

            <div class="q-mt-sm">
              <div class="text-h5 text-weight-bold line-height-tight">{{ profile.fullName }}</div>
              <div class="text-caption text-grey-6 q-mt-xs identity-line" :title="profile.managerCode">
                Manager ID: {{ profile.managerCode }} · Member since {{ profile.memberSince }}
              </div>
            </div>

            <div class="row q-col-gutter-sm q-mt-md">
              <div v-for="detail in details" :key="detail.label" class="col-6">
                <div class="detail-box q-pa-sm row items-start">
                  <q-icon :name="detail.icon" color="teal-7" size="16px" class="q-mr-sm q-mt-xs" />
                  <div class="col overflow-hidden">
                    <div class="text-xs text-grey-5 text-weight-bold letter-spacing-1">{{ detail.label }}</div>
                    <div class="text-caption text-weight-bold text-dark ellipsis" :title="detail.value">{{ detail.value }}</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </q-card>

        <!-- Stats Row -->
        <div class="row q-col-gutter-md q-px-md q-mb-lg stats-row">
          <div v-for="stat in stats" :key="stat.label" class="col-3 stat-column">
            <q-card flat class="stat-card full-height shadow-soft">
              <q-card-section class="q-pa-md column items-center justify-center text-center">
                <div class="icon-circle q-mb-sm" :class="stat.iconClass"><q-icon :name="stat.icon" size="18px" /></div>
                <div class="text-h6 text-weight-bold line-height-tight">{{ stat.value }}</div>
                <div class="text-xs text-grey-6 q-mt-xs">{{ stat.label }}</div>
                <div class="stat-note q-mt-xs" :class="stat.noteClass">{{ stat.note || '\u00a0' }}</div>
              </q-card-section>
            </q-card>
          </div>
        </div>

        <!-- Student QR Scanner -->
        <q-card flat class="q-mx-md q-mb-lg border-radius-24 q-pa-md shadow-soft">
          <div class="row items-center q-mb-sm">
            <div class="icon-circle bg-indigo-1 text-indigo-5 q-mr-sm"><q-icon name="qr_code_scanner" size="18px" /></div>
            <div class="col">
              <div class="text-subtitle1 text-weight-bold line-height-tight">Student QR Scanner</div>
              <div class="text-caption text-grey-6">Verify enrollment and view a student’s history</div>
            </div>
          </div>
          <q-btn unelevated color="deep-purple-6" icon="qr_code_scanner" label="Open Scanner" class="border-radius-16 text-weight-bold full-width q-py-sm q-mt-md" no-caps @click="openScanner" />
        </q-card>

        <!-- My Properties -->
        <q-card flat class="q-mx-md q-mb-lg border-radius-24 q-pa-md shadow-soft">
          <div class="row items-center justify-between q-mb-md">
            <div class="row items-center">
              <div class="icon-circle bg-teal-1 text-teal-8 q-mr-sm"><q-icon name="domain" size="18px" /></div>
              <div class="text-subtitle1 text-weight-bold">My Properties</div>
            </div>
            <q-chip dense color="teal-1" text-color="teal-8" class="text-weight-bold" style="font-size: 11px">{{ activeProperties }} active</q-chip>
          </div>

          <div v-if="properties.length === 0" class="empty-row">No properties yet.</div>
          <q-list v-else separator class="section-list">
            <q-item v-for="property in properties" :key="property.id" clickable v-ripple class="q-py-md" @click="openProperty(property.id)">
              <q-item-section>
                <div class="text-subtitle2 text-weight-bold text-dark line-height-tight">{{ property.name }}</div>
                <div class="text-caption text-grey-6 q-mt-xs">{{ property.address }}</div>
                <div class="row items-center q-mt-sm">
                  <q-icon name="star" size="14px" color="amber-7" class="q-mr-xs" />
                  <span class="text-caption text-weight-bold">{{ property.rating.toFixed(1) }}</span>
                  <span class="text-caption text-grey-6 q-ml-sm">{{ property.occupied }}/{{ property.total }} occupied</span>
                </div>
                <q-linear-progress :value="property.total ? property.occupied / property.total : 0" color="teal-8" track-color="grey-3" size="6px" rounded class="q-mt-sm" />
              </q-item-section>
              <q-item-section side><q-icon name="chevron_right" color="grey-4" /></q-item-section>
            </q-item>
          </q-list>
        </q-card>

        <!-- OSAS Compliance -->
        <q-card flat class="q-mx-md q-mb-lg border-radius-24 q-pa-md shadow-soft">
          <div class="row items-center q-mb-md">
            <div class="icon-circle bg-teal-1 text-teal-8 q-mr-sm"><q-icon name="shield" size="18px" /></div>
            <div class="text-subtitle1 text-weight-bold">OSAS Compliance</div>
          </div>
          <div v-if="compliance.length === 0" class="empty-row">No compliance records yet.</div>
          <q-list v-else separator class="section-list">
            <q-item v-for="item in compliance" :key="item.id" class="q-py-md compliance-row">
              <q-item-section>
                <div class="text-subtitle2 text-weight-bold text-dark">{{ item.name }}</div>
                <div class="text-caption text-grey-6 q-mt-xs">{{ item.date }}</div>
              </q-item-section>
              <q-item-section side>
                <q-chip dense :color="item.tone === 'valid' ? 'teal-1' : item.tone === 'danger' ? 'red-1' : 'amber-1'" :text-color="item.tone === 'valid' ? 'teal-8' : item.tone === 'danger' ? 'red-7' : 'orange-9'" class="text-weight-bold" style="font-size: 11px">{{ item.status }}</q-chip>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>

        <!-- Recent Reviews -->
        <q-card flat class="q-mx-md q-mb-lg border-radius-24 q-pa-md shadow-soft">
          <div class="row items-center justify-between q-mb-md">
            <div class="row items-center">
              <div class="icon-circle bg-orange-1 text-orange-8 q-mr-sm"><q-icon name="star_outline" size="18px" /></div>
              <div class="text-subtitle1 text-weight-bold">Recent Reviews</div>
            </div>
            <q-chip dense color="amber-1" text-color="orange-9" class="text-weight-bold" style="font-size: 11px">{{ reviewsAverage }} avg</q-chip>
          </div>
          <div v-if="reviews.length === 0" class="empty-row">No reviews yet.</div>
          <q-list v-else separator class="section-list">
            <q-item v-for="review in reviews" :key="review.id" class="q-py-md">
              <q-item-section avatar>
                <q-avatar size="40px" color="grey-3" text-color="grey-8" class="text-weight-bold text-caption">{{ review.initials }}</q-avatar>
              </q-item-section>
              <q-item-section>
                <div class="row items-center justify-between no-wrap q-col-gutter-sm">
                  <span class="text-subtitle2 text-weight-bold text-dark ellipsis">{{ review.author }}</span>
                  <span class="text-xs text-grey-5 no-wrap">{{ review.date }}</span>
                </div>
                <div class="row items-center q-mt-xs review-stars">
                  <q-icon v-for="star in 5" :key="star" name="star" size="14px" :color="star <= review.rating ? 'amber-6' : 'grey-4'" />
                </div>
                <div v-if="review.comment" class="text-caption text-grey-7 q-mt-xs review-comment">{{ review.comment }}</div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>

        <!-- Actions List -->
        <q-card flat class="q-mx-md q-mb-xl border-radius-24 overflow-hidden shadow-soft">
          <q-list class="bg-white">
            <q-item clickable v-ripple class="q-py-md" @click="goToSettings">
              <q-item-section avatar><div class="icon-circle bg-teal-1 text-teal-8"><q-icon name="settings_outlined" size="18px" /></div></q-item-section>
              <q-item-section>
                <div class="text-subtitle2 text-weight-bold text-dark">Settings</div>
                <div class="text-caption text-grey-5">Notifications, business, security</div>
              </q-item-section>
              <q-item-section side><q-icon name="chevron_right" color="grey-4" /></q-item-section>
            </q-item>
            <q-separator inset class="bg-grey-2" />
            <q-item clickable v-ripple class="q-py-md" @click="handleLogout">
              <q-item-section avatar><div class="icon-circle bg-red-1 text-red-5"><q-icon name="logout" size="18px" /></div></q-item-section>
              <q-item-section class="text-red-5 text-weight-bold text-subtitle2">Log Out</q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </template>
    </main>

    <!-- Edit Profile Dialog -->
    <q-dialog v-model="editDialog" position="bottom">
      <q-card class="full-width border-radius-24-top q-pa-md pb-safe">
        <div class="row items-center justify-between q-mb-md">
          <div class="text-h6 text-weight-bold">Edit Profile</div>
          <q-btn flat round dense icon="close" color="grey-6" aria-label="Close edit profile" v-close-popup />
        </div>
        <div class="text-caption text-grey-6 q-mb-xs">Full Name</div>
        <q-input v-model="editForm.fullName" outlined dense class="q-mb-md" placeholder="Your full name" />
        <div class="text-caption text-grey-6 q-mb-xs">Email</div>
        <q-input v-model="editForm.email" outlined dense readonly class="q-mb-lg" hint="Email is managed by your sign-in provider." />
        <q-btn unelevated color="teal-8" label="Save Changes" class="full-width border-radius-16 text-weight-bold q-py-sm" no-caps :loading="savingProfile" @click="saveEdit" />
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useQuasar } from 'quasar'
import { useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'

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
  } catch (caught) {
    console.error('loadProfile error:', caught)
    error.value = caught instanceof Error ? caught.message : 'Failed to load profile'
  } finally {
    loading.value = false
  }
}

function openEdit() {
  editForm.value = { fullName: profile.value.fullName, email: profile.value.email === '—' ? '' : profile.value.email }
  editDialog.value = true
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
function openScanner() { void router.push('/landlord/profile/qr-scanner') }
function openProperty(id: string) { void router.push(`/landlord/properties/${id}`) }
function goToSettings() { void router.push('/landlord/settings') }
function goBack() {
  const hasUsefulHistory = window.history.length > 1 && Boolean(window.history.state?.back)
  if (hasUsefulHistory) { router.back(); return }
  void router.replace('/landlord/dashboard')
}
async function handleLogout() { await supabase.auth.signOut(); void router.push('/login') }

onMounted(() => { void loadProfile() })
</script>

<style scoped>
.profile-page {
  min-height: 100vh;
  background: var(--m-bg);
  color: var(--m-text);
}

.profile-page-bar {
  position: sticky;
  top: 0;
  z-index: 10;
  display: grid;
  min-height: 56px;
  grid-template-columns: 44px 1fr 44px;
  align-items: center;
  gap: var(--m-space-2);
  padding: 0 var(--m-space-4);
  border-bottom: 1px solid var(--m-border);
  background: var(--m-surface);
}

.profile-content {
  width: min(100%, 760px);
  margin: 0 auto;
  padding: var(--m-space-3) 0 var(--m-space-8);
}

.profile-back-button {
  display: grid;
  width: 44px;
  height: 44px;
  padding: 0;
  place-items: center;
  border: 0;
  border-radius: 50%;
  background: transparent;
  color: var(--m-ink);
  cursor: pointer;
}

.profile-gradient { background: linear-gradient(135deg, var(--m-primary-dark), var(--m-primary)); }
.profile-avatar {
  border: 4px solid var(--m-surface);
  background: var(--m-primary-dark);
  box-shadow: var(--m-shadow);
  cursor: pointer;
}
.camera-badge {
  bottom: 0 !important;
  right: 0 !important;
  top: auto !important;
  width: 24px;
  height: 24px;
  border: 2px solid var(--m-surface);
  border-radius: 50%;
  cursor: pointer;
}
.detail-box {
  height: 100%;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
}
.stat-card {
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.stat-note { min-height: 12px; font-size: 10px; font-weight: 700; }
.border-radius-24 { border-radius: var(--m-radius-lg); }
.border-radius-24-top { border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0; }
.border-radius-16 { border-radius: var(--m-radius); }
.shadow-soft { border: 1px solid var(--m-border); box-shadow: var(--m-shadow); }
.icon-circle {
  display: flex;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
}
.section-list { overflow: hidden; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-bg); }
.empty-row { padding: var(--m-space-4); border: 1px dashed var(--m-border); border-radius: var(--m-radius); background: var(--m-bg); color: var(--m-muted); text-align: center; }
.review-stars { gap: 2px; }
.review-comment { line-height: 1.5; overflow-wrap: anywhere; }
.identity-line { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.bg-white-20 { background: rgba(255, 255, 255, 0.2); }
.line-height-tight { line-height: 1.2; }
.letter-spacing-1 { letter-spacing: 0.5px; }
.text-xs { font-size: 11px; }
.font-size-32 { font-size: 32px; }

.profile-state {
  display: grid;
  min-height: 260px;
  place-items: center;
  align-content: center;
  gap: var(--m-space-3);
  padding: var(--m-space-6);
  color: var(--m-muted);
  text-align: center;
}
.profile-state--error { color: var(--m-danger); }
.profile-state-action { min-height: 44px; border-radius: var(--m-radius-sm); }
.shell-icon-button { min-width: 44px; min-height: 44px; }
.profile-back-button:focus-visible { outline: 2px solid var(--m-primary); outline-offset: 2px; }
:deep(.q-card) { color: var(--m-text); }
:deep(.q-item) { min-height: 60px; }
:deep(.q-btn:not(.q-btn--dense)) { min-height: 44px; }

@media (max-width: 560px) {
  .stats-row { margin-right: -8px; margin-left: -8px; row-gap: var(--m-space-3); }
  .stat-column { width: 50%; }
}

@media (max-width: 420px) {
  .profile-content { padding-top: var(--m-space-3); }
  .stat-card :deep(.q-card__section) { padding: var(--m-space-3); }
  .compliance-row { align-items: flex-start; flex-wrap: wrap; }
}

@media (prefers-reduced-motion: reduce) {
  * { transition: none !important; }
}
</style>
