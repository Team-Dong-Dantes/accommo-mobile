<template>
  <q-page class="profile-page">
    <div class="profile-shell">
      <!-- HERO -->
      <div class="hero">
        <div class="hero-top">
          <q-btn flat round dense icon="edit" class="hero-edit" @click="openEdit" />
        </div>

        <div class="avatar-wrap">
          <q-avatar size="104px" class="hero-avatar" color="teal-9" text-color="white">
            {{ profile.initials }}
          </q-avatar>
          <q-btn round dense icon="photo_camera" class="camera-btn" color="white" text-color="teal-9" @click="openCamera" />
        </div>

        <div class="hero-info">
          <q-badge class="verify-badge" color="green-2" text-color="green-9">
            <q-icon name="check" size="14px" class="q-mr-xs" />
            OSAS Verified
          </q-badge>
          <div class="hero-name">{{ profile.fullName }}</div>
          <div class="hero-sub">{{ profile.landlordCode }} · Member since {{ profile.memberSince }}</div>
        </div>
      </div>

      <!-- INFO GRID 2x2 -->
      <div class="info-grid q-px-md">
        <div class="info-card">
          <div class="info-label">Email</div>
          <div class="info-value">{{ profile.email }}</div>
        </div>
        <div class="info-card">
          <div class="info-label">Contact</div>
          <div class="info-value">{{ profile.contact }}</div>
        </div>
        <div class="info-card">
          <div class="info-label">Area</div>
          <div class="info-value">{{ profile.area }}</div>
        </div>
        <div class="info-card">
          <div class="info-label">Joined</div>
          <div class="info-value">{{ profile.joined }}</div>
        </div>
      </div>

      <!-- STATS 4 COLUMN -->
      <div class="stats-grid q-px-md">
        <div v-for="stat in stats" :key="stat.label" class="stat-card">
          <div class="stat-value">{{ stat.value }}</div>
          <div class="stat-label">{{ stat.label }}</div>
          <div class="stat-note" :class="stat.noteClass">{{ stat.note }}</div>
        </div>
      </div>

      <!-- STUDENT QR SCANNER CARD -->
      <div class="section q-px-md">
        <q-card flat bordered class="qr-card">
          <q-card-section>
            <div class="row items-center no-wrap">
              <q-icon name="qr_code_scanner" size="24px" color="purple-6" class="q-mr-sm" />
              <div>
                <div class="section-title">Student QR Scanner</div>
                <div class="section-sub">Scan a student QR to verify enrollment and view history</div>
              </div>
            </div>
          </q-card-section>
          <q-card-actions class="q-px-md q-pb-md">
            <q-btn unelevated rounded full-width color="purple-6" class="qr-btn" @click="openScanner">
              <q-icon name="qr_code_scanner" class="q-mr-sm" />
              Open Scanner
            </q-btn>
          </q-card-actions>
        </q-card>
      </div>

      <!-- MY PROPERTIES -->
      <div class="section q-px-md">
        <div class="row items-center justify-between q-mb-sm">
          <div class="section-heading">My Properties</div>
          <q-badge color="teal-1" text-color="teal-9" class="count-badge">{{ activeProperties }} active</q-badge>
        </div>
        <q-card flat bordered class="content-card">
          <q-list separator>
            <q-item v-for="property in properties" :key="property.id" clickable v-ripple class="property-item" @click="openProperty(property.id)">
              <q-item-section>
                <div class="property-name">{{ property.name }}</div>
                <div class="property-address">{{ property.address }}</div>
                <div class="property-meta">
                  <q-icon name="star" size="14px" color="amber-6" class="q-mr-xs" />
                  <span>{{ property.rating }}</span>
                </div>
                <div class="property-occ q-mt-xs">{{ property.occupied }}/{{ property.total }} occupied</div>
                <q-linear-progress :value="property.occupied / property.total" color="teal-9" track-color="grey-3" size="6px" rounded class="q-mt-xs" />
              </q-item-section>
              <q-item-section side>
                <q-icon name="chevron_right" color="grey-5" />
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <!-- OSAS COMPLIANCE -->
      <div class="section q-px-md">
        <div class="row items-center q-mb-sm">
          <q-icon name="shield" size="20px" color="teal-9" class="q-mr-sm" />
          <div class="section-heading">OSAS Compliance</div>
        </div>
        <q-card flat bordered class="content-card">
          <q-list separator>
            <q-item v-for="item in compliance" :key="item.name" class="compliance-item">
              <q-item-section>
                <div class="compliance-name">{{ item.name }}</div>
                <div class="compliance-date">{{ item.date }}</div>
              </q-item-section>
              <q-item-section side>
                <q-badge :class="item.tone === 'valid' ? 'pill-valid' : 'pill-expiring'" class="pill-badge">
                  {{ item.status }}
                </q-badge>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <!-- RECENT REVIEWS -->
      <div class="section q-px-md">
        <div class="row items-center justify-between q-mb-sm">
          <div class="row items-center no-wrap">
            <q-icon name="star" size="20px" color="amber-6" class="q-mr-sm" />
            <div class="section-heading">Recent Reviews</div>
          </div>
          <q-badge color="amber-2" text-color="amber-9" class="count-badge">{{ reviewsAverage }} avg</q-badge>
        </div>
        <q-card flat bordered class="content-card">
          <q-list separator>
            <q-item v-for="review in reviews" :key="review.id" class="review-item">
              <q-item-section avatar>
                <q-avatar size="36px" color="grey-3" text-color="grey-8" class="review-avatar">{{ review.initials }}</q-avatar>
              </q-item-section>
              <q-item-section>
                <div class="row items-center justify-between">
                  <span class="review-author">{{ review.author }}</span>
                  <span class="review-date">{{ review.date }}</span>
                </div>
                <div class="row items-center q-mt-xs review-stars">
                  <q-icon v-for="star in 5" :key="star" name="star" size="14px" :color="star <= review.rating ? 'amber-6' : 'grey-4'" />
                </div>
                <div class="review-comment">{{ review.comment }}</div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <!-- SETTINGS AND ACTIONS -->
      <div class="section q-px-md q-mb-xl">
        <q-list bordered class="settings-list">
          <q-item clickable v-ripple @click="goToSettings">
            <q-item-section avatar><q-icon name="settings" color="grey-7" /></q-item-section>
            <q-item-section>
              <q-item-label class="settings-title">Settings</q-item-label>
              <q-item-label caption class="settings-sub">Notifications, business, security</q-item-label>
            </q-item-section>
            <q-item-section side><q-icon name="chevron_right" color="grey-5" /></q-item-section>
          </q-item>
          <q-separator />
          <q-item clickable v-ripple @click="handleLogout">
            <q-item-section avatar><q-icon name="logout" color="red-6" /></q-item-section>
            <q-item-section>
              <q-item-label class="logout-title">Log Out</q-item-label>
            </q-item-section>
          </q-item>
        </q-list>
      </div>
    </div>

    <!-- EDIT DIALOG (mock) -->
    <q-dialog v-model="editDialog" position="bottom">
      <q-card class="edit-card">
        <q-card-section>
          <div class="edit-title">Edit Profile</div>
          <q-input v-model="editForm.fullName" label="Full name" class="q-mt-md" outlined />
          <q-input v-model="editForm.email" label="Email" class="q-mt-sm" outlined />
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md q-pt-none">
          <q-btn flat label="Cancel" color="grey-7" v-close-popup />
          <q-btn unelevated label="Save" color="teal-9" @click="saveEdit" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- FIXED BOTTOM NAV -->
    <div class="bottom-nav">
      <button v-for="item in navItems" :key="item.key" type="button" class="nav-item" :class="{ 'nav-active': activeTab === item.key }" @click="navTo(item.key, item.to)">
        <q-icon :name="item.icon" size="22px" />
        <span class="nav-label">{{ item.label }}</span>
      </button>
    </div>

    <!-- TEAL FAB -->
    <q-btn fab icon="add" color="teal-9" class="profile-fab" @click="openAddProperty" />
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { supabase } from '@/shared/utils/supabase'

