<template>
  <q-page class="prof">
    <!-- Loading -->
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="160px" class="sk" />
      <q-skeleton type="rect" height="120px" class="sk" />
      <q-skeleton type="rect" height="100px" class="sk" />
    </div>

    <!-- Error -->
    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card card--pad text-center">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your profile</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <!-- Profile Content -->
    <div v-else class="stack">
      <!-- Hero Header -->
      <div class="hero">
        <div class="hero-cover" />
        <div class="hero-content">
          <div class="hero-avatar-wrapper" @click="openAvatarPicker">
            <img v-if="avatarUrl" :src="avatarUrl" alt="Avatar" class="hero-avatar" />
            <span v-else class="hero-avatar">{{ me.initials || '?' }}</span>
            <span class="hero-avatar-overlay">
              <IconifyIcon icon="lucide:camera" width="16" />
            </span>
          </div>
          <input ref="avatarInput" type="file" accept="image/*" class="hidden-input" @change="onAvatarSelected" />

          <div class="hero-meta">
            <h1 class="hero-name">{{ me.fullName || 'Your name' }}</h1>
            <p class="hero-role">{{ courseLine || 'Student' }}</p>
            <span class="hero-tag" :class="`hero-tag--${status.tone || 'warn'}`">{{ status.label || 'Unverified' }}</span>
          </div>
        </div>

        <!-- Stay & QR -->
        <div class="hero-stats">
          <div class="stay-info">
            <IconifyIcon icon="lucide:home" width="18" class="stay-icon" />
            <span class="stay-name">{{ stay ? stay.accommodationName : 'No active stay' }}</span>
            <span v-if="stay && stay.roomNumber" class="stay-room">· Room {{ stay.roomNumber }}</span>
          </div>
          <button class="stat-action" @click="qrDialog = true">
            <IconifyIcon icon="lucide:qr-code" width="18" />
            <span>My QR</span>
          </button>
        </div>
      </div>

      <!-- Details Card -->
      <section class="card-section">
        <div class="card-header">
          <IconifyIcon icon="lucide:user" width="18" class="card-icon" />
          <h2 class="card-title">Your details</h2>
        </div>
        <div class="card-body">
          <ProfileField v-model="draft.fullName" label="Full name" :editing="editing" />
          <ProfileField v-model="draft.phone" label="Phone" type="tel" :editing="editing" placeholder="+63…" />
          <ProfileField v-model="draft.email" label="Email" readonly :editing="editing" />
        </div>
      </section>

      <!-- Edit button & member since -->
      <div class="edit-row">
        <button v-if="!editing" class="edit-btn" @click="startEdit">
          <IconifyIcon icon="lucide:pencil" width="16" />
          Edit profile
        </button>
        <p class="member-since">
          Member since {{ memberSinceLabel || 'recently' }}
          <span v-if="updatedAt" class="updated">· Updated {{ ago(updatedAt) }}</span>
        </p>
      </div>

      <!-- Academics Card -->
      <section class="card-section">
        <div class="card-header">
          <IconifyIcon icon="lucide:graduation-cap" width="18" class="card-icon" />
          <h2 class="card-title">Academics</h2>
        </div>
        <div class="card-body">
          <ProfileField v-model="draft.studentId" label="Student ID" readonly :editing="editing" placeholder="Not set" />
          <ProfileField
            :model-value="draft.college"
            label="College"
            type="select"
            :options="collegeOptions"
            :editing="editing"
            @update:model-value="onCollegeChange"
          />
          <ProfileField
            v-model="draft.program"
            label="Program"
            type="select"
            :options="programOptions"
            :editing="editing"
          />
          <ProfileField
            v-model="draft.yearLevel"
            label="Year level"
            type="select"
            :options="yearOptions"
            :editing="editing"
          />
        </div>
      </section>

      <!-- Emergency Contact Card -->
      <section class="card-section">
        <div class="card-header">
          <IconifyIcon icon="lucide:phone-forwarded" width="18" class="card-icon" />
          <h2 class="card-title">Emergency contact</h2>
        </div>
        <div class="card-body">
          <ProfileField v-model="draft.emergencyName" label="Name" :editing="editing" />
          <ProfileField v-model="draft.emergencyRelation" label="Relationship" :editing="editing" placeholder="Parent, guardian…" />
          <ProfileField v-model="draft.emergencyPhone" label="Phone" type="tel" :editing="editing" placeholder="+63…" />
        </div>
      </section>

      <!-- Verification Card -->
      <section class="card-section">
        <div class="card-header">
          <IconifyIcon icon="lucide:shield-check" width="18" class="card-icon" />
          <h2 class="card-title">Verification</h2>
          <span v-if="pendingDocs > 0" class="badge">{{ pendingDocs }} pending</span>
        </div>
        <div class="card-body">
          <div v-if="documents.length">
            <div v-for="doc in documents" :key="doc.id" class="doc-row">
              <span class="doc-icon" :class="`doc-icon--${doc.tone}`">
                <IconifyIcon :icon="doc.icon" width="14" />
              </span>
              <div class="doc-info">
                <span class="doc-name">{{ doc.label }}</span>
                <span class="doc-when">{{ doc.when }}</span>
              </div>
              <span class="doc-tag" :class="`doc-tag--${doc.tone}`">{{ doc.statusLabel }}</span>
            </div>
          </div>
          <p v-else class="empty-message">You haven't submitted any documents yet</p>
          <button class="row-link" @click="go('/student/support')">
            <IconifyIcon icon="lucide:arrow-right" width="16" />
            <span>Open OSAS verification</span>
          </button>
        </div>
      </section>

      <!-- History Card -->
      <section v-if="history.length" class="card-section">
        <div class="card-header">
          <IconifyIcon icon="lucide:clock" width="18" class="card-icon" />
          <h2 class="card-title">Where you've stayed</h2>
        </div>
        <div class="card-body">
          <div v-for="row in history" :key="row.id" class="history-row">
            <div class="history-info">
              <span class="history-name">{{ row.name }}</span>
              <span class="history-meta">{{ row.meta }}</span>
            </div>
            <span class="history-when">{{ row.period }}</span>
          </div>
        </div>
      </section>

      <!-- Settings Card -->
      <section class="card-section">
        <div class="card-header">
          <IconifyIcon icon="lucide:settings" width="18" class="card-icon" />
          <h2 class="card-title">Settings</h2>
        </div>
        <div class="card-body">
          <button class="row-link" @click="go('/student/payments')">
            <IconifyIcon icon="lucide:wallet-cards" width="16" />
            <span>Payments</span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
          </button>
          <button class="row-link" @click="passwordOpen = true">
            <IconifyIcon icon="lucide:lock" width="16" />
            <span>Change password</span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
          </button>
          <button class="row-link row-danger" @click="signOut">
            <IconifyIcon icon="lucide:log-out" width="16" />
            <span>Sign out</span>
          </button>
        </div>
      </section>

      <!-- Edit bar -->
      <div v-if="editing" class="edit-bar">
        <button class="edit-btn-cancel" :disabled="saving" @click="cancelEdit">Cancel</button>
        <button class="edit-btn-save" :disabled="saving" @click="save">
          {{ saving ? 'Saving…' : 'Save changes' }}
        </button>
      </div>
    </div>

    <ChangePasswordDialog v-model="passwordOpen" />

    <!-- Improved QR Dialog -->
    <q-dialog v-model="qrDialog" position="top" class="qr-dialog">
      <div class="qr-card">
        <div class="qr-header">
          <IconifyIcon icon="lucide:shield-check" width="24" class="qr-header-icon" />
          <h3 class="qr-title">Verification QR</h3>
        </div>
        <p class="qr-sub">
          Scan this code to verify your identity with OSAS or your accommodation manager.
        </p>
        <div class="qr-image-wrapper">
          <img :src="qrImageUrl" alt="Verification QR Code" class="qr-image" width="220" height="220" loading="lazy" />
        </div>
        <p class="qr-id">ID: {{ userId }}</p>
        <div class="qr-actions">
          <q-btn flat dense no-caps color="primary" label="Download" class="qr-download" @click="downloadQR" />
          <q-btn flat dense no-caps color="grey-7" label="Close" class="qr-close" @click="qrDialog = false" />
        </div>
      </div>
    </q-dialog>
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
import { DOC_LABEL, docPresentation, statusPresentation, memberSince, ago, period } from '@/utils/profile'
import {
  collegeOptions,
  collegePrograms,
  yearOptions,
  yearLevelFromLabel,
  yearLevelToLabel,
} from '@/constants/academics'

