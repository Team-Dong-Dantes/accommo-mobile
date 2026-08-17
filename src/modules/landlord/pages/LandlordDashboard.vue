<template>
  <q-page class="dashboard-page bg-grey-1">
    <div class="page-shell q-pb-xl">
      <div class="top-summary q-mx-md q-mt-md">
        <div class="row q-col-gutter-sm">
          <div v-for="metric in metrics" :key="metric.id" class="col-6">
            <q-card flat bordered class="metric-card">
              <q-card-section class="q-pb-xs">
                <div class="metric-icon" :class="metric.tone">
                  <q-icon :name="metric.icon" size="20px" />
                </div>
              </q-card-section>

              <q-card-section class="q-pt-none">
                <div class="metric-value text-weight-bold">{{ metric.value }}</div>
                <div class="metric-label">{{ metric.label }}</div>
                <div class="metric-subtext" :class="metric.subtone">
                  {{ metric.subtext }}
                </div>
              </q-card-section>
            </q-card>
          </div>
        </div>
      </div>

      <div class="chart-card q-mx-md q-mt-md">
        <div class="section-header">
          <div class="section-title">12-Month Revenue</div>
          <div class="section-subtitle">Apr 2025 - Mar 2026</div>
        </div>

        <div class="chart-area">
          <div class="y-axis">
            <span v-for="label in yLabels" :key="label">{{ label }}</span>
          </div>

          <div class="bar-panel">
            <div v-for="bar in revenueBars" :key="bar.label" class="bar-column">
              <div class="bar-track">
                <div class="bar-fill" :style="{ height: `${bar.height}%` }" />
              </div>
              <div class="bar-label">{{ bar.label }}</div>
            </div>
          </div>
        </div>
      </div>

      <div class="payments-card q-mx-md q-mt-md">
        <div class="payments-header">
          <div class="section-title small-title">Recent Payments</div>
          <div class="view-all">View All</div>
        </div>

        <q-list separator class="payment-list">
          <q-item v-for="payment in paymentRows" :key="payment.id" class="payment-item">
            <q-item-section avatar>
              <q-avatar size="36px" color="teal-8" text-color="white" class="avatar-mini">
                {{ payment.initials }}
              </q-avatar>
            </q-item-section>

            <q-item-section>
              <q-item-label class="payment-name">{{ payment.name }}</q-item-label>
              <q-item-label caption class="payment-meta">
                {{ payment.meta }}
              </q-item-label>
            </q-item-section>

            <q-item-section side class="text-right">
              <div class="payment-amount">{{ payment.amount }}</div>
              <q-badge color="green-6" class="paid-badge">
                {{ payment.status }}
              </q-badge>
            </q-item-section>
          </q-item>
        </q-list>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'

interface MetricCard {
  id: string
  value: string
  label: string
  subtext: string
  icon: string
  tone: string
  subtone: string
}

interface RevenueBar {
  label: string
  value: number
  height: number
}

interface PaymentRow {
  id: string
  initials: string
  name: string
  meta: string
  amount: string
  status: string
}

const metrics = ref<MetricCard[]>([
  {
    id: 'revenue',
    value: 'P46,200',
    label: 'Monthly Revenue',
    subtext: '+3.1%',
    icon: 'attach_money',
    tone: 'icon-green',
    subtone: 'sub-green',
  },
  {
    id: 'overdue',
    value: 'P7,000',
    label: 'Overdue Rent',
    subtext: 'Due Mar 31',
    icon: 'warning_amber',
    tone: 'icon-red',
    subtone: 'sub-red',
  },
  {
    id: 'occupancy',
    value: '91.4%',
    label: 'Room Occupancy',
    subtext: '+2.3%',
    icon: 'home',
    tone: 'icon-purple',
    subtone: 'sub-purple',
  },
  {
    id: 'tenancies',
    value: '32',
    label: 'Active Tenancies',
    subtext: '+2 new',
    icon: 'people',
    tone: 'icon-orange',
    subtone: 'sub-orange',
  },
])

