<template>
  <q-page class="settings-page bg-white">
    <div class="page-shell q-pb-xl">
      <div class="page-header q-px-md q-pt-lg q-pb-sm">
        <div class="row items-center no-wrap">
          <q-btn
            flat
            round
            dense
            icon="arrow_back"
            class="back-button"
            @click="goBack"
          />
          <div class="page-title">Settings</div>
        </div>
      </div>

      <div class="content-stack q-px-md q-pt-sm">
        <div class="settings-section">
          <div class="section-label">NOTIFICATIONS</div>

          <q-list bordered class="settings-list">
            <q-item v-for="item in notificationItems" :key="item.id" class="setting-item">
              <q-item-section>
                <q-item-label class="setting-title">{{ item.label }}</q-item-label>
                <q-item-label caption class="setting-subtitle">{{ item.subtext }}</q-item-label>
              </q-item-section>

              <q-item-section side>
                <q-toggle
                  v-model="item.enabled"
                  color="teal-7"
                  keep-color
                  dense
                />
              </q-item-section>
            </q-item>
          </q-list>
        </div>

        <div class="settings-section">
          <div class="section-label">BUSINESS SETTINGS</div>

          <q-list bordered class="settings-list">
            <q-item clickable v-ripple class="setting-item">
              <q-item-section>
                <q-item-label class="setting-title">Manage Boarding Houses</q-item-label>
                <q-item-label caption class="setting-subtitle">Add, edit, or archive your listed properties</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-icon name="chevron_right" color="grey-6" />
              </q-item-section>
            </q-item>

            <q-separator />

            <q-item class="setting-item">
              <q-item-section>
                <q-item-label class="setting-title">Auto-Invoice</q-item-label>
                <q-item-label caption class="setting-subtitle">Automatically generate invoices every billing cycle</q-item-label>
              </q-item-section>

              <q-item-section side>
                <q-toggle v-model="autoInvoice" color="teal-7" keep-color dense />
              </q-item-section>
            </q-item>

            <q-separator />

            <q-item clickable v-ripple class="setting-item">
              <q-item-section>
                <q-item-label class="setting-title">Invoice Templates</q-item-label>
                <q-item-label caption class="setting-subtitle">Customize your billing format and due dates</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-icon name="chevron_right" color="grey-6" />
              </q-item-section>
            </q-item>

            <q-separator />

            <q-item class="setting-item">
              <q-item-section>
                <q-item-label class="setting-title">GCash / PayMaya</q-item-label>
                <q-item-label caption class="setting-subtitle">Linked payment accounts</q-item-label>
              </q-item-section>
              <q-item-section side>
                <span class="meta-value">GCash ...4321</span>
              </q-item-section>
            </q-item>
          </q-list>
        </div>

        <div class="settings-section">
          <q-list bordered class="settings-list">
            <q-item class="setting-item">
              <q-item-section>
                <q-item-label class="setting-title">Biometric Login</q-item-label>
                <q-item-label caption class="setting-subtitle">Use fingerprint or face ID to sign in</q-item-label>
              </q-item-section>

              <q-item-section side>
                <q-toggle v-model="biometricLogin" color="teal-7" keep-color dense />
              </q-item-section>
            </q-item>

            <q-separator />

            <q-item class="setting-item">
              <q-item-section>
                <q-item-label class="setting-title">Two-Factor Auth</q-item-label>
                <q-item-label caption class="setting-subtitle">Extra layer of account protection</q-item-label>
              </q-item-section>

              <q-item-section side>
                <span class="meta-value muted">Off</span>
              </q-item-section>
            </q-item>

            <q-separator />

            <q-item class="setting-item">
              <q-item-section>
                <q-item-label class="setting-title">Profile Visibility</q-item-label>
                <q-item-label caption class="setting-subtitle">Who can see your contact info</q-item-label>
              </q-item-section>

              <q-item-section side>
                <span class="meta-value">Tenants Only</span>
              </q-item-section>
            </q-item>
          </q-list>
        </div>

        <div class="settings-section">
          <div class="section-label">PREFERENCES</div>

          <q-list bordered class="settings-list">
            <q-item class="setting-item">
              <q-item-section>
                <q-item-label class="setting-title">Dark Mode</q-item-label>
                <q-item-label caption class="setting-subtitle">Easier on the eyes at night</q-item-label>
              </q-item-section>

              <q-item-section side>
                <q-toggle v-model="darkMode" color="teal-7" keep-color dense />
              </q-item-section>
            </q-item>

            <q-separator />

            <q-item class="setting-item">
              <q-item-section>
                <q-item-label class="setting-title">Language</q-item-label>
                <q-item-label caption class="setting-subtitle">App display language</q-item-label>
              </q-item-section>

              <q-item-section side>
                <span class="meta-value">English</span>
              </q-item-section>
            </q-item>
          </q-list>
        </div>

        <div class="settings-section">
          <div class="section-label">SUPPORT</div>

          <q-list bordered class="settings-list">
            <q-item clickable v-ripple class="setting-item">
              <q-item-section>
                <q-item-label class="setting-title">Help Center</q-item-label>
                <q-item-label caption class="setting-subtitle">Guides, FAQs, and landlord resources</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-icon name="chevron_right" color="grey-6" />
              </q-item-section>
            </q-item>

            <q-separator />

            <q-item clickable v-ripple class="setting-item">
              <q-item-section>
                <q-item-label class="setting-title">About Accommo</q-item-label>
                <q-item-label caption class="setting-subtitle">Version 1.0.0 ISU Echague</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-icon name="chevron_right" color="grey-6" />
              </q-item-section>
            </q-item>
          </q-list>
        </div>

        <div class="settings-section">
          <div class="section-label">ACCOUNT</div>

          <q-list bordered class="settings-list danger-list">
            <q-item clickable v-ripple class="setting-item danger-item">
              <q-item-section>
                <q-item-label class="setting-title danger-title">Log Out</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-icon name="chevron_right" color="red-6" />
              </q-item-section>
            </q-item>

            <q-separator color="red-2" />

            <q-item clickable v-ripple class="setting-item danger-item">
              <q-item-section>
                <q-item-label class="setting-title danger-title">Delete Account</q-item-label>
                <q-item-label caption class="setting-subtitle danger-subtitle">This permanently removes your account and listings</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-icon name="chevron_right" color="red-6" />
              </q-item-section>
            </q-item>
          </q-list>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'

