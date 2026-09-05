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
      <!-- ===== HEADER ===== -->
      <ProfileHero
        v-model:avatar-url="avatarUrl"
        :initials="me.initials"
        :user-id="userId"
        avatar-background="linear-gradient(135deg, #2563eb, #7c3aed)"
        :name="me.fullName || 'Your name'"
        subtitle="Accommodation Manager"
        :status-tone="status.tone || 'warn'"
        :status-label="status.label || 'Unverified'"
        action-icon="lucide:scan"
        action-label="Scan QR"
        @action="go('/manager/profile/qr-scanner')"
      >
        <div class="quick-stats">
          <div class="stat-block">
            <span class="stat-badge">
              <IconifyIcon icon="lucide:building-2" width="16" />
            </span>
            <div>
              <span class="stat-number">{{ accommodationCount }}</span>
              <span class="stat-label">Properties</span>
            </div>
          </div>
          <div class="stat-divider" />
          <div class="stat-block">
            <span class="stat-badge">
              <IconifyIcon icon="lucide:users" width="16" />
            </span>
            <div>
              <span class="stat-number">{{ tenantCount }}</span>
              <span class="stat-label">Tenants</span>
            </div>
          </div>
          <div class="stat-divider" />
          <div class="stat-block">
            <span class="stat-badge">
              <IconifyIcon icon="lucide:message-square" width="16" />
            </span>
            <div>
              <span class="stat-number">{{ responseRate !== null ? responseRate + '%' : '—' }}</span>
              <span class="stat-label">Reply rate</span>
            </div>
          </div>
        </div>
      </ProfileHero>

      <!-- ===== PROFILE ===== -->
      <ProfileCard>
        <template #always>
          <ProfileBlock icon="lucide:user" title="Personal details">
            <template #actions>
              <EditButton v-if="!editing" @click="startEdit" />
            </template>
            <ProfileField v-model="draft.fullName" label="Full name" :editing="editing" />
            <ProfileField v-model="draft.phone" label="Phone" type="tel" :editing="editing" placeholder="+63…" />
            <ProfileField v-model="draft.email" label="Email" readonly :editing="editing" />
            <template v-if="editing" #foot>
              <div class="card-actions">
                <button class="btn-cancel" :disabled="saving" @click="cancelEdit">Cancel</button>
                <button class="btn-save" :disabled="saving" @click="save">
                  {{ saving ? 'Saving…' : 'Save changes' }}
                </button>
              </div>
            </template>
          </ProfileBlock>
        </template>

        <template #more>
          <ProfileBlock
            icon="lucide:shield-check"
            title="Verification"
            :badge="pendingDocs > 0 ? `${pendingDocs} pending` : ''"
          >
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
          </ProfileBlock>

          <ProfileBlock icon="lucide:building-2" title="Accommodations">
            <template #actions>
              <button class="icon-btn" @click="go('/manager/properties/new')">
                <IconifyIcon icon="lucide:plus" width="18" />
              </button>
            </template>
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
          </ProfileBlock>

        </template>

        <template #footer>
          Member since {{ memberSinceLabel || 'recently' }}
          <span v-if="updatedAt" class="updated">· {{ ago(updatedAt) }}</span>
        </template>
      </ProfileCard>

      <!-- ===== SETTINGS ===== -->
      <ProfileSettingsSection
        :user-id="userId"
        :email="me.email"
        :notification-prefs="notificationPrefs"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { initialsOf, normalizePhPhone } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { useNotify } from '@/utils/notify'
import ProfileField from '@/components/shared/ProfileField.vue'
import ProfileHero from '@/components/shared/ProfileHero.vue'
import ProfileCard from '@/components/shared/ProfileCard.vue'
import ProfileBlock from '@/components/shared/ProfileBlock.vue'
import EditButton from '@/components/shared/EditButton.vue'
import ProfileSettingsSection from '@/components/manager/ProfileSettingsSection.vue'
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

