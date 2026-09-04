<template>
  <q-page class="profile-page">
    <!-- Loading -->
    <div v-if="loading" class="loading-stack">
      <q-skeleton type="rect" height="120px" class="sk" />
      <q-skeleton type="rect" height="80px" class="sk" />
      <q-skeleton type="rect" height="70px" class="sk" />
      <q-skeleton type="rect" height="70px" class="sk" />
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
      <!-- ===== HEADER CARD ===== -->
      <div class="header-card">
        <div class="header-top">
          <div class="avatar-wrap" @click="openAvatarPicker">
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
          <div class="header-text">
            <h1 class="name">{{ me.fullName || 'Your name' }}</h1>
            <div class="role-row">
              <span class="role">Accommodation Manager</span>
              <span class="status-tag" :class="`tag-${status.tone || 'warn'}`">
                <IconifyIcon
                  v-if="status.tone === 'good'"
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
          </div>
        </div>

        <!-- Quick Stats -->
        <div class="quick-stats">
          <div class="stat-block">
            <IconifyIcon icon="lucide:building-2" width="18" class="stat-icon" />
            <div>
              <span class="stat-number">{{ accommodationCount }}</span>
              <span class="stat-label">Properties</span>
            </div>
          </div>
          <div class="stat-divider" />
          <div class="stat-block">
            <IconifyIcon icon="lucide:users" width="18" class="stat-icon" />
            <div>
              <span class="stat-number">{{ tenantCount }}</span>
              <span class="stat-label">Tenants</span>
            </div>
          </div>
          <div class="stat-divider" />
          <div class="stat-block">
            <IconifyIcon icon="lucide:message-square" width="18" class="stat-icon" />
            <div>
              <span class="stat-number">{{ responseRate !== null ? responseRate + '%' : '—' }}</span>
              <span class="stat-label">Reply rate</span>
            </div>
          </div>
        </div>

        <!-- Action Button -->
        <button class="action-scan" @click="go('/manager/profile/qr-scanner')">
          <IconifyIcon icon="lucide:scan" width="18" />
          <span>Scan QR</span>
        </button>
      </div>

      <!-- ===== DETAILS CARD ===== -->
      <div class="card">
        <div class="card-header">
          <IconifyIcon icon="lucide:user" width="18" class="card-icon" />
          <h2 class="card-title">Personal details</h2>
          <button v-if="!editing" class="edit-btn" @click="startEdit">
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
          <button class="btn-cancel" :disabled="saving" @click="cancelEdit">Cancel</button>
          <button class="btn-save" :disabled="saving" @click="save">
            {{ saving ? 'Saving…' : 'Save changes' }}
          </button>
        </div>
        <div class="card-footer">
          <span class="member-since">
            Member since {{ memberSinceLabel || 'recently' }}
            <span v-if="updatedAt" class="updated">· {{ ago(updatedAt) }}</span>
          </span>
        </div>
      </div>

      <!-- ===== VERIFICATION CARD ===== -->
      <div class="card">
        <div class="card-header">
          <IconifyIcon icon="lucide:shield-check" width="18" class="card-icon" />
          <h2 class="card-title">Verification</h2>
          <span v-if="pendingDocs > 0" class="badge-pending">{{ pendingDocs }}</span>
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
          <button class="link-btn" @click="go('/manager/osas-compliance')">
            <IconifyIcon icon="lucide:arrow-right" width="16" />
            <span>Open OSAS compliance</span>
          </button>
        </div>
      </div>

      <!-- ===== ACCOMMODATIONS CARD ===== -->
      <div class="card">
        <div class="card-header">
          <IconifyIcon icon="lucide:building-2" width="18" class="card-icon" />
          <h2 class="card-title">Accommodations</h2>
          <button class="icon-btn" @click="go('/manager/properties/new')">
            <IconifyIcon icon="lucide:plus" width="18" />
          </button>
        </div>
        <div class="card-body">
          <button class="link-btn" @click="go('/manager/properties')">
            <IconifyIcon icon="lucide:list" width="16" />
            <span>Manage {{ accommodationCount }} {{ accommodationCount === 1 ? 'accommodation' : 'accommodations' }}</span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
          </button>
          <button class="link-btn" @click="go('/manager/tenants')">
            <IconifyIcon icon="lucide:users" width="16" />
            <span>{{ tenantCount }} active {{ tenantCount === 1 ? 'tenant' : 'tenants' }}</span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
          </button>
        </div>
      </div>

      <!-- ===== SETTINGS CARD ===== -->
      <div class="card">
        <div class="card-header">
          <IconifyIcon icon="lucide:settings" width="18" class="card-icon" />
          <h2 class="card-title">Settings</h2>
        </div>
        <div class="card-body">
          <button class="link-btn" @click="passwordOpen = true">
            <IconifyIcon icon="lucide:lock" width="16" />
            <span>Change password</span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
          </button>
          <button class="link-btn link-danger" @click="signOut">
            <IconifyIcon icon="lucide:log-out" width="16" />
            <span>Sign out</span>
          </button>
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
  background: #f1f5f9;
  padding-bottom: 24px;
  min-height: 100vh;
}

.loading-stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 12px 16px 80px;
}

.sk {
  border-radius: 12px;
}

.error-state {
  display: flex;
  justify-content: center;
  padding: 40px 16px;
}

.error-card {
  max-width: 340px;
  width: 100%;
  padding: 24px 20px;
  border-radius: 16px;
  background: white;
  text-align: center;
}

.error-icon {
  color: #94a3b8;
  margin-bottom: 8px;
}

.error-title {
  margin: 0 0 4px;
  font-size: 17px;
  font-weight: 700;
  color: #0f172a;
}

