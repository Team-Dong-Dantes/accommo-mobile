<template>
  <q-page class="settings-page">
    <div v-if="loading" class="stack">
      <div class="sk-card">
        <q-skeleton type="text" width="30%" height="13px" />
        <q-skeleton type="text" width="90%" height="44px" />
        <q-skeleton type="text" width="90%" height="44px" />
        <q-skeleton type="text" width="90%" height="44px" />
      </div>
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card card--pad text-center">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load settings</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <div v-else class="stack">
      <ProfileSettingsSection :user-id="userId" :email="email" :notification-prefs="notificationPrefs" />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import ProfileSettingsSection from '@/components/student/ProfileSettingsSection.vue'

const router = useRouter()

const loading = ref(true)
const error = ref('')
const userId = ref('')
const email = ref('')
const notificationPrefs = reactive({ push: true, email: true })

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
    userId.value = user.id

    const { data: profile, error: profileError } = await supabase
      .from('users')
      .select('email, notification_prefs')
      .eq('id', user.id)
      .maybeSingle()
    if (profileError) throw profileError

    email.value = profile?.email || user.email || ''
    const prefs = (profile?.notification_prefs ?? null) as { push?: boolean; email?: boolean } | null
    notificationPrefs.push = prefs?.push ?? true
    notificationPrefs.email = prefs?.email ?? true
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.settings-page {
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
  display: flex;
  flex-direction: column;
  gap: 12px;
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
</style>