// ----- Router & notifications -----
const router = useRouter()
const notify = useNotify()

// ----- Reactive State -----
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const editing = ref(false)

const userId = ref('')
const avatarUrl = ref<string | null>(null)
const notificationPrefs = reactive({ push: true, email: true })

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
    notify.error('Your name cannot be empty.')
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
    notify.success('Profile updated.')
  } catch (e) {
    notify.error(e instanceof Error ? e.message : 'Could not save.')
  } finally {
    saving.value = false
  }
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
        .select('full_name, email, phone, initials, status, created_at, updated_at, notification_prefs')
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

    const prefs = (profile?.notification_prefs ?? null) as { push?: boolean; email?: boolean } | null
    notificationPrefs.push = prefs?.push ?? true
    notificationPrefs.email = prefs?.email ?? true

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
  /* Manager's blue brand accent — deliberately distinct from the student
     app's teal --m-primary, kept as a page-scoped var to avoid repeating
     the hex across every accent usage below. */
  --mp-accent: #2563eb;
  --mp-accent-dark: #1d4ed8;
  background: var(--m-bg);
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
  color: var(--m-muted);
  margin-bottom: 8px;
}

.error-title {
  margin: 0 0 4px;
  font-size: 17px;
  font-weight: 700;
  color: var(--m-ink);
}

.error-message {
  margin: 0 0 16px;
  font-size: 14px;
  color: var(--m-muted);
}

/* ===== CONTENT ===== */
.content-stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 12px 16px 40px;
}

/* Quick Stats */
.quick-stats {
  display: flex;
  flex: 1;
  align-items: center;
  justify-content: space-around;
}

.stat-block {
  display: flex;
  align-items: center;
  gap: 8px;
}

.stat-badge {
  display: flex;
  flex: 0 0 32px;
  width: 32px;
  height: 32px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}

.stat-number {
  font-size: 18px;
  font-weight: 700;
  color: var(--m-ink);
  display: block;
  line-height: 1.2;
}

.stat-label {
  font-size: 11px;
  font-weight: 600;
  color: var(--m-muted);
  text-transform: uppercase;
  letter-spacing: 0.03em;
  display: block;
}

.stat-divider {
  width: 1px;
  height: 30px;
  background: var(--m-border);
}

/* Action Scan */
/* ===== CARDS ===== */
.icon-btn {
  display: flex;
  width: 32px;
  height: 32px;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: transparent;
  color: var(--m-muted);
  cursor: pointer;
  transition: all 0.15s;
}

.icon-btn:hover {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}

.card-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding: 12px 16px;
  border-top: 1px solid var(--m-bg);
  background: var(--m-surface);
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
  color: var(--m-muted);
}
.btn-cancel:hover {
  background: var(--m-bg);
}

.btn-save {
  background: var(--mp-accent);
  color: white;
}
.btn-save:hover {
  background: var(--mp-accent-dark);
}

.btn-cancel:disabled,
.btn-save:disabled {
  opacity: 0.5;
  pointer-events: none;
}

.updated {
  color: var(--m-muted);
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
  background: var(--m-success-soft);
  color: var(--m-success);
}
.doc-idle {
  background: var(--m-bg);
  color: var(--m-muted);
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
  font-size: 14px;
  font-weight: 600;
  color: var(--m-ink);
  display: block;
}

.doc-when {
  font-size: 12px;
  color: var(--m-muted);
}

.doc-status {
  padding: 2px 10px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}

.status-good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.status-idle {
  background: var(--m-bg);
  color: var(--m-muted);
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
  font-size: 14px;
  color: var(--m-muted);
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
  color: var(--m-ink);
  padding: 12px 16px;
  min-height: 48px;
  transition: background 0.12s;
}

.link-btn:hover {
  background: var(--m-bg);
}

.link-btn .chevron {
  margin-left: auto;
  color: var(--m-muted);
}
</style>