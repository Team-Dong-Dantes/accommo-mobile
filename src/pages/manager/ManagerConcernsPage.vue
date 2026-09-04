<template>
  <q-page class="cp">
    <div v-if="!loading && !error" class="dock">
      <div class="dock-field">
        <IconifyIcon icon="lucide:search" width="16" class="dock-icon" />
        <input v-model="query" class="dock-input" type="search" placeholder="Search tenant or concern" aria-label="Search concerns" />
      </div>
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
        <p class="err-title">Couldn't load concerns</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <EmptyState
      v-else-if="!rows.length"
      icon="lucide:message-square-warning"
      title="No concerns right now"
      message="Maintenance, safety and billing concerns from your tenants land in this inbox."
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
          <span class="row-avatar">{{ initialsOf(c.studentName) }}</span>
          <span class="row-body">
            <span class="row-top">
              <span class="row-name">{{ c.studentName }}</span>
              <span class="row-chip" :class="`row-chip--${statusColor(CONCERN_STATUS, c.status)}`">{{ statusText(CONCERN_STATUS, c.status) }}</span>
            </span>
            <span class="row-desc">{{ CONCERN_CATEGORY_LABEL[c.category] || c.category }} · {{ c.where }}</span>
            <span class="row-when">{{ since(c.reportedAt) }}</span>
          </span>
          <IconifyIcon icon="lucide:chevron-right" width="16" class="row-chevron" />
        </button>
      </div>
    </div>

    <q-dialog v-model="detailOpen" position="bottom">
      <q-card v-if="selected" class="detail-sheet">
        <div class="detail-head">
          <span class="detail-avatar">{{ initialsOf(selected.studentName) }}</span>
          <span class="detail-headbody">
            <span class="detail-name">{{ selected.studentName }}</span>
            <span class="detail-where">{{ selected.where }}</span>
          </span>
          <span class="detail-chip" :class="`detail-chip--${statusColor(CONCERN_STATUS, selected.status)}`">
            {{ statusText(CONCERN_STATUS, selected.status) }}
          </span>
        </div>

        <p class="detail-label">{{ CONCERN_CATEGORY_LABEL[selected.category] || selected.category }} · {{ since(selected.reportedAt) }}</p>
        <p class="detail-text">{{ selected.description || 'No description given.' }}</p>

        <label class="field">
          <span class="field-label">Response to tenant</span>
          <textarea v-model="response" class="field-input field-textarea" rows="3" placeholder="What are you doing about this?" />
        </label>

        <div class="actions">
          <button v-if="selected.status === 'open'" type="button" class="act-btn act-btn--ghost" :disabled="deciding" @click="decide('acknowledged')">
            Acknowledge
          </button>
          <button v-if="selected.status === 'open' || selected.status === 'acknowledged'" type="button" class="act-btn act-btn--ghost" :disabled="deciding" @click="decide('in_progress')">
            In progress
          </button>
          <button v-if="selected.status !== 'resolved' && selected.status !== 'rejected'" type="button" class="act-btn act-btn--ghost" :disabled="deciding" @click="decide('rejected')">
            Reject
          </button>
          <button v-if="selected.status !== 'resolved' && selected.status !== 'rejected'" type="button" class="act-btn" :disabled="deciding" @click="decide('resolved')">
            Resolve
          </button>
        </div>
        <p v-if="selected.status === 'resolved' || selected.status === 'rejected'" class="detail-final">
          This concern is closed.
        </p>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { initialsOf, CONCERN_STATUS, CONCERN_CATEGORY_LABEL, statusText, statusColor } from '@/utils/format'
import { since } from '@/utils/notifications'
import { useNotify } from '@/utils/notify'
import { createNotification } from '@/boot/notify'
import EmptyState from '@/components/shared/EmptyState.vue'

const FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'open', label: 'Open' },
  { key: 'acknowledged', label: 'Acknowledged' },
  { key: 'in_progress', label: 'In progress' },
  { key: 'resolved', label: 'Resolved' },
  { key: 'rejected', label: 'Rejected' },
] as const

interface Concern {
  id: string
  studentId: string
  category: string
  description: string
  status: string
  reportedAt: string
  managerResponse: string
  where: string
  studentName: string
}

const notify = useNotify()

const loading = ref(true)
const error = ref('')
const rows = ref<Concern[]>([])
const query = ref('')
const filter = ref<(typeof FILTERS)[number]['key']>('all')

