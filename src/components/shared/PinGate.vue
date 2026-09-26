<template>
  <!-- Mounted once in MainLayout. One component, three shapes: a floating card
       centred over a dimmed backdrop for an action, the same card asking in
       words when the account has no PIN to ask for, and — for the resume lock —
       a full screen built to mirror the login page, because that is what it is:
       a sign-back-in moment. The lock has no way out but the PIN or a completed
       reset, which is the point of it. -->
  <div v-if="prompt" class="gate" :class="{ 'gate--lock': isLock }">
    <div v-if="!isLock" class="gate-backdrop" @click="cancel" />

    <!-- AuthLayout's hero, rebuilt here rather than reused: the lock is mounted
         in MainLayout, which is the other layout entirely, so it cannot render
         into AuthLayout. Every number below is copied from `.hero-section` /
         `.hero-content` so the two screens line up pixel for pixel. -->
    <div v-if="isLock" class="lock-hero" :style="{ '--hero-bg': `url(${EXTERNAL_URLS.ISU_BACKGROUND})` }">
      <div class="lock-hero-overlay">
        <div class="lock-hero-content">
          <div class="lock-logo">accommo</div>
          <div class="lock-tagline">Verified boarding houses · ISU Echague</div>
        </div>
      </div>
    </div>

    <div class="gate-card" :class="{ 'gate-card--lock': isLock }">
      <div class="gate-head">
        <span v-if="!isLock" class="gate-icon">
          <IconifyIcon :icon="prompt.mode === 'confirm' ? 'lucide:help-circle' : 'lucide:lock'" width="18" />
        </span>
        <h3 class="gate-title">{{ prompt.title }}</h3>
        <p v-if="prompt.message" class="gate-message">{{ prompt.message }}</p>
      </div>

      <!-- Shared with the register form's PIN screen, so the lock and the place
           the PIN is chosen cannot drift into two different ideas of what
           entering one looks like. PinCells owns the boxes, the hidden input and
           the digits-only rule; what a full PIN means stays here. -->
      <PinCells
        v-if="prompt.mode !== 'confirm'"
        ref="field"
        v-model="code"
        class="gate-cells"
        :length="LENGTH"
        :disabled="busy"
        :invalid="shake"
        :large="isLock"
      />

      <p v-if="error" class="gate-error">{{ error }}</p>

      <!-- On the lock, the only way out is the reset — a text link in the same
           place the login screen keeps "Forgot password?". -->
      <div v-if="isLock" class="lock-actions">
        <button type="button" class="lock-forgot" :disabled="busy" @click="onForgot">
          Forgot your PIN?
        </button>
      </div>

      <div v-else class="gate-actions">
        <button type="button" class="gate-ghost" :disabled="busy" @click="cancel">
          Cancel
        </button>
        <button v-if="prompt.mode === 'confirm'" type="button" class="gate-primary" @click="settlePin(true)">
          Confirm
        </button>
        <button v-else type="button" class="gate-ghost" :disabled="busy" @click="emit('forgot')">
          Forgot your PIN?
        </button>
      </div>
    </div>

    <!-- Resetting from the lock happens in place. The PIN and the account
         password are separate layers, so forgetting the PIN must not cost the
         user their session: PinSetupDialog's 'forgot' mode proves ownership
         through the mailbox instead, and never asks for the password. -->
    <PinSetupDialog
      v-model="resetOpen"
      mode="forgot"
      :email="email"
      class="pin-reset-over-lock"
      @done="onResetDone"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch, nextTick } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { usePinStore } from '@/stores/pin'
import { prompt, settlePin } from '@/utils/requirePin'
import { errorMessage } from '@/utils/errors'
import { EXTERNAL_URLS } from '@/utils/config'
import { authUser } from '@/utils/supabase'
import PinSetupDialog from '@/components/shared/PinSetupDialog.vue'
import PinCells from '@/components/shared/PinCells.vue'

const LENGTH = 6

const emit = defineEmits<{ forgot: [] }>()

