<template>
  <q-page class="cp">
    <div v-if="loading" class="stack">
      <div class="group">
        <div v-for="n in 3" :key="n" class="row">
          <span class="row-body">
            <span class="row-top">
              <q-skeleton type="text" width="35%" height="13px" />
              <q-skeleton type="text" width="50px" height="16px" />
            </span>
            <q-skeleton type="text" width="75%" height="12px" />
            <q-skeleton type="text" width="45%" height="11px" />
          </span>
        </div>
      </div>
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your concerns</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <EmptyState
      v-else-if="!rows.length"
      icon="lucide:message-square-warning"
      title="No concerns yet"
      message="Maintenance, safety and billing issues you raise will show up here, with each one's status and your manager's response."
    />

    <EmptyState
      v-else-if="!visibleRows.length"
      variant="compact"
      icon="lucide:search-x"
      title="Nothing matches"
      message="Try a different search or filter."
    />

    <div v-else class="stack">
      <div class="group">
        <button v-for="c in visibleRows" :key="c.id" type="button" class="row" @click="openDetail(c)">
          <span class="row-body">
            <span class="row-top">
              <span class="row-cat">{{ CONCERN_CATEGORY_LABEL[c.category] || c.category }}</span>
              <span class="row-chip" :class="`row-chip--${statusColor(CONCERN_STATUS, c.status)}`">{{ statusText(CONCERN_STATUS, c.status) }}</span>
            </span>
            <span class="row-desc">{{ c.description || 'No description' }}</span>
            <span class="row-when">{{ c.where }} · {{ since(c.reportedAt) }}</span>
          </span>
          <IconifyIcon icon="lucide:chevron-right" width="16" class="row-chevron" />
        </button>
      </div>
    </div>

    <!-- Search sits on the FAB's baseline so the two read as one control band -->
    <div v-if="!loading && !error" class="dock">
      <button
        type="button"
        class="dock-btn"
        :class="{ 'dock-btn--on': filter !== 'all' }"
        aria-label="Filters"
        @click="filtersOpen = true"
      >
        <IconifyIcon icon="lucide:sliders-horizontal" width="17" />
        <span v-if="filter !== 'all'" class="dock-dot">1</span>
      </button>
      <div class="dock-field">
        <IconifyIcon icon="lucide:search" width="16" class="dock-icon" />
        <input v-model="query" class="dock-input" type="search" placeholder="Search concerns" aria-label="Search concerns" />
      </div>
      <button
        type="button"
        class="dock-btn"
        :disabled="!activeLease"
        aria-label="Report a concern"
        @click="openNew"
      >
        <IconifyIcon icon="lucide:plus" width="18" />
      </button>
    </div>

    <q-dialog v-model="filtersOpen" position="bottom">
      <div class="sheet">
        <div class="sheet-head">
          <h2 class="sheet-title">Filters</h2>
          <button type="button" class="sheet-clear" @click="filter = 'all'">Reset</button>
        </div>
        <div class="sheet-block">
          <span class="sheet-label">Status</span>
          <div class="chips">
            <button
              v-for="f in FILTERS"
              :key="f.key"
              type="button"
              class="chip"
              :class="{ 'chip--on': filter === f.key }"
              @click="filter = f.key"
            >
              {{ f.label }}
            </button>
          </div>
        </div>
        <button type="button" class="sheet-done" @click="filtersOpen = false">Done</button>
      </div>
    </q-dialog>

    <q-dialog v-model="detailOpen" position="bottom">
      <q-card v-if="selected" class="detail-sheet">
        <div class="detail-head">
          <h3 class="detail-title">{{ CONCERN_CATEGORY_LABEL[selected.category] || selected.category }}</h3>
          <span class="detail-chip" :class="`detail-chip--${statusColor(CONCERN_STATUS, selected.status)}`">
            {{ statusText(CONCERN_STATUS, selected.status) }}
          </span>
        </div>

        <ul class="timeline">
          <li v-for="s in timeline" :key="s.key" class="tl-row">
            <span class="tl-rail">
              <span class="tl-dot" :class="{ 'tl-dot--done': s.done, 'tl-dot--bad': s.bad }" />
              <span class="tl-line" />
            </span>
            <span class="tl-body">
              <span class="tl-label" :class="{ 'tl-label--pending': !s.done }">{{ s.label }}</span>
              <span class="tl-when">{{ s.at ? `${since(s.at)} ago` : 'Pending' }}</span>
            </span>
          </li>
        </ul>

        <p class="detail-label">Your report</p>
        <p class="detail-text">{{ selected.description || 'No description given.' }}</p>
        <p class="detail-meta">{{ selected.where }}</p>
        <img v-if="selected.photoUrl" :src="selected.photoUrl" alt="" class="detail-photo" />

        <template v-if="selected.managerResponse">
          <p class="detail-label">Manager's response</p>
          <p class="detail-text">{{ selected.managerResponse }}</p>
        </template>

        <q-btn unelevated rounded no-caps color="primary" class="detail-close" label="Close" @click="detailOpen = false" />
      </q-card>
    </q-dialog>

    <q-dialog v-model="newOpen" position="bottom">
      <q-card class="new-sheet">
        <h3 class="new-title">Report a concern</h3>
        <label class="field">
          <span class="field-label">Category</span>
          <select v-model="form.category" class="field-input">
            <option v-for="(label, key) in CONCERN_CATEGORY_LABEL" :key="key" :value="key">{{ label }}</option>
          </select>
        </label>
        <label class="field">
          <span class="field-label">Description</span>
          <textarea v-model="form.description" class="field-input field-textarea" rows="4" placeholder="What's going on?" />
        </label>
        <label class="field">
          <span class="field-label">Photo (optional)</span>
          <span class="file-picker" :class="{ 'file-picker--chosen': form.photo }">
            <IconifyIcon :icon="form.photo ? 'lucide:file-check' : 'lucide:camera'" width="16" />
            <span class="file-picker-text">{{ form.photo ? form.photo.name : 'Attach a photo' }}</span>
            <input type="file" accept="image/*" class="file-picker-input" @change="onPhotoSelected" />
          </span>
        </label>
        <q-btn unelevated rounded no-caps color="primary" class="new-submit" :loading="submitting" label="Submit" @click="submit" />
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import type { RealtimeChannel } from '@supabase/supabase-js'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { CONCERN_STATUS, CONCERN_CATEGORY_LABEL, statusText, statusColor } from '@/utils/format'
import { since } from '@/utils/notifications'
import { useNotify } from '@/utils/notify'
import { createNotification } from '@/boot/notify'
import { uploadDocument } from '@/utils/upload'
import EmptyState from '@/components/shared/EmptyState.vue'

const FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'open', label: 'Open' },
  { key: 'in_progress', label: 'In progress' },
  { key: 'resolved', label: 'Resolved' },
] as const

interface Concern {
  id: string
  category: string
  description: string
  status: string
  reportedAt: string
  acknowledgedAt: string | null
  inProgressAt: string | null
  resolvedAt: string | null
  managerResponse: string
  photoUrl: string
  where: string
}

const notify = useNotify()

const loading = ref(true)
const error = ref('')
const rows = ref<Concern[]>([])
const query = ref('')
const filter = ref<(typeof FILTERS)[number]['key']>('all')
const filtersOpen = ref(false)

const activeLease = ref<{ id: string; managerId: string } | null>(null)

const detailOpen = ref(false)
const selected = ref<Concern | null>(null)
const newOpen = ref(false)
const submitting = ref(false)
const form = reactive({ category: 'maintenance', description: '', photo: null as File | null })

let channel: RealtimeChannel | null = null

// A single timeline replaces the old step-tracker + activity list: each row
// is "done" once its timestamp lands, so a rejected report still shows
// whatever acknowledgement/in-progress steps actually happened before it closed.
const timeline = computed(() => {
  if (!selected.value) return []
  const c = selected.value
  const closed = c.status === 'resolved' || c.status === 'rejected'
  return [
    { key: 'open', label: 'Reported', at: c.reportedAt as string | null, done: true, bad: false },
    { key: 'acknowledged', label: 'Acknowledged', at: c.acknowledgedAt, done: !!c.acknowledgedAt, bad: false },
    { key: 'in_progress', label: 'In progress', at: c.inProgressAt, done: !!c.inProgressAt, bad: false },
    { key: 'closed', label: c.status === 'rejected' ? 'Rejected' : 'Resolved', at: closed ? c.resolvedAt : null, done: closed, bad: c.status === 'rejected' },
  ]
})

function onPhotoSelected(event: Event) {
  const input = event.target as HTMLInputElement
  form.photo = input.files?.[0] || null
}

const visibleRows = computed(() => {
  const q = query.value.trim().toLowerCase()
  return rows.value.filter((c) => {
    if (filter.value !== 'all' && c.status !== filter.value) return false
    if (!q) return true
    return c.description.toLowerCase().includes(q) || (CONCERN_CATEGORY_LABEL[c.category] || c.category).toLowerCase().includes(q)
  })
})

function openDetail(c: Concern) {
  selected.value = c
  detailOpen.value = true
}

