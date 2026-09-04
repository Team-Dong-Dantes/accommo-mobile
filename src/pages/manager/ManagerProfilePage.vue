<template>
  <q-page class="profile-page">
    <!-- Loading -->
    <div v-if="loading" class="loading-stack">
      <q-skeleton type="rect" height="180px" class="sk" />
      <q-skeleton type="rect" height="120px" class="sk" />
      <q-skeleton type="rect" height="80px" class="sk" />
      <q-skeleton type="rect" height="80px" class="sk" />
    </div>

    <!-- Error -->
    <div v-else-if="error" class="error-state">
      <q-card flat bordered class="error-card">
        <div class="error-icon">
          <IconifyIcon icon="lucide:cloud-off" width="28" />
        </div>
        <p class="error-title">Couldn't load your profile</p>
        <p class="error-message">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" @click="load" />
      </q-card>
    </div>

    <!-- Profile Content -->
    <div v-else class="content-stack">
      <!-- ===== PROFILE HEADER ===== -->
      <div class="profile-header">
        <div class="header-avatar" @click="openAvatarPicker">
          <img v-if="avatarUrl" :src="avatarUrl" alt="Avatar" />
          <span v-else>{{ me.initials || '?' }}</span>
          <div class="avatar-overlay">
            <IconifyIcon icon="lucide:camera" width="16" />
          </div>
        </div>
        <input
          ref="avatarInput"
          type="file"
          accept="image/*"
          class="hidden-input"
          @change="onAvatarSelected"
        />

        <div class="header-info">
          <h1 class="header-name">{{ me.fullName || 'Your name' }}</h1>
          <div class="header-meta">
            <span class="header-role">Accommodation Manager</span>
            <span class="status-badge" :class="`badge-${status.tone || 'warn'}`">
              <IconifyIcon
                v-if="status.tone === 'ok'"
                icon="lucide:check-circle"
                width="12"
              />
              <IconifyIcon
                v-else-if="status.tone === 'warn'"
                icon="lucide:clock"
                width="12"
              />
              <IconifyIcon v-else icon="lucide:alert-circle" width="12" />
              {{ status.label || 'Unverified' }}
            </span>
          </div>
          <p class="header-since">
            Member since {{ memberSinceLabel || 'recently' }}
            <span v-if="updatedAt" class="updated">· Updated {{ ago(updatedAt) }}</span>
          </p>
        </div>

        <div class="header-action">
          <button class="action-btn scan-btn" @click="go('/manager/profile/qr-scanner')">
            <IconifyIcon icon="lucide:scan" width="16" />
            <span>Scan QR</span>
          </button>
        </div>
      </div>

      <!-- ===== STATS ROW ===== -->
      <div class="stats-row">
        <div class="stat-item">
          <IconifyIcon icon="lucide:building-2" width="20" class="stat-icon" />
          <div>
            <span class="stat-number">{{ accommodationCount }}</span>
            <span class="stat-label">Accommodations</span>
          </div>
        </div>
        <div class="stat-divider" />
        <div class="stat-item">
          <IconifyIcon icon="lucide:users" width="20" class="stat-icon" />
          <div>
            <span class="stat-number">{{ tenantCount }}</span>
            <span class="stat-label">Tenants</span>
          </div>
        </div>
        <div class="stat-divider" />
        <div class="stat-item">
          <IconifyIcon icon="lucide:message-square" width="20" class="stat-icon" />
          <div>
            <span class="stat-number">{{ responseRate !== null ? responseRate + '%' : '—' }}</span>
            <span class="stat-label">Reply rate</span>
          </div>
        </div>
      </div>

      <!-- ===== TWO-COLUMN GRID ===== -->
      <div class="grid-2">
        <!-- Left Column -->
        <div class="grid-left">
          <!-- Details Card -->
          <section class="profile-card">
            <div class="card-header">
              <IconifyIcon icon="lucide:user" width="18" class="card-icon" />
              <h2 class="card-title">Personal details</h2>
              <button v-if="!editing" class="edit-trigger" @click="startEdit">
                <IconifyIcon icon="lucide:pencil" width="14" />
                Edit
              </button>
            </div>
            <div class="card-body">
              <ProfileField v-model="draft.fullName" label="Full name" :editing="editing" />
              <ProfileField v-model="draft.phone" label="Phone" type="tel" :editing="editing" placeholder="+63…" />
              <ProfileField v-model="draft.email" label="Email" readonly :editing="editing" />
            </div>
            <div v-if="editing" class="card-actions">
              <button class="action-cancel" :disabled="saving" @click="cancelEdit">Cancel</button>
              <button class="action-save" :disabled="saving" @click="save">
                {{ saving ? 'Saving…' : 'Save changes' }}
              </button>
            </div>
          </section>

          <!-- Verification Card -->
          <section class="profile-card">
            <div class="card-header">
              <IconifyIcon icon="lucide:shield-check" width="18" class="card-icon" />
              <h2 class="card-title">Verification</h2>
              <span v-if="pendingDocs > 0" class="badge-pending">{{ pendingDocs }} pending</span>
            </div>
            <div class="card-body">
              <div v-if="documents.length" class="doc-list">
                <div v-for="doc in documents" :key="doc.id" class="doc-item">
                  <span class="doc-icon" :class="`doc-${doc.tone}`">
                    <IconifyIcon :icon="doc.icon" width="14" />
                  </span>
                  <div class="doc-info">
                    <span class="doc-name">{{ doc.label }}</span>
                    <span class="doc-when">{{ doc.when }}</span>
                  </div>
                  <span class="doc-status" :class="`status-${doc.tone}`">{{ doc.statusLabel }}</span>
                </div>
              </div>
              <p v-else class="empty-text">No documents submitted yet</p>
              <button class="link-button" @click="go('/manager/osas-compliance')">
                <IconifyIcon icon="lucide:arrow-right" width="16" />
                <span>Open OSAS compliance</span>
              </button>
            </div>
          </section>
        </div>

        <!-- Right Column -->
        <div class="grid-right">
          <!-- Accommodations Card -->
          <section class="profile-card">
            <div class="card-header">
              <IconifyIcon icon="lucide:building-2" width="18" class="card-icon" />
              <h2 class="card-title">Accommodations</h2>
              <button class="icon-action" @click="go('/manager/properties/new')">
                <IconifyIcon icon="lucide:plus" width="16" />
              </button>
            </div>
            <div class="card-body">
              <button class="link-button" @click="go('/manager/properties')">
                <IconifyIcon icon="lucide:list" width="16" />
                <span>Manage {{ accommodationCount }} {{ accommodationCount === 1 ? 'accommodation' : 'accommodations' }}</span>
                <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
              </button>
              <button class="link-button" @click="go('/manager/tenants')">
                <IconifyIcon icon="lucide:users" width="16" />
                <span>{{ tenantCount }} active {{ tenantCount === 1 ? 'tenant' : 'tenants' }}</span>
                <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
              </button>
            </div>
          </section>

          <!-- Settings Card -->
          <section class="profile-card">
            <div class="card-header">
              <IconifyIcon icon="lucide:settings" width="18" class="card-icon" />
              <h2 class="card-title">Settings</h2>
            </div>
            <div class="card-body">
              <button class="link-button" @click="passwordOpen = true">
                <IconifyIcon icon="lucide:lock" width="16" />
                <span>Change password</span>
                <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
              </button>
              <button class="link-button link-danger" @click="signOut">
                <IconifyIcon icon="lucide:log-out" width="16" />
                <span>Sign out</span>
              </button>
            </div>
          </section>
        </div>
      </div>
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
// If uploadAvatar doesn't exist, comment out the import and usage below
// import { uploadAvatar } from '@/utils/upload'
import ProfileField from '@/components/shared/ProfileField.vue'
import ChangePasswordDialog from '@/components/shared/ChangePasswordDialog.vue'
import { DOC_LABEL, docPresentation, statusPresentation, memberSince, ago } from '@/utils/profile'