const pin = usePinStore()
const code = ref('')
const error = ref('')
const busy = ref(false)
const shake = ref(false)
const field = ref<InstanceType<typeof PinCells> | null>(null)
const resetOpen = ref(false)
const email = ref('')

const isLock = computed(() => prompt.value?.mode === 'lock')

watch(prompt, async (next) => {
  if (!next) return
  code.value = ''
  error.value = ''
  await nextTick()
  field.value?.focus()
})

// PinCells keeps the value to digits and to LENGTH, so all that is left here is
// what a complete PIN *means*: clear the last error, and verify once it is full.
watch(code, (value) => {
  error.value = ''
  if (value.length === LENGTH) void submit()
})

async function submit() {
  if (busy.value) return
  busy.value = true
  try {
    if (await pin.verify(code.value)) {
      settlePin(true)
      return
    }
    // Wrong: clear and stay put. The server is counting attempts and will lock
    // the account itself, so there is nothing to enforce here.
    error.value = 'Incorrect PIN.'
    shake.value = true
    setTimeout(() => (shake.value = false), 400)
    code.value = ''
    field.value?.focus()
  } catch (e) {
    // A lockout arrives as a thrown error carrying the time it lifts.
    error.value = errorMessage(e, 'Could not check that PIN.')
    code.value = ''
  } finally {
    busy.value = false
  }
}

/**
 * From the lock there is nowhere to navigate to — Settings is behind the very
 * cover being shown — so the reset opens here. From an action prompt the user is
 * already inside and unlocked, so the shell routes them to Settings as before.
 */
async function onForgot() {
  if (!isLock.value) {
    emit('forgot')
    return
  }
  const { data } = await authUser()
  email.value = data?.user?.email ?? ''
  resetOpen.value = true
}

function onResetDone() {
  resetOpen.value = false
  // They proved the mailbox is theirs and set a new PIN — a stronger claim than
  // typing the old one — so the cover comes off. PinSetupDialog has already
  // updated the store, so there is nothing to re-fetch.
  settlePin(true)
}

function cancel() {
  if (busy.value || isLock.value) return
  settlePin(false)
}
</script>

<style scoped>
/* A floating card in the middle of the screen, not a bottom sheet: this is a
   stop-and-answer moment, so it sits where the eye already is rather than
   sliding up from the thumb rail like the routine sheets do. */
.gate {
  position: fixed;
  inset: 0;
  /* Above Quasar's dialog layer (6000) and anything stacked just over it.
     At a lower value the gate opened UNDERNEATH an open q-dialog — the leave
     confirmation, the decline-reason sheet, the delete confirmations — so the
     button appeared to do nothing at all. Deliberately below Notify (9500), so
     an error toast still lands on top of the card. */
  z-index: 8000;
  display: grid;
  place-items: center;
  padding: var(--m-page-gutter);
}
/* The lock is a screen, not a card: hero photo on top, sheet below, exactly the
   shape of the login page it stands in for. This element plays AuthLayout's
   `.content-wrapper` — it scrolls while the hero behind it stays fixed — and
   carries LoginPage's own 150px top inset. */
.gate--lock {
  display: block;
  padding: 150px 0 0;
  overflow-x: hidden;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
  overscroll-behavior-y: contain;
  background: var(--m-bg);
}
.gate-backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.45);
}

/* Copied from AuthLayout's `.hero-section` in its login state: the same crop of
   the same photo under the same teal wash, so unlocking and signing in are the
   same picture. Fixed, so the sheet scrolls over it exactly as login's does. */
.lock-hero {
  position: fixed;
  top: -80px;
  left: 0;
  z-index: 1;
  width: 100%;
  height: 400px;
  /* Brand ground under the photo: a lock screen that cannot be dismissed is
     the worst place for a blank frame. */
  background-color: var(--m-primary-dark);
  background-image: var(--hero-bg);
  background-position: 46% center;
  background-size: cover;
  pointer-events: none;
}
/* Copied from AuthLayout's `.hero-overlay` in its login state. The two must
   stay identical — that is the whole premise of this screen. */