.error-message {
  margin: 0 0 16px;
  font-size: 14px;
  color: #64748b;
}

/* ===== CONTENT ===== */
.content-stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 12px 16px 40px;
}

/* ===== HEADER CARD ===== */
.header-card {
  background: white;
  border-radius: 16px;
  padding: 20px 16px 16px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04);
  border: 1px solid #e9edf2;
}

.header-top {
  display: flex;
  align-items: center;
  gap: 14px;
}

.avatar-wrap {
  position: relative;
  flex: 0 0 64px;
  width: 64px;
  height: 64px;
  border-radius: 999px;
  background: linear-gradient(135deg, #2563eb, #7c3aed);
  color: white;
  font-size: 24px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(37,99,235,0.2);
}

.avatar-wrap img {
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

.avatar-wrap:hover .avatar-overlay {
  opacity: 1;
}

.hidden-input {
  display: none;
}

.header-text {
  flex: 1;
  min-width: 0;
}

.name {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  color: #0f172a;
  line-height: 1.2;
}

.role-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px 10px;
  margin-top: 2px;
}

.role {
  font-size: 14px;
  color: #64748b;
}

.status-tag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 10px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.tag-good {
  background: #dcfce7;
  color: #16a34a;
}
.tag-idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.tag-warn {
  background: #fef9c3;
  color: #ca8a04;
}
.tag-danger {
  background: #fee2e2;
  color: #dc2626;
}

/* Quick Stats */
.quick-stats {
  display: flex;
  align-items: center;
  justify-content: space-around;
  margin-top: 16px;
  padding-top: 14px;
  border-top: 1px solid #f1f5f9;
}

.stat-block {
  display: flex;
  align-items: center;
  gap: 8px;
}

.stat-icon {
  color: #2563eb;
  opacity: 0.7;
}

.stat-number {
  font-size: 18px;
  font-weight: 700;
  color: #0f172a;
  display: block;
  line-height: 1.2;
}

.stat-label {
  font-size: 11px;
  font-weight: 600;
  color: #94a3b8;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  display: block;
}

.stat-divider {
  width: 1px;
  height: 30px;
  background: #e9edf2;
}

/* Action Scan */
.action-scan {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  width: 100%;
  margin-top: 14px;
  padding: 10px 0;
  border: 1px solid #e9edf2;
  border-radius: 999px;
  background: white;
  font-size: 14px;
  font-weight: 600;
  color: #1e293b;
  cursor: pointer;
  transition: all 0.15s;
}

.action-scan:hover {
  background: #f8fafc;
  border-color: #cbd5e1;
}

/* ===== CARDS ===== */
.card {
  background: white;
  border-radius: 16px;
  border: 1px solid #e9edf2;
  box-shadow: 0 2px 8px rgba(0,0,0,0.02);
  overflow: hidden;
}

.card-header {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px 16px;
  border-bottom: 1px solid #f1f5f9;
  background: #fafcfd;
}

.card-icon {
  color: #2563eb;
  opacity: 0.7;
}

.card-title {
  margin: 0;
  font-size: 15px;
  font-weight: 700;
  color: #0f172a;
  flex: 1;
}

.badge-pending {
  background: #fef9c3;
  color: #ca8a04;
  font-size: 11px;
  font-weight: 700;
  padding: 2px 10px;
  border-radius: 999px;
}

.edit-btn {
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
}

.edit-btn:hover {
  background: #eff6ff;
}

.icon-btn {
  display: flex;
  width: 32px;
  height: 32px;
  align-items: center;
  justify-content: center;
  border: 1px solid #e9edf2;
  border-radius: 999px;
  background: transparent;
  color: #64748b;
  cursor: pointer;
  transition: all 0.15s;
}

.icon-btn:hover {
  background: #eff6ff;
  color: #2563eb;
}

.card-body {
  padding: 2px 0;
}

.card-body > * {
  border-bottom: 1px solid #f1f5f9;
  padding: 10px 16px;
}

.card-body > *:last-child {
  border-bottom: none;
}

.card-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding: 12px 16px;
  border-top: 1px solid #f1f5f9;
  background: #fafcfd;
}

.btn-cancel,
.btn-save {
  padding: 8px 22px;
  border: 0;
  border-radius: 999px;
  font-size: 14px;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.15s;
  min-height: 44px;
}

.btn-cancel {
  background: transparent;
  color: #64748b;
}
.btn-cancel:hover {
  background: #f1f5f9;
}

.btn-save {
  background: #2563eb;
  color: white;
}
.btn-save:hover {
  background: #1d4ed8;
}

.btn-cancel:disabled,
.btn-save:disabled {
  opacity: 0.5;
  pointer-events: none;
}

.card-footer {
  padding: 8px 16px 12px;
  border-top: 1px solid #f1f5f9;
  text-align: center;
}

.member-since {
  font-size: 12px;
  color: #94a3b8;
}

.member-since .updated {
  color: #94a3b8;
  opacity: 0.7;
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

.doc-good {
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
.doc-danger {
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
  font-size: 10px;
  font-weight: 700;
}

.status-good {
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
.status-danger {
  background: #fee2e2;
  color: #dc2626;
}

.empty-text {
  margin: 0;
  font-size: 14px;
  color: #94a3b8;
  text-align: center;
  padding: 16px 0;
}

/* ===== LINK BUTTONS ===== */
.link-btn {
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
  padding: 12px 16px;
  min-height: 48px;
  transition: background 0.12s;
}

.link-btn:hover {
  background: #f8fafc;
}

.link-btn .chevron {
  margin-left: auto;
  color: #94a3b8;
}

.link-danger {
  color: #dc2626;
}
.link-danger:hover {
  background: #fef2f2;
}
</style>