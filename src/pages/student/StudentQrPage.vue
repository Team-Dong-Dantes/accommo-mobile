<template>
  <q-page class="qr-page">
    <div v-if="loading" class="stack">
      <div class="sk-card">
        <q-skeleton type="rect" width="220px" height="220px" class="q-mx-auto" />
      </div>
    </div>

    <div v-else-if="error" class="stack">
      <ErrorCard title="Couldn't load your QR" :detail="error" :retry="load" />
    </div>

    <div v-else class="stack">
      <div class="qr-card">
        <template v-if="osasVerified && qrDataUrl">
          <div class="qr-header">
            <IconifyIcon icon="lucide:shield-check" width="24" class="qr-header-icon" />
            <h3 class="qr-title">My student QR</h3>
          </div>
          <p class="qr-sub">
            Show this code at check-in so your manager can confirm you're an active, verified student.
          </p>
          <div class="qr-image-wrapper">
            <img :src="qrDataUrl" alt="Your student QR code" class="qr-image" width="220" height="220" />
          </div>
          <p class="qr-id">ID: {{ studentId }}</p>
          <div class="qr-timer" role="timer" :aria-label="`Code changes in ${secondsLeft} seconds`">
            <svg class="qr-ring" viewBox="0 0 36 36" aria-hidden="true">
              <circle class="qr-ring-track" cx="18" cy="18" r="15.5" />
              <!-- Restarted per code: the key remounts it, so the sweep always
                   matches the time this code actually has left. -->
              <circle :key="qrToken" class="qr-ring-sweep" cx="18" cy="18" r="15.5" pathLength="100" :style="{ animationDuration: `${ttlMs}ms` }" />
            </svg>
            <span class="qr-timer-num">{{ secondsLeft }}</span>
          </div>
          <p class="qr-note">
            This code changes every 5 seconds, so a screenshot stops working almost at once.
          </p>
        </template>
        <template v-else-if="!osasVerified">
          <div class="qr-locked">
            <span class="qr-locked-icon"><IconifyIcon icon="lucide:lock-keyhole" width="26" /></span>
            <p class="qr-locked-title">QR code locked</p>
            <p class="qr-locked-sub">Get verified by OSAS to unlock your student QR code.</p>
            <q-btn unelevated no-caps color="primary" class="qr-locked-cta" label="Verify with OSAS" @click="go('/student/support')" />
          </div>
        </template>
        <template v-else>
          <div class="qr-locked">
            <span class="qr-locked-icon"><IconifyIcon icon="lucide:circle-alert" width="26" /></span>
            <p class="qr-locked-title">Student ID missing</p>
            <p class="qr-locked-sub">Your account doesn't have a student ID on file yet, so a QR code can't be generated. Contact OSAS to have it added.</p>
            <q-btn unelevated no-caps color="primary" class="qr-locked-cta" label="Contact OSAS" @click="go('/student/support')" />
          </div>
        </template>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import QRCode from 'qrcode'
import { supabase, authUser } from '@/utils/supabase'
import ErrorCard from '@/components/shared/ErrorCard.vue'

const router = useRouter()

const loading = ref(true)
const error = ref('')
const studentId = ref('')
const osasVerified = ref(false)
const qrDataUrl = ref('')
const qrToken = ref('')
const secondsLeft = ref(0)
const ttlMs = ref(5000)
let refreshTimer: ReturnType<typeof setTimeout> | null = null
let tickTimer: ReturnType<typeof setInterval> | null = null
let stopped = false

/**
 * The code changes every 5 seconds. The server says how long this one has left
 * (ttl_ms), so the phone's own clock never matters; the next one is fetched
 * the moment it runs out. A failed fetch retries shortly rather than leaving a
 * dead code up.
 */
async function refreshToken() {
  if (refreshTimer) clearTimeout(refreshTimer)
  if (stopped || document.hidden) return
  try {
    const { data, error: tokenError } = await supabase.rpc('current_qr_token')
    if (tokenError) throw tokenError
    const row = Array.isArray(data) ? data[0] : data
    qrToken.value = String(row?.token ?? '')
    ttlMs.value = Math.max(500, Number(row?.ttl_ms ?? 5000))
    await generateQr()
    const endsAt = Date.now() + ttlMs.value
    if (tickTimer) clearInterval(tickTimer)
    const tick = () => { secondsLeft.value = Math.max(0, Math.ceil((endsAt - Date.now()) / 1000)) }
    tick()
    tickTimer = setInterval(tick, 250)
    refreshTimer = setTimeout(() => void refreshToken(), ttlMs.value)
  } catch (e) {
    if (!qrToken.value) throw e
    refreshTimer = setTimeout(() => void refreshToken(), 2000)
  }
}

