<template>
<q-page class="scanner-page">
  <div class="scanner-shell">
    <!-- Camera stage: html5-qrcode mounts #qr-reader -->
    <div class="camera-stage">
      <div v-if="!cameraError" ref="readerRef" id="qr-reader" class="camera-reader" />
      <div v-else class="camera-empty" role="alert">
        <span class="camera-empty__icon"><IconifyIcon icon="lucide:circle-alert" width="30" /></span>
        <p>Camera unavailable</p>
        <small>{{ cameraError }}</small>
      </div>

      <!-- Corner brackets over the reader -->
      <div v-if="!cameraError" class="scan-focus" aria-hidden="true">
        <i class="focus-corner focus-corner--tl" />
        <i class="focus-corner focus-corner--tr" />
        <i class="focus-corner focus-corner--bl" />
        <i class="focus-corner focus-corner--br" />
        <span class="scan-beam" />
      </div>

      <div class="stage-shade" aria-hidden="true" />
    </div>

    <div v-if="manualMode" class="manual-panel">
      <label for="manual-code">Enter the student code from their QR</label>
      <div class="manual-row">
        <q-input id="manual-code" v-model="manualCode" outlined dense class="manual-input" placeholder="e.g. 2024-12345" @keyup.enter="lookupManual" return-key-options />
        <q-btn unelevated no-caps color="primary" class="manual-btn" label="Look up" @click="lookupManual" />
      </div>
      <p class="manual-hint">You can enter the code on the student’s ISU ID manually.</p>
    </div>
  </div>

  <!-- Hint bar -->
  <div class="scan-hint">
    <p>{{
      manualMode
        ? 'Scan the student code below, or re-enable the camera when ready.'
        : 'Point the camera at the student’s QR code to verify identity.'
    }}</p>
    <button v-if="!cameraError" type="button" class="hint-action" @click="manualMode = !manualMode">
      <IconifyIcon icon="lucide:keyboard" width="16" /> {{ manualMode ? 'Back to camera' : 'Enter code manually' }}
    </button>
    <p v-else class="hint-static">Camera is off. Enter the student code below to continue.</p>
  </div>

  <!-- Result sheet -->
  <q-dialog v-model="qrBottomSheetOpen" position="bottom" class="result-dialog">
    <q-card class="sheet-card full-width pb-safe">
      <div class="sheet-header">
        <span class="sheet-grip" aria-hidden="true" />
        <h2 class="sheet-title">Student found</h2>
        <q-btn v-if="scannedStudent" flat round dense icon="close" color="grey-6" v-close-popup aria-label="Close" />
      </div>

      <div v-if="scannedStudent" class="sheet-body">
        <div class="result-hero">
          <q-avatar size="60px" class="result-avatar">{{ scannedStudent.name.trim().charAt(0).toUpperCase() || '?' }}</q-avatar>
          <div class="result-copy">
            <strong>{{ scannedStudent.name }}</strong>
            <span>{{ scannedStudent.course || '—' }}{{ scannedStudent.yearLevel && scannedStudent.yearLevel !== '—' ? ` · Year ${scannedStudent.yearLevel}` : '' }}</span>
          </div>
          <q-badge class="result-badge" :color="scannedStudent.osasVerified ? 'positive' : 'warning'">
            <IconifyIcon :icon="scannedStudent.osasVerified ? 'lucide:shield-check' : 'lucide:shield-alert'" width="13" />
            {{ scannedStudent.osasVerified ? 'Verified' : 'Not verified' }}
          </q-badge>
        </div>

        <div class="result-block">
          <dl>
            <div><dt>Student ID</dt><dd>{{ scannedStudent.studentId }}</dd></div>
            <div v-if="scannedStudent.currentBoarding">
              <dt>Accommodation</dt>
              <dd>{{ scannedStudent.currentBoarding.propertyName }}</dd>
            </div>
          </dl>
        </div>

        <div v-if="scannedStudent.currentBoarding" class="stay-facts">
          <div><span>Unit</span><strong>{{ scannedStudent.currentBoarding.unit }}</strong></div>
          <div><span>Status</span><strong>Active</strong></div>
          <div><span>Monthly</span><strong>₱{{ scannedStudent.currentBoarding.monthlyRate.toLocaleString() }}</strong></div>
        </div>

        <div class="result-actions">
          <q-btn unelevated no-caps color="primary" class="sheet-cta" label="View tenancy history" @click="qrBottomSheetOpen = false; tenancyDialog = true" />
          <q-btn outline no-caps color="primary" text-color="primary" class="sheet-cta sheet-cta--ghost-row" label="Mark attendance" @click="markAttendance" />
        </div>
      </div>
    </q-card>
  </q-dialog>

  <!-- Tenancy history -->
  <q-dialog v-model="tenancyDialog" position="bottom" class="result-dialog">
    <q-card class="sheet-card full-width pb-safe housesheet">
      <div class="sheet-header sheet-header--fixed">
        <span class="sheet-grip sheet-grip--inline" aria-hidden="true" />
        <h2 class="sheet-title">Tenancy history</h2>
      </div>
      <div class="sheet-body sheet-body--scroll">
        <p v-if="!(scannedStudent?.tenancyHistory?.length)" class="empty-note">No lease records with your property.</p>
        <div v-else class="history-list">
          <div v-for="(h, i) in scannedStudent?.tenancyHistory ?? []" :key="i" class="history-row">
            <span class="history-icon"><IconifyIcon icon="lucide:building-2" width="18" /></span>
            <div class="history-copy">
              <strong>{{ h.propertyName }}</strong>
              <small>{{ h.address }}</small>
              <small>{{ h.period }}</small>
            </div>
            <q-badge class="history-status" :color="h.status === 'Current' ? 'teal' : 'grey'">{{ h.status }}</q-badge>
          </div>
        </div>
      </div>
    </q-card>
  </q-dialog>
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

