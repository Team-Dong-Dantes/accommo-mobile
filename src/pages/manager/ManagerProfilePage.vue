<template>
  <q-page class="prof">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="118px" class="sk" />
      <q-skeleton type="rect" height="150px" class="sk" />
      <q-skeleton type="rect" height="120px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card card--pad text-center">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your profile</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn
          unelevated
          rounded
          no-caps
          dense
          color="primary"
          label="Try again"
          class="q-mt-sm q-px-md"
          @click="load"
        />
      </q-card>
    </div>

    <div v-else class="stack">
      <!-- Who you are, and the portfolio that proves it -->
      <div class="hero">
        <div class="hero-top">
          <span class="hero-avatar" @click="openAvatarPicker">
            <img v-if="avatarUrl" :src="avatarUrl" alt="Avatar" />
            <span v-else>{{ me.initials }}</span>
            <span class="avatar-overlay">
              <IconifyIcon icon="lucide:camera" width="14" />
            </span>
          </span>
          <input
            ref="avatarInput"
            type="file"
            accept="image/*"
            class="hidden-input"
            @change="onAvatarSelected"
          />
          <span class="hero-id">
            <span class="hero-name">{{ me.fullName }}</span>
            <span class="hero-role">Accommodation manager</span>
          </span>
          <span class="hero-tag" :class="`hero-tag--${status.tone}`">{{ status.label }}</span>
        </div>
        <div class="hero-foot">
          <span>
            <b>{{ accommodationCount }}</b>
            {{ accommodationCount === 1 ? 'accommodation' : 'accommodations' }}
          </span>
          <span><b>{{ tenantCount }}</b> {{ tenantCount === 1 ? 'tenant' : 'tenants' }}</span>
          <span v-if="responseRate !== null"><b>{{ responseRate }}%</b> reply rate</span>
          <button type="button" class="qr-btn" @click="go('/manager/profile/qr-scanner')">
            <IconifyIcon icon="lucide:scan" width="16" />
            Scan QR
          </button>
        </div>
      </div>

      <!-- Details: read-only until Edit is pressed -->
      <section class="sec">
        <h2 class="sec-title">Your details</h2>
        <div class="group">
          <ProfileField v-model="draft.fullName" label="Full name" :editing="editing" />
          <ProfileField
            v-model="draft.phone"
            label="Phone"
            type="tel"
            :editing="editing"
            placeholder="+63…"
          />
          <ProfileField v-model="draft.email" label="Email" readonly :editing="editing" />
        </div>
      </section>

      <!-- Verification is OSAS's call, so it is never editable here -->
      <section class="sec">
        <h2 class="sec-title">
          Verification
          <span v-if="pendingDocs > 0" class="sec-badge">{{ pendingDocs }} pending</span>
        </h2>
        <div class="group">
          <div v-for="doc in documents" :key="doc.id" class="doc">
            <span class="doc-icon" :class="`doc-icon--${doc.tone}`">
              <IconifyIcon :icon="doc.icon" width="15" />
            </span>
            <span class="doc-body">
              <span class="doc-name">{{ doc.label }}</span>
              <span class="doc-when">{{ doc.when }}</span>
            </span>
            <span class="doc-tag" :class="`doc-tag--${doc.tone}`">{{ doc.statusLabel }}</span>
          </div>

          <p v-if="!documents.length" class="none">You haven't submitted any documents yet</p>

          <button type="button" class="row" @click="go('/manager/osas-compliance')">
            <span class="row-icon"><IconifyIcon icon="lucide:shield-check" width="16" /></span>
            <span class="row-label">Open OSAS compliance</span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="row-chev" />
          </button>
        </div>
      </section>

      <section class="sec">
        <div class="sec-head-with-action">
          <h2 class="sec-title">Your accommodations</h2>
          <button type="button" class="sec-add" @click="go('/manager/properties/new')">
            <IconifyIcon icon="lucide:plus" width="16" />
          </button>
        </div>
        <div class="group">
          <button type="button" class="row" @click="go('/manager/properties')">
            <span class="row-icon"><IconifyIcon icon="lucide:building-2" width="16" /></span>
            <span class="row-label">
              Manage {{ accommodationCount }}
              {{ accommodationCount === 1 ? 'accommodation' : 'accommodations' }}
            </span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="row-chev" />
          </button>
          <button type="button" class="row" @click="go('/manager/tenants')">
            <span class="row-icon"><IconifyIcon icon="lucide:users" width="16" /></span>
            <span class="row-label">
              {{ tenantCount }} active {{ tenantCount === 1 ? 'tenant' : 'tenants' }}
            </span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="row-chev" />
          </button>
        </div>
      </section>

      <section class="sec">
        <h2 class="sec-title">Settings</h2>
        <div class="group">
          <button type="button" class="row" @click="passwordOpen = true">
            <span class="row-icon"><IconifyIcon icon="lucide:lock" width="16" /></span>
            <span class="row-label">Change password</span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="row-chev" />
          </button>
          <button type="button" class="row row--danger" @click="signOut">
            <span class="row-icon row-icon--danger">
              <IconifyIcon icon="lucide:log-out" width="16" />
            </span>
            <span class="row-label">Sign out</span>
          </button>
        </div>
      </section>

      <button v-if="!editing" type="button" class="edit" @click="startEdit">
        <IconifyIcon icon="lucide:pencil" width="15" />
        Edit profile
      </button>

      <p class="since">
        Member since {{ memberSinceLabel }}
        <span v-if="updatedAt" class="updated">· Updated {{ ago(updatedAt) }}</span>
      </p>
    </div>

    <div v-if="editing" class="bar">
      <button type="button" class="bar-btn bar-btn--ghost" :disabled="saving" @click="cancelEdit">
        Cancel
      </button>
      <button type="button" class="bar-btn bar-btn--go" :disabled="saving" @click="save">
        {{ saving ? 'Saving…' : 'Save changes' }}
      </button>
    </div>

    <ChangePasswordDialog v-model="passwordOpen" />
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { initialsOf, normalizePhPhone } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { uploadAvatar } from '@/utils/upload'
import ProfileField from '@/components/shared/ProfileField.vue'
import ChangePasswordDialog from '@/components/shared/ChangePasswordDialog.vue'
import { DOC_LABEL, docPresentation, statusPresentation, memberSince, ago } from '@/utils/profile'

