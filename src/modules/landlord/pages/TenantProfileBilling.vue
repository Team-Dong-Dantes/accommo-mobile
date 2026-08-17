<template>
  <q-page class="tenant-profile-page bg-white">
    <div class="page-shell">
      <div class="top-header q-px-md q-py-sm row items-center no-wrap">
        <div class="col-auto">
          <q-btn flat round dense icon="arrow_back" class="back-btn" @click="goBack" />
        </div>

        <div class="col text-center">
          <div class="tenant-name">Maria Santos</div>
          <div class="tenant-course">BS Computer Engineering</div>
        </div>

        <div class="col-auto row items-center no-wrap q-gutter-sm">
          <q-btn flat round dense icon="chat_bubble_outline" class="chat-btn" />
          <q-btn flat round dense icon="close" class="close-btn" @click="goBack" />
        </div>
      </div>

      <div class="profile-header q-px-md q-py-md row items-center">
        <q-avatar size="64px" color="teal-8" text-color="white" class="profile-avatar">
          MS
        </q-avatar>

        <div class="profile-meta q-ml-md">
          <div class="profile-name row items-center no-wrap">
            <span>Maria Santos</span>
            <q-icon name="verified" size="18px" color="teal-7" class="q-ml-xs" />
          </div>
          <div class="student-id">Student ID ISU-2021-00342</div>
        </div>
      </div>

      <div class="assignment-card q-mx-md q-my-md">
        <div class="row items-center no-wrap">
          <div class="assignment-icon">
            <q-icon name="person_outline" size="22px" color="teal-8" />
          </div>

          <div class="assignment-copy q-ml-md">
            <div class="assignment-title">Solo - Room 2-B</div>
            <div class="assignment-subtitle">Pinzon Student Hub - Floor 2</div>
          </div>

          <div class="assignment-status q-ml-auto">Current</div>
        </div>
      </div>

      <div class="metrics-grid q-px-md row q-col-gutter-sm">
        <div class="col-4">
          <div class="metric-card teal">
            <q-icon name="credit_card" size="20px" color="teal-8" />
            <div class="metric-value">P3,500</div>
            <div class="metric-label">MONTHLY</div>
          </div>
        </div>

        <div class="col-4">
          <div class="metric-card purple">
            <q-icon name="check_circle" size="20px" color="purple-7" />
            <div class="metric-value">3 mo</div>
            <div class="metric-label">PAY STREAK</div>
          </div>
        </div>

        <div class="col-4">
          <div class="metric-card orange">
            <q-icon name="star" size="20px" color="orange-7" />
            <div class="metric-value">0</div>
            <div class="metric-label">REVIEWS</div>
          </div>
        </div>
      </div>

      <div class="tab-wrap q-mt-lg">
        <q-tabs
          v-model="activeTab"
          dense
          align="left"
          active-color="black"
          indicator-color="black"
          class="billing-tabs"
        >
          <q-tab name="billing" label="Billing" />
          <q-tab name="info" label="Info" />
          <q-tab name="history" label="History" />
          <q-tab name="reviews" label="Reviews (0)" />
        </q-tabs>
      </div>

      <div v-if="activeTab === 'billing'" class="billing-tab q-px-md q-pb-xl">
        <div class="status-banner q-mt-md row items-center no-wrap">
          <div class="banner-icon">
            <q-icon name="check" size="18px" color="green-7" />
          </div>

          <div class="banner-copy q-ml-md">
            <div class="banner-title">All payments current</div>
            <div class="banner-subtitle">P3,500/mo - Deposit: Paid</div>
          </div>
        </div>

        <q-btn
          unelevated
          color="black"
          class="full-width q-mt-md log-payment-btn"
          icon="add"
          label="Log Cash Payment"
        />

        <div class="section-label q-mt-lg">PAYMENT STREAK</div>

        <div class="streak-row q-mt-sm row items-center no-wrap">
          <div class="streak-label left">Jan</div>

          <div class="streak-track row items-center justify-between col">
            <div v-for="month in streakMonths" :key="month.name" class="streak-dot" :class="month.filled ? 'filled' : ''" />
          </div>

          <div class="streak-label center text-teal-8">3/12 on time</div>
          <div class="streak-label right">Dec</div>
        </div>

        <div class="section-label q-mt-lg">PAYMENT HISTORY</div>

        <div class="history-list q-mt-sm">
          <div v-for="payment in paymentHistory" :key="payment.month" class="history-item row items-center no-wrap">
            <div class="history-check">
              <q-icon name="check" size="14px" color="white" />
            </div>

            <div class="history-copy q-ml-sm col">
              <div class="history-month">{{ payment.month }}</div>
              <div class="history-meta">Paid {{ payment.date }} - {{ payment.method }}</div>
            </div>

            <div class="history-side text-right">
              <div class="history-amount">{{ payment.amount }}</div>
              <div class="history-status">{{ payment.status }}</div>
            </div>
          </div>
        </div>

        <div class="section-label q-mt-lg">BILLING SUMMARY</div>

        <div class="summary-list q-mt-sm">
          <div class="summary-row">
            <span>Monthly Rent</span>
            <strong>P3,500</strong>
          </div>

          <div class="summary-row">
            <span>Security Deposit</span>
            <strong>P3,500 Paid</strong>
          </div>

          <div class="summary-row">
            <span>Total Paid est.</span>
            <strong>P10,500</strong>
          </div>

          <div class="summary-row">
            <span>Active Repairs</span>
            <strong>1</strong>
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'

