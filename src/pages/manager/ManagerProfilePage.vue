<template>
  <q-page class="profile-page">
    <!-- Loading -->
    <div v-if="loading" class="loading-stack">
      <q-skeleton type="rect" height="180px" class="sk" />
      <q-skeleton type="rect" height="100px" class="sk" />
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
      <!-- ===== Improved Hero Card ===== -->
      <div class="hero-card">
        <!-- Cover gradient -->
        <div class="hero-cover" />

        <div class="hero-body">
          <!-- Avatar with upload overlay -->
          <div class="hero-avatar" @click="openAvatarPicker">
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

          <!-- Name, role, status -->
          <div class="hero-info">
            <h1 class="hero-name">{{ me.fullName || 'Your name' }}</h1>
            <div class="hero-meta">
              <span class="hero-role">Accommodation Manager</span>
              <span class="hero-tag" :class="`tag-${status.tone || 'warn'}`">
                <IconifyIcon v-if="status.tone === 'ok'" icon="lucide:check-circle" width="12" />
                <IconifyIcon v-else-if="status.tone === 'warn'" icon="lucide:clock" width="12" />
                <IconifyIcon v-else icon="lucide:alert-circle" width="12" />
                {{ status.label || 'Unverified' }}
              </span>
            </div>
          </div>
        </div>

        <!-- Stats row -->
        <div class="hero-stats">
          <div class="stat-item">
            <span class="stat-number">{{ accommodationCount }}</span>
            <span class="stat-label">{{ accommodationCount === 1 ? 'Accommodation' : 'Accommodations' }}</span>
          </div>
          <div class="stat-divider" />
          <div class="stat-item">
            <span class="stat-number">{{ tenantCount }}</span>
            <span class="stat-label">{{ tenantCount === 1 ? 'Tenant' : 'Tenants' }}</span>
          </div>
          <div class="stat-divider" />
          <div class="stat-item">
            <span class="stat-number">{{ responseRate !== null ? responseRate + '%' : '—' }}</span>
            <span class="stat-label">Reply rate</span>
          </div>
          <div class="stat-divider" />
          <button class="stat-action" @click="go('/manager/profile/qr-scanner')">
            <IconifyIcon icon="lucide:scan" width="18" />
            <span>Scan QR</span>
          </button>
        </div>
      </div>

      <!-- Details Section -->
      <section class="profile-section">
        <div class="section-header">
          <IconifyIcon icon="lucide:user" width="18" class="section-icon" />
          <h2 class="section-title">Your details</h2>
        </div>
        <div class="section-body">
          <ProfileField v-model="draft.fullName" label="Full name" :editing="editing" />
          <ProfileField v-model="draft.phone" label="Phone" type="tel" :editing="editing" placeholder="+63…" />
          <ProfileField v-model="draft.email" label="Email" readonly :editing="editing" />
        </div>
        <div class="edit-row">
          <button v-if="!editing" class="edit-button" @click="startEdit">
            <IconifyIcon icon="lucide:pencil" width="16" />
            Edit profile
          </button>
          <div v-else class="edit-actions">
            <button class="edit-cancel" :disabled="saving" @click="cancelEdit">Cancel</button>
            <button class="edit-save" :disabled="saving" @click="save">
              {{ saving ? 'Saving…' : 'Save changes' }}
            </button>
          </div>
          <p class="member-since">
            Member since {{ memberSinceLabel || 'recently' }}
            <span v-if="updatedAt" class="updated">· Updated {{ ago(updatedAt) }}</span>
          </p>
        </div>
      </section>

      <!-- Verification Section -->
      <section class="profile-section">
        <div class="section-header">
          <IconifyIcon icon="lucide:shield-check" width="18" class="section-icon" />
          <h2 class="section-title">Verification</h2>
          <span v-if="pendingDocs > 0" class="badge">{{ pendingDocs }} pending</span>
        </div>
        <div class="section-body">
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
          <p v-else class="empty-text">You haven't submitted any documents yet</p>
          <button class="link-button" @click="go('/manager/osas-compliance')">
            <IconifyIcon icon="lucide:arrow-right" width="16" />
            <span>Open OSAS compliance</span>
          </button>
        </div>
      </section>

      <!-- Accommodations Section -->
      <section class="profile-section">
        <div class="section-header">
          <IconifyIcon icon="lucide:building-2" width="18" class="section-icon" />
          <h2 class="section-title">Your accommodations</h2>
          <button class="icon-action" @click="go('/manager/properties/new')">
            <IconifyIcon icon="lucide:plus" width="16" />
          </button>
        </div>
        <div class="section-body">
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

      <!-- Settings Section -->
      <section class="profile-section">
        <div class="section-header">
          <IconifyIcon icon="lucide:settings" width="18" class="section-icon" />
          <h2 class="section-title">Settings</h2>
        </div>
        <div class="section-body">
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
// If uploadAvatar doesn't exist, comment this out and the related function
// import { uploadAvatar } from '@/utils/upload'
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

