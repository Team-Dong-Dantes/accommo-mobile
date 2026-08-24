<template>
  <q-page class="tenant-profile-page">
    <!-- Sticky header -->
    <div class="sticky-header">
      <div class="row items-center no-wrap">
        <q-btn flat round dense icon="arrow_back" @click="goBack" />
        <div class="col text-center">
          <div class="header-name">{{ tenant.name }}</div>
          <div class="header-sub">{{ tenant.course }}</div>
        </div>
        <div class="row no-wrap items-center">
          <q-btn flat round dense icon="chat_bubble_outline" @click="openChat" />
          <q-btn flat round dense icon="close" @click="closeProfile" />
        </div>
      </div>
    </div>

    <div class="content q-pa-md">
      <!-- Profile identity -->
      <div class="profile-block text-center">
        <q-avatar size="84px" style="background-color: #00897b; color: #ffffff;">
          <span class="avatar-initials">{{ tenant.initials }}</span>
        </q-avatar>
        <div class="profile-name q-mt-sm">
          {{ tenant.name }}
          <q-icon v-if="tenant.verified" name="verified" size="18px" style="color: #00897b; vertical-align: middle;" />
        </div>
        <div class="profile-id">{{ tenant.studentId }}</div>
      </div>

      <!-- Current stay card -->
      <q-card flat class="stay-card q-mt-md" style="background-color: #e0f2f1;">
        <div class="row items-center no-wrap">
          <q-icon name="person" size="28px" style="color: #00897b;" />
          <div class="col q-ml-md">
            <div class="stay-title">{{ tenant.currentStay.type }} · {{ tenant.currentStay.room }}</div>
            <div class="stay-sub">{{ tenant.currentStay.property }} · {{ tenant.currentStay.floor }}</div>
          </div>
          <q-badge class="current-badge" style="background-color: #ffffff; color: #00897b;">Current</q-badge>
        </div>
      </q-card>

      <!-- Quick stats -->
      <div class="row q-mt-md q-col-gutter-sm">
        <div v-for="stat in tenant.stats" :key="stat.label" class="col-4">
          <q-card flat class="stat-card" :style="{ backgroundColor: stat.bg }">
            <q-icon :name="stat.icon" size="22px" style="color: #00897b;" />
            <div class="stat-value">{{ stat.value }}</div>
            <div class="stat-label">{{ stat.label }}</div>
          </q-card>
        </div>
      </div>

      <!-- Pill tabs -->
      <div class="pill-tabs q-mt-lg">
        <button
          v-for="tab in tabDefs"
          :key="tab.value"
          class="pill-tab"
          :class="{ active: activeTab === tab.value }"
          @click="activeTab = tab.value"
        >
          {{ tab.label }}<span v-if="tab.value === 'reviews'"> ({{ tenant.reviews.length }})</span>
        </button>
      </div>

      <!-- Tab content -->
      <div class="tab-content q-mt-md">
        <!-- Billing -->
        <div v-if="activeTab === 'billing'">
          <q-card flat class="placeholder-card">
            <div class="placeholder-text">No billing records to show.</div>
          </q-card>
        </div>

        <!-- Info -->
        <div v-if="activeTab === 'info'">
          <div class="section-header">CONTACT</div>
          <q-card v-for="c in tenant.contacts" :key="c.label" flat class="info-card">
            <div class="row items-center no-wrap">
              <q-icon :name="c.icon" size="22px" style="color: #00897b;" />
              <div class="col q-ml-md">
                <div class="info-label">{{ c.label }}</div>
                <div class="info-value">{{ c.value }}</div>
              </div>
            </div>
          </q-card>

          <div class="section-header q-mt-lg">EMERGENCY CONTACT</div>
          <q-card flat class="emergency-card" style="background-color: #ffebee;">
            <div class="row items-center no-wrap">
              <q-avatar size="40px" style="background-color: #ffcdd2; color: #c62828;">
                <q-icon name="person" size="22px" />
              </q-avatar>
              <div class="col q-ml-md">
                <div class="info-value">{{ tenant.emergency.name }}</div>
                <div class="info-sub">{{ tenant.emergency.relation }} · {{ tenant.emergency.phone }}</div>
              </div>
            </div>
          </q-card>

          <div class="section-header q-mt-lg">LEASE</div>
          <div class="lease-row">
            <span class="lease-label">Move-in</span>
            <span class="lease-value">{{ tenant.lease.moveIn }}</span>
          </div>
        </div>

        <!-- History -->
        <div v-if="activeTab === 'history'">
          <div class="section-header">BOARDING TIMELINE</div>
          <div class="timeline">
            <div v-for="item in tenant.timeline" :key="item.id" class="timeline-item">
              <div class="timeline-dot" :style="{ backgroundColor: item.dotColor }">
                <q-icon :name="item.status === 'current' ? 'check' : 'schedule'" size="14px" style="color: #ffffff;" />
              </div>
              <q-card flat class="timeline-card" :style="{ backgroundColor: item.status === 'current' ? '#e0f2f1' : '#f5f5f5' }">
                <div class="row items-center justify-between no-wrap">
                  <div class="timeline-title">{{ item.title }}</div>
                  <div v-if="item.status === 'current'" class="active-badge">Active</div>
                </div>
                <div class="timeline-sub">{{ item.property }}</div>
                <div class="timeline-sub">{{ item.period }}</div>
                <div v-if="item.note" class="timeline-note">{{ item.note }}</div>
                <div v-if="item.rating" class="stars q-mt-xs">
                  <q-icon
                    v-for="(filled, i) in filledStars(item.rating)"
                    :key="i"
                    :name="filled ? 'star' : 'star_border'"
                    :style="{ color: filled ? '#fbc02d' : '#cfcfcf', fontSize: '16px' }"
                  />
                </div>
              </q-card>
            </div>
          </div>
        </div>

        <!-- Reviews -->
        <div v-if="activeTab === 'reviews'">
          <div class="section-header">LEAVE A REVIEW</div>
          <q-card flat class="review-card">
            <div class="stars q-mb-md">
              <q-icon
                v-for="i in 5"
                :key="i"
                :name="i <= newReviewRating ? 'star' : 'star_border'"
                :style="{ color: i <= newReviewRating ? '#fbc02d' : '#cfcfcf', fontSize: '28px', cursor: 'pointer' }"
                @click="newReviewRating = i"
              />
            </div>
            <q-input
              v-model="newReviewNote"
              type="textarea"
              borderless
              placeholder="Write a note about this tenant (optional)..."
              class="review-input"
            />
            <q-btn
              unelevated
              class="submit-review"
              style="background-color: #e0e0e0; color: #ffffff;"
              @click="submitReview"
            >
              Submit Review
            </q-btn>
          </q-card>

          <div v-if="tenant.reviews.length" class="q-mt-lg">
            <div v-for="r in tenant.reviews" :key="r.id" class="review-item">
              <div class="row items-center justify-between no-wrap">
                <span class="review-author">{{ r.author }}</span>
                <span class="review-date">{{ r.date }}</span>
              </div>
              <div class="stars q-mt-xs">
                <q-icon
                  v-for="(filled, i) in filledStars(r.rating)"
                  :key="i"
                  :name="filled ? 'star' : 'star_border'"
                  :style="{ color: filled ? '#fbc02d' : '#cfcfcf', fontSize: '16px' }"
                />
              </div>
              <div class="review-note">{{ r.note }}</div>
            </div>
          </div>
          <div v-else class="empty-state q-mt-lg">
            <q-icon name="star" size="56px" style="color: #e0e0e0;" />
            <div class="empty-text">No reviews yet</div>
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'

