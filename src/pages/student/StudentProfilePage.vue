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
      <!-- Who you are, and where you currently live -->
      <div class="hero">
        <div class="hero-top">
          <span class="hero-avatar">{{ me.initials }}</span>
          <span class="hero-id">
            <span class="hero-name">{{ me.fullName }}</span>
            <span class="hero-role">{{ courseLine }}</span>
          </span>
          <span class="hero-tag" :class="`hero-tag--${status.tone}`">{{ status.label }}</span>
        </div>
        <div class="hero-foot">
          <span v-if="stay"><b>{{ stay.accommodationName }}</b></span>
          <span v-if="stay && stay.roomNumber">Room {{ stay.roomNumber }}</span>
          <span v-if="!stay">No active stay</span>
        </div>
      </div>

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

      <!-- Student ID is verified by OSAS, so it stays read-only -->
      <section class="sec">
        <h2 class="sec-title">Academics</h2>
        <div class="group">
          <ProfileField
            v-model="draft.studentId"
            label="Student ID"
            readonly
            :editing="editing"
            placeholder="Not set"
          />
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

      <section class="sec">
        <h2 class="sec-title">Emergency contact</h2>
        <div class="group">
          <ProfileField v-model="draft.emergencyName" label="Name" :editing="editing" />
          <ProfileField
            v-model="draft.emergencyRelation"
            label="Relationship"
            :editing="editing"
            placeholder="Parent, guardian…"
          />
          <ProfileField
            v-model="draft.emergencyPhone"
            label="Phone"
            type="tel"
            :editing="editing"
            placeholder="+63…"
          />
        </div>
      </section>

      <section class="sec">
        <h2 class="sec-title">Verification</h2>
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

          <button type="button" class="row" @click="go('/student/support')">
            <span class="row-icon"><IconifyIcon icon="lucide:shield-check" width="16" /></span>
            <span class="row-label">Open OSAS verification</span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="row-chev" />
          </button>
        </div>
      </section>

      <section v-if="history.length" class="sec">
        <h2 class="sec-title">Where you've stayed</h2>
        <div class="group">
          <div v-for="row in history" :key="row.id" class="hist">
            <span class="hist-body">
              <span class="hist-name">{{ row.name }}</span>
              <span class="hist-meta">{{ row.meta }}</span>
            </span>
            <span class="hist-when">{{ row.period }}</span>
          </div>
        </div>
      </section>

      <section class="sec">
        <h2 class="sec-title">Settings</h2>
        <div class="group">
          <button type="button" class="row" @click="go('/student/payments')">
            <span class="row-icon"><IconifyIcon icon="lucide:wallet-cards" width="16" /></span>
            <span class="row-label">Payments</span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="row-chev" />
          </button>
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

      <p class="since">Member since {{ memberSinceLabel }}</p>
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

const userId = ref('')
const me = reactive({ fullName: '', email: '', phone: '', initials: '?', status: 'unverified' })
const academics = reactive({ studentId: '', college: '', program: '', yearLevel: '' })
const emergency = reactive({ name: '', relation: '', phone: '' })

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
const stay = ref<Stay | null>(null)
const documents = ref<DocRow[]>([])
const history = ref<HistoryRow[]>([])

const status = computed(() => statusPresentation(me.status))
const memberSinceLabel = computed(() => memberSince(createdAt.value))

const courseLine = computed(() => {
  const parts = [academics.program, yearLevelToLabel(Number(academics.yearLevel) || null)].filter(Boolean)
  return parts.length ? parts.join(' · ') : 'Student'
})

const programOptions = computed(() => collegePrograms[draft.college] ?? [])

// Only a deliberate college change clears the program. A watcher would also
// fire while the draft is being seeded, wiping a stored program that happens
// not to match its college's list before the student has touched anything.
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

    // An emergency contact is only stored once it has something in it, so a
    // half-filled form never writes an object of empty strings.
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

    const [{ data: profile, error: profileError }, { data: studentProfile }] = await Promise.all([
      supabase
        .from('users')
        .select('full_name, email, phone, initials, status, created_at')
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

<style scoped src="@/css/profile.css"></style>
