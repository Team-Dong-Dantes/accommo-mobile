<template>
  <q-page class="support-page bg-grey-1">
    <div class="page-shell q-pb-xl">
      <div class="header-block q-px-md q-pt-lg q-pb-sm">
        <div class="page-title">Support</div>
        <div class="page-subtitle">OSAS Help Center - Maintenance - Reviews</div>
      </div>

      <div class="q-px-md q-mt-sm">
        <q-tabs
          v-model="activeSupportTab"
          class="support-tabs"
          active-color="black"
          indicator-color="transparent"
          inline-label
          dense
          switch-indicator
        >
          <q-tab name="osas" class="support-tab">
            <span class="tab-label">OSAS Support</span>
            <q-badge color="grey-3" text-color="black" class="tab-badge">
              4
            </q-badge>
          </q-tab>
          <q-tab name="maintenance" class="support-tab">
            <span class="tab-label">Maintenance</span>
          </q-tab>
          <q-tab name="reviews" class="support-tab">
            <span class="tab-label">Reviews</span>
          </q-tab>
        </q-tabs>
      </div>

      <div class="q-px-md q-mt-md">
        <q-card class="help-banner">
          <q-card-section class="q-pb-sm">
            <div class="banner-header">
              <div>
                <div class="banner-title">How can OSAS help?</div>
                <div class="banner-meta">
                  <span class="online-dot" />
                  Officer Reyes - Responds within 1-2 business days
                </div>
              </div>
            </div>
          </q-card-section>

          <q-card-section class="q-pt-none">
            <q-input
              v-model="searchText"
              outlined
              dense
              bg-color="white"
              input-class="search-input"
              placeholder="Search for help"
              class="support-search"
            >
              <template #prepend>
                <q-icon name="search" color="grey-7" />
              </template>
            </q-input>
          </q-card-section>
        </q-card>
      </div>

      <div class="q-px-md q-mt-lg">
        <div class="section-row">
          <div class="section-title">Help Categories</div>
        </div>

        <div class="category-grid">
          <q-card
            v-for="category in helpCategories"
            :key="category.id"
            flat
            bordered
            class="category-card"
          >
            <q-card-section class="column items-center text-center q-pa-md">
              <div class="category-icon" :class="category.tone">
                <q-icon :name="category.icon" size="22px" />
              </div>
              <div class="category-name">{{ category.name }}</div>
              <div class="category-detail">{{ category.detail }}</div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <div class="q-px-md q-mt-xl">
        <div class="section-row ticket-header">
          <div class="section-title">MY TICKETS</div>
          <q-btn flat dense class="view-link">View all</q-btn>
        </div>

        <q-list bordered class="ticket-list bg-white rounded-borders">
          <q-item v-for="ticket in tickets" :key="ticket.id" class="ticket-item">
            <q-item-section>
              <div class="ticket-top-row">
                <span class="ticket-id">{{ ticket.id }}</span>
                <q-badge :color="ticket.badgeColor" text-color="black" class="ticket-status">
                  {{ ticket.status }}
                </q-badge>
              </div>

              <div class="ticket-title">{{ ticket.title }}</div>
              <div class="ticket-meta-row">
                <span>{{ ticket.date }}</span>
                <span class="message-snippet">{{ ticket.message }}</span>
              </div>
            </q-item-section>
          </q-item>
        </q-list>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue'

interface HelpCategory {
  id: string
  name: string
  detail: string
  icon: string
  tone: string
}

interface Ticket {
  id: string
  status: string
  badgeColor: string
  title: string
  date: string
  message: string
}

const activeSupportTab = ref('osas')
const searchText = ref('')

const helpCategories = ref<HelpCategory[]>([
  {
    id: 'accreditation',
    name: 'Accreditation',
    detail: 'Status updates',
    icon: 'verified_user',
    tone: 'icon-teal',
  },
  {
    id: 'tenant-dispute',
    name: 'Tenant Dispute',
    detail: 'Case support',
    icon: 'gavel',
    tone: 'icon-purple',
  },
  {
    id: 'documents',
    name: 'Documents',
    detail: 'Certificates',
    icon: 'description',
    tone: 'icon-amber',
  },
  {
    id: 'inspection',
    name: 'Inspection',
    detail: 'Property check',
    icon: 'fact_check',
    tone: 'icon-blue',
  },
  {
    id: 'general',
    name: 'General',
    detail: 'General help',
    icon: 'help_outline',
    tone: 'icon-slate',
  },
])