interface DocRow {
  id: string
  label: string
  statusLabel: string
  tone: string
  icon: string
  when: string
}
interface HistoryRow {
  id: string
  name: string
  meta: string
  period: string
}
interface Stay {
  accommodationName: string
  roomNumber: string | null
}

const router = useRouter()
const $q = useQuasar()

const loading = ref(true)
const saving = ref(false)
const error = ref('')
const editing = ref(false)
const passwordOpen = ref(false)
const qrDialog = ref(false)

const userId = ref('')
const avatarUrl = ref<string | null>(null)
const avatarInput = ref<HTMLInputElement | null>(null)

const me = reactive({
  fullName: '',
  email: '',
  phone: '',
  initials: '?',
  status: 'unverified',
})
const academics = reactive({
  studentId: '',
  college: '',
  program: '',
  yearLevel: '',
})
const emergency = reactive({
  name: '',
  relation: '',
  phone: '',
})

const draft = reactive({
  fullName: '',
  phone: '',
  email: '',
  studentId: '',
  college: '',
  program: '',
  yearLevel: '',
  emergencyName: '',
  emergencyRelation: '',
  emergencyPhone: '',
})

const createdAt = ref<string | null>(null)
const updatedAt = ref<string | null>(null)
const stay = ref<Stay | null>(null)
const documents = ref<DocRow[]>([])
const history = ref<HistoryRow[]>([])