.lock-hero-overlay {
  position: relative;
  height: 100%;
  background:
    linear-gradient(
      180deg,
      rgba(0, 44, 37, 0.74) 0%,
      rgba(0, 44, 37, 0.52) 34%,
      rgba(0, 44, 37, 0.34) 62%,
      rgba(0, 44, 37, 0.26) 100%
    ),
    linear-gradient(135deg, rgba(0, 150, 136, 0.52), rgba(0, 121, 107, 0.4));
}
.lock-hero-content {
  position: absolute;
  top: 120px;
  left: 0;
  width: 100%;
  padding: 0 24px;
  color: #fff;
}
.lock-logo {
  /* No display font here: AuthLayout's wordmark is a div, so it rides the
     body face. Setting one made the lock's logo a different typeface. */
  font-size: 38px;
  font-weight: 700;
  line-height: 1;
}
.lock-tagline {
  font-size: 14px;
  opacity: 0.95;
}

@media (max-height: 600px) {
  .lock-hero { height: 300px; }
  .lock-hero-content { top: 60px; }
}

.gate-card {
  position: relative;
  display: flex;
  width: 100%;
  max-width: 340px;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 22px 20px 18px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-lg);
  background: var(--m-surface);
  box-shadow: 0 18px 48px rgba(15, 23, 42, 0.22);
  text-align: center;
}
/* LoginPage's `.login-container`, rule for rule: full width, 28px top corners,
   24px padding, left-aligned copy, filling the screen below the hero. (dvh
   rather than vh — the address bar makes vh overshoot on a phone, which is the
   one place this screen ever appears.) */
.gate-card--lock {
  z-index: 10;
  max-width: none;
  min-height: calc(100vh - 150px);
  min-height: calc(100dvh - 150px);
  align-items: stretch;
  gap: 0;
  padding: 24px;
  border: 0;
  border-radius: 28px 28px 0 0;
  box-shadow: none;
  text-align: left;
}

.gate-head {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}
.gate-card--lock .gate-head {
  align-items: stretch;
  gap: 0;
}
.gate-icon {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.gate-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
}
/* The login screen's welcome-title scale. */
.gate-card--lock .gate-title {
  font-size: 34px;
}
.gate-message {
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
}
.gate-card--lock .gate-message {
  margin-top: 6px;
  font-size: 14px;
}

/* Only the spacing around the shared PinCells row — the six boxes, the hidden
   input and the shake all live in that component now. On the lock the row is
   left-aligned and sits 24px below the subtitle, the same air login leaves above
   its first field. */
.gate-cells {
  padding: 14px 0 6px;
}
.gate-card--lock .gate-cells {
  justify-content: flex-start;
  padding-top: 24px;
}

.gate-error {
  margin: 0;
  color: var(--m-danger);
  font-size: 12.5px;
  text-align: center;
}
.gate-card--lock .gate-error {
  margin-top: 10px;
  text-align: left;
}

/* Where the login screen keeps "Forgot password?". */
.lock-actions {
  display: flex;
  justify-content: flex-end;
  margin-top: 10px;
}
.lock-forgot {
  padding: 6px 2px;
  border: 0;
  background: none;
  color: var(--m-primary);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 600;
  -webkit-tap-highlight-color: transparent;
}
.lock-forgot:disabled {
  opacity: 0.6;
}

.gate-actions {
  display: flex;
  justify-content: center;
  gap: 8px;
}
.gate-ghost {
  min-height: 42px;
  padding: 0 18px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.gate-primary {
  min-height: 42px;
  padding: 0 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.gate-ghost:disabled {
  opacity: 0.6;
}
</style>

<style>
/* QDialog portals to <body>, so this cannot be scoped. The gate sits at 8000;
   without this the reset sheet would open UNDERNEATH the very lock it is meant
   to clear — the same trap documented on `.gate` above. Still below Notify
   (9500) so its error toasts land on top. */
.pin-reset-over-lock {
  z-index: 8500;
}
</style>
