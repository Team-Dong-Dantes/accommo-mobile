<template>
  <q-page class="landlord-profile-page">
    <div class="profile-shell">
      <div class="profile-hero">
        <div class="top-actions">
          <q-btn flat round dense icon="edit" class="edit-btn" />
        </div>

        <div class="avatar-wrap">
          <q-avatar size="110px" class="profile-avatar" text-color="white" color="teal-9">
            {{ initials }}
          </q-avatar>
          <q-btn round dense class="camera-btn" color="white" text-color="teal-9" icon="photo_camera" />
        </div>

        <div class="hero-user-block">
          <div class="status-row">
            <q-badge color="green-2" text-color="green-9" class="status-badge">
              <q-icon name="check" size="14px" class="q-mr-xs" />
              OSAS Verified
            </q-badge>
          </div>

          <div class="text-h5 text-weight-bold text-white q-mt-md">{{ profile.fullName }}</div>
          <div class="text-subtitle2 text-white-7">{{ profile.landlordCode }} · Member since {{ profile.memberSince }}</div>
        </div>
      </div>

      <div v-if="profileError" class="q-px-md q-mt-md">
        <q-banner class="bg-red-1 text-red-8 rounded-borders">
          {{ profileError }}
        </q-banner>
      </div>

      <div class="info-grid q-px-md q-mt-lg">
        <div class="info-card">
          <div class="info-label">Email</div>
          <div class="info-value">{{ profile.email }}</div>
        </div>
        <div class="info-card">
          <div class="info-label">Contact</div>
          <div class="info-value">{{ profile.phone }}</div>
        </div>
        <div class="info-card">
          <div class="info-label">Area</div>
          <div class="info-value">{{ profile.area }}</div>
        </div>
        <div class="info-card">
          <div class="info-label">Joined</div>
          <div class="info-value">{{ profile.joinedLabel }}</div>
        </div>
      </div>

      <div class="metrics-grid q-px-md q-mt-lg">
        <div v-for="metric in metrics" :key="metric.label" class="metric-card">
          <div class="metric-value">{{ metric.value }}</div>
          <div class="metric-label">{{ metric.label }}</div>
          <div class="metric-note" :class="metric.noteTone">{{ metric.note }}</div>
        </div>
      </div>

      <div class="section-wrap q-px-md q-mt-lg">
        <q-card flat bordered class="promo-card">
          <q-card-section class="row items-center no-wrap q-col-gutter-sm">
            <div class="col-auto">
              <div class="promo-icon">
                <q-icon name="qr_code_2" size="28px" />
              </div>
            </div>
            <div class="col">
              <div class="promo-title">Student QR verification</div>
              <div class="promo-copy">Quickly verify tenant identity and residency records</div>
            </div>
          </q-card-section>

          <q-card-actions class="q-pa-md q-pt-none">
            <q-btn
              unelevated
              full-width
              rounded
              color="purple-5"
              class="scanner-btn"
              @click="openScanner"
            >
              <q-icon name="qr_code_scanner" class="q-mr-sm" />
              Open Scanner
            </q-btn>
          </q-card-actions>
        </q-card>
      </div>

      <div class="section-wrap q-px-md q-mt-lg">
        <div class="section-header row items-center justify-between">
          <div class="section-title">My Boarding Houses</div>
          <q-badge color="green-2" text-color="green-9" class="section-badge">{{ properties.length }} active</q-badge>
        </div>

        <q-card flat bordered class="content-card">
          <q-list separator>
            <q-item v-if="properties.length === 0">
              <q-item-section>
                <div class="empty-state">No properties yet</div>
              </q-item-section>
            </q-item>

            <q-item v-for="property in properties" :key="property.id" clickable v-ripple class="property-item">
              <q-item-section avatar>
                <div class="property-icon">
                  <q-icon :name="property.icon" size="22px" />
                </div>
              </q-item-section>

              <q-item-section>
                <div class="property-name">{{ property.name }}</div>
                <div class="property-address">{{ property.address }}</div>
                <div class="property-meta row items-center q-mt-xs">
                  <q-icon name="star" size="14px" color="amber-6" class="q-mr-xs" />
                  <span>{{ property.rating }}</span>
                </div>
                <div class="property-occupancy q-mt-sm">{{ property.occupancyLabel }} · <span class="available-text">{{ property.availableLabel }}</span></div>
              </q-item-section>

              <q-item-section side>
                <q-icon name="chevron_right" color="grey-6" size="24px" />
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <div class="section-wrap q-px-md q-mt-lg">
        <div class="section-header row items-center justify-between">
          <div class="section-title row items-center no-wrap">
            <q-icon name="shield" size="20px" class="q-mr-sm" color="teal-9" />
            OSAS Compliance
          </div>
        </div>

        <q-card flat bordered class="content-card">
          <q-list separator>
            <q-item v-if="complianceItems.length === 0">
              <q-item-section>
                <div class="empty-state">No compliance records yet</div>
              </q-item-section>
            </q-item>

            <q-item v-for="item in complianceItems" :key="item.name" class="compliance-item">
              <q-item-section avatar>
                <span class="status-dot" :class="item.statusTone" />
              </q-item-section>

              <q-item-section>
                <div class="compliance-name">{{ item.name }}</div>
                <div class="compliance-date">{{ item.date }}</div>
              </q-item-section>

              <q-item-section side>
                <q-badge :color="item.badgeColor" text-color="white" class="status-badge-pill">
                  {{ item.statusText }}
                </q-badge>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <div class="section-wrap q-px-md q-mt-lg">
        <div class="section-header row items-center justify-between">
          <div class="section-title row items-center no-wrap">
            <q-icon name="star" size="20px" class="q-mr-sm" color="amber-6" />
            Recent Reviews
          </div>
          <q-badge color="amber-2" text-color="amber-9" class="section-badge">{{ reviewsAverage }} avg</q-badge>
        </div>

        <q-card flat bordered class="content-card">
          <q-list separator>
            <q-item v-if="displayReviews.length === 0">
              <q-item-section>
                <div class="empty-state">No reviews yet</div>
              </q-item-section>
            </q-item>

            <q-item v-for="review in displayReviews" :key="review.id" class="review-item">
              <q-item-section avatar>
                <q-avatar size="36px" color="grey-3" text-color="grey-8" class="review-avatar">
                  {{ review.initials }}
                </q-avatar>
              </q-item-section>

              <q-item-section>
                <div class="review-author row items-center justify-between">
                  <span class="text-weight-medium">{{ review.author }}</span>
                  <span class="review-date">{{ review.date }}</span>
                </div>
                <div class="review-stars row items-center q-mt-xs">
                  <q-icon v-for="star in 5" :key="star" name="star" size="14px" :color="star <= review.rating ? 'amber-6' : 'grey-4'" />
                </div>
                <div class="review-comment q-mt-xs">{{ review.comment }}</div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <div class="section-wrap q-px-md q-mt-lg">
        <div class="section-header row items-center justify-between">
          <div class="section-title row items-center no-wrap">
            <q-icon name="forum" size="20px" class="q-mr-sm" color="teal-9" />
            Messages
          </div>
          <q-badge color="red-2" text-color="red-9" class="section-badge">{{ unreadMessageCount }} new</q-badge>
        </div>

        <q-card flat bordered class="content-card">
          <q-list separator>
            <q-item v-if="messages.length === 0">
              <q-item-section>
                <div class="empty-state">No messages yet</div>
              </q-item-section>
            </q-item>

            <q-item v-for="message in messages" :key="message.id" clickable v-ripple class="activity-item" @click="openMessage(message)">
              <q-item-section avatar>
                <q-avatar size="40px" color="teal-8" text-color="white" class="activity-avatar">
                  {{ message.initials }}
                </q-avatar>
              </q-item-section>

              <q-item-section>
                <div class="activity-title row items-center justify-between">
                  <span class="text-weight-bold">{{ message.sender }}</span>
                  <span class="activity-time">{{ message.time }}</span>
                </div>
                <div class="activity-preview q-mt-xs">{{ message.preview }}</div>
              </q-item-section>

              <q-item-section side>
                <span v-if="message.unread" class="unread-dot" />
                <q-icon v-else name="chevron_right" color="grey-6" size="22px" />
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <div class="section-wrap q-px-md q-mt-lg">
        <div class="section-header row items-center justify-between">
          <div class="section-title row items-center no-wrap">
            <q-icon name="notifications" size="20px" class="q-mr-sm" color="teal-9" />
            Notifications
          </div>
          <q-badge color="amber-2" text-color="amber-9" class="section-badge">{{ notifications.length }}</q-badge>
        </div>

        <q-card flat bordered class="content-card">
          <q-list separator>
            <q-item v-if="notifications.length === 0">
              <q-item-section>
                <div class="empty-state">No notifications yet</div>
              </q-item-section>
            </q-item>

            <q-item v-for="notification in notifications" :key="notification.id" clickable v-ripple class="activity-item" @click="openNotification(notification)">
              <q-item-section avatar>
                <div class="activity-icon" :class="notification.tone">
                  <q-icon :name="notification.icon" size="20px" />
                </div>
              </q-item-section>

              <q-item-section>
                <div class="activity-title row items-center justify-between">
                  <span class="text-weight-bold">{{ notification.title }}</span>
                  <span class="activity-time">{{ notification.time }}</span>
                </div>
                <div class="activity-preview q-mt-xs">{{ notification.body }}</div>
              </q-item-section>

              <q-item-section side>
                <q-icon name="chevron_right" color="grey-6" size="22px" />
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <div class="section-wrap q-px-md q-mt-lg">
        <div class="section-header row items-center justify-between">
          <div class="section-title row items-center no-wrap">
            <q-icon name="rate_review" size="20px" class="q-mr-sm" color="teal-9" />
            Feedback
          </div>
          <q-badge color="amber-2" text-color="amber-9" class="section-badge">{{ feedbackAverage }} avg</q-badge>
        </div>

        <q-card flat bordered class="content-card">
          <q-list separator>
            <q-item v-if="feedback.length === 0">
              <q-item-section>
                <div class="empty-state">No feedback yet</div>
              </q-item-section>
            </q-item>

            <q-item v-for="item in feedback" :key="item.id" clickable v-ripple class="activity-item" @click="openFeedback(item)">
              <q-item-section avatar>
                <q-avatar size="40px" color="grey-3" text-color="grey-8" class="activity-avatar">
                  {{ item.initials }}
                </q-avatar>
              </q-item-section>

              <q-item-section>
                <div class="activity-title row items-center justify-between">
                  <span class="text-weight-bold">{{ item.author }}</span>
                  <span class="activity-time">{{ item.date }}</span>
                </div>
                <div class="activity-stars row items-center q-mt-xs">
                  <q-icon v-for="star in 5" :key="star" name="star" size="13px" :color="star <= item.rating ? 'amber-6' : 'grey-4'" />
                </div>
                <div class="activity-preview q-mt-xs">{{ item.comment }}</div>
              </q-item-section>

              <q-item-section side>
                <q-icon name="chevron_right" color="grey-6" size="22px" />
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <div class="section-wrap q-px-md q-mt-lg q-mb-xl">
        <q-list bordered class="settings-list">
          <q-item clickable v-ripple @click="goToSettings">
            <q-item-section avatar>
              <q-icon name="settings" color="grey-7" />
            </q-item-section>
            <q-item-section>
              <q-item-label class="settings-title">Settings</q-item-label>
              <q-item-label caption class="settings-subtitle">Notifications, business, security</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-icon name="chevron_right" color="grey-6" />
            </q-item-section>
          </q-item>
        </q-list>

        <q-btn flat class="logout-button" icon="logout" label="Log Out" @click="handleLogout" />
      </div>
    </div>
      <q-dialog v-model="detailDialog" position="bottom">
        <q-card class="detail-dialog-card">
          <q-card-section class="q-pt-lg">
            <div class="detail-type">{{ detailData.type }}</div>
            <div class="detail-title">{{ detailData.title }}</div>
            <div v-if="detailData.subtitle" class="detail-subtitle">{{ detailData.subtitle }}</div>
            <div class="detail-meta">{{ detailData.meta }}</div>
            <div v-if="detailData.rating" class="detail-stars row items-center q-mt-sm">
              <q-icon v-for="star in 5" :key="star" name="star" size="18px" :color="star <= detailData.rating ? 'amber-6' : 'grey-4'" />
              <span class="detail-rating-label q-ml-sm">{{ detailData.rating }} / 5</span>
            </div>
            <div class="detail-body q-mt-md">{{ detailData.body }}</div>
          </q-card-section>

          <q-card-actions align="right" class="q-pa-md q-pt-none">
            <q-btn flat label="Close" color="teal-9" v-close-popup />
          </q-card-actions>
        </q-card>
      </q-dialog>

  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'