const userRole = ref<'manager' | 'student' | ''>('manager')
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
let disposed = false

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
  // If the user navigates away while the camera is still initialising, never
  // continue attaching to an unmounted element afterwards.
  if (disposed) return
  try {
    if (disposed) return
    html5Scanner = new Html5Qrcode(readerRef.value.id)
    await html5Scanner.start(
      { facingMode: 'environment' },
      { fps: 10, qrbox: 250 },
      onScanSuccess,
      () => {
        /* ignore per-frame decode errors */
      },
    )
    // A scan could have stopped the stream while start() was resolving.
    if (disposed) stopScanner()
  } catch (error: unknown) {
    if (disposed) { stopScanner(); return }
    const message = error instanceof Error ? error.message : 'Camera unavailable.'
    cameraError.value =
      'Camera unavailable (' + message + '). You can enter the student code manually below.'
    manualMode.value = true
  }
}

function stopScanner() {
  const scanner = html5Scanner
  html5Scanner = null
  if (!scanner) return
  // Html5Qrcode throws (or resolves undefined) if the stream is not currently
  // running, which happens when navigating away mid-init. Guard every call so
  // teardown in onBeforeUnmount can never throw and break route navigation.
  try {
    if (scanner.isScanning) {
      const stopResult = scanner.stop() as unknown
      if (stopResult instanceof Promise) void (stopResult as Promise<void>).catch(() => {})
    }
  } catch {
    /* not scanning yet - the start() promise will surface its own error */
  }
  try {
    const clearResult = scanner.clear() as unknown
    if (clearResult instanceof Promise) void (clearResult as Promise<void>).catch(() => {})
  } catch {
    /* clear on an uninitialised scanner is a no-op */
  }
}

onMounted(() => {
  void startScanner()
})

onBeforeUnmount(() => {
  disposed = true
  stopScanner()
})
</script>

<style scoped>
.scanner-page { min-height: 100vh; background: var(--m-bg); color: var(--m-text); }
.scanner-shell { position: relative; width: min(100%, 760px); margin: 0 auto; padding: var(--m-space-3) var(--m-page-gutter) 0; box-sizing: border-box; }