const tickets = ref<Ticket[]>([
  {
    id: 'OSAS-246',
    status: 'In Progress',
    badgeColor: 'amber-3',
    title: 'Fire safety certificate renewal',
    date: 'Jun 12, 2026',
    message: 'Pending final inspection approval',
  },
  {
    id: 'OSAS-183',
    status: 'Resolved',
    badgeColor: 'green-3',
    title: 'Tenant documentation review',
    date: 'Jun 04, 2026',
    message: 'Documentation was verified and closed',
  },
])
</script>

<style scoped>
.support-page {
  background: #f4f5f7;
}

.page-shell {
  padding-bottom: 110px;
}

.header-block {
  background: #f4f5f7;
}

.page-title {
  color: #111827;
  font-size: 30px;
  font-weight: 800;
  letter-spacing: -0.05em;
}

.page-subtitle {
  margin-top: 4px;
  color: #6b7280;
  font-size: 13px;
  font-weight: 600;
}

.support-tabs {
  background: #edf2f2;
  border-radius: 999px;
  padding: 4px;
}

.support-tab {
  min-height: 42px;
  font-size: 12px;
  font-weight: 700;
  color: #374151;
}

.support-tab :deep(.q-tab__content) {
  gap: 6px;
}

.support-tab[aria-selected='true'] {
  background: #111827;
  color: white;
  border-radius: 999px;
}

.tab-label {
  position: relative;
  z-index: 1;
}

.tab-badge {
  border-radius: 999px;
  font-size: 10px;
  min-width: 20px;
  min-height: 20px;
  padding: 0 6px;
}

.help-banner {
  background: linear-gradient(135deg, #0d474f 0%, #0f766e 100%);
  border-radius: 26px;
  color: white;
  box-shadow: 0 20px 30px rgba(15, 118, 110, 0.15);
}

.banner-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}

.banner-title {
  font-size: 26px;
  line-height: 1.1;
  font-weight: 800;
  letter-spacing: -0.05em;
}

.banner-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 10px;
  color: rgba(255, 255, 255, 0.8);
  font-size: 12px;
  font-weight: 600;
}

.online-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #4ade80;
  display: inline-flex;
}

.support-search {
  margin-top: 6px;
}

:deep(.support-search .q-field__control) {
  height: 48px;
  border-radius: 14px;
}

.section-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.section-title {
  color: #111827;
  font-size: 14px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.category-grid {
  margin-top: 14px;
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.category-card {
  border-radius: 18px;
  background: white;
  border: 1px solid rgba(15, 23, 42, 0.06);
}

.category-icon {
  width: 54px;
  height: 54px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.icon-teal {
  background: rgba(13, 148, 136, 0.12);
  color: #0f766e;
}

.icon-purple {
  background: rgba(124, 58, 237, 0.1);
  color: #7c3aed;
}

.icon-amber {
  background: rgba(245, 158, 11, 0.12);
  color: #b45309;
}

.icon-blue {
  background: rgba(59, 130, 246, 0.1);
  color: #2563eb;
}

.icon-slate {
  background: rgba(71, 85, 105, 0.08);
  color: #475569;
}

.category-name {
  margin-top: 12px;
  color: #111827;
  font-size: 14px;
  font-weight: 700;
}

.category-detail {
  margin-top: 4px;
  color: #6b7280;
  font-size: 11px;
}

.ticket-header {
  margin-bottom: 10px;
}

.view-link {
  color: #0f766e;
  font-size: 12px;
  font-weight: 700;
}

.ticket-list {
  border: 1px solid rgba(15, 23, 42, 0.06);
  overflow: hidden;
}

.ticket-item {
  padding: 14px 16px;
}

.ticket-top-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.ticket-id {
  color: #6b7280;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.06em;
}

.ticket-status {
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}

.ticket-title {
  margin-top: 8px;
  color: #111827;
  font-size: 15px;
  font-weight: 700;
}

.ticket-meta-row {
  margin-top: 6px;
  display: flex;
  flex-direction: column;
  gap: 2px;
  color: #6b7280;
  font-size: 11px;
}

.message-snippet {
  color: #374151;
  font-weight: 600;
}
</style>
