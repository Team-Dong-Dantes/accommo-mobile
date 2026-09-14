<template>
  <section class="settings">
    <div class="settings-group">
      <p class="settings-group-label">Account</p>
      <SettingsRow icon="lucide:mail" label="Email">
        <template #trailing>
          <span class="settings-static">{{ email }}</span>
        </template>
      </SettingsRow>
      <SettingsRow icon="lucide:repeat" label="Change email" @click="openAccountChange('email')" />
      <SettingsRow icon="lucide:lock" label="Change password" @click="openAccountChange('password')" />
      <SettingsRow icon="lucide:chrome" label="Google account">
        <template #trailing>
          <span class="settings-static">{{ googleLinked ? 'Connected' : 'Not linked' }}</span>
        </template>
      </SettingsRow>
    </div>

    <div class="settings-group">
      <p class="settings-group-label">Security</p>
      <SettingsRow v-if="!pin.hasPin" icon="lucide:shield" label="Set a PIN" @click="openPinSetup('set')" />
      <SettingsRow v-else icon="lucide:help-circle" label="Forgot your PIN?" @click="openPinSetup('forgot')" />
      <SettingsRow v-if="pin.hasPin" icon="lucide:lock-open" label="Turn off PIN" @click="openPinSetup('off')" />
    </div>
    <div class="settings-group">
      <p class="settings-group-label">Activity</p>
      <SettingsRow icon="lucide:clock" label="History" @click="go('/manager/profile/history')" />
    </div>

    <div class="settings-group">
      <p class="settings-group-label">Notifications</p>
      <SettingsRow icon="lucide:bell" label="Push notifications">
        <template #trailing>
          <q-toggle v-model="prefs.push" color="primary" dense @update:model-value="savePrefs" />
        </template>
      </SettingsRow>
      <SettingsRow icon="lucide:mail-open" label="Email notifications">
        <template #trailing>
          <q-toggle v-model="prefs.email" color="primary" dense @update:model-value="savePrefs" />
        </template>
      </SettingsRow>
    </div>

    <div class="settings-group">
      <p class="settings-group-label">Appearance</p>
      <SettingsRow icon="lucide:moon" label="Dark mode">
        <template #trailing>
          <q-toggle v-model="darkMode" color="primary" dense @update:model-value="onToggleDark" />
        </template>
      </SettingsRow>
    </div>

    <div class="settings-group">
      <p class="settings-group-label">Support</p>
      <SettingsRow icon="lucide:shield-check" label="OSAS" @click="go('/manager/osas')" />
      <SettingsRow icon="lucide:message-square-warning" label="Concerns" @click="go('/manager/support')" />
    </div>

    <div class="settings-group">
      <p class="settings-group-label">About</p>
      <SettingsRow icon="lucide:scroll-text" label="Policies &amp; guidelines" @click="go('/manager/settings/policies')" />
      <SettingsRow icon="lucide:info" label="App version">
        <template #trailing>
          <span class="settings-static">{{ appVersion }}</span>
        </template>
      </SettingsRow>
    </div>

    <div class="settings-group">
      <SettingsRow icon="lucide:log-out" label="Sign out" danger @click="signOut" />
    </div>

    <ChangePasswordDialog v-model="passwordOpen" />
    <ChangeEmailDialog v-model="emailOpen" />
    <PinSetupDialog v-model="pinSetupOpen" :mode="pinSetupMode" :email="email" />
  </section>
</template>

<script setup lang="ts">
import { reactive, ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase, authUser } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'
import { requirePin } from '@/utils/requirePin'
import PinSetupDialog from '@/components/shared/PinSetupDialog.vue'
import { usePinStore } from '@/stores/pin'
import { getStoredTheme, setStoredTheme } from '@/utils/theme'
import { APP_VERSION, getAppVersion } from '@/utils/config'
import SettingsRow from '@/components/shared/SettingsRow.vue'
import ChangePasswordDialog from '@/components/shared/ChangePasswordDialog.vue'
import ChangeEmailDialog from '@/components/shared/ChangeEmailDialog.vue'

const props = defineProps<{
  userId: string
  email: string
  notificationPrefs: { push: boolean; email: boolean }
}>()

const router = useRouter()
const notify = useNotify()

const appVersion = ref(APP_VERSION)
const passwordOpen = ref(false)
const emailOpen = ref(false)
const googleLinked = ref(false)
const darkMode = ref(getStoredTheme() === 'dark')
const prefs = reactive({ ...props.notificationPrefs })

function go(path: string) {
  void router.push(path)
}

function onToggleDark(value: boolean) {
  setStoredTheme(value ? 'dark' : 'light')
}

async function savePrefs() {
  const { error } = await supabase
    .from('users')
    .update({ notification_prefs: { push: prefs.push, email: prefs.email } })
    .eq('id', props.userId)
  if (error) notify.error('Could not save notification preferences.')
}

async function signOut() {
  await supabase.auth.signOut()
  void router.push('/login')
}

onMounted(async () => {
  // The bundled constant is only a fallback; show what is actually installed.
  appVersion.value = await getAppVersion()
  const { data } = await authUser()
  const identities = data.user?.identities ?? []
  googleLinked.value = identities.some((i) => i.provider === 'google')
})

// Changing an e-mail or password is the only thing here nobody can undo, so
// it always asks: the 'always' option skips the grace window even if the PIN
// was entered a minute ago for something else.
async function openAccountChange(which: 'email' | 'password') {
  const label = which === 'email' ? 'Change your e-mail?' : 'Change your password?'
  if (!(await requirePin({ always: true, title: label }))) return
  if (which === 'email') emailOpen.value = true
  else passwordOpen.value = true
}

const pin = usePinStore()
const pinSetupOpen = ref(false)
const pinSetupMode = ref<'set' | 'forgot' | 'off'>('set')

function openPinSetup(mode: 'set' | 'forgot' | 'off') {
  pinSetupMode.value = mode
  pinSetupOpen.value = true
}

</script>

<style scoped>
.settings-group {
  margin-top: var(--m-space-5);
}
.settings-group-label {
  margin: 0 0 var(--m-space-1);
  padding: 0 2px;
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.settings-static {
  color: var(--m-muted);
  font-size: 13px;
  font-weight: 600;
}
</style>