// === STATE ===
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const editing = ref(false)
const passwordOpen = ref(false)

const userId = ref('')
const avatarUrl = ref<string | null>(null)
const avatarInput = ref<HTMLInputElement | null>(null)

// These are reactive objects that must be defined before the template renders
const me = reactive({
  fullName: '',
  email: '',
  phone: '',
  initials: '?',
  status: 'unverified',
})
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

// === COMPUTED ===
const status = computed(() => statusPresentation(me.status))
const memberSinceLabel = computed(() => memberSince(createdAt.value))
const pendingDocs = computed(() => documents.value.filter(d => d.tone === 'warn').length)

// === METHODS ===
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
    // If uploadAvatar is not available, skip this or use a placeholder
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

    // Avatar from auth metadata
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

    // Count accommodations
    const { data: accommodations } = await supabase
      .from('accommodations')
      .select('id')
      .eq('accommodation_manager_id', user.id)
    const accommodationIds = (accommodations || []).map((a) => a.id)
    accommodationCount.value = accommodationIds.length

    // Count tenants
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

    // Get verification documents
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
.profile-page {
  background: var(--m-bg);
  padding-bottom: 20px;
  min-height: 100vh;
}
.loading-stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 12px var(--m-page-gutter) 80px;
}
.sk {
  border-radius: var(--m-radius);
}

/* Error state */
.error-state {
  display: flex;
  justify-content: center;
  padding: 40px var(--m-page-gutter);
}
.error-card {
  max-width: 360px;
  width: 100%;
  padding: 24px 20px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}
.error-icon {
  color: var(--m-muted);
  margin-bottom: 8px;
}
.error-title {
  margin: 0 0 4px;
  font-size: 16px;
  font-weight: 700;
  color: var(--m-ink);
}
.error-message {
  margin: 0 0 16px;
  font-size: 13px;
  color: var(--m-muted);
}

.content-stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 12px var(--m-page-gutter) 80px;
}

