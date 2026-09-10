<template>
  <q-page class="qr-page">
    <div v-if="loading" class="stack">
      <div class="sk-card">
        <q-skeleton type="rect" width="220px" height="220px" class="q-mx-auto" />
      </div>
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card card--pad text-center">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your QR</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
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
          <p class="qr-expiry" :class="{ 'qr-expiry--soon': secondsLeft <= 300 }">
            <IconifyIcon icon="lucide:timer" width="13" />
            {{ secondsLeft > 0 ? `Changes in ${clock}` : 'Refreshing…' }}
          </p>
          <p class="qr-note">
            This code changes every hour and stops working when it does, so an old screenshot
            is useless to anyone else. Replace it now if you think it has been shared.
          </p>
          <div class="qr-actions">
            <button type="button" class="qr-save" :disabled="saving" @click="saveQR">
              <IconifyIcon :icon="canShare ? 'lucide:share' : 'lucide:download'" width="17" />
              {{ saving ? 'Preparing…' : canShare ? 'Save or share' : 'Save image' }}
            </button>
            <button type="button" class="qr-replace" :disabled="rotating || cooldown > 0" @click="rotate">
              <IconifyIcon icon="lucide:refresh-cw" width="14" />
              {{ cooldown > 0 ? `Replace in ${cooldown}s` : rotating ? 'Replacing…' : 'Replace code' }}
            </button>
          </div>
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
import { computed, ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import QRCode from 'qrcode'
import { supabase, authUser } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'

const router = useRouter()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const studentId = ref('')
const osasVerified = ref(false)
const qrDataUrl = ref('')
const qrToken = ref('')
const expiresAt = ref<string | null>(null)
const secondsLeft = ref(0)
const rotating = ref(false)
const saving = ref(false)
const cooldown = ref(0)
let cooldownTimer: ReturnType<typeof setInterval> | null = null

// Sharing hands the image to the OS sheet — Photos, Files, Messages — which is
// the only route that works inside the app's webview. A plain <a download> is
// inert there, and silently did nothing on the very devices students use.
const canShare = computed(
  () => typeof navigator !== 'undefined' && typeof navigator.canShare === 'function',
)

// mm:ss for the countdown under the code.
const clock = computed(() => {
  const m = Math.floor(secondsLeft.value / 60)
  const sec = secondsLeft.value % 60
  return `${m}:${String(sec).padStart(2, '0')}`
})

let tickTimer: ReturnType<typeof setInterval> | null = null

/**
 * The code lives for an hour and then stops working, so the screen keeps its
 * own clock: at zero it asks for a fresh one rather than showing a QR that a
 * scanner will now refuse.
 */
function watchExpiry() {
  if (tickTimer) clearInterval(tickTimer)
  const tick = () => {
    const end = expiresAt.value ? new Date(expiresAt.value).getTime() : 0
    secondsLeft.value = Math.max(0, Math.round((end - Date.now()) / 1000))
    if (secondsLeft.value === 0) {
      if (tickTimer) clearInterval(tickTimer)
      tickTimer = null
      void refreshToken()
    }
  }
  tick()
  tickTimer = setInterval(tick, 1000)
}

async function refreshToken() {
  const { data, error: tokenError } = await supabase.rpc('current_qr_token')
  if (tokenError) throw tokenError
  const row = Array.isArray(data) ? data[0] : data
  qrToken.value = String(row?.token ?? '')
  expiresAt.value = (row?.expires_at as string) ?? null
  await generateQr()
  watchExpiry()
}

function startCooldown(seconds: number) {
  cooldown.value = seconds
  if (cooldownTimer) clearInterval(cooldownTimer)
  cooldownTimer = setInterval(() => {
    cooldown.value -= 1
    if (cooldown.value <= 0 && cooldownTimer) {
      clearInterval(cooldownTimer)
      cooldownTimer = null
    }
  }, 1000)
}

onUnmounted(() => {
  if (cooldownTimer) clearInterval(cooldownTimer)
  if (tickTimer) clearInterval(tickTimer)
})

async function qrFile(): Promise<File | null> {
  if (!qrDataUrl.value) return null
  const blob = await (await fetch(qrDataUrl.value)).blob()
  return new File([blob], `accommo-qr-${studentId.value || 'student'}.png`, { type: 'image/png' })
}

function go(path: string) {
  void router.push(path)
}

async function generateQr() {
  // The code carries the rotatable token, never the student number: a student
  // number is public enough to guess, and a QR built from one proves nothing.
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

async function saveQR() {
  if (!qrDataUrl.value || saving.value) return
  saving.value = true
  try {
    const file = await qrFile()
    if (file && navigator.canShare?.({ files: [file] })) {
      await navigator.share({ files: [file], title: 'My student QR' })
      return
    }
    // Desktop browser: a download link still works there.
    const link = document.createElement('a')
    link.href = qrDataUrl.value
    link.download = `accommo-qr-${studentId.value || 'student'}.png`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    notify.success('QR code saved.')
  } catch (e) {
    // A cancelled share sheet is not a failure.
    if (e instanceof DOMException && e.name === 'AbortError') return
    notify.error('Could not save the image. Press and hold the code to save it instead.')
  } finally {
    saving.value = false
  }
}

async function rotate() {
  rotating.value = true
  try {
    const { data, error: rotateError } = await supabase.rpc('rotate_qr_token')
    if (rotateError) throw rotateError
    qrToken.value = String(data ?? '')
    await refreshToken()
    startCooldown(60)
    notify.success('New code generated. The old one no longer works.')
  } catch (e) {
    const message = e instanceof Error ? e.message : 'Could not replace your code.'
    // The server owns the cooldown; mirror whatever it says is left.
    const left = Number(/in (\d+) second/.exec(message)?.[1] ?? 0)
    if (left > 0) startCooldown(left)
    notify.warning(message)
  } finally {
    rotating.value = false
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

onMounted(load)
</script>

<style scoped>
.qr-expiry {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  margin: 8px 0 0;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
}
.qr-expiry--soon { color: var(--m-warning); }
.qr-actions {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-top: 14px;
  padding: 0 14px;
}
.qr-save {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  padding: 12px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  cursor: pointer;
}
.qr-save:disabled { opacity: 0.6; cursor: default; }
.qr-replace {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 9px;
  border: 0;
  background: none;
  color: var(--m-muted);
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  cursor: pointer;
}
.qr-replace:disabled { opacity: 0.55; cursor: default; }
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
.err-title {
  margin: 8px 0 0;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.err-sub {
  margin: 2px 0 0;
  color: var(--m-muted);
  font-size: 12px;
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