// ----- Types -----
interface DocRow {
  id: string
  label: string
  statusLabel: string
  tone: string
  icon: string
  when: string
}

// ----- Router & Quasar -----
const router = useRouter()
const $q = useQuasar()

// ----- Reactive State -----
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const editing = ref(false)
const passwordOpen = ref(false)

const userId = ref('')
const avatarUrl = ref<string | null>(null)
const avatarInput = ref<HTMLInputElement | null>(null)

// User data – must be defined before render
const me = reactive({
  fullName: '',
  email: '',
  phone: '',
  initials: '?',
  status: 'unverified',
})

// Draft for editing
const draft = reactive({
  fullName: '',
  phone: '',
  email: '',
})

const createdAt = ref<string | null>(null)
const updatedAt = ref<string | null>(null)
const responseRate = ref<number | null>(null)
const accommodationCount = ref(0)
const tenantCount = ref(0)
const documents = ref<DocRow[]>([])

// ----- Computed -----
const status = computed(() => statusPresentation(me.status))
const memberSinceLabel = computed(() => memberSince(createdAt.value))
const pendingDocs = computed(() => documents.value.filter(d => d.tone === 'warn').length)

// ----- Methods -----
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
    // If you have uploadAvatar, uncomment:
    // const url = await uploadAvatar(file, userId.value)
    // avatarUrl.value = url
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