function openNew() {
  form.category = 'maintenance'
  form.description = ''
  form.photo = null
  newOpen.value = true
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: authData } = await supabase.auth.getUser()
    const user = authData?.user
    if (!user) {
      error.value = 'Not signed in.'
      return
    }

    const { data: leaseRow } = await supabase
      .from('leases')
      .select('id, accommodation_manager_id')
      .eq('student_id', user.id)
      .in('status', ['active', 'leave_requested'])
      .order('start_date', { ascending: false })
      .limit(1)
      .maybeSingle()
    activeLease.value = leaseRow ? { id: leaseRow.id, managerId: leaseRow.accommodation_manager_id } : null

    const { data, error: loadError } = await supabase
      .from('concerns')
      .select(
        'id, category, description, status, reported_at, acknowledged_at, in_progress_at, resolved_at, manager_response, photo_url, leases!inner(student_id, rooms(room_number, label, accommodations(name)))',
      )
      .eq('leases.student_id', user.id)
      .order('reported_at', { ascending: false })
    if (loadError) throw loadError

    rows.value = (data ?? []).map((c) => {
      const lease = c.leases as unknown as {
        rooms: { room_number: string | null; label: string | null; accommodations: { name: string | null } | null } | null
      }
      const room = lease.rooms
      return {
        id: c.id,
        category: c.category,
        description: c.description || '',
        status: c.status,
        reportedAt: c.reported_at,
        acknowledgedAt: c.acknowledged_at,
        inProgressAt: c.in_progress_at,
        resolvedAt: c.resolved_at,
        managerResponse: c.manager_response || '',
        photoUrl: c.photo_url || '',
        where: room?.accommodations?.name || room?.label || 'Your stay',
      }
    })

    startRealtime()
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

/** Live status/response updates from the manager land on an open list or detail sheet without a manual reload. */
function startRealtime() {
  if (channel || !activeLease.value || typeof supabase.channel !== 'function') return
  channel = supabase
    .channel(`concerns:student:${activeLease.value.id}`)
    .on(
      'postgres_changes',
      { event: 'UPDATE', schema: 'public', table: 'concerns', filter: `lease_id=eq.${activeLease.value.id}` },
      (payload) => {
        const row = payload.new as {
          id: string
          status: string
          acknowledged_at: string | null
          in_progress_at: string | null
          resolved_at: string | null
          manager_response: string | null
        }
        const patch = (c: Concern) => {
          c.status = row.status
          c.acknowledgedAt = row.acknowledged_at
          c.inProgressAt = row.in_progress_at
          c.resolvedAt = row.resolved_at
          c.managerResponse = row.manager_response || ''
        }
        const listed = rows.value.find((c) => c.id === row.id)
        if (listed) patch(listed)
        if (selected.value?.id === row.id) patch(selected.value)
      },
    )
    .subscribe()
}

onUnmounted(() => {
  if (channel) void supabase.removeChannel(channel)
})