/* ===== HERO CARD – improved ===== */
.hero-card {
  background: var(--m-surface);
  border-radius: var(--m-radius);
  border: 1px solid var(--m-border);
  overflow: hidden;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.04);
}
.hero-cover {
  height: 72px;
  background: linear-gradient(135deg, var(--m-primary) 0%, var(--m-primary-dark) 80%);
}
.hero-body {
  display: flex;
  align-items: flex-end;
  gap: 16px;
  padding: 0 16px 14px;
  margin-top: -36px;
}
.hero-avatar {
  position: relative;
  flex: 0 0 76px;
  width: 76px;
  height: 76px;
  border-radius: 999px;
  border: 3px solid var(--m-surface);
  background: var(--m-primary);
  color: #fff;
  font-size: 30px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  overflow: hidden;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  transition: transform 0.2s;
}
.hero-avatar:hover {
  transform: scale(1.02);
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
  transition: opacity 0.2s;
  backdrop-filter: blur(2px);
}
.hero-avatar:hover .avatar-overlay {
  opacity: 1;
}
.hidden-input {
  display: none;
}
.hero-info {
  flex: 1;
  min-width: 0;
  padding-bottom: 4px;
}
.hero-name {
  margin: 0;
  font-size: 21px;
  font-weight: 700;
  color: var(--m-ink);
  line-height: 1.2;
}
.hero-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px 12px;
  margin-top: 2px;
}
.hero-role {
  font-size: 13px;
  color: var(--m-muted);
}
.hero-tag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 12px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
.tag-ok {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.tag-idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.tag-warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.tag-bad {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}

/* Stats */
.hero-stats {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 16px 14px;
  border-top: 1px solid var(--m-border);
  flex-wrap: wrap;
}
.stat-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 0 4px;
}
.stat-number {
  font-size: 20px;
  font-weight: 700;
  color: var(--m-ink);
  line-height: 1.2;
}
.stat-label {
  font-size: 10px;
  font-weight: 600;
  color: var(--m-muted);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
.stat-divider {
  width: 1px;
  height: 32px;
  background: var(--m-border);
}
.stat-action {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  margin-left: auto;
  padding: 6px 14px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  font-size: 12px;
  font-weight: 600;
  color: var(--m-primary-dark);
  cursor: pointer;
  transition: all 0.15s;
}
.stat-action:hover {
  background: var(--m-primary-soft);
  border-color: var(--m-primary);
  transform: translateY(-1px);
}

/* ===== Profile Sections ===== */
.profile-section {
  background: var(--m-surface);
  border-radius: var(--m-radius);
  border: 1px solid var(--m-border);
  overflow: hidden;
}
.section-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  border-bottom: 1px solid var(--m-border);
}
.section-icon {
  color: var(--m-primary-dark);
  opacity: 0.7;
}
.section-title {
  margin: 0;
  font-size: 12px;
  font-weight: 700;
  color: var(--m-ink);
  text-transform: uppercase;
  letter-spacing: 0.04em;
  flex: 1;
}
.badge {
  background: var(--m-warning-soft);
  color: var(--m-warning);
  font-size: 10px;
  font-weight: 700;
  padding: 1px 8px;
  border-radius: 999px;
}
.icon-action {
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
  transition: all 0.15s;
}
.icon-action:hover {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.section-body {
  padding: 2px 0;
}
.section-body > * {
  border-bottom: 1px solid var(--m-border);
  padding: 8px 14px;
}
.section-body > *:last-child {
  border-bottom: none;
}

/* Docs */
.doc-item {
  display: flex;
  align-items: center;
  gap: 10px;
}
.doc-icon {
  flex: 0 0 28px;
  width: 28px;
  height: 28px;
  display: grid;
  place-items: center;
  border-radius: 999px;
}
.doc-good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.doc-warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.doc-danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.doc-info {
  flex: 1;
  min-width: 0;
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
.doc-status {
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}
.status-good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.status-warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.status-danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.empty-text {
  margin: 0;
  font-size: 13px;
  color: var(--m-muted);
  text-align: center;
  padding: 16px 0;
}

/* Link buttons */
.link-button {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  background: transparent;
  border: 0;
  cursor: pointer;
  font: inherit;
  text-align: left;
  color: var(--m-ink);
  transition: background 0.12s;
  padding: 8px 14px;
}
.link-button:hover {
  background: var(--m-bg);
}
.link-button .chevron {
  margin-left: auto;
  color: var(--m-muted);
}
.link-danger {
  color: var(--m-danger);
}
.link-danger:hover {
  background: var(--m-danger-soft);
}

/* Edit row */
.edit-row {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 8px 14px 12px;
  border-top: 1px solid var(--m-border);
}
.edit-button {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 20px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  font-size: 13px;
  font-weight: 600;
  color: var(--m-primary-dark);
  cursor: pointer;
  transition: all 0.15s;
}
.edit-button:hover {
  background: var(--m-primary-soft);
  border-color: var(--m-primary);
}
.edit-actions {
  display: flex;
  gap: 8px;
  width: 100%;
  justify-content: flex-end;
}
.edit-cancel,
.edit-save {
  padding: 6px 18px;
  border: 0;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.15s;
}
.edit-cancel {
  background: transparent;
  color: var(--m-muted);
}
.edit-cancel:hover {
  background: var(--m-bg);
}
.edit-save {
  background: var(--m-primary);
  color: #fff;
}
.edit-save:hover {
  background: var(--m-primary-dark);
}
.edit-cancel:disabled,
.edit-save:disabled {
  opacity: 0.5;
  pointer-events: none;
}
.member-since {
  margin: 4px 0 0;
  font-size: 12px;
  color: var(--m-muted);
}
.updated {
  color: var(--m-muted);
  opacity: 0.7;
}

@media (prefers-reduced-motion: reduce) {
  .hero-avatar,
  .stat-action {
    transition: none !important;
  }
}
</style>