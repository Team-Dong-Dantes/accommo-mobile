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
              <q-item-section> My Boarding Houses </q-item-section>
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
              <div ref="readerRef" id="qr-reader" class="real-reader"></div>
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
                  @click="tenancyDialog = true"
                />
                <q-btn
                  unelevated
                  color="amber"
                  class="q-mt-sm"
                  label="Mark Attendance"
                  @click="markAttendance"
                />
              </q-card-section>
            </q-card>
          </q-bottom-sheet>

          <!-- Camera error / manual fallback -->
          <div v-if="cameraError" class="camera-error">
            <q-icon name="material-icons:error_outline" color="white" size="28px" />
            <span class="q-mx-sm">{{ cameraError }}</span>
          </div>

          <div v-if="manualMode || cameraError" class="manual-box">
            <q-input
              v-model="manualCode"
              label="Enter student code"
              filled
              dense
              class="manual-input"
              @keyup.enter="lookupManual"
            >
              <template #append>
                <q-btn round dense flat icon="search" color="teal-9" @click="lookupManual" />
              </template>
            </q-input>
          </div>

          <!-- Tenancy history dialog -->
          <q-dialog v-model="tenancyDialog">
            <q-card style="width: 350px; max-width: 90vw">
              <q-card-section class="row items-center q-pb-none">
                <div class="text-h6">Tenancy History</div>
                <q-space />
                <q-btn icon="close" flat round dense v-close-popup />
              </q-card-section>
              <q-card-section>
                <q-list separator>
                  <q-item v-for="(h, i) in scannedStudent?.tenancyHistory ?? []" :key="i">
                    <q-item-section>
                      <q-item-label>{{ h.propertyName }}</q-item-label>
                      <q-item-label caption>{{ h.address }}</q-item-label>
                      <q-item-label caption>{{ h.period }} · {{ h.status }}</q-item-label>
                    </q-item-section>
                  </q-item>
                  <q-item v-if="!(scannedStudent?.tenancyHistory?.length)">
                    <q-item-section>
                      <q-item-label caption>No lease records with your property.</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-card-section>
            </q-card>
          </q-dialog>

          <!-- Instruction text -->
          <div class="instruction-text">
            <q-icon name="material-icons:flash_on" color="teal-9" class="q-mr-sm" />
            <span>Scan student QR code to verify</span>
            <q-btn flat dense no-caps color="white" class="q-ml-sm" label="Enter code" @click="manualMode = !manualMode" />
          </div>
        </div>
      </q-page-container>
    </q-layout>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from '@/stores/auth'
import { useQrStore } from '@/stores/qr'
import { Html5Qrcode } from 'html5-qrcode'

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
const cameraError = ref('')
const manualMode = ref(false)
const manualCode = ref('')
const tenancyDialog = ref(false)
const readerRef = ref<HTMLElement | null>(null)
let html5Scanner: Html5Qrcode | null = null

// Watch the store so a successful scan (camera or manual) opens the sheet.
watch(
  () => qrStore.scannedStudent,
  (newStudent) => {
    if (newStudent) {
      scannedStudent.value = newStudent
      qrBottomSheetOpen.value = true
    }
  },
)

function onScanSuccess(decodedText: string) {
  stopScanner()
  void lookup(decodedText)
}

async function lookup(code: string) {
  const trimmed = code.trim()
  if (!trimmed) return
  try {
    await qrStore.scanStudent(trimmed)
    // The watch above opens the bottom sheet once the store updates.
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Failed to look up student.'
    $q.notify({ message, color: 'negative', position: 'top', icon: 'error_outline' })
  }
}

function lookupManual() {
  void lookup(manualCode.value)
}

function markAttendance() {
  if (!scannedStudent.value) return
  $q.notify({
    message: `Attendance recorded for ${scannedStudent.value.name}.`,
    color: 'teal-9',
    position: 'top',
    icon: 'check_circle',
  })
  // TODO: persist attendance (e.g. insert into an attendance table) when that
  // feature is scoped. For now this confirms the scanned student was identified.
}

async function startScanner() {
  cameraError.value = ''
  if (!readerRef.value) return
  try {
    html5Scanner = new Html5Qrcode(readerRef.value.id)
    await html5Scanner.start(
      { facingMode: 'environment' },
      { fps: 10, qrbox: 250 },
      onScanSuccess,
      () => {
        /* ignore per-frame decode errors */
      },
    )
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Camera unavailable.'
    cameraError.value =
      'Camera unavailable (' + message + '). You can enter the student code manually below.'
    manualMode.value = true
  }
}

function stopScanner() {
  if (html5Scanner) {
    const scanner = html5Scanner
    html5Scanner = null
    try {
      // Only stop when actually scanning; stop() throws a synchronous
      // "Cannot stop, scanner is not running or paused." otherwise.
      if (scanner.isScanning) {
        void (scanner.stop() as unknown as Promise<void>).catch(() => {})
      }
    } catch {
      /* ignore stop errors */
    }
    void (scanner.clear() as unknown as Promise<void>).catch(() => {})
  }
}

onMounted(() => {
  void startScanner()
})

onBeforeUnmount(() => {
  stopScanner()
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
  background: transparent;
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

.real-reader {
  position: absolute;
  inset: 0;
  z-index: 0;
}

.real-reader video,
.real-reader img {
  width: 100% !important;
  height: 100% !important;
  object-fit: cover;
}

.camera-overlay {
  z-index: 1;
}

.camera-error {
  position: absolute;
  top: 12%;
  left: 50%;
  transform: translateX(-50%);
  max-width: 90%;
  display: flex;
  align-items: center;
  color: white;
  font-size: 14px;
  text-align: center;
  background: rgba(0, 0, 0, 0.6);
  padding: 10px 14px;
  border-radius: 12px;
  z-index: 3;
}

.manual-box {
  position: absolute;
  bottom: 90px;
  left: 50%;
  transform: translateX(-50%);
  width: 90%;
  max-width: 420px;
  z-index: 3;
}

.manual-input {
  background: white;
  border-radius: 12px;
}
</style>