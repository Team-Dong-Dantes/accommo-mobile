<template>
  <q-page class="landlord-profile-page">
    <q-layout view="hHh lpR fFf">
      <q-header elevated class="bg-primary text-white">
        <q-toolbar>
          <q-btn dense flat round @click="toggleLeftDrawer">
            <IconifyIcon width="24" icon="material-icons:menu" />
          </q-btn>

          <q-toolbar-title>Accommo</q-toolbar-title>

          <q-btn flat round dense @click="handleLogout">
            <IconifyIcon width="24" icon="material-icons:logout" />
          </q-btn>
        </q-toolbar>
      </q-header>

      <q-drawer show-if-above v-model="leftDrawerOpen" side="left" bordered>
        <q-list>
          <q-item-label header>Menu</q-item-label>

          <template v-if="userRole === 'landlord'">
            <q-item clickable v-ripple to="/landlord/dashboard" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:dashboard" />
              </q-item-section>
              <q-item-section> Overview </q-item-section>
            </q-item>

            <q-item clickable v-ripple to="/landlord/properties" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:domain" />
              </q-item-section>
              <q-item-section> My Properties </q-item-section>
            </q-item>

            <q-item clickable v-ripple to="/landlord/tenants" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:people" />
              </q-item-section>
              <q-item-section> Tenants </q-item-section>
            </q-item>

            <q-item clickable v-ripple to="/landlord/payments" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:payments" />
              </q-item-section>
              <q-item-section> Payments </q-item-section>
            </q-item>

            <q-item clickable v-ripple to="/landlord/profile" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:person" />
              </q-item-section>
              <q-item-section> Profile </q-item-section>
            </q-item>

            <q-item clickable v-ripple to="/landlord/chat" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:chat" />
              </q-item-section>
              <q-item-section> Chat </q-item-section>
            </q-item>

            <q-item clickable v-ripple to="/landlord/notifications" exact>
              <q-item-section avatar>
                <IconifyIcon width="24" icon="material-icons:notifications" />
              </q-item-section>
              <q-item-section> Notifications </q-item-section>
            </q-item>
          </template>
        </q-list>
      </q-drawer>

      <q-page-container>
        <div class="profile-header">
          <div class="profile-avatar-section">
            <q-avatar
              size="120"
              color="teal-9"
              text-color="white"
              font-size="64px"
            >
              {{ landlordInitials }}
            </q-avatar>
            <div class="profile-badge-wrapper">
              <q-badge
                color="teal"
                :label="isOSASVerified ? 'OSAS Verified' : 'Pending'"
                class="q-ml-sm"
              />
            </div>
          </div>

          <div class="profile-details">
            <div class="text-h4 text-weight-bold">{{ landlordName }}</div>
            <div class="text-subtitle2 text-grey-7">{{ memberSince }}</div>

            <div class="core-metrics q-mt-2">
              <q-divider class="q-my-md" />
              <q-row class="q-gutter-sm">
                <q-col cols="6" rows="1">
                  <div class="metric-item">
                    <div class="metric-value">{{ propertiesActive }}</div>
                    <div class="metric-label">Properties Active</div>
                  </div>
                </q-col>
                <q-col cols="6" rows="1">
                  <div class="metric-item">
                    <div class="metric-value">{{ occupancyRate }}%</div>
                    <div class="metric-label">Occupancy Rate</div>
                  </div>
                </q-col>
                <q-col cols="6" rows="1">
                  <div class="metric-item">
                    <div class="metric-value">{{ rating.toFixed(1) }}</div>
                    <div class="metric-label">Rating</div>
                  </div>
                </q-col>
                <q-col cols="6" rows="1">
                  <div class="metric-item">
                    <div class="metric-value">{{ totalReviews }}</div>
                    <div class="metric-label">Total Reviews</div>
                  </div>
                </q-col>
              </q-row>
            </div>
          </div>
        </div>

        <div class="profile-actions q-pa-md">
          <q-btn
            unelevated
            color="teal-9"
            class="q-mb-md q-mr-sm"
            label="Student QR Scanner"
            @click="goToQRScanner"
          />
          <q-btn
            unelevated
            color="teal-3"
            class="q-mb-md"
            label="Settings"
          />
        </div>

        <q-divider class="q-my-md" />

        <!-- Managed Properties -->
        <div class="section-title">Managed Properties</div>

        <q-scroll-area
          class="properties-area"
          :content-style="{ maxHeight: '400px' }"
        >
          <q-tabs
            v-model="propertiesTab"
            type="segment"
            background-color="transparent"
            text-color="teal-9"
            ink-bar-color="teal-9"
          >
            <q-tab v-for="prop in managedProperties" :key="prop.id" label="prop.name" />
          </q-tabs>

          <template v-if="managedProperties.length === 0">
            <q-card flat bordered class="custom-card q-pa-md text-center text-grey-7">
              <div>No properties yet — add your first property from the dashboard.</div>
            </q-card>
          </template>

          <q-item v-for="prop in managedProperties" :key="prop.id" clickable>
            <q-item-section>
              <q-item-label>{{ prop.name }}</q-item-label>
              <q-item-label caption>{{ prop.address || 'No address set' }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-progress-linear
                :progress="prop.occupancyRate / 100"
                :color="prop.occupancyRate >= 90 ? 'green' : prop.occupancyRate >= 70 ? 'amber' : 'red'"
                size="12"
                class="q-mn-sm"
              />
              <div class="text-caption q-text-darken-4">{{ prop.occupancyRate }}% occupied</div>
            </q-item-section>
          </q-item>
        </q-scroll-area>

        <q-divider class="q-my-md" />

        <!-- OSAS Compliance Section -->
        <div class="section-title">OSAS Compliance</div>

        <q-card flat bordered class="custom-card">
          <q-card-section>
            <div class="text-h6 text-weight-bold">Compliance Permits</div>
          </q-card-section>

          <q-card-section class="q-px-md q-py-md">
            <q-tabs
              v-model="complianceTab"
              type="segment"
              background-color="transparent"
              text-color="teal-9"
              ink-bar-color="teal-9"
            >
              <q-tab label="Valid" />
              <q-tab label="Expiring" />
              <q-tab label="Missing" />
            </q-tabs>
          </q-card-section>

          <q-card-section class="q-px-md q-py-md">
            <q-list bordered separator class="rounded-borders bg-white">
              <q-item v-for="item in osasCompliance" :key="item.id">
                <q-item-section>
                  <q-item-label>{{ item.documentName }}</q-item-label>
                  <q-item-label caption>
                    {{ item.expiryDate }} ·
                    <q-badge
                      :color="statusColor(item.status)"
                      :label="item.status"
                    />
                  </q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-btn
                    flat
                    small
                    color="teal-3"
                    label="View Document"
                  />
                </q-item-section>
              </q-item>
            </q-list>

            <template v-if="osasCompliance.length === 0">
              <div class="text-subtitle2 text-grey-7 q-py-4 text-center">
                No compliance documents uploaded yet.
              </div>
            </template>
          </q-card-section>
        </q-card>

        <q-divider class="q-my-md" />

        <!-- Recent Reviews -->
        <div class="section-title">Recent Reviews</div>

        <q-card flat bordered class="custom-card">
          <q-card-section>
            <div class="text-h6 text-weight-bold">Reviews</div>
          </q-card-section>

          <q-card-section class="q-px-md q-py-md">
            <q-list bordered separator class="rounded-borders bg-white">
              <q-item v-for="review in recentReviews" :key="review.id">
                <q-item-section>
                  <q-item-label>{{ review.text }}</q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-badge :color="review.isLandlord ? 'teal' : 'grey'" :label="review.isLandlord ? 'Landlord' : 'Student'" />
                </q-item-section>
              </q-item>
            </q-list>

            <template v-if="recentReviews.length === 0">
              <div class="text-subtitle2 text-grey-7 q-py-4 text-center">
                No reviews yet.
              </div>
            </template>
          </q-card-section>
        </q-card>
      </div>
    </q-layout>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useLandlordStore } from '@/stores/landlord'