async function submit() {
  if (submitting.value || !activeLease.value) return
  submitting.value = true
  try {
    const photoUrl = form.photo ? await uploadDocument(form.photo, '', 'concern') : null

    const { data: created, error: insertError } = await supabase
      .from('concerns')
      .insert({
        lease_id: activeLease.value.id,
        category: form.category,
        description: form.description.trim() || null,
        status: 'open',
        photo_url: photoUrl,
      })
      .select('id, category, description, status, reported_at, manager_response, photo_url')
      .single()
    if (insertError) throw insertError

    rows.value = [
      {
        id: created.id,
        category: created.category,
        description: created.description || '',
        status: created.status,
        reportedAt: created.reported_at,
        acknowledgedAt: null,
        inProgressAt: null,
        resolvedAt: null,
        managerResponse: '',
        photoUrl: created.photo_url || '',
        where: 'Your stay',
      },
      ...rows.value,
    ]

    void createNotification(
      activeLease.value.managerId,
      'New concern reported',
      `A ${CONCERN_CATEGORY_LABEL[form.category] || form.category} concern was reported.`,
      'concern',
      '/manager/support',
    )

    newOpen.value = false
    notify.success('Concern reported.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not submit your concern.'))
  } finally {
    submitting.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.cp {
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 10px;
  /* Clears the docked search, which sits on the FAB's baseline. */
  padding: 10px var(--m-page-gutter) 74px;
}
.sk {
  border-radius: var(--m-radius);
  margin: 0 var(--m-page-gutter);
}
.card {
  margin: 8px var(--m-page-gutter);
  padding: 18px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
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

/* Docked search — same baseline and height as the quick-actions FAB, ending
   where it begins, so the two read as one band. */
.dock {
  position: fixed;
  bottom: calc(16px + env(safe-area-inset-bottom, 0px));
  left: var(--m-page-gutter);
  right: var(--m-page-gutter);
  z-index: 60;
  display: flex;
  align-items: center;
  gap: 8px;
}
.dock-field {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  align-items: center;
  gap: 8px;
  height: 44px;
  padding: 0 14px;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 999px;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  box-shadow: var(--m-shadow);
}
.dock-field:focus-within {
  border-color: var(--m-primary);
}
.dock-icon {
  flex: 0 0 auto;
  display: grid;
  place-items: center;
  color: var(--m-muted);
  pointer-events: none;
}
.dock-input {
  width: 100%;
  min-width: 0;
  height: 100%;
  padding: 0;
  border: none;
  background: transparent;
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
}
.dock-input::placeholder {
  color: var(--m-muted);
  opacity: 0.85;
}
.dock-input:focus {
  outline: none;
}
.dock-btn {
  position: relative;
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border: 1px solid color-mix(in srgb, var(--m-border) 55%, transparent);
  border-radius: 50%;
  background: color-mix(in srgb, var(--m-surface) 62%, transparent);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  backdrop-filter: blur(16px) saturate(160%);
  box-shadow: var(--m-shadow);
  color: var(--m-ink);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.dock-btn:disabled {
  opacity: 0.5;
}
.dock-btn--on {
  border-color: var(--m-primary);
  color: var(--m-primary-dark);
}
.dock-dot {
  position: absolute;
  top: -2px;
  right: -2px;
  display: grid;
  min-width: 17px;
  height: 17px;
  place-items: center;
  padding: 0 4px;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
}

/* Filter sheet */
.sheet {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 14px;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0;
  background: var(--m-surface);
}
.sheet-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.sheet-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.sheet-clear {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.sheet-block {
  display: flex;
  flex-direction: column;
  gap: 7px;
}
.sheet-label {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
}
.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.chip {
  padding: 6px 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 600;
  -webkit-tap-highlight-color: transparent;
}
.chip--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.sheet-done {
  min-height: 48px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}

.group {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.row {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.group > .row:first-child {
  border-top: 0;
}
.row-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.row-top {
  display: flex;
  align-items: center;
  gap: 8px;
}
.row-cat {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.row-chip {
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}
.row-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.row-chip--amber,
.row-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.row-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.row-desc {
  overflow: hidden;
  color: var(--m-text);
  font-size: 12.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.row-when {
  color: var(--m-muted);
  font-size: 11px;
}
.row-chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
}

.detail-sheet,
.new-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 10px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.new-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.detail-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
}
.detail-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.detail-chip {
  flex: 0 0 auto;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.detail-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.detail-chip--amber,
.detail-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.detail-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}

.detail-label {
  margin: 4px 0 0;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.detail-text {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.5;
}
.detail-meta {
  margin: 0;
  color: var(--m-muted);
  font-size: 11.5px;
}
.detail-close {
  min-height: 46px;
  margin-top: 6px;
  font-weight: 700;
}
.detail-photo {
  width: 100%;
  max-height: 180px;
  border-radius: var(--m-radius-sm);
  object-fit: cover;
}

.timeline {
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 0;
  list-style: none;
}
.tl-row {
  display: flex;
  gap: 10px;
}
.tl-rail {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: center;
  width: 10px;
}
.tl-dot {
  width: 10px;
  height: 10px;
  flex: 0 0 auto;
  border-radius: 50%;
  background: var(--m-border);
}
.tl-dot--done {
  background: var(--m-primary);
}
.tl-dot--bad {
  background: var(--m-danger);
}
.tl-line {
  width: 2px;
  flex: 1;
  margin: 2px 0;
  background: var(--m-border);
}
.tl-row:last-child .tl-line {
  display: none;
}
.tl-body {
  display: flex;
  flex: 1;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
  padding-bottom: 12px;
}
.tl-label {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.tl-label--pending {
  color: var(--m-muted);
  font-weight: 600;
}
.tl-when {
  flex: 0 0 auto;
  color: var(--m-muted);
  font-size: 11px;
}

.file-picker {
  position: relative;
  display: flex;
  min-height: 44px;
  align-items: center;
  gap: 8px;
  padding: 0 12px;
  border: 1px dashed var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-muted);
  cursor: pointer;
}
.file-picker--chosen {
  border-style: solid;
  border-color: var(--m-primary);
  color: var(--m-primary-dark);
}
.file-picker-text {
  flex: 1;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.file-picker-input {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  cursor: pointer;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.field-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.field-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.field-textarea {
  min-height: 90px;
  padding: 10px 12px;
  resize: vertical;
}
.new-submit {
  min-height: 48px;
  font-weight: 700;
}
</style>