interface QuickStat {
  value: string
  label: string
  icon: string
  bg: string
}

interface ContactItem {
  icon: string
  label: string
  value: string
}

interface EmergencyContact {
  name: string
  relation: string
  phone: string
}

interface TimelineItem {
  id: number
  status: 'current' | 'past'
  title: string
  property: string
  period: string
  note: string
  rating: number | null
  dotColor: string
}

interface Review {
  id: number
  author: string
  rating: number
  note: string
  date: string
}

interface TenantProfile {
  name: string
  course: string
  initials: string
  verified: boolean
  studentId: string
  currentStay: {
    type: string
    room: string
    property: string
    floor: string
  }
  stats: QuickStat[]
  contacts: ContactItem[]
  emergency: EmergencyContact
  lease: { moveIn: string }
  timeline: TimelineItem[]
  reviews: Review[]
}

type TabValue = 'billing' | 'info' | 'history' | 'reviews'

const router = useRouter()

const activeTab = ref<TabValue>('info')

const tabDefs: ReadonlyArray<{ value: TabValue; label: string }> = [
  { value: 'billing', label: 'Billing' },
  { value: 'info', label: 'Info' },
  { value: 'history', label: 'History' },
  { value: 'reviews', label: 'Reviews' },
]

const newReviewRating = ref(0)
const newReviewNote = ref('')

