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
          <span class="hero-avatar">{{ me.initials }}</span>
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

          <button type="button" class="row" @click="go('/manager/osas-compliance')">
            <span class="row-icon"><IconifyIcon icon="lucide:shield-check" width="16" /></span>
            <span class="row-label">Open OSAS compliance</span>
            <IconifyIcon icon="lucide:chevron-right" width="16" class="row-chev" />
          </button>
        </div>
      </section>

      <section class="sec">
        <h2 class="sec-title">Your accommodations</h2>
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
const me = reactive({ fullName: '', email: '', phone: '', initials: '?', status: 'unverified' })
const draft = reactive({ fullName: '', phone: '', email: '' })

const createdAt = ref<string | null>(null)
const responseRate = ref<number | null>(null)
const accommodationCount = ref(0)
const tenantCount = ref(0)
const documents = ref<DocRow[]>([])

const status = computed(() => statusPresentation(me.status))
const memberSinceLabel = computed(() => memberSince(createdAt.value))

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
  // Drop the draft; the next Edit re-seeds it from what was actually saved.
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
        .select('full_name, email, phone, initials, status, created_at')
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
    // Left null rather than shown as 0% — an unmeasured rate is not a bad one.
    responseRate.value = managerProfile?.response_rate ?? null

    Object.assign(draft, { fullName: me.fullName, phone: me.phone, email: me.email })

    // The portfolio, and the tenants actually housed in it. Occupancy comes from
    // active leases because rooms.current_pax is not maintained.
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

<style scoped src="@/css/profile.css"></style>
