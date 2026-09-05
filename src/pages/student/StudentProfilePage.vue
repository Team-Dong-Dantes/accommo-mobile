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
      <ProfileHero
        v-model:avatar-url="avatarUrl"
        :initials="me.initials"
        :user-id="userId"
        :name="me.fullName || 'Your name'"
        :subtitle="courseLine || 'Student'"
        :status-tone="status.tone || 'warn'"
        :status-label="status.label || 'Unverified'"
        action-icon="lucide:qr-code"
        action-label="My QR"
        @action="qrDialog = true"
      >
        <component :is="stay ? 'button' : 'div'" class="stay-info" v-bind="stay ? { type: 'button' } : {}" @click="stay && go('/student/stay')">
          <span class="stay-badge">
            <IconifyIcon icon="lucide:home" width="18" />
          </span>
          <div class="stay-text">
            <span class="stay-name">{{ stay ? stay.accommodationName : 'No active stay' }}</span>
            <span v-if="stay && stay.roomNumber" class="stay-room">Room {{ stay.roomNumber }}</span>
            <span v-if="stayStatusNote" class="stay-note">{{ stayStatusNote }}</span>
          </div>
          <IconifyIcon v-if="stay" icon="lucide:chevron-right" width="16" class="stay-chevron" />
        </component>
      </ProfileHero>

      <!-- Profile -->
      <ProfileCard>
        <template #always>
          <ProfileBlock icon="lucide:user" title="Your details">
            <template #actions>
              <EditButton v-if="!editing" @click="startEdit" />
            </template>
            <ProfileField v-model="draft.fullName" label="Full name" :editing="editing" />
            <ProfileField v-model="draft.phone" label="Phone" type="tel" :editing="editing" placeholder="+63…" />
            <ProfileField v-model="draft.email" label="Email" readonly :editing="editing" />
          </ProfileBlock>
        </template>

        <template #more>
          <ProfileBlock icon="lucide:graduation-cap" title="Academics">
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
          </ProfileBlock>

          <ProfileBlock icon="lucide:phone-forwarded" title="Emergency contact">
            <ProfileField v-model="draft.emergencyName" label="Name" :editing="editing" />
            <ProfileField v-model="draft.emergencyRelation" label="Relationship" :editing="editing" placeholder="Parent, guardian…" />
            <ProfileField v-model="draft.emergencyPhone" label="Phone" type="tel" :editing="editing" placeholder="+63…" />
          </ProfileBlock>

          <ProfileBlock icon="lucide:shield-check" title="Verification" :badge="pendingDocs > 0 ? `${pendingDocs} pending` : ''">
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
          </ProfileBlock>

        </template>

        <template #footer>
          Member since {{ memberSinceLabel || 'recently' }}
          <span v-if="updatedAt" class="updated">· Updated {{ ago(updatedAt) }}</span>
        </template>
      </ProfileCard>

      <!-- Settings -->
      <ProfileSettingsSection
        :user-id="userId"
        :email="me.email"
        :notification-prefs="notificationPrefs"
      />

      <!-- Edit bar -->
      <div v-if="editing" class="edit-bar">
        <button class="edit-btn-cancel" :disabled="saving" @click="cancelEdit">Cancel</button>
        <button class="edit-btn-save" :disabled="saving" @click="save">
          {{ saving ? 'Saving…' : 'Save changes' }}
        </button>
      </div>
    </div>

    <!-- My QR -->
    <q-dialog v-model="qrDialog" position="bottom" class="qr-dialog">
      <div class="qr-card">
        <span class="qr-grip" aria-hidden="true" />
        <template v-if="osasVerified && qrDataUrl">
          <div class="qr-header">
            <IconifyIcon icon="lucide:shield-check" width="24" class="qr-header-icon" />
            <h3 class="qr-title">My student QR</h3>
          </div>
          <p class="qr-sub">
            Show this code at check-in so your manager can confirm you're an active, verified student.
          </p>
          <div class="qr-image-wrapper">
            <img :src="qrDataUrl" alt="Your student QR code" class="qr-image" width="220" height="220" />
          </div>
          <p class="qr-id">ID: {{ academics.studentId }}</p>
          <div class="qr-actions">
            <q-btn flat dense no-caps color="primary" label="Download" class="qr-download" @click="downloadQR" />
            <q-btn flat dense no-caps color="grey-7" label="Close" class="qr-close" @click="qrDialog = false" />
          </div>
        </template>
        <template v-else-if="!osasVerified">
          <div class="qr-locked">
            <span class="qr-locked-icon"><IconifyIcon icon="lucide:lock-keyhole" width="26" /></span>
            <p class="qr-locked-title">QR code locked</p>
            <p class="qr-locked-sub">Get verified by OSAS to unlock your student QR code.</p>
            <q-btn unelevated no-caps color="primary" class="qr-locked-cta" label="Verify with OSAS" @click="qrDialog = false; go('/student/support')" />
          </div>
        </template>
        <template v-else>
          <div class="qr-locked">
            <span class="qr-locked-icon"><IconifyIcon icon="lucide:circle-alert" width="26" /></span>
            <p class="qr-locked-title">Student ID missing</p>
            <p class="qr-locked-sub">Your account doesn't have a student ID on file yet, so a QR code can't be generated. Contact OSAS to have it added.</p>
            <q-btn unelevated no-caps color="primary" class="qr-locked-cta" label="Contact OSAS" @click="qrDialog = false; go('/student/support')" />
          </div>
        </template>
      </div>
    </q-dialog>

  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import QRCode from 'qrcode'