// No polling while the screen is off or the app is in the background.
function onVisibility() {
  if (!document.hidden) void refreshToken()
}
document.addEventListener('visibilitychange', onVisibility)

onUnmounted(() => {
  stopped = true
  document.removeEventListener('visibilitychange', onVisibility)
  if (refreshTimer) clearTimeout(refreshTimer)
  if (tickTimer) clearInterval(tickTimer)
})

function go(path: string) {
  void router.push(path)
}

async function generateQr() {
  // The code is a 5-second token signed by the server, never the student
  // number: a student number is public enough to guess and proves nothing.
  if (!qrToken.value) {
    qrDataUrl.value = ''
    return
  }
  try {
    qrDataUrl.value = await QRCode.toDataURL(qrToken.value, {
      width: 220,
      margin: 1,
      color: { dark: '#111827', light: '#ffffff' },
    })
  } catch {
    qrDataUrl.value = ''
  }
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: auth } = await authUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }

    const { data: studentProfile, error: profileError } = await supabase
      .from('student_profiles')
      .select('student_id, osas_verified_at')
      .eq('user_id', user.id)
      .maybeSingle()
    if (profileError) throw profileError

    studentId.value = studentProfile?.student_id || ''
    osasVerified.value = !!studentProfile?.osas_verified_at
    qrDataUrl.value = ''
    if (osasVerified.value && studentId.value) {
      await refreshToken()
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void load()
})
</script>

<style scoped>
.qr-timer {
  position: relative;
  display: grid;
  width: 44px;
  height: 44px;
  margin: 4px auto 0;
  place-items: center;
}
.qr-ring {
  position: absolute;
  inset: 0;
  transform: rotate(-90deg);
}
.qr-ring circle {
  fill: none;
  stroke-width: 3;
}
.qr-ring-track { stroke: var(--m-border); }
/* The line runs round once per code and empties as the time runs out. */
.qr-ring-sweep {
  stroke: var(--m-primary);
  stroke-linecap: round;
  stroke-dasharray: 100;
  animation: qr-sweep linear forwards;
}
@keyframes qr-sweep {
  from { stroke-dashoffset: 0; }
  to { stroke-dashoffset: 100; }
}
.qr-timer-num {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.qr-note {
  margin: 6px 14px 0;
  color: var(--m-muted);
  font-size: 11px;
  line-height: 1.4;
  text-align: center;
}
.qr-page {
  background: var(--m-bg);
  padding-bottom: 24px;
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 12px var(--m-page-gutter) 40px;
}
.sk-card {
  padding: 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.card {
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.card--pad {
  padding: 18px 14px;
}



.qr-card {
  padding: 20px 16px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}
.qr-locked {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 12px 0 4px;
}
.qr-locked-icon {
  display: grid;
  width: 52px;
  height: 52px;
  margin-bottom: 12px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
}
.qr-locked-title {
  margin: 0;
  font-size: 15px;
  font-weight: 700;
  color: var(--m-ink);
}
.qr-locked-sub {
  margin: 6px 0 16px;
  font-size: 13px;
  color: var(--m-muted);
  line-height: 1.4;
}
.qr-locked-cta {
  width: 100%;
  min-height: 44px;
  border-radius: var(--m-radius-sm);
  font-weight: 700;
}
.qr-header {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-bottom: 4px;
}
.qr-header-icon {
  color: var(--m-primary);
}
.qr-title {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  color: var(--m-ink);
}
.qr-sub {
  margin: 4px 0 16px;
  font-size: 13px;
  color: var(--m-muted);
  line-height: 1.4;
}
.qr-image-wrapper {
  display: flex;
  justify-content: center;
  padding: 8px;
  background: #fff;
  border-radius: var(--m-radius-sm);
  border: 1px solid var(--m-border);
  margin-bottom: 8px;
}
.qr-image {
  display: block;
  width: 220px;
  height: 220px;
  object-fit: contain;
}
.qr-id {
  font-size: 12px;
  font-weight: 500;
  color: var(--m-muted);
  margin: 0 0 16px;
  word-break: break-all;
  background: var(--m-bg);
  padding: 4px 8px;
  border-radius: 4px;
  display: inline-block;
}
</style>