const status = computed(() => statusPresentation(me.status))
const memberSinceLabel = computed(() => memberSince(createdAt.value))
const pendingDocs = computed(() => documents.value.filter(d => d.tone === 'warn').length)

const qrImageUrl = computed(() => {
  if (!userId.value) return ''
  return `https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${encodeURIComponent(userId.value)}`
})

const courseLine = computed(() => {
  const parts = [academics.program, yearLevelToLabel(Number(academics.yearLevel) || null)].filter(Boolean)
  return parts.length ? parts.join(' · ') : 'Student'
})

const programOptions = computed(() => collegePrograms[draft.college] ?? [])

function onCollegeChange(next: string) {
  draft.college = next
  if (!(collegePrograms[next] ?? []).includes(draft.program)) draft.program = ''
}

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
  Object.assign(draft, {
    fullName: me.fullName,
    phone: me.phone,
    email: me.email,
    studentId: academics.studentId,
    college: academics.college,
    program: academics.program,
    yearLevel: academics.yearLevel,
    emergencyName: emergency.name,
    emergencyRelation: emergency.relation,
    emergencyPhone: emergency.phone,
  })
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

    const { error: userError } = await supabase
      .from('users')
      .update({ full_name: name, phone, initials })
      .eq('id', userId.value)
    if (userError) throw userError

    const contact = {
      name: draft.emergencyName.trim(),
      relationship: draft.emergencyRelation.trim(),
      phone: draft.emergencyPhone.trim() ? normalizePhPhone(draft.emergencyPhone) : '',
    }
    const hasContact = Boolean(contact.name || contact.relationship || contact.phone)

    const { error: profileError } = await supabase.from('student_profiles').upsert(
      {
        user_id: userId.value,
        college: draft.college || null,
        program: draft.program || null,
        year_level: draft.yearLevel ? yearLevelFromLabel(draft.yearLevel) : null,
        emergency_contact_json: hasContact ? contact : null,
      },
      { onConflict: 'user_id' },
    )
    if (profileError) throw profileError

    me.fullName = name
    me.phone = phone
    me.initials = initials
    academics.college = draft.college
    academics.program = draft.program
    academics.yearLevel = draft.yearLevel
    emergency.name = contact.name
    emergency.relation = contact.relationship
    emergency.phone = contact.phone
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