// ----- Load Data -----
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

    // Avatar from metadata
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

    // Accommodations count
    const { data: accommodations } = await supabase
      .from('accommodations')
      .select('id')
      .eq('accommodation_manager_id', user.id)
    const accommodationIds = (accommodations || []).map((a) => a.id)
    accommodationCount.value = accommodationIds.length

    // Tenant count
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

    // Verification documents
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
/* ===== BASE ===== */
.profile-page {
  background: #f8fafc;
  padding-bottom: 40px;
  min-height: 100vh;
}

.loading-stack {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 16px var(--m-page-gutter) 80px;
}

.sk {
  border-radius: 12px;
}

.error-state {
  display: flex;
  justify-content: center;
  padding: 40px var(--m-page-gutter);
}

.error-card {
  max-width: 360px;
  width: 100%;
  padding: 28px 24px;
  border-radius: 16px;
  background: white;
  text-align: center;
  box-shadow: 0 4px 12px rgba(0,0,0,0.04);
}

.error-icon {
  color: #94a3b8;
  margin-bottom: 8px;
}

.error-title {
  margin: 0 0 4px;
  font-size: 18px;
  font-weight: 700;
  color: #0f172a;
}

.error-message {
  margin: 0 0 20px;
  font-size: 14px;
  color: #64748b;
}

/* ===== CONTENT ===== */
.content-stack {
  max-width: 1200px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) 40px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

/* ===== PROFILE HEADER ===== */
.profile-header {
  display: flex;
  align-items: center;
  gap: 18px;
  background: white;
  border-radius: 16px;
  padding: 24px 28px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);
  border: 1px solid #e9edf2;
  flex-wrap: wrap;
}

.header-avatar {
  position: relative;
  flex: 0 0 72px;
  width: 72px;
  height: 72px;
  border-radius: 999px;
  background: linear-gradient(135deg, #2563eb, #7c3aed);
  color: white;
  font-size: 28px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  overflow: hidden;
  box-shadow: 0 2px 10px rgba(37,99,235,0.2);
  transition: transform 0.2s;
}

.header-avatar:hover {
  transform: scale(1.03);
}

.header-avatar img {
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
  background: rgba(0,0,0,0.35);
  color: white;
  opacity: 0;
  transition: opacity 0.2s;
}

.header-avatar:hover .avatar-overlay {
  opacity: 1;
}

.hidden-input {
  display: none;
}

.header-info {
  flex: 1;
  min-width: 180px;
}

.header-name {
  margin: 0;
  font-size: 22px;
  font-weight: 700;
  color: #0f172a;
  line-height: 1.2;
}

.header-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px 14px;
  margin-top: 4px;
}

.header-role {
  font-size: 14px;
  color: #64748b;
}

.status-badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 12px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.badge-ok {
  background: #dcfce7;
  color: #16a34a;
}
.badge-idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.badge-warn {
  background: #fef9c3;
  color: #ca8a04;
}
.badge-bad {
  background: #fee2e2;
  color: #dc2626;
}

.header-since {
  margin: 6px 0 0;
  font-size: 13px;
  color: #94a3b8;
}

.header-since .updated {
  color: #94a3b8;
  opacity: 0.7;
}

.header-action {
  margin-left: auto;
}

.scan-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 20px;
  border: 1px solid #e9edf2;
  border-radius: 999px;
  background: white;
  font-size: 13px;
  font-weight: 600;
  color: #1e293b;
  cursor: pointer;
  transition: all 0.15s;
}

.scan-btn:hover {
  background: #f1f5f9;
  border-color: #cbd5e1;
}

/* ===== STATS ROW ===== */
.stats-row {
  display: flex;
  align-items: stretch;
  background: white;
  border-radius: 16px;
  padding: 16px 24px;
  border: 1px solid #e9edf2;
  box-shadow: 0 1px 4px rgba(0,0,0,0.02);
  gap: 16px;
}