import { useQrStore } from '@/stores/qr'
import { useChatStore } from '@/stores/chat'
import { supabase } from '@/shared/utils/supabase'

const isDemoMode = (import.meta.env.VITE_DEMO_MODE as unknown) === 'true'

const router = useRouter()
const authStore = useAuthStore()
const landlordStore = useLandlordStore()
const qrStore = useQrStore()
const chatStore = useChatStore()

const userRole = ref<'landlord' | 'student' | ''>('landlord')
const leftDrawerOpen = ref(false)

function toggleLeftDrawer() {
  leftDrawerOpen.value = !leftDrawerOpen.value
}

function goToQRScanner() {
  void router.push('/landlord/profile/qr-scanner')
}

function handleLogout() {
  authStore.clearCachedRole()
  void supabase.auth.signOut()
  void router.push('/login')
}

const landlordName = ref('Landlord')

const memberSince = computed(() => {
  const date = new Date()
  return `Member since ${date.getFullYear()}`
})

const landlordInitials = computed(() => {
  const name = landlordName.value
  const parts = name.split(' ').filter(Boolean)
  return (
    (parts[0]?.[0] ?? 'U') + (parts[parts.length - 1]?.[0] ?? '')
  ).toUpperCase()
})

const isOSASVerified = computed(() => {
  // In real app, check from Supabase
  return false
})

