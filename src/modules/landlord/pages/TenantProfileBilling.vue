<template>
  <q-page class="tenant-profile-billing-page">
    <q-layout view="hHh lpR fFf">
      <q-header elevated class="bg-primary text-white">
        <q-toolbar>
          <q-btn dense flat round @click="toggleLeftDrawer">
            <IconifyIcon width="24" icon="material-icons:menu" />
          </q-btn>

          <q-toolbar-title>Tenant Profile</q-toolbar-title>

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
        <div class="tenant-billing-page">
          <!-- Header with tenant info and billing tab -->
          <div class="tenant-header q-pa-md q-bg-white q-shadow-small">
            <q-row>
              <q-col cols="6">
                <div class="text-h6 text-weight-bold">Current Tenant</div>
                <div class="q-mt-1">
                  <q-avatar
                    size="40"
                    color="teal-9"
                    text-color="white"
                    font-size="24px"
                  >
                    {{ tenantNameInitials }}
                  </q-avatar>
                  <div class="q-mt-2 text-subtitle2">{{ tenantName }}</div>
                </div>
              </q-col>

              <q-col cols="6" class="text-right">
                <div class="text-h6 text-weight-bold">₱{{ tenantMonthlyRate.toLocaleString() }}</div>
                <div class="text-caption text-grey-7">Monthly Rate</div>
              </q-col>
            </q-row>
          </div>

          <!-- Billing Tab -->
          <div class="billing-tab q-pa-md" style="max-height: 80vh; overflow-y: auto;">
            <!-- Payment Streak Tracker -->
            <div class="payment-streak q-mb-6">
              <div class="text-subtitle2 text-grey-7">Payment Streak</div>

              <q-row class="q-gutter-md q-mt-3">
                <q-col cols="3" v-for="(day, index) in streakDays" :key="index">
                  <q-card
                    flat
                    :color="day.status === 'current' ? 'green' : day.status === 'missed' ? 'red' : 'amber'"
                    class="streak-card text-center"
                  >
                    <q-card-section>
                      <div class="text-h6 text-weight-bold {{ day.status === 'current' ? 'active' : '' }}">{{ day.number }}</div>
                      <div class="text-caption {{ day.status === 'current' ? 'text-teal-7' : day.status === 'missed' ? 'text-red-7' : 'text-amber-7' }}">{{ day.label }}</div>
                    </q-card-section>
                  </q-card>
                </q-col>
              </q-row>

              <div class="q-mt-3 text-right">
                <q-btn
                  flat
                  small
                  color="teal-9"
                  label="Reset Streak"
                />
              </div>
            </div>

            <!-- Log Cash Payment Button -->
            <div class="log-payment-btn q-mb-6">
              <q-btn
                unelevated
                color="teal-9"
                class="q-md-width-auto q-mb-md q-mr-md"
                label="Log Cash Payment"
                @click="openLogPaymentDialog"
              />
            </div>

            <!-- Payment History -->
            <div class="payment-history q-mt-4">
              <div class="text-subtitle2 text-grey-7 q-mb-3">Payment History</div>

              <q-list bordered separator class="rounded-borders bg-white">
                <q-item v-for="payment in paymentHistory" :key="payment.month">
                  <q-item-section>
                    <q-item-label>
                      {{ payment.month }} ·
                      {{ formatPeso(payment.amount) }}
                    </q-item-label>
                    <q-item-label caption>
                      Due: {{ payment.dueDate }}
                    </q-item-label>
                  </q-item-section>
                  <q-item-section side>
                    <q-badge
                      :color="paymentStatusColor(payment.status)"
                      :label="payment.status"
                    />
                  </q-item-section>
                </q-item>

                <template v-if="paymentHistory.length === 0">
                  <q-item class="text-center text-grey-7 q-py-8">
                    No payments recorded yet.
                  </q-item>
                </template>
              </q-list>
            </div>
          </div>

          <!-- Log Payment Dialog -->
          <q-dialog v-model="logPaymentDialogOpen">
            <q-card class="q-pa-md">
              <q-card-section>
                <q-icon name="material-icons:monetization_on" color="teal-9" class="q-mr-sm" />
                <span class="text-h6">Log Cash Payment</span>
              </q-card-section>

              <q-card-section>
                <q-input
                  v-model="paymentAmount"
                  type="number"
                  :counter="1000000"
                  labeled
                  label="Amount (₱)"
                  @keyup.enter="closeLogPaymentDialogAndLog"
                  class="q-w-64"
                  step="100"
                />
                <q-input
                  v-model="paymentMonth"
                  labeled
                  label="Month (e.g. January 2024)"
                  class="q-ml-md q-mt-sm q-w-64"
                />
              </q-card-section>

              <q-card-actions>
                <q-btn
                  flat
                  color="grey-8"
                  @click="closeLogPaymentDialog"
                >
                  Cancel
                </q-btn>
                <q-btn
                  unelevated
                  color="teal-9"
                  @click="closeLogPaymentDialogAndLog"
                >
                  Log Payment
                </q-btn>
              </q-card-actions>
            </q-card>
          </q-dialog>
        </div>
      </q-page-container>
    </q-layout>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from '@/stores/auth'