.stat-item {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.stat-item > div {
  display: flex;
  flex-direction: column;
  line-height: 1.2;
}

.stat-icon {
  color: #2563eb;
  opacity: 0.7;
  flex-shrink: 0;
}

.stat-number {
  font-size: 20px;
  font-weight: 700;
  color: #0f172a;
}

.stat-label {
  font-size: 12px;
  font-weight: 600;
  color: #94a3b8;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.stat-divider {
  width: 1px;
  background: #e9edf2;
  flex-shrink: 0;
}

/* ===== GRID LAYOUT ===== */
.grid-2 {
  display: grid;
  grid-template-columns: 1fr;
  gap: 20px;
}

@media (min-width: 768px) {
  .grid-2 {
    grid-template-columns: 1fr 1fr;
  }
}

/* ===== CARDS ===== */
.profile-card {
  background: white;
  border-radius: 16px;
  border: 1px solid #e9edf2;
  box-shadow: 0 1px 4px rgba(0,0,0,0.02);
  overflow: hidden;
}

.card-header {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px 20px;
  border-bottom: 1px solid #e9edf2;
  background: #fafcfd;
}

.card-icon {
  color: #2563eb;
  opacity: 0.7;
}

.card-title {
  margin: 0;
  font-size: 14px;
  font-weight: 700;
  color: #0f172a;
  flex: 1;
  letter-spacing: 0.02em;
}

.badge-pending {
  background: #fef9c3;
  color: #ca8a04;
  font-size: 11px;
  font-weight: 700;
  padding: 2px 10px;
  border-radius: 999px;
}

.edit-trigger {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 12px;
  border: 0;
  background: transparent;
  font-size: 13px;
  font-weight: 600;
  color: #2563eb;
  cursor: pointer;
  border-radius: 999px;
  transition: background 0.15s;
}

.edit-trigger:hover {
  background: #eff6ff;
}

.icon-action {
  display: flex;
  width: 30px;
  height: 30px;
  align-items: center;
  justify-content: center;
  border: 1px solid #e9edf2;
  border-radius: 999px;
  background: transparent;
  color: #64748b;
  cursor: pointer;
  transition: all 0.15s;
}

.icon-action:hover {
  background: #eff6ff;
  color: #2563eb;
}

.card-body {
  padding: 4px 0;
}

.card-body > * {
  border-bottom: 1px solid #f1f5f9;
  padding: 10px 20px;
}

.card-body > *:last-child {
  border-bottom: none;
}

.card-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  padding: 12px 20px;
  border-top: 1px solid #e9edf2;
  background: #fafcfd;
}

.action-cancel,
.action-save {
  padding: 6px 20px;
  border: 0;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.15s;
}

.action-cancel {
  background: transparent;
  color: #64748b;
}
.action-cancel:hover {
  background: #f1f5f9;
}

.action-save {
  background: #2563eb;
  color: white;
}
.action-save:hover {
  background: #1d4ed8;
}

.action-cancel:disabled,
.action-save:disabled {
  opacity: 0.5;
  pointer-events: none;
}

/* ===== DOCS ===== */
.doc-item {
  display: flex;
  align-items: center;
  gap: 12px;
}

.doc-icon {
  flex: 0 0 32px;
  width: 32px;
  height: 32px;
  display: grid;
  place-items: center;
  border-radius: 999px;
}

.doc-ok {
  background: #dcfce7;
  color: #16a34a;
}
.doc-idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.doc-warn {
  background: #fef9c3;
  color: #ca8a04;
}
.doc-bad {
  background: #fee2e2;
  color: #dc2626;
}

.doc-info {
  flex: 1;
  min-width: 0;
}

.doc-name {
  font-size: 14px;
  font-weight: 600;
  color: #0f172a;
  display: block;
}

.doc-when {
  font-size: 12px;
  color: #94a3b8;
}

.doc-status {
  padding: 2px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}

.status-ok {
  background: #dcfce7;
  color: #16a34a;
}
.status-idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.status-warn {
  background: #fef9c3;
  color: #ca8a04;
}
.status-bad {
  background: #fee2e2;
  color: #dc2626;
}

.empty-text {
  margin: 0;
  font-size: 14px;
  color: #94a3b8;
  text-align: center;
  padding: 20px 0;
}

/* ===== LINK BUTTONS ===== */
.link-button {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 12px;
  background: transparent;
  border: 0;
  cursor: pointer;
  font: inherit;
  text-align: left;
  color: #0f172a;
  transition: background 0.12s;
  padding: 10px 20px;
}

.link-button:hover {
  background: #f8fafc;
}

.link-button .chevron {
  margin-left: auto;
  color: #94a3b8;
}

.link-danger {
  color: #dc2626;
}
.link-danger:hover {
  background: #fef2f2;
}

/* ===== RESPONSIVE TWEAKS ===== */
@media (max-width: 600px) {
  .profile-header {
    flex-direction: column;
    align-items: center;
    text-align: center;
    padding: 20px;
  }

  .header-action {
    margin-left: 0;
    width: 100%;
    display: flex;
    justify-content: center;
  }

  .stats-row {
    flex-direction: column;
    align-items: stretch;
    gap: 12px;
    padding: 16px;
  }

  .stat-divider {
    display: none;
  }

  .stat-item {
    justify-content: center;
  }
}
</style>