interface DocRow {
  id: string
  label: string
  statusLabel: string
  tone: string
  icon: string
  when: string
}

const router = useRouter()
const $q = useQuasar()

const loading = ref(true)
const saving = ref(false)
const error = ref('')
const editing = ref(false)
const passwordOpen = ref(false)

const userId = ref('')
const avatarUrl = ref<string | null>(null)
const avatarInput = ref<HTMLInputElement | null>(null)
const me = reactive({ fullName: '', email: '', phone: '', initials: '?', status: 'unverified' })
const draft = reactive({ fullName: '', phone: '', email: '' })

const createdAt = ref<string | null>(null)
const updatedAt = ref<string | null>(null)
const responseRate = ref<number | null>(null)
const accommodationCount = ref(0)
const tenantCount = ref(0)
const documents = ref<DocRow[]>([])

const status = computed(() => statusPresentation(me.status))
const memberSinceLabel = computed(() => memberSince(createdAt.value))
const pendingDocs = computed(() => documents.value.filter(d => d.tone === 'warn').length)

function go(path: string) {
  void router.push(path)
}

function openAvatarPicker() {
  avatarInput.value?.click()
}

async function onAvatarSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return

  try {
    const url = await uploadAvatar(file, userId.value)
    avatarUrl.value = url
    $q.notify({ type: 'positive', message: 'Avatar updated.' })
  } catch (e) {
    $q.notify({
      type: 'negative',
      message: e instanceof Error ? e.message : 'Could not upload avatar.',
    })
  }
  input.value = ''
}

function startEdit() {
  draft.fullName = me.fullName
  draft.phone = me.phone
  draft.email = me.email
  editing.value = true
}

function cancelEdit() {
  editing.value = false
}

async function save() {
  const name = draft.fullName.trim()
  if (!name) {
    $q.notify({ type: 'negative', message: 'Your name cannot be empty.' })
    return
  }

  saving.value = true
  try {
    const phone = normalizePhPhone(draft.phone)
    const initials = initialsOf(name)
    const { error: updateError } = await supabase
      .from('users')
      .update({ full_name: name, phone, initials })
      .eq('id', userId.value)
    if (updateError) throw updateError

    me.fullName = name
    me.phone = phone
    me.initials = initials
    updatedAt.value = new Date().toISOString()
    editing.value = false
    $q.notify({ type: 'positive', message: 'Profile updated.' })
  } catch (e) {
    $q.notify({ type: 'negative', message: e instanceof Error ? e.message : 'Could not save.' })
  } finally {
    saving.value = false
  }
}