// Mock UI data for the landlord profile. Swap these refs for a store or API
// fetch once the backend data is ready to use.
interface ProfileState {
  initials: string
  fullName: string
  landlordCode: string
  memberSince: string
  email: string
  contact: string
  area: string
  joined: string
}

interface StatItem {
  label: string
  value: string
  note: string
  noteClass: string
}

interface PropertyItem {
  id: string
  name: string
  address: string
  rating: number
  occupied: number
  total: number
}

interface ComplianceItem {
  name: string
  date: string
  status: string
  tone: string
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
const $q = useQuasar()

const profile = ref<ProfileState>({
  initials: 'JD',
  fullName: 'Juan Dela Cruz',
  landlordCode: 'LL-2021-009',
  memberSince: 'Aug 2021',
  email: 'jdelacruz@email.com',
  contact: '+63 912 345 6789',
  area: 'Echague, Isabela',
  joined: 'August 2021',
})

const stats = ref<StatItem[]>([
  { label: 'Properties', value: '3', note: 'Active', noteClass: 'stat-active' },
  { label: 'Tenants', value: '15', note: '+2 new', noteClass: 'stat-new' },
  { label: 'Rating', value: '4.8', note: '22 reviews', noteClass: 'stat-reviews' },
  { label: 'Occupancy', value: '98%', note: '+1.2%', noteClass: 'stat-active' },
])

const properties = ref<PropertyItem[]>([
  { id: 'p1', name: 'Pinzon Student Hub', address: 'Purok 3, Alibagu', rating: 4.8, occupied: 7, total: 8 },
  { id: 'p2', name: 'JD Boarding House', address: 'Brgy. Osmeña', rating: 4.6, occupied: 4, total: 5 },
  { id: 'p3', name: 'Campus View Annex', address: 'Brgy. Ugac Norte', rating: 4.9, occupied: 4, total: 4 },
])

const compliance = ref<ComplianceItem[]>([
  { name: 'Business Permit', date: 'Dec 2026', status: 'Valid', tone: 'valid' },
  { name: 'OSAS Accreditation', date: 'Jun 2026', status: 'Valid', tone: 'valid' },
  { name: 'Fire Safety Cert.', date: 'May 2026', status: 'Expiring', tone: 'expiring' },
  { name: 'Sanitary Permit', date: 'Dec 2026', status: 'Valid', tone: 'valid' },
])

const reviews = ref<ReviewItem[]>([
  { id: 'r1', initials: 'MS', author: 'Maria S.', rating: 5, date: 'Apr 2026', comment: 'Very clean and affordable. Landlord is very responsive!' },
  { id: 'r2', initials: 'CR', author: 'Carlo R.', rating: 4, date: 'Mar 2026', comment: 'Good location near ISU. Minor issues fixed quickly.' },
])

const reviewsAverage = '4.8'
const activeProperties = computed(() => properties.value.length)

const navItems = [
  { key: 'home', label: 'Home', icon: 'home', to: '/landlord/dashboard' },
  { key: 'tenants', label: 'Tenants', icon: 'groups', to: '/landlord/tenants' },
  { key: 'msgs', label: 'Msgs', icon: 'chat', to: '/landlord/chat' },
  { key: 'notif', label: 'Notif', icon: 'notifications', to: '/landlord/notifications' },
]
const activeTab = ref('')

const editDialog = ref(false)
const editForm = ref({ fullName: '', email: '' })

function openEdit() {
  editForm.value = { fullName: profile.value.fullName, email: profile.value.email }
  editDialog.value = true
}

function saveEdit() {
  profile.value.fullName = editForm.value.fullName
  profile.value.email = editForm.value.email
  editDialog.value = false
  $q.notify({ message: 'Profile updated (mock)', color: 'teal-9', position: 'top' })
}

function openCamera() {
  $q.notify({ message: 'Camera opened (mock)', color: 'teal-9', position: 'top' })
}

function openScanner() {
  void router.push('/landlord/profile/qr-scanner')
}

function openProperty(id: string) {
  void router.push(`/landlord/properties/${id}`)
}

function goToSettings() {
  void router.push('/landlord/settings')
}

function openAddProperty() {
  void router.push('/landlord/properties/new')
}

function navTo(key: string, to: string) {
  activeTab.value = key
  void router.push(to)
}

async function handleLogout() {
  await supabase.auth.signOut()
  void router.push('/login')
}
</script>

<style scoped>
.profile-page {
  background: #F7F9FA;
  min-height: 100vh;
}

.profile-shell {
  padding-bottom: 96px;
}

.hero {
  position: relative;
  background: linear-gradient(180deg, #00897B 0%, #00695C 100%);
  padding: 16px 16px 96px;
  border-bottom-left-radius: 28px;
  border-bottom-right-radius: 28px;
}

.hero-top {
  display: flex;
  justify-content: flex-end;
}

.hero-edit {
  color: #FFFFFF;
  opacity: 0.95;
}

.avatar-wrap {
  position: relative;
  display: flex;
  justify-content: center;
  margin-top: 8px;
}

.hero-avatar {
  border: 4px solid #FFFFFF;
  font-size: 34px;
  font-weight: 800;
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.18);
}

.camera-btn {
  position: absolute;
  right: calc(50% - 58px);
  bottom: -8px;
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.18);
}