interface ProfileState {
  fullName: string
  landlordCode: string
  email: string
  phone: string
  area: string
  memberSince: string
  joinedLabel: string
}

interface MetricItem {
  label: string
  value: string
  note: string
  noteTone: string
}

interface PropertyItem {
  id: string
  name: string
  address: string
  rating: number
  occupancy: number
  occupancyLabel: string
  availableLabel: string
  icon: string
}

interface ComplianceItem {
  name: string
  date: string
  statusText: string
  badgeColor: string
  statusTone: string
}

interface ReviewItem {
  id: string
  initials: string
  author: string
  rating: number
  date: string
  comment: string
}

const router = useRouter()

const profile = ref<ProfileState>({
  fullName: 'Juan Dela Cruz',
  landlordCode: 'LL-2021-009',
  email: 'jdelacruz@email.com',
  phone: '+63 912 345 6789',
  area: 'Echague, Isabela',
  memberSince: 'Aug 2021',
  joinedLabel: 'August 2021',
})

const profileError = ref<string | null>(null)
const properties = ref<PropertyItem[]>([])
const complianceItems = ref<ComplianceItem[]>([])
const reviews = ref<ReviewItem[]>([])

const placeholderReviews = ref<ReviewItem[]>([
  {
    id: 'pr1',
    initials: 'MS',
    author: 'Maria Santos',
    rating: 5,
    date: '2d ago',
    comment: 'Very responsive landlord. The boarding house is clean and well-maintained. Highly recommended!',
  },
  {
    id: 'pr2',
    initials: 'JR',
    author: 'John Reyes',
    rating: 4,
    date: '5d ago',
    comment: 'Great location near campus and affordable. Wifi could be a bit faster at night.',
  },
  {
    id: 'pr3',
    initials: 'AT',
    author: 'Anonymous Tenant',
    rating: 5,
    date: '1w ago',
    comment: 'Safe and quiet environment. The landlord handles repairs quickly.',
  },
])

