<template>
  <q-page class="qr-scanner-page">
    <q-layout view="hHh lpR fFf">
      <q-header elevated class="bg-primary text-white">
        <q-toolbar>
          <q-btn dense flat round @click="toggleLeftDrawer">
            <IconifyIcon width="24" icon="material-icons:menu" />
          </q-btn>

          <q-toolbar-title>QR Scanner</q-toolbar-title>

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
          </template>
        </q-list>
      </q-drawer>

      <q-page-container>
        <div class="qr-scanner-container">
          <!-- Camera preview area -->
          <div class="camera-preview">
            <div class="camera-frame">
              <div class="camera-overlay">
                <div class="flash-icon" />
                <q-icon
                  name="material-icons:qr_code_scanner"
                  size="48"
                  color="teal-9"
                  class="center-qr-icon"
                />
              </div>
            </div>

            <!-- Scanning frame -->
            <div class="scanning-bar">
              <div class="scanning-line" />
            </div>
          </div>

          <!-- QR Code Frame CSS Areas -->
          <div class="qr-frame-borders">
            <div class="frame-tl" />
            <div class="frame-tr" />
            <div class="frame-bl" />
            <div class="frame-br" />
          </div>

          <!-- Student Verified Bottom Sheet -->
          <q-bottom-sheet v-model="qrBottomSheetOpen" class="qr-bottom-sheet">
            <q-card class="q-pa-md q-bg-white q-shadow-4">
              <q-card-section>
                <div class="row items-center">
                  <q-avatar
                    size="56"
                    color="teal-9"
                    text-color="white"
                    font-size="32px"
                  >
                    {{ scannedStudent?.name?.charAt(0) ?? '?' }}
                  </q-avatar>

                  <div class="q-ml-sm q-mt-1">
                    <div class="text-h6 text-weight-bold">{{ scannedStudent?.name }}</div>
                    <div class="text-subtitle2 text-teal-7">{{ scannedStudent?.course }}</div>
                  </div>

                  <q-btn
                    flat
                    round
                    icon="close"
                    color="teal-9"
                    @click="qrBottomSheetOpen = false"
                  />
                </div>
              </q-card-section>

              <q-card-section>
                <div class="row q-mt-sm">
                  <div class="col-6">
                    <q-icon name="material-badge" color="teal-9" class="q-mr-sm" />
                    <span>Student ID: {{ scannedStudent?.studentId }}</span>
                  </div>
                  <div class="col-6">
                    <q-icon
                      :color="scannedStudent?.osasVerified ? 'green' : 'red'"
                      name="material-icons:verified"
                      class="q-mr-sm"
                    />
                    <span
                      v-if="scannedStudent?.osasVerified"
                      class="text-weight-bold text-teal-7"
                    >OSAS Verified</span>
                    <span
                      v-else
                      class="text-weight-bold text-red-7"
                    >OSAS Not Verified</span>
                  </div>
                </div>
              </q-card-section>

              <q-card-section>
                <div class="row q-mt-sm">
                  <div class="col-6">
                    <q-icon name="material-icons:room" color="teal-9" class="q-mr-sm" />
                    <span>Current Property: {{ scannedStudent?.currentBoarding?.propertyName }}</span>
                  </div>
                  <div class="col-6">
                    <q-icon name="material-icons:bed" color="teal-9" class="q-mr-sm" />
                    <span>Unit: {{ scannedStudent?.currentBoarding?.unit }}</span>
                  </div>
                </div>
                <div class="row q-mt-2">
                  <div class="col-12">
                    <q-icon name="material-icons:monetization_on" color="teal-9" class="q-mr-sm" />
                    <span>Monthly Rate: ₱{{ scannedStudent?.currentBoarding?.monthlyRate.toLocaleString() }}</span>
                  </div>
                </div>
              </q-card-section>

              <q-card-section>
                <q-btn
                  unelevated
                  color="teal-9"
                  class="q-ml-sm q-mr-sm q-mt-sm"
                  label="View Tenancy History"
                />
                <q-btn
                  unelevated
                  color="amber"
                  class="q-mt-sm"
                  label="Mark Attendance"
                />
              </q-card-section>
            </q-card>
          </q-bottom-sheet>

          <!-- Instruction text -->
          <div class="instruction-text">
            <q-icon name="material-icons:flash_on" color="teal-9" class="q-mr-sm" />
            <span>Scan student QR code to verify</span>
          </div>
        </div>
      </q-page-container>
    </q-layout>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from '@/stores/auth'
import { useQrStore } from '@/stores/qr'

import { supabase } from '@/shared/utils/supabase'

const router = useRouter()
const route = useRoute()
const $q = useQuasar()
const authStore = useAuthStore()
const qrStore = useQrStore()