const tenant = reactive<TenantProfile>({
  name: 'Maria Santos',
  course: 'BS Computer Eng...',
  initials: 'MS',
  verified: true,
  studentId: 'ISU-2021-00342',
  currentStay: {
    type: 'Solo',
    room: 'Room 2-B',
    property: 'Pinzon Student Hub',
    floor: 'Floor 2',
  },
  stats: [
    { value: '₱3,500', label: 'MONTHLY', icon: 'credit_card', bg: '#e0f2f1' },
    { value: '3 mo', label: 'PAY STREAK', icon: 'check_circle', bg: '#ede7f6' },
    { value: '0', label: 'REVIEWS', icon: 'star', bg: '#fff3e0' },
  ],
  contacts: [
    { icon: 'smartphone', label: 'Mobile', value: '+63 912 111 2233' },
    { icon: 'email', label: 'Email', value: 'm.santos@isu.edu.ph' },
    { icon: 'badge', label: 'Student ID', value: 'ISU-2021-00342' },
  ],
  emergency: {
    name: 'Carla Santos',
    relation: 'Mother',
    phone: '+63 912 444 5566',
  },
  lease: {
    moveIn: 'Jan 1, 2026',
  },
  timeline: [
    {
      id: 1,
      status: 'current',
      title: 'CURRENT STAY',
      property: 'Pinzon Student Hub',
      period: 'Solo · Room 2-B · Jan 1, 2026 - present',
      note: '',
      rating: null,
      dotColor: '#00897b',
    },
    {
      id: 2,
      status: 'past',
      title: 'BEDSPACER',
      property: 'ISU Gate Apartment',
      period: 'Jun 2024 - Dec 2024',
      note: 'Moved to closer property',
      rating: 4,
      dotColor: '#9e9e9e',
    },
    {
      id: 3,
      status: 'past',
      title: 'SHARED',
      property: 'Green Meadows BH',
      period: 'Jan 2024 - May 2024',
      note: 'Transferred due to noise complaints',
      rating: 3,
      dotColor: '#9e9e9e',
    },
  ],
  reviews: [],
})

function filledStars(rating: number): boolean[] {
  return Array.from({ length: 5 }, (_, i) => i < rating)
}

function submitReview() {
  if (!newReviewNote.value.trim() && newReviewRating.value === 0) return
  tenant.reviews.push({
    id: Date.now(),
    author: 'You',
    rating: newReviewRating.value,
    note: newReviewNote.value.trim() || '(no note)',
    date: new Date().toLocaleDateString(),
  })
  newReviewNote.value = ''
  newReviewRating.value = 0
}

function goBack() {
  void router.back()
}

function openChat() {
  void router.push('/landlord/chat')
}

function closeProfile() {
  void router.push('/landlord/tenants')
}
</script>

<style scoped>
.tenant-profile-page {
  min-height: 100vh;
  background-color: #ffffff;
}

.sticky-header {
  position: sticky;
  top: 0;
  z-index: 10;
  background-color: #ffffff;
  padding: 10px 12px;
  border-bottom: 1px solid #eeeeee;
}

.header-name {
  font-size: 16px;
  font-weight: 700;
  color: #111827;
}

.header-sub {
  font-size: 12px;
  color: #6b7280;
}

.profile-block {
  margin-top: 16px;
}

.avatar-initials {
  font-size: 30px;
  font-weight: 700;
}