async function signOut() {
  await supabase.auth.signOut()
  void router.push('/login')
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: auth } = await supabase.auth.getUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }
    userId.value = user.id

    const [{ data: profile, error: profileError }, { data: managerProfile }] = await Promise.all([
      supabase
        .from('users')
        .select('full_name, email, phone, initials, status, created_at, updated_at')
        .eq('id', user.id)
        .maybeSingle(),
      supabase
        .from('accommodation_manager_profiles')
        .select('response_rate')
        .eq('user_id', user.id)
        .maybeSingle(),
    ])
    if (profileError) throw profileError

    me.fullName = profile?.full_name || 'Your name'
    me.email = profile?.email || user.email || ''
    me.phone = profile?.phone || ''
    me.initials = profile?.initials || initialsOf(me.fullName)
    me.status = profile?.status || 'unverified'
    createdAt.value = profile?.created_at ?? null
    updatedAt.value = profile?.updated_at ?? null
    // No users.avatar_url column exists; the avatar lives on the auth user's
    // metadata, which is also where MainLayout reads it from.
    const metadata = user.user_metadata as Record<string, unknown> | undefined
    const picture =
      typeof metadata?.avatar_url === 'string'
        ? metadata.avatar_url
        : typeof metadata?.picture === 'string'
          ? metadata.picture
          : ''
    avatarUrl.value = picture ? resolveAsset(picture) : null
    responseRate.value = managerProfile?.response_rate ?? null

    Object.assign(draft, { fullName: me.fullName, phone: me.phone, email: me.email })

    const { data: accommodations } = await supabase
      .from('accommodations')
      .select('id')
      .eq('accommodation_manager_id', user.id)
    const accommodationIds = (accommodations || []).map((a) => a.id)
    accommodationCount.value = accommodationIds.length

    if (accommodationIds.length) {
      const { data: rooms } = await supabase
        .from('rooms')
        .select('id')
        .in('accommodation_id', accommodationIds)
      const roomIds = (rooms || []).map((r) => r.id)
      if (roomIds.length) {
        const { count } = await supabase
          .from('leases')
          .select('*', { count: 'exact', head: true })
          .in('room_id', roomIds)
          .eq('status', 'active')
        tenantCount.value = count ?? 0
      }
    }

    const { data: docs } = await supabase
      .from('verification_documents')
      .select('id, doc_type, status, uploaded_at, verified_at')
      .eq('user_id', user.id)
      .order('uploaded_at', { ascending: false })

    documents.value = (docs || []).map((d) => {
      const presentation = docPresentation(d.status)
      return {
        id: d.id,
        label: DOC_LABEL[d.doc_type || ''] || 'Document',
        statusLabel: presentation.label,
        tone: presentation.tone,
        icon: presentation.icon,
        when: d.verified_at ? `Reviewed ${ago(d.verified_at)}` : `Sent ${ago(d.uploaded_at)}`,
      }
    })
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.prof {
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 5px var(--m-page-gutter) 16px;
}
.sk {
  border-radius: var(--m-radius);
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

.hero {
  padding: 16px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  border: 1px solid var(--m-border);
}
.hero-top {
  display: flex;
  align-items: center;
  gap: 12px;
}
.hero-avatar {
  position: relative;
  display: flex;
  width: 52px;
  height: 52px;
  flex: 0 0 52px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font-size: 20px;
  font-weight: 700;
  cursor: pointer;
  overflow: hidden;
  transition: opacity 0.15s;
}
.hero-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.avatar-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.4);
  color: #fff;
  opacity: 0;
  transition: opacity 0.15s;
}
.hero-avatar:hover .avatar-overlay {
  opacity: 1;
}
.hidden-input {
  display: none;
}
.hero-id {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  min-width: 0;
}
.hero-name {
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
  color: var(--m-ink);
  line-height: 1.2;
}
.hero-role {
  font-size: 12px;
  color: var(--m-muted);
}
.hero-tag {
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  flex: 0 0 auto;
}
.hero-tag--good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.hero-tag--warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.hero-tag--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.hero-foot {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px 16px;
  margin-top: 10px;
  padding-top: 10px;
  border-top: 1px solid var(--m-border);
  font-size: 13px;
  color: var(--m-muted);
}
.hero-foot b {
  color: var(--m-ink);
}

