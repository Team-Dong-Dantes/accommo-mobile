<template>
  <q-card class="email-otp surface">
    <q-card-section class="otp-pad">
      <div class="otp-head">
        <span class="otp-icon" aria-hidden="true"><IconifyIcon icon="lucide:mail-check" width="20" /></span>
        <div>
          <h2>Confirm your e-mail</h2>
          <p>We sent a one-time code to <strong>{{ mask(email) }}</strong>. It’s the extra check for accounts created with e-mail + password.</p>
        </div>
      </div>

      <div v-if="!sent" class="otp-idle">
        <q-btn unelevated no-caps color="primary" class="otp-go" :loading="sending" @click="send">
          Send me the code
        </q-btn>
      </div>

      <template v-else>
        <div class="otp-code">
          <q-input
            v-model="code"
            outlined
            dense
            maxlength="8"
            inputmode="numeric"
            placeholder="Enter the code"
            class="otp-input"
            autocomplete="one-time-code"
            :disable="busy"
            @keyup.enter="verify"
          />
          <q-btn unelevated no-caps color="primary" class="otp-verify" :loading="busy" :disable="!codeOk" @click="verify">
            Verify
          </q-btn>
        </div>

        <p v-if="errorText" class="otp-error">{{ errorText }}</p>

        <button type="button" class="otp-resend" :disabled="busy || !canResend" @click="resend">
          <span v-if="!canResend">Didn’t receive it? Resend in {{ countdownSeconds }}s</span>
          <span v-else>Didn’t receive it? Resend code</span>
        </button>
      </template>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useAuthStore } from '@/stores/auth'

const props = defineProps<{ email: string }>()
const emit = defineEmits<{ verified: [] }>()

const auth = useAuthStore()
const sent = ref(false)
const sending = ref(false)
const busy = ref(false)
const errorText = ref('')
const code = ref('')
const canResend = ref(true)
const countdownSeconds = ref(0)
let timerId: number | null = null

const codeOk = computed(() => code.value.length >= 6 && code.value.length <= 8)

function mask(e: string): string {
  if (!e) return ''
  const at = e.indexOf('@')
  if (at < 0) return e
  const local = e.slice(0, at)
  const head = local.slice(0, Math.min(2, local.length))
  return local.length <= 2 ? head : `${head}${'•'.repeat(Math.max(1, local.length - 2))}`
}

function beginCountdown() {
  canResend.value = false
  countdownSeconds.value = 60 // Supabase rate limit is 60s
  if (timerId) window.clearInterval(timerId)
  timerId = window.setInterval(() => {
    if (countdownSeconds.value > 1) {
      countdownSeconds.value--
    } else {
      canResend.value = true
      countdownSeconds.value = 0
      if (timerId) {
        window.clearInterval(timerId)
        timerId = null
      }
    }
  }, 1000)
}

onUnmounted(() => {
  if (timerId) window.clearInterval(timerId)
})

async function send() {
  errorText.value = ''
  sending.value = true
  try {
    await auth.sendEmailOtp(props.email)
    sent.value = true
    beginCountdown()
  } catch (err) {
    errorText.value = err instanceof Error ? err.message : 'Could not send the code.'
  } finally {
    sending.value = false
  }
}

async function resend() {
  if (!canResend.value) return
  errorText.value = ''
  sending.value = true
  try {
    await auth.sendEmailOtp(props.email)
    beginCountdown()
  } catch (err) {
    errorText.value = err instanceof Error ? err.message : 'Could not resend the code.'
  } finally {
    sending.value = false
  }
}

async function verify() {
  if (!codeOk.value) return
  errorText.value = ''
  busy.value = true
  try {
    await auth.verifyEmailOtp(props.email, code.value)
    emit('verified')
  } catch (err) {
    errorText.value = err instanceof Error ? err.message : 'That code didn’t work. Check it and try again.'
  } finally {
    busy.value = false
  }
}

onMounted(() => {
  void send()
})
</script>

<style scoped>
.surface { border: 1px solid var(--m-border, #e5e7eb); border-radius: 16px; background: #fff; }
.email-otp { max-width: 460px; margin: 0 auto; }
.otp-pad { padding: 20px; }
.otp-head { display: flex; align-items: flex-start; gap: 12px; }
.otp-icon { display: grid; width: 40px; height: 40px; flex: 0 0 auto; place-items: center; border-radius: 10px; background: #e6f5f3; color: #00695c; }
.otp-head h2 { margin: 0 0 4px; color: #17202a; font-family: var(--m-font-display, 'Space Grotesk', sans-serif); font-size: 17px; font-weight: 700; }
.otp-head p { margin: 0; color: #6b7280; font-size: 13px; line-height: 1.5; text-align: left; }
.otp-idle, .otp-code { margin-top: 16px; display: flex; gap: 8px; }
.otp-go, .otp-verify { min-width: 130px; border-radius: 10px; }
.otp-go, .otp-verify { background: #00695c; }
.otp-input { flex: 1; text-align: center; letter-spacing: 6px; }
.otp-error { margin: 10px 0 0; color: #b42318; font-size: 12px; }
.otp-resend { display: block; margin: 12px 0 0; padding: 0; border: 0; background: transparent; color: #00695c; cursor: pointer; font: inherit; font-size: 13px; font-weight: 700; }
.otp-resend:disabled { opacity: 0.5; cursor: default; }
</style>