const displayReviews = computed(() => {
  if (reviews.value.length > 0) return reviews.value
  return placeholderReviews.value
})
const activeTenantCount = ref(0)
const reviewAverage = ref(0)

const initials = computed(() => {
  const parts = profile.value.fullName.split(' ').filter(Boolean)
  return `${parts[0]?.[0] ?? 'J'}${parts[1]?.[0] ?? 'D'}`.toUpperCase()
})

const reviewsAverage = computed(() => {
  const source = displayReviews.value
  if (source.length === 0) return '0.0'
  const average = source.reduce((sum, review) => sum + review.rating, 0) / source.length
  return average.toFixed(1)
})

const metrics = computed<MetricItem[]>(() => [
  {
    label: 'Boarding Houses',
    value: String(properties.value.length || 0),
    note: 'Active',
    noteTone: 'note-positive',
  },
  {
    label: 'Tenants',
    value: String(activeTenantCount.value),
    note: `${Math.max(activeTenantCount.value - 13, 0)} new`,
    noteTone: 'note-neutral',
  },
  {
    label: 'Rating',
    value: reviewsAverage.value,
    note: `${reviews.value.length} reviews`,
    noteTone: 'note-neutral',
  },
  {
    label: 'Occupancy',
    value: `${getOccupancyAverage()}%`,
    note: '+1.2%',
    noteTone: 'note-positive',
  },
])