async function downloadQR() {
  try {
    const response = await fetch(qrImageUrl.value)
    const blob = await response.blob()
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `verification-qr-${userId.value}.png`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)
    $q.notify({ type: 'positive', message: 'QR code downloaded.' })
  } catch {
    $q.notify({ type: 'negative', message: 'Could not download QR code.' })
  }
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

    const [{ data: profile, error: profileError }, { data: studentProfile }] = await Promise.all([
      supabase
        .from('users')
        .select('full_name, email, phone, initials, status, created_at, updated_at')
        .eq('id', user.id)
        .maybeSingle(),
      supabase
        .from('student_profiles')
        .select('student_id, college, program, year_level, emergency_contact_json')
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

    const metadata = user.user_metadata as Record<string, unknown> | undefined
    const picture =
      typeof metadata?.avatar_url === 'string'
        ? metadata.avatar_url
        : typeof metadata?.picture === 'string'
          ? metadata.picture
          : ''
    avatarUrl.value = picture ? resolveAsset(picture) : null

    academics.studentId = studentProfile?.student_id || ''
    academics.college = studentProfile?.college || ''
    academics.program = studentProfile?.program || ''
    academics.yearLevel = yearLevelToLabel(studentProfile?.year_level)

    const contact = (studentProfile?.emergency_contact_json ?? null) as {
      name?: string
      relationship?: string
      phone?: string
    } | null
    emergency.name = contact?.name || ''
    emergency.relation = contact?.relationship || ''
    emergency.phone = contact?.phone || ''

    Object.assign(draft, {
      fullName: me.fullName,
      phone: me.phone,
      email: me.email,
      studentId: academics.studentId,
      college: academics.college,
      program: academics.program,
      yearLevel: academics.yearLevel,
      emergencyName: emergency.name,
      emergencyRelation: emergency.relation,
      emergencyPhone: emergency.phone,
    })

    const { data: leaseRow } = await supabase
      .from('leases')
      .select('rooms(room_number, accommodations(name))')
      .eq('student_id', user.id)
      .in('status', ['active', 'pending', 'leave_requested'])
      .order('start_date', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (leaseRow) {
      const room = leaseRow.rooms as unknown as {
        room_number: string | null
        accommodations: { name: string } | null
      } | null
      stay.value = {
        accommodationName: room?.accommodations?.name || 'Your accommodation',
        roomNumber: room?.room_number ?? null,
      }
    }

    const [{ data: docs }, { data: past }] = await Promise.all([
      supabase
        .from('verification_documents')
        .select('id, doc_type, status, uploaded_at, verified_at')
        .eq('user_id', user.id)
        .order('uploaded_at', { ascending: false }),
      supabase
        .from('boarding_history')
        .select('id, accommodation_name, room_type, period_start, period_end, end_reason')
        .eq('student_id', user.id)
        .order('period_start', { ascending: false })
        .limit(5),
    ])

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

    history.value = (past || []).map((h) => ({
      id: h.id,
      name: h.accommodation_name || 'Accommodation',
      meta: [h.room_type, h.end_reason].filter(Boolean).join(' · ') || 'Stay',
      period: period(h.period_start, h.period_end),
    }))
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
  padding-bottom: 20px;
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 12px var(--m-page-gutter) 80px;
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
  background: var(--m-surface);
  border-radius: var(--m-radius);
  border: 1px solid var(--m-border);
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0,0,0,0.02);
}
.hero-cover {
  height: 60px;
  background: linear-gradient(135deg, var(--m-primary) 0%, var(--m-primary-dark) 100%);
}
.hero-content {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 0 14px 12px;
  margin-top: -30px;
}
.hero-avatar-wrapper {
  position: relative;
  flex: 0 0 72px;
  width: 72px;
  height: 72px;
  border-radius: 999px;
  border: 3px solid var(--m-surface);
  background: var(--m-primary);
  cursor: pointer;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
}
.hero-avatar {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.hero-avatar-wrapper .hero-avatar {
  font-size: 28px;
  font-weight: 700;
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
}
.hero-avatar-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0,0,0,0.35);
  color: #fff;
  opacity: 0;
  transition: opacity 0.2s;
}
.hero-avatar-wrapper:hover .hero-avatar-overlay {
  opacity: 1;
}
.hidden-input {
  display: none;
}
.hero-meta {
  flex: 1;
  min-width: 0;
}
.hero-name {
  margin: 0;
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
  color: var(--m-ink);
  line-height: 1.2;
}
.hero-role {
  margin: 0;
  font-size: 13px;
  color: var(--m-muted);
}
.hero-tag {
  display: inline-block;
  margin-top: 4px;
  padding: 2px 10px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
.hero-tag--good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.hero-tag--idle {
  background: rgba(255, 255, 255, 0.22);
  color: #fff;
}
.hero-tag--warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.hero-tag--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.hero-stats {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 14px 12px;
  border-top: 1px solid var(--m-border);
  flex-wrap: wrap;
}
.stat {
  display: flex;
  flex-direction: column;
  align-items: center;
}
.stat-value {
  font-size: 18px;
  font-weight: 700;
  color: var(--m-ink);
  line-height: 1.2;
}
.stat-label {
  font-size: 10px;
  font-weight: 600;
  color: var(--m-muted);
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.stat-divider {
  width: 1px;
  height: 28px;
  background: var(--m-border);
}
.stat-action {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin-left: auto;
  padding: 4px 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  font-size: 12px;
  font-weight: 600;
  color: var(--m-primary-dark);
  cursor: pointer;
  transition: background 0.15s;
}
.stat-action:hover {
  background: var(--m-primary-soft);
}
.card-section {
  background: var(--m-surface);
  border-radius: var(--m-radius);
  border: 1px solid var(--m-border);
  overflow: hidden;
}
.card-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  border-bottom: 1px solid var(--m-border);
}
.card-icon {
  color: var(--m-primary-dark);
  opacity: 0.7;
}
.card-title {
  margin: 0;
  font-size: 13px;
  font-weight: 700;
  color: var(--m-ink);
  text-transform: uppercase;
  letter-spacing: 0.03em;
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
.icon-btn {
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
.icon-btn:hover {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.card-body {
  padding: 4px 0;
}
.card-body > * {
  border-bottom: 1px solid var(--m-border);
  padding: 8px 14px;
}
.card-body > *:last-child {
  border-bottom: none;
}
.doc-row {
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
.doc-icon--good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.doc-icon--idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.doc-icon--warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.doc-icon--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.doc-info {
  flex: 1;
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
}
.doc-tag--good {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.doc-tag--idle {
  background: var(--m-bg);
  color: var(--m-muted);
}
.doc-tag--warn {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.doc-tag--danger {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.empty-message {
  margin: 0;
  font-size: 13px;
  color: var(--m-muted);
  text-align: center;
  padding: 16px 0;
}
.row-link {
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
}
.row-link:hover {
  background: var(--m-bg);
}
.row-link .chevron {
  margin-left: auto;
  color: var(--m-muted);
}
.row-danger {
  color: var(--m-danger);
}
.row-danger:hover {
  background: var(--m-danger-soft);
}
.edit-row {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  margin-top: -4px;
}
.edit-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 18px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  font-size: 13px;
  font-weight: 600;
  color: var(--m-primary-dark);
  cursor: pointer;
  transition: background 0.15s;
}
.edit-btn:hover {
  background: var(--m-primary-soft);
}
.member-since {
  margin: 0;
  font-size: 12px;
  color: var(--m-muted);
}
.updated {
  color: var(--m-muted);
  opacity: 0.7;
}
.stay-info {
  display: flex;
  align-items: center;
  gap: 6px;
  flex: 1;
}
.stay-icon {
  color: var(--m-primary-dark);
  opacity: 0.7;
}
.stay-name {
  font-weight: 600;
  color: var(--m-ink);
}
.stay-room {
  color: var(--m-muted);
  font-size: 13px;
}
.history-row {
  display: flex;
  align-items: center;
  gap: 10px;
}
.history-info {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
}
.history-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--m-ink);
}
.history-meta {
  font-size: 11px;
  color: var(--m-muted);
}
.history-when {
  font-size: 11px;
  color: var(--m-muted);
  white-space: nowrap;
}
.edit-bar {
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
  box-shadow: 0 -6px 20px rgba(0,0,0,0.06);
  animation: slideUp 0.2s ease;
}
.edit-btn-cancel,
.edit-btn-save {
  padding: 8px 18px;
  border: 0;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.15s;
}
.edit-btn-cancel {
  background: transparent;
  color: var(--m-muted);
}
.edit-btn-cancel:hover {
  background: var(--m-bg);
}
.edit-btn-save {
  background: var(--m-primary);
  color: #fff;
}
.edit-btn-save:hover {
  background: var(--m-primary-dark);
}
.edit-btn-cancel:disabled,
.edit-btn-save:disabled {
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
  .edit-bar {
    animation: none;
  }
}

/* QR Dialog */
.qr-dialog :deep(.q-dialog__backdrop) {
  background: rgba(0,0,0,0.5);
}
.qr-card {
  margin: 10% auto 0;
  max-width: 360px;
  padding: 24px 20px 20px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  box-shadow: 0 16px 48px rgba(0,0,0,0.15);
  text-align: center;
}
.qr-header {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-bottom: 4px;
}
.qr-header-icon {
  color: var(--m-primary);
}
.qr-title {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  color: var(--m-ink);
}
.qr-sub {
  margin: 4px 0 16px;
  font-size: 13px;
  color: var(--m-muted);
  line-height: 1.4;
}
.qr-image-wrapper {
  display: flex;
  justify-content: center;
  padding: 8px;
  background: #fff;
  border-radius: var(--m-radius-sm);
  border: 1px solid var(--m-border);
  margin-bottom: 8px;
}
.qr-image {
  display: block;
  width: 220px;
  height: 220px;
  object-fit: contain;
}
.qr-id {
  font-size: 12px;
  font-weight: 500;
  color: var(--m-muted);
  margin: 0 0 16px;
  word-break: break-all;
  background: var(--m-bg);
  padding: 4px 8px;
  border-radius: 4px;
  display: inline-block;
}
.qr-actions {
  display: flex;
  gap: 8px;
  justify-content: center;
}
.qr-download,
.qr-close {
  font-weight: 600;
  padding: 6px 18px;
  border-radius: 999px;
}
.qr-download {
  background: var(--m-primary);
  color: #fff;
}
.qr-download:hover {
  background: var(--m-primary-dark);
}
.qr-close {
  background: transparent;
  color: var(--m-muted);
}
.qr-close:hover {
  background: var(--m-bg);
}
</style>