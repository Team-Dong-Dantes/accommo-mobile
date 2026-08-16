<template>
  <q-page class="dashboard-page bg-grey-1">
    <div class="page-header">
      <q-tabs
        v-model="activeTab"
        type="tabs"
        background-color="transparent"
        text-color="teal-9"
        ink-bar-color="teal-9"
        class="tab-style"
      >
        <q-tab label="Home" icon="home" />
        <q-tab label="Payments" icon="payments" />
        <q-tab label="Tenants" icon="people" />
        <q-tab label="Notifications" icon="notifications" />
      </q-tabs>
    </div>

    <div class="dashboard-content">
      <!-- HOME TAB -->
      <div v-if="activeTab === 'home'" class="home-tab">
        <div class="row q-col-gutter-md q-mb-md">
          <!-- Metric Cards -->
          <div class="col-12 col-sm-6 col-md-4">
            <q-card flat bordered class="custom-card">
              <q-card-section>
                <div class="text-overline text-teal-9">Active Tenants</div>
                <div class="text-h3 q-mt-sm text-weight-bold">{{ activeTenants }}</div>
                <div class="text-subtitle2 text-grey-7">
                  {{ activeTenantsLabel }}
                </div>
              </q-card-section>
            </q-card>
          </div>

          <div class="col-12 col-sm-6 col-md-4">
            <q-card flat bordered class="custom-card">
              <q-card-section>
                <div class="text-overline text-teal-9">Pending Payments</div>
                <div class="text-h3 q-mt-sm text-weight-bold">{{ pendingPayments }}</div>
                <div class="text-subtitle2 text-grey-7">
                  {{ pendingAmountLabel }}
                </div>
              </q-card-section>
              <q-card-actions align="right" class="q-pa-md">
                <q-btn flat color="teal-9" class="text-weight-bold" label="View Details" @click="viewPayments" />
              </q-card-actions>
            </q-card>
          </div>

          <div class="col-12 col-md-4">
            <q-card flat bordered class="custom-card">
              <q-card-section>
                <div class="text-overline text-teal-9">Properties</div>
                <div class="text-h3 q-mt-sm text-weight-bold">{{ totalProperties }}</div>
                <div class="text-subtitle2 text-grey-7">{{ propertiesSubtitle }}</div>
              </q-card-section>
              <q-card-actions align="right" class="q-pa-md">
                <q-btn unelevated color="teal-9" class="action-btn" label="Add Property" @click="goToAddProperty" />
              </q-card-actions>
            </q-card>
          </div>

          <div class="col-12 col-sm-6 col-md-4">
            <q-card flat bordered class="custom-card">
              <q-card-section>
                <div class="text-overline text-teal-9">Occupancy Rate</div>
                <div class="text-h3 q-mt-sm text-weight-bold">{{ occupancyRateValue }}%</div>
                <div class="text-subtitle2 text-grey-7">Overall occupancy</div>
              </q-card-section>
            </q-card>
          </div>

          <div class="col-12 col-sm-6 col-md-4">
            <q-card flat bordered class="custom-card">
              <q-card-section>
                <div class="text-overline text-teal-9">Revenue This Month</div>
                <div class="text-h3 q-mt-sm text-weight-bold">{{ formatPeso(monthlyRevenue) }}</div>
                <div class="text-subtitle2 text-grey-7">Current month collection</div>
              </q-card-section>
            </q-card>
          </div>

          <div class="col-12 col-sm-6 col-md-4">
            <q-card flat bordered class="custom-card">
              <q-card-section>
                <div class="text-overline text-teal-9">OSAS Compliance</div>
                <div class="text-h3 q-mt-sm text-weight-bold">{{ compliantCount }}/{{ properties.length }} valid</div>
                <div class="text-subtitle2 text-grey-7">Valid permits</div>
              </q-card-section>
            </q-card>
          </div>
        </div>

        <!-- Twelve Month Revenue Chart -->
        <div class="q-pa-md" style="max-height: 400px;">
          <q-chart
            type="Line"
 :options="chartOptions"
 :data="revenueChartData"
 class="q-max-width-full"
          />
        </div>
      </div>

      <!-- PAYMENTS TAB -->
      <div v-if="activeTab === 'payments'" class="payments-tab">
        <div class="q-pa-md">
          <q-list
            v-if="recentPayments.length > 0"
            bordered
            separator
            class="rounded-borders bg-white"
          >
            <q-item v-for="payment in recentPayments" :key="payment.id">
              <q-item-section>
                <q-item-label class="text-weight-bold">
                  {{ payment.student_name }} ·
                  {{ formatPeso(payment.amount) }}
                </q-item-label>
                <q-item-label caption>
                  {{ payment.month }} ·
                  {{ payment.property_name }} ·
                  {{ payment.room_number }}
                </q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-badge :color="payment.statusColor" :label="payment.statusDisplay" />
              </q-item-section>
            </q-item>
          </q-list>

          <q-card v-if="recentPayments.length === 0" flat bordered class="custom-card q-mt-sm">
            <q-card-section class="text-center">
              <div class="text-subtitle2 text-grey-7 q-py-md">
                No payments recorded yet. Add tenants and collect payments to see history here.
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <!-- TENANTS TAB -->
      <div v-if="activeTab === 'tenants'" class="tenants-tab">
        <div class="q-pa-md">
          <div class="section-title">Students by Property</div>

          <q-tabs
            v-model="tenantsTab"
            type="segment"
            background-color="transparent"
            text-color="teal-9"
            ink-bar-color="teal-9"
          >
            <q-tab v-for="prop in managedProperties" :key="prop.id" label="prop.name" />
            <q-tab label="All" />
          </q-tabs>

          <q-scroll-area
            class="tenants-area"
            :content-style="{ maxHeight: '500px' }"
          >
            <q-item v-for="tenant in tenantsByGroup" :key="tenant.id">
              <q-item-section>
                <q-item-label class="text-weight-bold">{{ tenant.propertyName }}</q-item-label>
                <q-item-label caption>{{ tenant.roomType }} rooms</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-badge color="teal" label="Active" />
              </q-item-section>
            </q-item>
          </q-scroll-area>

          <q-card v-if="tenantsByGroup.length === 0" flat bordered class="custom-card q-mt-sm">
            <q-card-section class="text-center">
              <div class="text-subtitle2 text-grey-7 q-py-md">
                No active tenants yet — add a property and assign a room to get started.
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <!-- NOTIFICATIONS TAB -->
      <div v-if="activeTab === 'notifications'" class="notifications-tab">
        <div class="q-pa-md">
          <div class="row q-col-gutter-md q-mb-md">
            <div class="col-12">
              <div class="text-subtitle2 text-grey-7 q-mb-2">
                Unread: {{ unreadCount }} {{ unreadCount === 1 ? 'alert' : 'alerts' }}
              </div>

              <q-list
                v-if="notifications.length > 0"
                bordered
                separator
                class="rounded-borders bg-white"
              >
                <q-item v-for="notification in notifications" :key="notification.id">
                  <q-item-section>
                    <q-item-label>
                      {{ notification.title }}
                    </q-item-label>
                    <q-item-label caption>
                      {{ notification.body }}
                      <q-badge
                        v-if="!notification.read_at"
                        color="red"
                        small
                        class="q-ml-sm"
                      />
                    </q-item-label>
                  </q-item-section>
                  <q-item-section side>
                    <q-badge
                      v-if="!notification.read_at"
                      color="amber"
                      small
                      label="Unread"
                    />
                  </q-item-section>
                </q-item>
              </q-list>

              <q-card v-if="notifications.length === 0" flat bordered class="custom-card q-mt-sm">
                <q-card-section class="text-center">
                  <div class="text-subtitle2 text-grey-7 q-py-md">
                    No notifications yet.
                  </div>
                </q-card-section>
              </q-card>
            </div>
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useLandlordStore } from '@/stores/landlord'