function getOccupancyAverage() {
  if (properties.value.length === 0) return 0

  const total = properties.value.reduce((sum, item) => sum + item.occupancy, 0)
  return Math.round(total / properties.value.length)
}

async function loadProfileData() {
  profileError.value = null

  try {
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser()

    if (userError || !user) {
      void router.push('/login')
      return
    }

    const { data: userRow, error: userRowError } = await supabase
      .from('users')
      .select('full_name, phone, created_at')
      .eq('id', user.id)
      .maybeSingle()

    if (userRowError) throw userRowError

    if (userRow?.full_name) {
      profile.value.fullName = userRow.full_name
    }

    if (user.email) {
      profile.value.email = user.email
    }

    if (userRow?.phone) {
      profile.value.phone = userRow.phone
    }

    if (userRow?.created_at) {
      const joinedDate = new Date(userRow.created_at)
      profile.value.memberSince = joinedDate.toLocaleString('en-US', { month: 'short', year: 'numeric' })
      profile.value.joinedLabel = joinedDate.toLocaleString('en-US', { month: 'long', year: 'numeric' })
    }

    const { data: propertyRows, error: propertyError } = await supabase
      .from('properties')
      .select('id, name, address, status, total_rooms, capacity')
      .eq('landlord_id', user.id)
      .order('name')

    if (propertyError) throw propertyError

    const mappedProperties = (propertyRows ?? []).map((property: any, index: number) => {
      const totalRooms = Number(property.total_rooms ?? 0)
      const occupied = Math.max(totalRooms - Number(property.capacity ?? 0), 0)
      const available = Math.max(totalRooms - occupied, 0)

      return {
        id: String(property.id),
        name: property.name ?? `Property ${index + 1}`,
        address: property.address ?? 'No address provided',
        rating: 4.8,
        occupancy: totalRooms > 0 ? Math.min(100, Math.round((occupied / totalRooms) * 100)) : 0,
        occupancyLabel: totalRooms > 0 ? `${occupied}/${totalRooms} occupied` : '0/0 occupied',
        availableLabel: `${available} available`,
        icon: index % 3 === 0 ? 'apartment' : index % 3 === 1 ? 'home' : 'business',
      }
    })

    properties.value = mappedProperties

    const { data: leaseRows, count, error: leaseError } = await supabase
      .from('leases')
      .select('id', { count: 'exact' })
      .eq('landlord_id', user.id)
      .eq('status', 'active')

    if (leaseError) throw leaseError
    activeTenantCount.value = count ?? leaseRows?.length ?? 0

    const { data: reviewRows, error: reviewError } = await supabase
      .from('landlord_reviews')
      .select('id, rating, comment, created_at, users!student_id(full_name)')
      .eq('landlord_id', user.id)
      .order('created_at', { ascending: false })
      .limit(5)

    if (reviewError) throw reviewError

    reviews.value = (reviewRows ?? []).map((review: any) => {
      const author = review.users?.full_name ?? 'Anonymous Student'
      const initialsValue = author
        .split(' ')
        .filter(Boolean)
        .slice(0, 2)
        .map((part: string) => part[0])
        .join('')
        .toUpperCase()

      return {
        id: String(review.id),
        initials: initialsValue || 'ST',
        author,
        rating: Number(review.rating ?? 0),
        date: review.created_at ? new Date(review.created_at).toLocaleString('en-US', { month: 'short', year: 'numeric' }) : 'Recent',
        comment: review.comment ?? 'Great experience overall',
      }
    })

    reviewAverage.value = reviews.value.length > 0
      ? reviews.value.reduce((sum, review) => sum + review.rating, 0) / reviews.value.length
      : 0

    const { data: documentRows, error: documentError } = await supabase
      .from('verification_documents')
      .select('doc_type, expiry_date, status, filename')
      .eq('user_id', user.id)
      .order('expiry_date', { ascending: true })
      .limit(8)

    if (documentError) throw documentError

    const mappedDocs = (documentRows ?? []).map((doc: any) => {
      const docName = doc.doc_type ? doc.doc_type.replace(/_/g, ' ').replace(/\b\w/g, (char: string) => char.toUpperCase()) : 'Document'
      const statusText = doc.status === 'approved' ? 'Valid' : doc.status === 'pending' ? 'Expiring' : 'Missing'
      const badgeColor = statusText === 'Valid' ? 'green-7' : statusText === 'Expiring' ? 'amber-6' : 'grey-7'
      const statusTone = statusText === 'Valid' ? 'tone-valid' : statusText === 'Expiring' ? 'tone-warning' : 'tone-warning'

      return {
        name: docName,
        date: doc.expiry_date ? new Date(doc.expiry_date).toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : 'No date',
        statusText,
        badgeColor,
        statusTone,
      }
    })

    if (mappedDocs.length === 0) {
      complianceItems.value = [
        {
          name: 'Business Permit',
          date: 'No record',
          statusText: 'Valid',
          badgeColor: 'green-7',
          statusTone: 'tone-valid',
        },
        {
          name: 'OSAS Accreditation',
          date: 'No record',
          statusText: 'Valid',
          badgeColor: 'green-7',
          statusTone: 'tone-valid',
        },
      ]
    } else {
      complianceItems.value = mappedDocs
    }
  } catch (error) {
    profileError.value = error instanceof Error ? error.message : 'Failed to load profile details'
  }
}

