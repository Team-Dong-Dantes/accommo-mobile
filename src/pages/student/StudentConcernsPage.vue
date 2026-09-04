<template>
  <q-page class="cp">
    <div v-if="!loading && !error" class="dock">
      <div class="dock-field">
        <IconifyIcon icon="lucide:search" width="16" class="dock-icon" />
        <input v-model="query" class="dock-input" type="search" placeholder="Search concerns" aria-label="Search concerns" />
      </div>
      <button type="button" class="dock-btn" :disabled="!activeLease" @click="openNew">
        <IconifyIcon icon="lucide:plus" width="16" />
        New
      </button>
    </div>

    <div v-if="!loading && !error" class="chips">
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

    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="72px" class="sk" />
      <q-skeleton type="rect" height="72px" class="sk" />
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
    >
      <template #actions>
        <q-btn v-if="activeLease" unelevated rounded no-caps color="primary" label="Report a concern" @click="openNew" />
      </template>
    </EmptyState>

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

    <q-dialog v-model="detailOpen" position="bottom">
      <q-card v-if="selected" class="detail-sheet">
        <h3 class="detail-title">{{ CONCERN_CATEGORY_LABEL[selected.category] || selected.category }}</h3>
        <span class="detail-chip" :class="`detail-chip--${statusColor(CONCERN_STATUS, selected.status)}`">
          {{ statusText(CONCERN_STATUS, selected.status) }}
        </span>

        <div class="steps">
          <span
            v-for="s in STEP_ORDER"
            :key="s"
            class="step"
            :class="{ 'step--on': stepIndex(selected.status) >= STEP_ORDER.indexOf(s), 'step--bad': selected.status === 'rejected' && s === 'resolved' }"
          >
            {{ CONCERN_STATUS[s]?.text }}
          </span>
        </div>

        <p class="detail-label">Your report</p>
        <p class="detail-text">{{ selected.description || 'No description given.' }}</p>
        <p class="detail-meta">{{ selected.where }} · Reported {{ since(selected.reportedAt) }}</p>

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
        <q-btn unelevated rounded no-caps color="primary" class="new-submit" :loading="submitting" label="Submit" @click="submit" />
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { CONCERN_STATUS, CONCERN_CATEGORY_LABEL, statusText, statusColor } from '@/utils/format'
import { since } from '@/utils/notifications'
import { useNotify } from '@/utils/notify'
import { createNotification } from '@/boot/notify'
import EmptyState from '@/components/shared/EmptyState.vue'

const STEP_ORDER = ['open', 'acknowledged', 'in_progress', 'resolved'] as const

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
  managerResponse: string
  where: string
}

const notify = useNotify()

const loading = ref(true)
const error = ref('')
const rows = ref<Concern[]>([])
const query = ref('')
const filter = ref<(typeof FILTERS)[number]['key']>('all')

const activeLease = ref<{ id: string; managerId: string } | null>(null)

const detailOpen = ref(false)
const selected = ref<Concern | null>(null)
const newOpen = ref(false)
const submitting = ref(false)
const form = reactive({ category: 'maintenance', description: '' })

// 'rejected' has no place on the open→acknowledged→in_progress→resolved
// track, so it lights up only the first step (the report itself happened).
function stepIndex(status: string): number {
  const i = STEP_ORDER.indexOf(status as (typeof STEP_ORDER)[number])
  return i === -1 ? 0 : i
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
      .select('id, category, description, status, reported_at, manager_response, leases!inner(student_id, rooms(room_number, label, accommodations(name)))')
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
        managerResponse: c.manager_response || '',
        where: room?.accommodations?.name || room?.label || 'Your stay',
      }
    })
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

async function submit() {
  if (submitting.value || !activeLease.value) return
  submitting.value = true
  try {
    const { data: created, error: insertError } = await supabase
      .from('concerns')
      .insert({
        lease_id: activeLease.value.id,
        category: form.category,
        description: form.description.trim() || null,
        status: 'open',
      })
      .select('id, category, description, status, reported_at, manager_response')
      .single()
    if (insertError) throw insertError

    rows.value = [
      {
        id: created.id,
        category: created.category,
        description: created.description || '',
        status: created.status,
        reportedAt: created.reported_at,
        managerResponse: '',
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
  padding: 10px var(--m-page-gutter) 24px;
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

.dock {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px var(--m-page-gutter) 0;
}
.dock-field {
  display: flex;
  flex: 1;
  align-items: center;
  gap: 8px;
  min-height: 42px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
}
.dock-icon {
  color: var(--m-muted);
  flex: 0 0 auto;
}
.dock-input {
  flex: 1;
  min-width: 0;
  border: 0;
  background: transparent;
  font: inherit;
  font-size: 14px;
  color: var(--m-ink);
  outline: none;
}
.dock-btn {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 6px;
  min-height: 42px;
  padding: 0 14px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.dock-btn:disabled {
  opacity: 0.5;
}

.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  padding: 10px var(--m-page-gutter) 0;
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
.detail-title,
.new-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.detail-chip {
  align-self: flex-start;
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

.steps {
  display: flex;
  gap: 4px;
}
.step {
  flex: 1;
  padding: 6px 4px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  font-size: 10px;
  font-weight: 700;
  text-align: center;
}
.step--on {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.step--bad {
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