const router = useRouter()
const landlordStore = useLandlordStore()

const activeTab = ref<'home' | 'payments' | 'tenants' | 'notifications'>('home')
const tenantsTab = ref('All')

const totalProperties = computed(() => landlordStore.totalProperties)
const occupancyRateValue = computed(() => landlordStore.occupancyRate)
const activeTenants = computed(() => landlordStore.activeTenants)
const activeTenantsLabel = computed(() => `${landlordStore.activeTenants} tenants active`)
const pendingPayments = computed(() => landlordStore.pendingPayments)
const pendingAmountLabel = computed(() => landlordStore.pendingAmount)
const properties = computed(() => landlordStore.properties)
const propertiesSubtitle = computed(() => `${landlordStore.properties.length} properties managed`)
const recentPayments = computed(() => landlordStore.recentPayments)
const notifications = computed(() => landlordStore.notifications)
const unreadCount = computed(() => landlordStore.unreadCount)
const monthlyRevenue = computed(() => landlordStore.revenueChartData?.datasets?.[0]?.data?.reduce((total: number, value: number) => total + (value || 0), 0) ?? 0)
const compliantCount = computed(() => 0)
const managedProperties = computed(() => landlordStore.tenantsByGroup ?? [])
const tenantsByGroup = computed(() => landlordStore.tenantsByGroup ?? [])
const revenueChartData = computed(() => landlordStore.revenueChartData)

const chartOptions = {
  showPoints: false,
  lineWidth: 2,
  area: true,
  colors: ['#00897B'],
  xAxis: { color: '#8b8b8b' },
  yAxis: {
    color: '#8b8b8b',
    label: {
      formatter: (value: number) => '₱' + value.toLocaleString(),
    },
  },
  tooltip: {
    formatter: (value: number) => '₱' + value.toLocaleString(),
  },
}

function formatPeso(amount: number): string {
  return '₱' + amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function viewPayments() {
  activeTab.value = 'payments'
}

function goToAddProperty() {
  router.push('/landlord/properties/new')
}
</script>

<style scoped>
.dashboard-page {
  background: #F7F9FA;
}

.page-header {
  padding: 24px;
  background: white;
  border-radius: 24px 24px 0 0;
  margin-bottom: 24px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}

.tab-style .q-tab {
  padding: 12px 24px;
  font-weight: 500;
  font-size: 14px;
}

.tab-style .ink-bar {
  background: #00897B !important;
}

.home-tab {
  padding: 0 24px 24px;
}

.section-title {
  font-size: 18px;
  font-weight: 600;
  color: #00897B;
  margin-bottom: 16px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.tenants-area {
  padding: 0 24px 24px;
}

.notifications-tab {
  padding: 0 24px 24px;
}
</style>