import { supabase } from '@/utils/supabase'
import { initialsOf, normalizePhPhone } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { useNotify } from '@/utils/notify'
import ProfileField from '@/components/shared/ProfileField.vue'
import ProfileHero from '@/components/shared/ProfileHero.vue'
import ProfileCard from '@/components/shared/ProfileCard.vue'
import ProfileBlock from '@/components/shared/ProfileBlock.vue'
import EditButton from '@/components/shared/EditButton.vue'
import ProfileSettingsSection from '@/components/student/ProfileSettingsSection.vue'
import { DOC_LABEL, docPresentation, statusPresentation, memberSince, ago } from '@/utils/profile'
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
interface Stay {
  leaseId: string
  managerId: string
  accommodationName: string
  roomNumber: string | null
  status: 'active' | 'pending' | 'leave_requested'
}

const router = useRouter()
const notify = useNotify()

const loading = ref(true)
const saving = ref(false)
const error = ref('')
const editing = ref(false)
const qrDialog = ref(false)

const userId = ref('')
const avatarUrl = ref<string | null>(null)
const notificationPrefs = reactive({ push: true, email: true })

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

const status = computed(() => statusPresentation(me.status))
const stayStatusNote = computed(() => {
  if (stay.value?.status === 'pending') return 'Application pending — awaiting manager decision'
  if (stay.value?.status === 'leave_requested') return 'Leave requested — awaiting manager decision'
  return ''
})
const memberSinceLabel = computed(() => memberSince(createdAt.value))
const pendingDocs = computed(() => documents.value.filter(d => d.tone === 'warn').length)

const osasVerifiedAt = ref<string | null>(null)
const osasVerified = computed(() => !!osasVerifiedAt.value)
const qrDataUrl = ref('')

async function generateQr() {
  const id = academics.studentId
  if (!id) {
    qrDataUrl.value = ''
    return
  }
  try {
    qrDataUrl.value = await QRCode.toDataURL(id, {
      width: 220,
      margin: 1,
      color: { dark: '#111827', light: '#ffffff' },
    })
  } catch {
    qrDataUrl.value = ''
  }
}

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
    notify.error('Your name cannot be empty.')
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
    notify.success('Profile updated.')
  } catch (e) {
    notify.error(e instanceof Error ? e.message : 'Could not save.')
  } finally {
    saving.value = false
  }
}

function downloadQR() {
  if (!qrDataUrl.value) return
  const link = document.createElement('a')
  link.href = qrDataUrl.value
  link.download = `student-qr-${academics.studentId}.png`
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  notify.success('QR code downloaded.')
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
        .select('full_name, email, phone, initials, status, created_at, updated_at, notification_prefs')
        .eq('id', user.id)
        .maybeSingle(),
      supabase
        .from('student_profiles')
        .select('student_id, college, program, year_level, emergency_contact_json, osas_verified_at')
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

    osasVerifiedAt.value = studentProfile?.osas_verified_at ?? null
    qrDataUrl.value = ''
    if (osasVerified.value && academics.studentId) {
      await generateQr()
    }

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
      .select('id, status, accommodation_manager_id, rooms(room_number, accommodations(name))')
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
        leaseId: leaseRow.id,
        managerId: leaseRow.accommodation_manager_id,
        accommodationName: room?.accommodations?.name || 'Your accommodation',
        roomNumber: room?.room_number ?? null,
        status: leaseRow.status as Stay['status'],
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
.updated {
  color: var(--m-muted);
  opacity: 0.7;
}
.stay-info {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  padding: 0;
  border: 0;
  background: transparent;
  font: inherit;
  text-align: left;
  color: inherit;
}
.stay-badge {
  display: flex;
  flex: 0 0 36px;
  width: 36px;
  height: 36px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.stay-text {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
}
.stay-name {
  font-weight: 600;
  color: var(--m-ink);
}
.stay-room {
  color: var(--m-muted);
  font-size: 13px;
}
.stay-note {
  color: var(--m-warning);
  font-size: 12px;
  font-weight: 600;
}
.stay-chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
}
button.stay-info {
  cursor: pointer;
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
  width: 100%;
  max-width: 480px;
  margin: 0 auto;
  padding: 10px 20px calc(20px + env(safe-area-inset-bottom, 0px));
  border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0;
  background: var(--m-surface);
  box-shadow: 0 -8px 30px rgba(0,0,0,0.14);
  text-align: center;
}
.qr-grip {
  display: block;
  width: 40px;
  height: 4px;
  margin: 0 auto 14px;
  border-radius: 999px;
  background: var(--m-border);
}
.qr-locked {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 12px 0 4px;
}
.qr-locked-icon {
  display: grid;
  width: 52px;
  height: 52px;
  margin-bottom: 12px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
}
.qr-locked-title {
  margin: 0;
  font-size: 15px;
  font-weight: 700;
  color: var(--m-ink);
}
.qr-locked-sub {
  margin: 6px 0 16px;
  font-size: 13px;
  color: var(--m-muted);
  line-height: 1.4;
}
.qr-locked-cta {
  width: 100%;
  min-height: 44px;
  border-radius: var(--m-radius-sm);
  font-weight: 700;
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