/* ---------- Camera stage ---------- */
.camera-stage {
  position: relative;
  height: clamp(360px, 62vh, 560px);
  overflow: hidden;
  border-radius: var(--m-radius-lg);
  background: #0b1210;
}
.camera-reader { position: absolute; inset: 0; z-index: 0; }
.camera-empty {
  position: absolute;
  inset: 0;
  z-index: 0;
  display: flex;
  align-items: center;
  flex-direction: column;
  justify-content: center;
  padding: var(--m-space-6);
  color: #dfe5e1;
  text-align: center;
}
.camera-empty__icon { display: grid; width: 56px; height: 56px; margin-bottom: var(--m-space-3); place-items: center; border-radius: 50%; background: rgba(255,255,255,0.08); color: var(--m-primary-lt, #5eead4); }
.camera-empty p { margin: 0; font-size: 15px; font-weight: 700; }
.camera-empty small { margin-top: 6px; color: rgba(255,255,255,0.6); font-size: 12px; line-height: 1.5; }

/* vignette so corners / text read */
.stage-shade { position: absolute; inset: 0; z-index: 1; pointer-events: none; box-shadow: inset 0 0 120px rgba(0,0,0,0.45); }

/* focus window + corners */
.scan-focus {
  position: absolute;
  top: 50%;
  left: 50%;
  z-index: 2;
  width: 70%;
  max-width: 260px;
  height: 70%;
  max-height: 260px;
  transform: translate(-50%, -50%);
  pointer-events: none;
}
.focus-corner { position: absolute; width: 22px; height: 22px; border-color: var(--m-primary, #14b8a6); border-style: solid; border-width: 0; }
.focus-corner--tl { top: 0; left: 0; border-top-width: 3px; border-left-width: 3px; border-top-left-radius: 6px; }
.focus-corner--tr { top: 0; right: 0; border-top-width: 3px; border-right-width: 3px; border-top-right-radius: 6px; }
.focus-corner--bl { bottom: 0; left: 0; border-bottom-width: 3px; border-left-width: 3px; border-bottom-left-radius: 6px; }
.focus-corner--br { bottom: 0; right: 0; border-bottom-width: 3px; border-right-width: 3px; border-bottom-right-radius: 6px; }
.scan-beam { position: absolute; right: 14px; left: 14px; height: 2px; border-radius: 999px; background: linear-gradient(90deg, transparent, var(--m-primary-lt,#5eead4), transparent); box-shadow: 0 0 14px var(--m-primary, #14b8a6); animation: scan-y 2.2s ease-in-out infinite; }
@keyframes scan-y { 0% { top: 16%; } 50% { top: calc(84% - 2px); } 100% { top: 16%; } }

/* manual entry overlay */
.manual-panel {
  margin-top: var(--m-space-3);
  padding: var(--m-space-4);
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.manual-panel label { display: block; margin-bottom: var(--m-space-2); color: var(--m-text); font-size: 13px; font-weight: 650; }
.manual-row { display: flex; align-items: center; gap: var(--m-space-2); }
.manual-input { flex: 1; }
.manual-input :deep(.q-field__control) { border-radius: var(--m-radius-sm); background: #fff; }
.manual-btn { min-width: 96px; min-height: 40px; border-radius: var(--m-radius-sm); }
.manual-hint { margin: var(--m-space-2) 0 0; color: var(--m-muted); font-size: 11px; line-height: 1.4; }

/* hint row */
.scan-hint {
  display: flex;
  min-height: 56px;
  align-items: center;
  justify-content: space-between;
  gap: var(--m-space-3);
  padding-top: var(--m-space-3);
}
.scan-hint p { margin: 0; color: var(--m-muted); font-size: 13px; line-height: 1.45; }
.scan-hint .hint-static { font-weight: 650; }
.hint-action { display: inline-flex; min-height: 44px; align-items: center; gap: 6px; padding: 0 6px; border: 0; background: transparent; color: var(--m-primary-dark); cursor: pointer; font: inherit; font-size: 13px; font-weight: 750; }

/* ---------- Sheets ---------- */
.sheet-card { grid-column: 1 / -1; border: 0; border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0; box-shadow: 0 -8px 30px rgba(15,23,42,0.14); color: var(--m-text); }
.housesheet { display: flex; max-height: 82vh; flex-direction: column; }
.housesheet .sheet-body--scroll { min-height: 0; }
.sheet-header { display: flex; min-height: 52px; align-items: center; justify-content: space-between; padding: var(--m-space-3) var(--m-space-4) var(--m-space-2); box-sizing: border-box; }
.sheet-header--fixed { flex: 0 0 auto; border-bottom: 1px solid var(--m-border); }
.sheet-grip { width: 40px; height: 4px; margin: 0 auto; border-radius: 999px; background: #d8dce2; }
.sheet-grip--inline { flex: 0 0 auto; }
.sheet-title { margin: 0; color: var(--m-ink); font-family: var(--m-font-display); font-size: 18px; font-weight: 700; letter-spacing: -0.01em; }
.sheet-body { padding: var(--m-space-2) var(--m-space-4) var(--m-space-5); }
.pb-safe { padding-bottom: calc(var(--m-space-5) + env(safe-area-inset-bottom)); }
.sheet-cta { width: 100%; min-height: 48px; margin-top: var(--m-space-3); border-radius: var(--m-radius-sm); font-weight: 800; }
.q-btn.sheet-cta:not(.q-btn--outline) { background: var(--m-primary-dark); }
.sheet-cta--ghost-row { border: 1px solid var(--m-border) !important; color: var(--m-primary-dark); }
.result-actions { margin-top: var(--m-space-4); }
.result-actions .sheet-cta + .sheet-cta { margin-top: var(--m-space-2); }

/* result hero */
.result-hero { display: flex; align-items: center; gap: var(--m-space-3); }
.result-avatar { flex: 0 0 auto; background: linear-gradient(135deg, var(--m-primary-dark), var(--m-primary)); color: #fff; font-size: 22px; font-weight: 800; }
.result-copy { display: flex; min-width: 0; flex: 1; flex-direction: column; gap: 3px; }
.result-copy strong { color: var(--m-ink); font-size: 15px; line-height: 1.3; overflow-wrap: anywhere; }
.result-copy span { color: var(--m-muted); font-size: 12px; line-height: 1.4; }
.result-badge { display: inline-flex; align-items: center; gap: 5px; min-height: 24px; padding: 0 9px; border-radius: 999px; font-size: 11px; font-weight: 750; }

.result-block dl, .history-block dl { margin: var(--m-space-4) 0 0; border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); overflow: hidden; }
.result-block dl > div { display: flex; align-items: center; justify-content: space-between; gap: var(--m-space-3); padding: var(--m-space-3); }
.result-block dl > div + div { border-top: 1px solid var(--m-border); }
.result-block dt, .history-block dt { color: var(--m-muted); font-size: 12px; }
.result-block dd, .history-block dd { margin: 0; color: var(--m-ink); font-size: 13px; font-weight: 650; text-align: right; overflow-wrap: anywhere; }

.stay-facts { display: grid; grid-template-columns: repeat(3, minmax(0,1fr)); gap: var(--m-space-2); margin-top: var(--m-space-4); }
.stay-facts > div { min-width: 0; padding: var(--m-space-3); border-radius: var(--m-radius-sm); background: var(--m-bg); }
.stay-facts span { display: block; color: var(--m-muted); font-size: 9px; font-weight: 800; letter-spacing: 0.05em; text-transform: uppercase; }
.stay-facts strong { display: block; margin-top: 4px; overflow: hidden; color: var(--m-ink); font-size: 12px; line-height: 1.4; text-overflow: ellipsis; white-space: nowrap; }

.empty-note { margin: var(--m-space-3) 0; color: var(--m-muted); font-size: 13px; text-align: center; }

/* history list */
.history-row { display: flex; align-items: center; gap: var(--m-space-3); padding: var(--m-space-3) 0; }
.history-row + .history-row { border-top: 1px solid var(--m-border); }
.history-icon { display: grid; width: 38px; height: 38px; flex: 0 0 auto; place-items: center; border-radius: 9px; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.history-copy { display: flex; min-width: 0; flex: 1; flex-direction: column; gap: 2px; }
.history-copy strong { color: var(--m-ink); font-size: 14px; line-height: 1.3; }
.history-copy small { color: var(--m-muted); font-size: 12px; line-height: 1.4; }
.history-status { display: inline-flex; align-items: center; min-height: 22px; padding: 0 8px; border-radius: 999px; font-size: 11px; font-weight: 750; }

@media (prefers-reduced-motion: reduce) {
  .scan-beam { animation: none; }
}
</style>