const userRole = ref<'landlord' | 'student' | ''>('landlord')
const leftDrawerOpen = ref(false)

function toggleLeftDrawer() {
  leftDrawerOpen.value = !leftDrawerOpen.value
}

function handleLogout() {
  authStore.clearCachedRole()
  void supabase.auth.signOut()
  void router.push('/login')
}

const qrBottomSheetOpen = ref(false)
const scannedStudent = ref<any | null>(null)

// Watch for QR scan changes
watch(
  () => qrStore.scannedStudent,
  (newStudent) => {
    if (newStudent) {
      scannedStudent.value = newStudent
      qrBottomSheetOpen.value = true
    }
  },
)

// Initial load - simulate a scan for demo
onMounted(async () => {
  // In a real app, this would trigger the camera and QR detection
  // For demo, we'll just initialize the scanner state
  qrStore.isScanning = true

  // Simulate scan after a brief delay
  await new Promise((resolve) => setTimeout(resolve, 1000))

  // Mock QR scan result
  const mockScanResult: any = {
    studentId: '2023-001',
    name: 'Juan Dela Cruz',
    course: 'BS Computer Science',
    osasVerified: true,
    propertyName: 'Rose Dormitory',
    unit: '2B',
    monthlyRate: 5000,
  }

  qrStore.scanStudent(mockScanResult.studentId)
  qrStore.isScanning = false
})
</script>

<style scoped>
.qr-scanner-page {
  background: #F7F9FA;
}

.qr-scanner-container {
  position: relative;
  width: 100%;
  height: 100vh;
  background: black;
  overflow: hidden;
}

.camera-preview {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.camera-frame {
  position: absolute;
  top: 20%;
  left: 50%;
  transform: translateX(-50%);
  width: 80%;
  max-width: 400px;
  height: 60%;
  background: black;
  border: 4px solid #00897B;
  border-radius: 24px;
  overflow: hidden;
  box-shadow: 0 16px 48px rgba(0, 0, 0, 0.4);
}

.camera-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: linear-gradient(
    135deg,
    rgba(0, 0, 0, 0.8) 0%,
    rgba(0, 0, 0, 0.6) 100%
  );
}

.flash-icon {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 80px;
  height: 80px;
  border: 4px solid rgba(255, 255, 255, 0.3);
  border-radius: 50%;
  animation: flashPulse 2s ease-in-out infinite;
  pointer-events: none;
}

@keyframes flashPulse {
  0% {
    opacity: 1;
    transform: translate(-50%, -50%) scale(1);
  }
  50% {
    opacity: 0.5;
    transform: translate(-50%, -50%) scale(1.2);
  }
  100% {
    opacity: 1;
    transform: translate(-50%, -50%) scale(1);
  }
}

.center-qr-icon {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  pointer-events: none;
}

.scanning-bar {
  position: absolute;
  bottom: 0;
  left: 50%;
  width: 60%;
  max-width: 300px;
  transform: translateX(-50%);
  height: 3px;
  background: rgba(255, 255, 255, 0.3);
}

.scanning-line {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: linear-gradient(
    to bottom,
    rgba(0, 137, 123, 0) 0%,
    #00897B 50%,
    rgba(0, 137, 123, 0) 100%
  );
  animation: scanLine 2s linear infinite;
}

@keyframes scanLine {
  0% {
    top: 0;
  }
  100% {
    top: 100%;
  }
}

.qr-frame-borders {
  position: absolute;
  top: 20%;
  left: 50%;
  transform: translateX(-50%);
  width: 80%;
  max-width: 400px;
  height: 60%;
  pointer-events: none;
}

.frame-tl,
.frame-tr,
.frame-bl,
.frame-br {
  position: absolute;
  width: 20px;
  height: 20px;
  border: 4px solid #00897B;
}

.frame-tl {
  top: -12px;
  left: -12px;
  border-right-width: 0;
  border-bottom-width: 0;
}

.frame-tr {
  top: -12px;
  right: -12px;
  border-left-width: 0;
  border-bottom-width: 0;
}

.frame-bl {
  bottom: -12px;
  left: -12px;
  border-right-width: 0;
  border-top-width: 0;
}

.frame-br {
  bottom: -12px;
  right: -12px;
  border-left-width: 0;
  border-top-width: 0;
}

.instruction-text {
  position: absolute;
  bottom: 30px;
  left: 50%;
  transform: translateX(-50%);
  color: white;
  font-size: 14px;
  pointer-events: none;
}

.qr-bottom-sheet {
  max-height: 90%;
  overflow: auto;
}

.q-bottom-sheet .q-card {
  border-radius: 24px;
}

.q-card .q-card-section {
  padding: 24px;
}

.q-card .q-card-section:last-child {
  padding: 16px 24px 24px;
}
</style>