const openScanner = () => {
  void router.push('/landlord/profile/qr-scanner')
}

const goToSettings = () => {
  void router.push('/landlord/settings')
}

const handleLogout = async () => {
  await supabase.auth.signOut()
  void router.push('/login')
}

interface MessageItem {
  id: string
  sender: string
  initials: string
  preview: string
  body: string
  time: string
  unread: boolean
}

interface NotificationItem {
  id: string
  icon: string
  tone: string
  title: string
  body: string
  time: string
}

interface FeedbackItem {
  id: string
  author: string
  initials: string
  rating: number
  date: string
  comment: string
}

interface DetailView {
  type: string
  title: string
  subtitle: string
  meta: string
  body: string
  rating: number
}

const messages = ref<MessageItem[]>([
  {
    id: 'm1',
    sender: 'Maria Santos',
    initials: 'MS',
    preview: 'Question about lease renewal for Room 3',
    body: 'Hi! My lease ends next month. Can we renew for another semester? Also, is the advance payment still the same amount?',
    time: '2h ago',
    unread: true,
  },
  {
    id: 'm2',
    sender: 'OSAS Office',
    initials: 'OS',
    preview: 'Accreditation documents received',
    body: 'We have received your submitted business permit. Our officer will review it within 3 business days and update your status.',
    time: '1d ago',
    unread: false,
  },
  {
    id: 'm3',
    sender: 'Pedro Cruz',
    initials: 'PC',
    preview: 'Maintenance request: leaky faucet',
    body: 'The faucet in the common kitchen has been dripping since yesterday. Could someone take a look at it this week?',
    time: '3d ago',
    unread: false,
  },
])