const detailOpen = ref(false)
const selected = ref<Concern | null>(null)
const response = ref('')
const deciding = ref(false)

const visibleRows = computed(() => {
  const q = query.value.trim().toLowerCase()
  return rows.value.filter((c) => {
    if (filter.value !== 'all' && c.status !== filter.value) return false
    if (!q) return true
    return (
      c.studentName.toLowerCase().includes(q) ||
      c.description.toLowerCase().includes(q) ||
      (CONCERN_CATEGORY_LABEL[c.category] || c.category).toLowerCase().includes(q)
    )
  })
})

function openDetail(c: Concern) {
  selected.value = c
  response.value = c.managerResponse
  detailOpen.value = true
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

    const { data, error: loadError } = await supabase
      .from('concerns')
      .select(
        'id, category, description, status, reported_at, manager_response, leases!inner(accommodation_manager_id, student_id, users!leases_student_id_fkey(full_name), rooms(room_number, label, accommodations(name)))',
      )
      .eq('leases.accommodation_manager_id', user.id)
      .order('reported_at', { ascending: false })
    if (loadError) throw loadError

    rows.value = (data ?? []).map((c) => {
      const lease = c.leases as unknown as {
        student_id: string
        users: { full_name: string | null } | null
        rooms: { room_number: string | null; label: string | null; accommodations: { name: string | null } | null } | null
      }
      const room = lease.rooms
      return {
        id: c.id,
        studentId: lease.student_id,
        category: c.category,
        description: c.description || '',
        status: c.status,
        reportedAt: c.reported_at,
        managerResponse: c.manager_response || '',
        where: room?.accommodations?.name || room?.label || 'Accommodation',
        studentName: lease.users?.full_name || 'A student',
      }
    })
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

const STATUS_VERB: Record<string, string> = {
  acknowledged: 'acknowledged',
  in_progress: 'marked in progress',
  resolved: 'resolved',
  rejected: 'rejected',
}

async function decide(next: 'acknowledged' | 'in_progress' | 'resolved' | 'rejected') {
  if (deciding.value || !selected.value) return
  deciding.value = true
  try {
    const payload: {
      status: string
      manager_response: string | null
      acknowledged_at?: string
      resolved_at?: string
    } = {
      status: next,
      manager_response: response.value.trim() || null,
    }
    if (next === 'acknowledged') payload.acknowledged_at = new Date().toISOString()
    if (next === 'resolved' || next === 'rejected') payload.resolved_at = new Date().toISOString()

    const { error: updateError } = await supabase.from('concerns').update(payload).eq('id', selected.value.id)
    if (updateError) throw updateError

    selected.value.status = next
    selected.value.managerResponse = response.value.trim()
    const row = rows.value.find((r) => r.id === selected.value?.id)
    if (row) {
      row.status = next
      row.managerResponse = response.value.trim()
    }

    void createNotification(
      selected.value.studentId,
      'Concern update',
      `Your ${CONCERN_CATEGORY_LABEL[selected.value.category] || selected.value.category} concern was ${STATUS_VERB[next]}.`,
      'concern',
      '/student/concerns',
    )

    notify.success('Updated.')
    if (next === 'resolved' || next === 'rejected') detailOpen.value = false
  } catch (e) {
    notify.error(errorMessage(e, 'Could not update this concern.'))
  } finally {
    deciding.value = false
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
  gap: 10px;
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
.row-avatar {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 12px;
  font-weight: 800;
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
.row-name {
  min-width: 0;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
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
  color: var(--m-muted);
  font-size: 11.5px;
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

.detail-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 10px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.detail-head {
  display: flex;
  align-items: center;
  gap: 10px;
}
.detail-avatar {
  display: grid;
  width: 40px;
  height: 40px;
  flex: 0 0 40px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 800;
}
.detail-headbody {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}
.detail-name {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.detail-where {
  color: var(--m-muted);
  font-size: 11.5px;
}
.detail-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
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
.detail-final {
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
  text-align: center;
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
  min-height: 70px;
  padding: 10px 12px;
  resize: vertical;
}

.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.act-btn {
  flex: 1 1 auto;
  min-height: 44px;
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
.act-btn:disabled {
  opacity: 0.6;
}
.act-btn--ghost {
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}
</style>