.profile-name {
  font-size: 20px;
  font-weight: 800;
  color: #111827;
}

.profile-id {
  font-size: 13px;
  color: #6b7280;
  margin-top: 2px;
}

.stay-card {
  border-radius: 16px;
  padding: 14px 16px;
}

.stay-title {
  font-size: 15px;
  font-weight: 700;
  color: #111827;
}

.stay-sub {
  font-size: 13px;
  color: #00695c;
  margin-top: 2px;
}

.current-badge {
  border-radius: 20px;
  font-size: 11px;
  font-weight: 700;
  padding: 4px 12px;
}

.stat-card {
  border-radius: 14px;
  padding: 12px 8px;
  text-align: center;
}

.stat-value {
  font-size: 16px;
  font-weight: 800;
  color: #111827;
  margin-top: 6px;
}

.stat-label {
  font-size: 10px;
  font-weight: 700;
  color: #6b7280;
  letter-spacing: 0.5px;
  margin-top: 2px;
}

.pill-tabs {
  display: flex;
  gap: 8px;
  overflow-x: auto;
}

.pill-tab {
  flex: 1 0 auto;
  border: none;
  border-radius: 20px;
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 700;
  background-color: #f1f3f5;
  color: #374151;
  cursor: pointer;
}

.pill-tab.active {
  background-color: #000000;
  color: #ffffff;
}

.section-header {
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 1px;
  color: #6b7280;
  margin-bottom: 10px;
}

.info-card {
  border-radius: 14px;
  background-color: #f5f6f8;
  padding: 12px 14px;
  margin-bottom: 10px;
}

.info-label {
  font-size: 12px;
  color: #6b7280;
}

.info-value {
  font-size: 14px;
  font-weight: 700;
  color: #111827;
}

.info-sub {
  font-size: 13px;
  color: #6b7280;
  margin-top: 2px;
}

.emergency-card {
  border-radius: 14px;
  padding: 12px 14px;
}

.lease-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 4px;
  border-bottom: 1px solid #eeeeee;
}

.lease-label {
  font-size: 14px;
  color: #374151;
}

.lease-value {
  font-size: 14px;
  font-weight: 700;
  color: #111827;
}

.timeline {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.timeline-item {
  display: flex;
  gap: 12px;
}

.timeline-dot {
  flex: 0 0 28px;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 4px;
}

.timeline-card {
  flex: 1;
  border-radius: 14px;
  padding: 12px 14px;
}

.timeline-title {
  font-size: 14px;
  font-weight: 800;
  color: #111827;
}

.active-badge {
  background-color: #00897b;
  color: #ffffff;
  font-size: 10px;
  font-weight: 700;
  border-radius: 20px;
  padding: 3px 10px;
}

.timeline-sub {
  font-size: 13px;
  color: #6b7280;
  margin-top: 2px;
}

.timeline-note {
  font-size: 13px;
  color: #374151;
  margin-top: 4px;
}

.stars {
  display: flex;
  gap: 2px;
}

.review-card {
  border-radius: 16px;
  background-color: #ffffff;
  border: 1px solid #eeeeee;
  padding: 16px;
}

.review-input {
  background-color: #f5f6f8;
  border-radius: 10px;
  margin-top: 6px;
}

.submit-review {
  width: 100%;
  border-radius: 10px;
  font-weight: 700;
  margin-top: 12px;
  text-transform: none;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 20px;
}

.empty-text {
  font-size: 14px;
  color: #9e9e9e;
  margin-top: 8px;
}

.review-item {
  border-radius: 12px;
  background-color: #f5f6f8;
  padding: 12px;
  margin-bottom: 10px;
}

.review-author {
  font-size: 14px;
  font-weight: 700;
  color: #111827;
}

.review-date {
  font-size: 12px;
  color: #9e9e9e;
}

.review-note {
  font-size: 13px;
  color: #374151;
  margin-top: 4px;
}

.placeholder-card {
  border-radius: 14px;
  background-color: #f5f6f8;
  padding: 20px;
  text-align: center;
}

.placeholder-text {
  font-size: 14px;
  color: #9e9e9e;
}
</style>