.qr-btn {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 10px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  font-size: 11px;
  font-weight: 600;
  color: var(--m-primary-dark);
  cursor: pointer;
  transition: background 0.15s;
}
.qr-btn:hover {
  background: var(--m-primary-soft);
}

.sec {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.sec-title {
  margin: 0;
  color: var(--m-ink);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  padding: 0 2px;
  display: flex;
  align-items: center;
  gap: 6px;
}
.sec-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 1px 8px;
  border-radius: 999px;
  background: var(--m-warning-soft);
  color: var(--m-warning);
  font-size: 10px;
  font-weight: 700;
}
.sec-head-with-action {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.sec-add {
  display: flex;
  width: 28px;
  height: 28px;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
  transition: background 0.15s;
}
.sec-add:hover {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}

.group {
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.group > * {
  border-bottom: 1px solid var(--m-border);
}
.group > *:last-child {
  border-bottom: none;
}

.doc {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
}
.doc-icon {
  display: grid;
  width: 28px;
  height: 28px;
  flex: 0 0 28px;
  place-items: center;
  border-radius: 999px;
}
.doc-icon--good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.doc-icon--warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.doc-icon--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.doc-body {
  flex: 1 1 auto;
  min-width: 0;
  display: flex;
  flex-direction: column;
}
.doc-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--m-ink);
}
.doc-when {
  font-size: 11px;
  color: var(--m-muted);
}
.doc-tag {
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  flex: 0 0 auto;
}
.doc-tag--good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.doc-tag--warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.doc-tag--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.none {
  padding: 14px 12px;
  margin: 0;
  font-size: 13px;
  color: var(--m-muted);
  text-align: center;
}

.row {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 0;
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  transition: background 0.12s;
}
.row:hover {
  background: var(--m-bg);
}
.row-icon {
  flex: 0 0 28px;
  display: grid;
  place-items: center;
  color: var(--m-muted);
}
.row-icon--danger {
  color: var(--m-danger);
}
.row-label {
  flex: 1 1 auto;
  font-size: 13px;
  font-weight: 500;
  color: var(--m-ink);
}
.row-chev {
  flex: 0 0 16px;
  color: var(--m-muted);
}
.row--danger .row-label {
  color: var(--m-danger);
}
.row--danger:hover {
  background: var(--m-danger-soft);
}

.edit {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  align-self: center;
  padding: 6px 16px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  font-size: 13px;
  font-weight: 600;
  color: var(--m-primary-dark);
  cursor: pointer;
  transition: background 0.15s;
}
.edit:hover {
  background: var(--m-primary-soft);
}

.since {
  margin: 0;
  text-align: center;
  font-size: 12px;
  color: var(--m-muted);
}
.updated {
  color: var(--m-muted);
  opacity: 0.7;
}

.bar {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 100;
  display: flex;
  gap: 8px;
  justify-content: flex-end;
  padding: 12px 16px;
  padding-bottom: calc(12px + env(safe-area-inset-bottom, 0px));
  background: var(--m-surface);
  border-top: 1px solid var(--m-border);
  box-shadow: 0 -6px 20px rgba(0, 0, 0, 0.06);
  animation: slideUp 0.2s ease;
}
.bar-btn {
  padding: 8px 18px;
  border: 0;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.15s;
}
.bar-btn--ghost {
  background: transparent;
  color: var(--m-muted);
}
.bar-btn--ghost:hover {
  background: var(--m-bg);
}
.bar-btn--go {
  background: var(--m-primary);
  color: #fff;
}
.bar-btn--go:hover {
  background: var(--m-primary-dark);
}
.bar-btn:disabled {
  opacity: 0.5;
  pointer-events: none;
}

@keyframes slideUp {
  from {
    transform: translateY(100%);
    opacity: 0;
  }
  to {
    transform: translateY(0);
    opacity: 1;
  }
}

@media (prefers-reduced-motion: reduce) {
  .bar {
    animation: none;
  }
}
</style>