interface PaymentRecord {
  month: string
  date: string
  method: string
  amount: string
  status: string
}

interface StreakMonth {
  name: string
  filled: boolean
}

const router = useRouter()
const activeTab = ref<'billing' | 'info' | 'history' | 'reviews'>('billing')

const paymentHistory = computed<PaymentRecord[]>(() => [
  {
    month: 'April 2026',
    date: 'Apr 3, 2026',
    method: 'Cash',
    amount: 'P3,500',
    status: 'Paid',
  },
  {
    month: 'March 2026',
    date: 'Mar 3, 2026',
    method: 'Bank Transfer',
    amount: 'P3,500',
    status: 'Paid',
  },
  {
    month: 'February 2026',
    date: 'Feb 3, 2026',
    method: 'GCash',
    amount: 'P3,500',
    status: 'Paid',
  },
])

const streakMonths = computed<StreakMonth[]>(() => [
  { name: 'Jan', filled: true },
  { name: 'Feb', filled: true },
  { name: 'Mar', filled: true },
  { name: 'Apr', filled: false },
  { name: 'May', filled: false },
  { name: 'Jun', filled: false },
  { name: 'Jul', filled: false },
  { name: 'Aug', filled: false },
  { name: 'Sep', filled: false },
  { name: 'Oct', filled: false },
  { name: 'Nov', filled: false },
  { name: 'Dec', filled: false },
])

const goBack = () => {
  void router.back()
}
</script>

<style scoped>
.tenant-profile-page {
  min-height: 100vh
}

.page-shell {
  padding-bottom: 32px
}

.top-header {
  border-bottom: 1px solid rgba(15, 23, 42, 0.06)
}

.tenant-name {
  color: #111827
  font-size: 18px
  font-weight: 800
}

.tenant-course {
  color: #6B7280
  font-size: 12px
  margin-top: 2px
}

.back-btn,
.chat-btn,
.close-btn {
  color: #00897B
}

.close-btn {
  color: #DC2626
}

.profile-header {
  border-bottom: 1px solid rgba(15, 23, 42, 0.06)
}

.profile-avatar {
  font-size: 24px
  font-weight: 700
}

.profile-name {
  font-size: 20px
  font-weight: 800
  color: #111827
}

.student-id {
  color: #6B7280
  font-size: 13px
  margin-top: 4px
}

.assignment-card {
  background: #FFFFFF
  border: 1px solid rgba(15, 23, 42, 0.08)
  border-radius: 18px
  padding: 16px
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.02)
}

.assignment-icon {
  width: 40px
  height: 40px
  border-radius: 12px
  display: flex
  align-items: center
  justify-content: center
  background: rgba(0, 137, 123, 0.08)
}

.assignment-title {
  color: #111827
  font-size: 15px
  font-weight: 700
}