const notifications = ref<NotificationItem[]>([
  {
    id: 'n1',
    icon: 'payments',
    tone: 'tone-green',
    title: 'Rent payment received',
    body: 'Maria Santos paid 3,500 for Room 3 (August 2026).',
    time: '2h ago',
  },
  {
    id: 'n2',
    icon: 'assignment',
    tone: 'tone-purple',
    title: 'New lease request',
    body: 'John Reyes submitted a lease application for Sunset Terrace.',
    time: '5h ago',
  },
  {
    id: 'n3',
    icon: 'warning',
    tone: 'tone-amber',
    title: 'Document expiring soon',
    body: 'Your Fire Safety Certificate expires in 14 days. Please renew to avoid compliance issues.',
    time: '1d ago',
  },
])

const feedback = ref<FeedbackItem[]>([
  {
    id: 'f1',
    author: 'Maria Santos',
    initials: 'MS',
    rating: 5,
    date: '2d ago',
    comment: 'Very responsive landlord. The boarding house is clean and well-maintained. Highly recommended!',
  },
  {
    id: 'f2',
    author: 'Anonymous Tenant',
    initials: 'AT',
    rating: 4,
    date: '1w ago',
    comment: 'Good location near campus. Wifi could be a bit faster during peak hours.',
  },
])

const detailDialog = ref(false)
const detailData = ref<DetailView>({
  type: '',
  title: '',
  subtitle: '',
  meta: '',
  body: '',
  rating: 0,
})

const unreadMessageCount = computed(() => messages.value.filter((message) => message.unread).length)

const feedbackAverage = computed(() => {
  if (feedback.value.length === 0) return '0.0'
  const average = feedback.value.reduce((sum, item) => sum + item.rating, 0) / feedback.value.length
  return average.toFixed(1)
})