const propertiesActive = ref(0)
const occupancyRate = ref(0)

onMounted(async () => {
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser()

  if (userError || !user) return

  const { data: props, error: propsError } = await supabase
    .from('properties')
    .select('id, total_rooms, vacant_rooms')
    .eq('landlord_id', user.id)

  if (propsError) return

  const propertyRows = props ?? []
  propertiesActive.value = propertyRows.length

  if (propertyRows.length === 0) {
    occupancyRate.value = 0
    return
  }

  const total = propertyRows.reduce((sum: number, p: any) => sum + (p.total_rooms || 0), 0)
  const occupied = propertyRows.reduce(
    (sum: number, p: any) => sum + ((p.total_rooms || 0) - (p.vacant_rooms || 0)),
    0,
  )
  occupancyRate.value = total > 0 ? Number(((occupied / total) * 100).toFixed(1)) : 0
})

const totalReviews = ref(5)
const rating = ref(4.7)

const recentReviews = ref([
  {
    id: 'rev-1',
    text: 'Great place for students!',
    isLandlord: false,
  },
  {
    id: 'rev-2',
    text: 'Well maintained property.',
    isLandlord: false,
  },
])

const managedProperties = ref([
  {
    id: 'prop-1',
    name: 'Rose Dormitory',
    address: '123 Quezon St., Brgy. Tibang',
    occupancyRate: 95,
  },
  {
    id: 'prop-2',
    name: 'University View Boarding',
    address: '456 Rizal Ave., Brgy. Maasin',
    occupancyRate: 82,
  },
  {
    id: 'prop-3',
    name: 'St. John Residence',
    address: '789 M. Hidalgo St., Brgy. Camarilla',
    occupancyRate: 67,
  },
])

const complianceTab = ref('Valid')
const propertiesTab = ref('All')

// OSAS compliance items
const osasCompliance = ref([
  {
    id: 'comp-1',
    documentName: 'OSAS Permit 2024',
    expiryDate: 'December 15, 2025',
    status: 'Valid' as const,
  },
  {
    id: 'comp-2',
    documentName: 'Fire Safety Inspection',
    expiryDate: 'March 30, 2025',
    status: 'Expiring' as const,
  },
  {
    id: 'comp-3',
    documentName: 'Business Permit',
    expiryDate: 'March 30, 2025',
    status: 'Missing' as const,
  },
])

// Status color for compliance
function statusColor(status: 'Valid' | 'Expiring' | 'Missing'): string {
  switch (status) {
    case 'Valid':
      return 'green'
    case 'Expiring':
      return 'amber'
    case 'Missing':
      return 'red'
    default:
      return 'grey'
  }
}
</script>

<style scoped>
.profile-header {
  background: #00897B;
  color: white;
  padding: 32px 24px;
  border-radius: 24px 24px 0 0;
}

.profile-avatar-section {
  text-align: center;
  margin-bottom: 24px;
}

.profile-details {
  text-align: center;
}

.core-metrics {
  display: flex;
  justify-content: center;
  margin-top: 24px;
}

.metric-item {
  text-align: center;
  min-width: 80px;
}

.metric-value {
  font-size: 24px;
  font-weight: 700;
  color: #00897B;
}

.metric-label {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.7);
  margin-top: 4px;
}

.profile-actions {
  padding: 0 24px 24px;
  display: flex;
  justify-content: center;
}

.section-title {
  font-size: 18px;
  font-weight: 600;
  color: #00897B;
  margin: 24px 24px 12px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.properties-area {
  padding: 0 24px 24px;
}

.compliance-section {
  padding: 0 24px 24px;
}
</style>