.hero-info {
  text-align: center;
  margin-top: 16px;
}

.verify-badge {
  border-radius: 999px;
  padding: 6px 12px;
  font-size: 11px;
  font-weight: 700;
}

.hero-name {
  color: #FFFFFF;
  font-size: 22px;
  font-weight: 800;
  margin-top: 10px;
}

.hero-sub {
  color: rgba(255, 255, 255, 0.8);
  font-size: 13px;
  margin-top: 4px;
}

.info-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
  margin-top: -64px;
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
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.info-value {
  color: #1F2937;
  font-size: 14px;
  font-weight: 700;
  margin-top: 6px;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
  margin-top: 16px;
}

.stat-card {
  background: #FFFFFF;
  border: 1px solid rgba(0, 0, 0, 0.05);
  border-radius: 14px;
  padding: 12px 8px;
  text-align: center;
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.03);
}

.stat-value {
  font-size: 20px;
  font-weight: 800;
  color: #1F2937;
  line-height: 1;
}

.stat-label {
  font-size: 10px;
  color: #6B7280;
  margin-top: 6px;
  font-weight: 600;
}

.stat-note {
  font-size: 10px;
  font-weight: 700;
  margin-top: 4px;
}

.stat-active {
  color: #00897B;
}

.stat-new {
  color: #7C3AED;
}