import { useTenantBillingStore } from '@/stores/tenant-billing'

import { supabase } from '@/shared/utils/supabase'

const router = useRouter()
const route = useRoute()
const $q = useQuasar()
const authStore = useAuthStore()
const tenantBillingStore = useTenantBillingStore()

const userRole = ref<'landlord' | 'student' | ''>('landlord')
const leftDrawerOpen = ref(false)

// --- Mock Tenant Data ---
const tenantName = computed(() => 'Maria Santos')
const tenantNameInitials = computed(() => {
  const parts = tenantName.value.split(' ').filter(Boolean)
  return (parts[0]?.[0] ?? 'U') + (parts[parts.length - 1]?.[0] ?? '').toUpperCase()
})

const tenantMonthlyRate = computed(() => 5500)
const tenantProperty = computed(() => 'Rose Dormitory, Unit 3A')

// Payment streak data - 30 days
const streakDays = ref<
  Array<{
    number: number
    status: 'current' | 'missed' | 'upcoming'
    label: string
  }>
>(
  (() => {
    const days: Array<{ number: number; status: 'current' | 'missed' | 'upcoming'; label: string }> = []
    for (let i = 29; i >= 0; i--) {
      const d = new Date()
      d.setDate(d.getDate() - i)
      const dayNum = d.getDate()
      const status: 'current' | 'missed' | 'upcoming' = i < 20 ? 'current' : 'missed'
      days.push({
        number: dayNum,
        status,
        label: status === 'current' ? 'Paid' : 'Missed',
      })
    }
    return days
  })()
)

// Payment history - mock data
const paymentHistory = ref<
  Array<{
    month: string
    dueDate: string
    amount: number
    status: 'Pending' | 'Paid'
    paymentMethod: string
  }
>(
  (() => {
    const history: Array<{
      month: string
      dueDate: string
      amount: number
      status: 'Pending' | 'Paid'
      paymentMethod: string
    }> = []
    const months = [
      'January 2024',
      'February 2024',
      'March 2024',
      'April 2024',
      'May 2024',
    ]
    const baseAmount = 5500

    months.forEach((month, index) => {
      const isLast = index === months.length - 1
      history.push({
        month,
        dueDate: new Date().toISOString().split('T')[0],
        amount: baseAmount,
        status: isLast ? 'Pending' : 'Paid',
        paymentMethod: 'Cash',
      })
    })

    return history
  })()
)

// --- Dialog State ---
const logPaymentDialogOpen = ref(false)
const paymentAmount = ref('')
const paymentMonth = ref('')

// --- Methods ---

function formatPeso(amount: number): string {
  return '₱' + amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function paymentStatusColor(status: 'Pending' | 'Paid'): string {
  if (status === 'Paid') return 'green'
  return 'amber'
}

function openLogPaymentDialog() {
  logPaymentDialogOpen.value = true
  paymentAmount.value = ''
  paymentMonth.value = new Date().toLocaleString('en-PH', { month: 'long', year: 'numeric' })
}

function closeLogPaymentDialog() {
  logPaymentDialogOpen.value = false
}

function closeLogPaymentDialogAndLog() {
  const amount = Number(paymentAmount.value) || 0
  const month = paymentMonth.value || new Date().toLocaleString('en-PH', { month: 'long', year: 'numeric' })

  if (amount <= 0) {
    $q.notify({
      message: 'Please enter a valid amount.',
      position: 'top',
      color: 'grey-9',
      textColor: 'white',
      icon: 'error_outline',
      iconColor: 'red-4',
      classes: 'custom-notify',
    })
    return
  }

  tenantBillingStore.logCashPayment(amount, month)
  closeLogPaymentDialog()
  logPaymentDialogOpen.value = false
}
</script>

<style scoped>
.tenant-profile-billing-page {
  background: #F7F9FA;
}

.tenant-header {
  background: white;
  border-radius: 24px 24px 0 0;
  margin-bottom: 0;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}

.payment-streak {
  padding: 0 24px 12px;
}

.streak-card {
  height: 40px;
  min-width: 32px;
}

.streak-card .q-card-section {
  padding: 4px 8px;
}

.payment-history {
  padding: 0 24px 24px;
}

.log-payment-btn {
  padding: 0 24px 12px;
}

.q-dialog .q-card {
  border-radius: 16px;
}

.q-dialog .q-card-section {
  padding: 24px;
}

.q-dialog .q-card-actions {
  padding: 0 24px 24px;
}

.q-dialog q-input {
  margin-bottom: 8px;
}

.streak-card .text-h6 {
  margin: 0;
  font-size: 14px;
}

.text-teal-7 {
  color: rgba(0, 137, 123, 0.7) !important;
}

.text-red-7 {
  color: #ff5252 !important;
}

.text-amber-7 {
  color: #fdd835 !important;
}
</style>