function openMessage(message: MessageItem) {
  detailData.value = {
    type: 'Message',
    title: message.sender,
    subtitle: message.preview,
    meta: message.time,
    body: message.body,
    rating: 0,
  }
  detailDialog.value = true
}

function openNotification(notification: NotificationItem) {
  detailData.value = {
    type: 'Notification',
    title: notification.title,
    subtitle: '',
    meta: notification.time,
    body: notification.body,
    rating: 0,
  }
  detailDialog.value = true
}

function openFeedback(item: FeedbackItem) {
  detailData.value = {
    type: 'Feedback',
    title: item.author,
    subtitle: '',
    meta: item.date,
    body: item.comment,
    rating: item.rating,
  }
  detailDialog.value = true
}

onMounted(() => {
  void loadProfileData()
})
</script>

<style scoped>
.landlord-profile-page {
  background: #F7F9FA;
  min-height: 100vh;
}

.profile-shell {
  padding-bottom: 32px;
}

.profile-hero {
  position: relative;
  background: linear-gradient(180deg, #005F59 0%, #003F3A 100%);
  padding: 20px 20px 120px;
  border-bottom-left-radius: 32px;
  border-bottom-right-radius: 32px;
}

.top-actions {
  display: flex;
  justify-content: flex-end;
}

.edit-btn {
  color: rgba(255, 255, 255, 0.9);
}

.avatar-wrap {
  position: relative;
  display: flex;
  justify-content: center;
  margin-top: 8px;
}

.profile-avatar {
  border: 4px solid #FFFFFF;
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.12);
  font-size: 38px;
  font-weight: 700;
}

.camera-btn {
  position: absolute;
  right: calc(50% - 62px);
  bottom: -10px;
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.12);
}

.hero-user-block {
  margin-top: 18px;
  text-align: center;
}

.status-badge {
  border-radius: 999px;
  padding: 6px 12px;
  font-size: 11px;
  font-weight: 700;
}

.text-white-7 {
  color: rgba(255, 255, 255, 0.75);
}

.info-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin-top: -72px;
  position: relative;
  z-index: 2;
}

.info-card {
  background: #FFFFFF;
  border: 1px solid rgba(0, 0, 0, 0.05);
  border-radius: 16px;
  padding: 14px 12px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.04);
}

.info-label {
  color: #6B7280;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.info-value {
  color: #1F2937;
  font-size: 14px;
  font-weight: 700;
  margin-top: 8px;
  line-height: 1.45;
}

.metrics-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin-top: 18px;
}

.metric-card {
  background: #FFFFFF;
  border: 1px solid rgba(0, 0, 0, 0.05);
  border-radius: 18px;
  padding: 18px 14px;
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.03);
}

.metric-value {
  font-size: 28px;
  font-weight: 800;
  color: #1F2937;
  line-height: 1;
}

.metric-label {
  font-size: 12px;
  color: #6B7280;
  margin-top: 8px;
  font-weight: 600;
}

.metric-note {
  margin-top: 8px;
  font-size: 11px;
  font-weight: 700;
}

.note-positive {
  color: #00897B;
}

.note-neutral {
  color: #6B7280;
}

.section-wrap {
  margin-top: 20px;
}

.promo-card {
  background: #FFFFFF;
  border: 1px solid rgba(0, 0, 0, 0.05);
  border-radius: 20px;
  box-shadow: 0 6px 14px rgba(0, 0, 0, 0.03);
}

.promo-icon {
  width: 52px;
  height: 52px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 14px;
  background: rgba(102, 58, 183, 0.12);
  color: #6D28D9;
}

.promo-title {
  color: #1F2937;
  font-weight: 700;
  font-size: 16px;
}

.promo-copy {
  color: #6B7280;
  font-size: 12px;
  margin-top: 4px;
  line-height: 1.4;
}

.scanner-btn {
  font-weight: 700;
  border-radius: 12px;
  height: 48px;
}

.section-header {
  margin-bottom: 10px;
}

.section-title {
  color: #1F2937;
  font-size: 20px;
  font-weight: 800;
}

.section-badge {
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
  padding: 6px 10px;
}

