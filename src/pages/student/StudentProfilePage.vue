<template>
  <q-page class="prof">
    <!-- Loading -->
    <div v-if="loading" class="stack">
      <div class="sk-card">
        <div class="sk-hero-top">
          <q-skeleton type="circle" size="56px" />
          <div class="sk-hero-meta">
            <q-skeleton type="text" width="55%" height="17px" />
            <q-skeleton type="text" width="40%" height="12px" />
          </div>
        </div>
        <div class="sk-hero-row">
          <q-skeleton type="circle" size="36px" />
          <div class="sk-hero-meta">
            <q-skeleton type="text" width="60%" height="14px" />
            <q-skeleton type="text" width="30%" height="11px" />
          </div>
        </div>
      </div>
      <div class="sk-card sk-fields">
        <q-skeleton type="text" width="45%" height="13px" />
        <q-skeleton type="text" width="90%" height="15px" />
        <q-skeleton type="text" width="90%" height="15px" />
        <q-skeleton type="text" width="90%" height="15px" />
      </div>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card card--pad text-center">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your profile</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load()" />
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
        @action="go('/student/profile/qr')"
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
            <EmptyState v-else variant="compact" icon="lucide:file-text" title="No documents yet" message="Documents you submit to OSAS show up here." />
            <button class="row-link" @click="go('/student/support')">
              <IconifyIcon icon="lucide:arrow-right" width="16" />
              <span>Open OSAS verification</span>
            </button>
          </ProfileBlock>

          <ProfileBlock icon="lucide:settings" title="Settings">
            <button class="row-link" @click="go('/student/profile/settings')">
              <IconifyIcon icon="lucide:sliders-horizontal" width="16" />
              <span>Notifications, security, appearance &amp; more</span>
            </button>
          </ProfileBlock>
        </template>

        <template #footer>
          Member since {{ memberSinceLabel || 'recently' }}
          <span v-if="updatedAt" class="updated">· Updated {{ ago(updatedAt) }}</span>
        </template>
      </ProfileCard>

      <!-- Edit bar -->
      <div v-if="editing" class="edit-bar">
        <button class="edit-btn-cancel" :disabled="saving" @click="cancelEdit">Cancel</button>
        <button class="edit-btn-save" :disabled="saving" @click="save">
          {{ saving ? 'Saving…' : 'Save changes' }}
        </button>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { initialsOf, normalizePhPhone } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { useNotify } from '@/utils/notify'
import ProfileField from '@/components/shared/ProfileField.vue'
import ProfileHero from '@/components/shared/ProfileHero.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import ProfileCard from '@/components/shared/ProfileCard.vue'
import ProfileBlock from '@/components/shared/ProfileBlock.vue'
import EditButton from '@/components/shared/EditButton.vue'
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

const userId = ref('')
const avatarUrl = ref<string | null>(null)

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

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data: auth } = await authUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }
    userId.value = user.id

    const [{ data: profile, error: profileError }, { data: studentProfile }] = await Promise.all([
      supabase
        .from('users')
        .select('full_name, email, phone, initials, status, created_at, updated_at, avatar_url')
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
    // users.avatar_url is the fallback, not just a mirror: this session's
    // cached metadata can be stale or empty (an avatar uploaded on another
    // device, or set straight in the database), and reading metadata alone
    // left the profile stuck on initials even though a photo existed.
    const storedAvatar = (profile as { avatar_url?: string | null } | null)?.avatar_url || ''
    avatarUrl.value = resolveAsset(picture || storedAvatar) || null

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

    // Never clobber an in-progress edit with a silent (realtime-triggered)
    // background refresh — only the real first load seeds the draft.
    if (!silent) {
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
    }

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

// Kept alive across tab switches (see MainLayout's KEEP_ALIVE_PAGES), so an
// OSAS verification decision pushes here instead of the page re-asking on
// return. utils/useLiveData.ts owns the whole policy — first load, the
// subscription's lifetime, and how stale the data may be on return.
useLiveData({
  key: 'student-profile',
  load,
  watch: (uid) => [{ table: 'verification_documents', filter: `user_id=eq.${uid}` }],
})
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
.sk-card {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.sk-hero-top,
.sk-hero-row {
  display: flex;
  align-items: center;
  gap: 12px;
}
.sk-hero-meta {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 6px;
}
.sk-fields {
  gap: 10px;
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
</style>