.stat-reviews {
  color: #EA580C;
}

.section {
  margin-top: 20px;
}

.section-title {
  font-size: 16px;
  font-weight: 800;
  color: #1F2937;
}

.section-sub {
  font-size: 12px;
  color: #6B7280;
  margin-top: 2px;
}

.section-heading {
  font-size: 18px;
  font-weight: 800;
  color: #1F2937;
}

.count-badge {
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
  padding: 5px 10px;
}

.qr-card {
  border-radius: 18px;
  box-shadow: 0 6px 14px rgba(0, 0, 0, 0.03);
}

.qr-btn {
  height: 46px;
  font-weight: 700;
}

.content-card {
  background: #FFFFFF;
  border: 1px solid rgba(0, 0, 0, 0.05);
  border-radius: 18px;
  overflow: hidden;
}

.property-item {
  padding: 14px;
  min-height: 76px;
}

.property-name {
  font-size: 15px;
  font-weight: 700;
  color: #1F2937;
}

.property-address {
  font-size: 12px;
  color: #6B7280;
  margin-top: 2px;
}

.property-meta {
  font-size: 12px;
  font-weight: 600;
  color: #374151;
}

.property-occ {
  font-size: 12px;
  color: #374151;
  font-weight: 600;
}

.compliance-item {
  padding: 14px;
}

.compliance-name {
  font-size: 15px;
  font-weight: 700;
  color: #1F2937;
}

.compliance-date {
  font-size: 12px;
  color: #6B7280;
  margin-top: 4px;
}

.pill-badge {
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
  padding: 5px 12px;
}

.pill-valid {
  background: #DCFCE7;
  color: #15803D;
}

.pill-expiring {
  background: #FFEDD5;
  color: #C2410C;
}

.review-item {
  padding: 14px;
}

.review-avatar {
  font-size: 12px;
  font-weight: 700;
}

.review-author {
  font-size: 14px;
  font-weight: 700;
  color: #1F2937;
}

.review-date {
  font-size: 11px;
  color: #6B7280;
}

.review-stars {
  gap: 2px;
}

.review-comment {
  font-size: 13px;
  color: #4B5563;
  line-height: 1.5;
  margin-top: 4px;
}

.settings-list {
  background: #FFFFFF;
  border: 1px solid rgba(0, 0, 0, 0.05);
  border-radius: 18px;
  overflow: hidden;
}

.settings-title {
  font-size: 15px;
  font-weight: 700;
  color: #1F2937;
}

.settings-sub {
  font-size: 12px;
  color: #6B7280;
}

.logout-title {
  font-size: 15px;
  font-weight: 700;
  color: #DC2626;
}

.edit-card {
  width: 100%;
  max-width: 460px;
  border-radius: 20px 20px 0 0;
}

.edit-title {
  font-size: 18px;
  font-weight: 800;
  color: #1F2937;
}

.bottom-nav {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  height: 64px;
  background: #FFFFFF;
  border-top: 1px solid rgba(15, 23, 42, 0.06);
  display: flex;
  z-index: 50;
}

.nav-item {
  flex: 1;
  border: none;
  background: transparent;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  color: #9CA3AF;
  cursor: pointer;
  padding: 0;
  font-family: inherit;
}

.nav-item.nav-active {
  color: #00897B;
}

.nav-label {
  font-size: 11px;
  font-weight: 600;
}

.profile-fab {
  position: fixed;
  right: 16px;
  bottom: 80px;
  z-index: 60;
}

@media (min-width: 768px) {
  .profile-shell {
    max-width: 760px;
    margin: 0 auto;
  }
}
</style>
