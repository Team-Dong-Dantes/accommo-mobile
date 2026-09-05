<template>
  <section class="settings">
    <h2 class="settings-title">Settings</h2>

    <div class="settings-group">
      <p class="settings-group-label">Account</p>
      <SettingsRow icon="lucide:mail" label="Email">
        <template #trailing>
          <span class="settings-static">{{ email }}</span>
        </template>
      </SettingsRow>
      <SettingsRow icon="lucide:repeat" label="Change email" @click="emailOpen = true" />
      <SettingsRow icon="lucide:lock" label="Change password" @click="passwordOpen = true" />
      <SettingsRow icon="lucide:chrome" label="Google account">
        <template #trailing>
          <span class="settings-static">{{ googleLinked ? 'Connected' : 'Not linked' }}</span>
        </template>
      </SettingsRow>
    </div>

    <div class="settings-group">
      <p class="settings-group-label">Activity</p>
      <SettingsRow icon="lucide:clock" label="History" @click="go('/student/profile/history')" />
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
      <SettingsRow icon="lucide:shield-check" label="OSAS &amp; support" @click="go('/student/support')" />
      <SettingsRow icon="lucide:message-square-warning" label="Concerns" @click="go('/student/concerns')" />
      <SettingsRow icon="lucide:wallet-cards" label="Payments" @click="go('/student/payments')" />
    </div>

    <div class="settings-group">
      <p class="settings-group-label">About</p>
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
  </section>
</template>

<script setup lang="ts">
import { reactive, ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'
import { getStoredTheme, setStoredTheme } from '@/utils/theme'
import { APP_VERSION } from '@/utils/config'
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

const appVersion = APP_VERSION
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
  const { data } = await supabase.auth.getUser()
  const identities = data.user?.identities ?? []
  googleLinked.value = identities.some((i) => i.provider === 'google')
})
</script>

<style scoped>
.settings-title {
  margin: 0 0 4px;
  padding: 0 2px;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15px;
  font-weight: 700;
}
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