.content-card {
  background: #FFFFFF;
  border: 1px solid rgba(0, 0, 0, 0.05);
  border-radius: 20px;
  overflow: hidden;
}

.property-item {
  padding: 16px 14px;
}

.property-icon {
  width: 42px;
  height: 42px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
  background: rgba(0, 137, 123, 0.11);
  color: #00897B;
}

.property-name {
  color: #1F2937;
  font-size: 16px;
  font-weight: 700;
}

.property-address {
  color: #6B7280;
  font-size: 12px;
  margin-top: 2px;
}

.property-meta {
  color: #374151;
  font-size: 12px;
  font-weight: 600;
}

.property-occupancy {
  color: #374151;
  font-size: 12px;
  font-weight: 600;
}

.available-text {
  color: #0f766e;
  font-weight: 800;
}

.compliance-item {
  padding: 16px 14px;
}

.status-dot {
  display: inline-block;
  width: 12px;
  height: 12px;
  border-radius: 50%;
}

.tone-valid {
  background: #22C55E;
  box-shadow: 0 0 0 4px rgba(34, 197, 94, 0.12);
}

.tone-warning {
  background: #F59E0B;
  box-shadow: 0 0 0 4px rgba(245, 158, 11, 0.12);
}

.compliance-name {
  color: #1F2937;
  font-size: 15px;
  font-weight: 700;
}

.compliance-date {
  color: #6B7280;
  font-size: 12px;
  margin-top: 4px;
}

.status-badge-pill {
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}

.review-item {
  padding: 16px 14px;
}

.review-avatar {
  font-size: 12px;
  font-weight: 700;
}

.review-author {
  color: #1F2937;
  font-size: 14px;
}

.review-date {
  color: #6B7280;
  font-size: 11px;
}

.review-stars {
  gap: 2px;
}

.review-comment {
  color: #4B5563;
  font-size: 13px;
  line-height: 1.5;
}

.settings-list {
  background: #FFFFFF;
  border: 1px solid rgba(0, 0, 0, 0.05);
  border-radius: 18px;
  overflow: hidden;
}

.settings-title {
  color: #1F2937;
  font-size: 15px;
  font-weight: 700;
}

.settings-subtitle {
  color: #6B7280;
  font-size: 12px;
}

.logout-button {
  width: 100%;
  margin-top: 18px;
  background: rgba(220, 38, 38, 0.06);
  color: #DC2626;
  border-radius: 14px;
  font-weight: 700;
}

.empty-state {
  color: #6B7280;
  font-size: 14px;
  font-weight: 600;
  padding: 12px 0;
}

@media (min-width: 768px) {
  .profile-shell {
    max-width: 760px;
    margin: 0 auto;
  }
}

.activity-item {
  padding: 14px;
}

.activity-avatar {
  font-size: 13px;
  font-weight: 700;
}

.activity-title {
  color: #1F2937;
  font-size: 14px;
}

.activity-time {
  color: #9CA3AF;
  font-size: 11px;
  font-weight: 600;
}

.activity-preview {
  color: #6B7280;
  font-size: 12px;
  line-height: 1.4;
}

.activity-stars {
  gap: 2px;
}

.unread-dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #DC2626;
}

.activity-icon {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
}

.tone-green { background: rgba(16, 185, 129, 0.12); color: #059669; }
.tone-purple { background: rgba(124, 58, 237, 0.12); color: #7C3AED; }
.tone-amber { background: rgba(245, 158, 11, 0.14); color: #D97706; }

.detail-dialog-card {
  width: 100%;
  max-width: 460px;
  border-radius: 20px 20px 0 0;
}

.detail-type {
  color: #0F766E;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.detail-title {
  color: #1F2937;
  font-size: 20px;
  font-weight: 800;
  margin-top: 6px;
}

.detail-subtitle {
  color: #4B5563;
  font-size: 13px;
  font-weight: 600;
  margin-top: 4px;
}

.detail-meta {
  color: #9CA3AF;
  font-size: 12px;
  font-weight: 600;
  margin-top: 6px;
}

.detail-rating-label {
  color: #6B7280;
  font-size: 13px;
  font-weight: 700;
}

.detail-body {
  color: #374151;
  font-size: 14px;
  line-height: 1.6;
}
</style>