const revenueBars = computed<RevenueBar[]>(() => [
  { label: 'Apr', value: 18, height: 30 },
  { label: 'May', value: 25, height: 42 },
  { label: 'Jun', value: 34, height: 57 },
  { label: 'Jul', value: 29, height: 48 },
  { label: 'Aug', value: 38, height: 63 },
  { label: 'Sep', value: 42, height: 70 },
  { label: 'Oct', value: 37, height: 62 },
  { label: 'Nov', value: 47, height: 78 },
  { label: 'Dec', value: 44, height: 73 },
  { label: 'Jan', value: 52, height: 87 },
  { label: 'Feb', value: 46, height: 77 },
  { label: 'Mar', value: 56, height: 93 },
])

const yLabels = ['P0k', 'P15k', 'P30k', 'P45k', 'P60k']

const paymentRows = ref<PaymentRow[]>([
  {
    id: 'ms',
    initials: 'MS',
    name: 'Maria Santos',
    meta: 'HSE-001 - Rm 101-A - GCash',
    amount: 'P3,500',
    status: 'Paid',
  },
  {
    id: 'ar',
    initials: 'AR',
    name: 'Ana Rivera',
    meta: 'HSE-001 - Rm 202-B - Bank Transfer',
    amount: 'P3,500',
    status: 'Paid',
  },
])
</script>

<style scoped>
.dashboard-page {
  background: #F7F9FA;
}

.page-shell {
  padding-bottom: 120px;
}

.metric-card {
  background: #FFFFFF;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 18px;
  min-height: 168px;
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.03);
}

.metric-icon {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
}

.icon-green {
  background: rgba(0, 137, 123, 0.12);
  color: #00897B;
}

.icon-red {
  background: rgba(239, 68, 68, 0.1);
  color: #DC2626;
}

.icon-purple {
  background: rgba(124, 58, 237, 0.12);
  color: #7C3AED;
}

.icon-orange {
  background: rgba(245, 158, 11, 0.12);
  color: #F59E0B;
}

.metric-value {
  font-size: 28px;
  color: #111827;
  line-height: 1.1;
}

.metric-label {
  margin-top: 8px;
  font-size: 13px;
  font-weight: 600;
  color: #4B5563;
}

.metric-subtext {
  margin-top: 8px;
  font-size: 11px;
  font-weight: 700;
}

.sub-green {
  color: #00897B;
}

.sub-red {
  color: #DC2626;
}

.sub-purple {
  color: #7C3AED;
}

.sub-orange {
  color: #F59E0B;
}

.chart-card,
.payments-card {
  background: #FFFFFF;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 22px;
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.02);
}

.chart-card {
  padding: 18px 16px 12px;
}

.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.section-title {
  color: #111827;
  font-size: 18px;
  font-weight: 800;
}

.small-title {
  font-size: 16px;
}

.section-subtitle {
  color: #6B7280;
  font-size: 12px;
}

.chart-area {
  display: flex;
  align-items: flex-end;
  gap: 10px;
  margin-top: 20px;
  min-height: 230px;
}

.y-axis {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  height: 180px;
  padding-bottom: 28px;
  color: #6B7280;
  font-size: 11px;
  font-weight: 600;
}

.bar-panel {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  flex: 1;
  height: 200px;
  padding-left: 4px;
}

.bar-column {
  display: flex;
  flex: 1;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}

.bar-track {
  width: 100%;
  height: 160px;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  background: linear-gradient(180deg, rgba(0, 137, 123, 0.06), rgba(0, 137, 123, 0.02));
  border-radius: 12px 12px 8px 8px;
  overflow: hidden;
}

.bar-fill {
  width: 100%;
  background: #00897B;
  border-radius: 12px 12px 0 0;
  min-height: 12px;
}

.bar-label {
  color: #6B7280;
  font-size: 10px;
  font-weight: 700;
}

.payments-card {
  padding: 18px 0 0;
}

.payments-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 16px 8px;
}

.view-all {
  color: #00897B;
  font-size: 12px;
  font-weight: 700;
}

.payment-list {
  border-top: 1px solid rgba(15, 23, 42, 0.06);
}

.payment-item {
  padding: 12px 16px;
}

.avatar-mini {
  font-size: 11px;
  font-weight: 700;
}

.payment-name {
  color: #111827;
  font-size: 14px;
  font-weight: 700;
}

.payment-meta {
  color: #6B7280;
  font-size: 11px;
  line-height: 1.4;
}

.payment-amount {
  color: #111827;
  font-size: 14px;
  font-weight: 800;
}

.paid-badge {
  margin-top: 6px;
  font-size: 9px;
  font-weight: 700;
}
</style>