.assignment-subtitle {
  color: #6B7280
  font-size: 12px
  margin-top: 3px
}

.assignment-status {
  border: 1px solid rgba(0, 137, 123, 0.35)
  color: #00897B
  background: rgba(0, 137, 123, 0.05)
  border-radius: 999px
  padding: 6px 10px
  font-size: 11px
  font-weight: 700
}

.metrics-grid {
  margin-top: 4px
}

.metric-card {
  border-radius: 18px
  border: 1px solid rgba(15, 23, 42, 0.06)
  padding: 14px 10px
  text-align: center
  min-height: 116px
  display: flex
  flex-direction: column
  align-items: center
  justify-content: center
}

.metric-card.teal {
  background: rgba(0, 137, 123, 0.04)
}

.metric-card.purple {
  background: rgba(124, 58, 237, 0.04)
}

.metric-card.orange {
  background: rgba(245, 158, 11, 0.04)
}

.metric-value {
  color: #111827
  font-size: 18px
  font-weight: 800
  margin-top: 12px
}

.metric-label {
  color: #6B7280
  font-size: 10px
  font-weight: 700
  letter-spacing: 0.08em
  margin-top: 8px
}

.tab-wrap {
  border-bottom: 1px solid rgba(15, 23, 42, 0.06)
}

.billing-tabs {
  padding: 0 16px
}

.billing-tabs :deep(.q-tab) {
  color: #6B7280
  font-weight: 600
  font-size: 13px
}

.billing-tabs :deep(.q-tab--active) {
  color: #111827
}

.billing-tab {
  padding-top: 16px
}

.status-banner {
  background: rgba(0, 137, 123, 0.08)
  border: 1px solid rgba(0, 137, 123, 0.15)
  border-radius: 18px
  padding: 16px
}

.banner-icon {
  width: 28px
  height: 28px
  border-radius: 50%
  background: rgba(34, 197, 94, 0.14)
  display: flex
  align-items: center
  justify-content: center
}

.banner-title {
  color: #111827
  font-size: 15px
  font-weight: 800
}

.banner-subtitle {
  color: #374151
  font-size: 12px
  margin-top: 3px
}

.log-payment-btn {
  height: 48px
  font-weight: 700
}

.section-label {
  color: #6B7280
  font-size: 11px
  font-weight: 800
  letter-spacing: 0.08em
}

.streak-row {
  gap: 10px
  margin-top: 12px
}

.streak-label {
  color: #6B7280
  font-size: 10px
  font-weight: 700
}

.streak-label.center {
  min-width: 82px
  text-align: center
}

.streak-track {
  flex: 1
  gap: 8px
}

.streak-dot {
  width: 18px
  height: 18px
  border-radius: 50%
  background: #E5E7EB
  border: 1px solid rgba(15, 23, 42, 0.04)
}

.streak-dot.filled {
  background: #00897B
}

.history-list {
  margin-top: 12px
}

.history-item {
  background: #FFFFFF
  border: 1px solid rgba(15, 23, 42, 0.06)
  border-radius: 16px
  padding: 12px 14px
  margin-bottom: 10px
}

.history-check {
  width: 26px
  height: 26px
  border-radius: 50%
  background: #22C55E
  display: flex
  align-items: center
  justify-content: center
}

.history-month {
  color: #111827
  font-size: 14px
  font-weight: 700
}

.history-meta {
  color: #6B7280
  font-size: 11px
  margin-top: 2px
}

.history-amount {
  color: #111827
  font-weight: 800
  font-size: 14px
}

.history-status {
  color: #22C55E
  font-size: 11px
  font-weight: 700
  margin-top: 4px
}

.summary-list {
  background: #FFFFFF
  border: 1px solid rgba(15, 23, 42, 0.06)
  border-radius: 16px
  overflow: hidden
  margin-top: 12px
}

.summary-row {
  display: flex
  align-items: center
  justify-content: space-between
  padding: 14px 16px
  border-bottom: 1px solid rgba(15, 23, 42, 0.06)
  color: #111827
  font-size: 14px
}

.summary-row:last-child {
  border-bottom: none
}

.summary-row strong {
  font-weight: 800
  color: #111827
}
</style>


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