interface NotificationSetting {
  id: string
  label: string
  subtext: string
  enabled: boolean
}

const router = useRouter()

const autoInvoice = ref(true)
const biometricLogin = ref(true)
const darkMode = ref(false)

const notificationItems = ref<NotificationSetting[]>([
  {
    id: 'tenant-payments',
    label: 'Tenant Payments',
    subtext: 'When a tenant pays rent or has an overdue balance',
    enabled: true,
  },
  {
    id: 'new-booking-requests',
    label: 'New Booking Requests',
    subtext: 'Student applications and reservation requests',
    enabled: true,
  },
  {
    id: 'concerns-repairs',
    label: 'Concerns & Repairs',
    subtext: 'Maintenance tickets and student complaints',
    enabled: true,
  },
  {
    id: 'monthly-reports',
    label: 'Monthly Reports',
    subtext: 'Occupancy and revenue summary every month',
    enabled: true,
  },
  {
    id: 'sms-alerts',
    label: 'SMS Alerts',
    subtext: 'Text messages for urgent notifications',
    enabled: false,
  },
  {
    id: 'email-notifications',
    label: 'Email Notifications',
    subtext: 'Weekly digest and account updates',
    enabled: true,
  },
])

const goBack = () => {
  void router.back()
}
</script>

<style scoped>
.settings-page {
  background: #FFFFFF;
}

.page-shell {
  min-height: 100vh;
}

.page-header {
  background: #FFFFFF;
  border-bottom: 1px solid rgba(15, 23, 42, 0.04);
}

.page-title {
  font-size: 30px;
  font-weight: 800;
  letter-spacing: -0.05em;
  color: #111827;
  margin-left: 8px;
}

.back-button {
  color: #111827;
}

.content-stack {
  padding-bottom: 32px;
}

.settings-section {
  margin-top: 20px;
}

.section-label {
  margin-bottom: 10px;
  color: #6b7280;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
}

.settings-list {
  background: #FFFFFF;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 18px;
  overflow: hidden;
}

.setting-item {
  min-height: 74px;
  padding: 12px 14px;
}

.setting-title {
  color: #111827;
  font-size: 15px;
  font-weight: 700;
}

.setting-subtitle {
  color: #6b7280;
  font-size: 12px;
  line-height: 1.45;
  margin-top: 4px;
}

.meta-value {
  color: #111827;
  font-size: 12px;
  font-weight: 700;
}

.meta-value.muted {
  color: #6b7280;
}

.danger-list {
  border-color: rgba(239, 68, 68, 0.18);
}

.danger-item {
  background: rgba(239, 68, 68, 0.02);
}

.danger-title {
  color: #dc2626;
}

.danger-subtitle {
  color: #dc2626;
  opacity: 0.9;
}

:deep(.q-toggle__track) {
  border: 1px solid rgba(15, 23, 42, 0.08);
}

:deep(.q-item__section--side) {
  min-width: auto;
}
</style>
