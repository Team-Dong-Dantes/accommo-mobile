<template>
  <q-page class="support-page">
    <!-- Handle overview -->
    <div class="mgr-hero">
      <div class="mgr-hero-top">
        <span class="mgm-kicker">TENANT CONCERNS</span>
        <span v-if="mgrSummary.open > 0" class="mgr-new-badge">{{ mgrSummary.open }} need action</span>
      </div>
      <div class="mgr-hero-title">Stay on top of your tenants' issues</div>
      <div class="mgr-hero-sub">Acknowledge, respond, and resolve — updates go straight to the student.</div>
    </div>

    <template v-if="tenantConcernsLoading">
      <div class="text-center q-pa-md"><q-spinner size="28px" color="teal-8" /></div>
    </template>
    <template v-else-if="filteredManagerConcerns.length">
      <div class="mgr-group" v-for="(group, gi) in mgrGroups" :key="gi">
        <template v-if="group.items.length">
          <div class="mgr-group-label">{{ group.label }} <span class="mgr-group-count">{{ group.items.length }}</span></div>
          <q-list separator class="concern-list">
            <q-item v-for="cc in group.items" :key="cc.id" class="concern-item">
              <q-item-section>
                <div class="concern-top">
                  <q-badge :color="concernStatusColor(cc.status)" :label="concernStatusText(cc.status)" class="mini-chip" />
                  <span class="concern-ago">{{ timeAgo(cc.reported_at) }}</span>
                </div>
                <q-item-label class="concern-category">{{ concernCategoryLabel(cc.category) }}</q-item-label>
                <q-item-label caption class="concern-desc">{{ cc.description || 'No description provided.' }}</q-item-label>
                <div class="concern-tenant">
                  <q-avatar size="24px" color="teal-7" text-color="white" class="tenant-avatar">{{ cc.studentInitial }}</q-avatar>
                  <span class="tenant-name">{{ cc.studentName }}</span>
                  <span v-if="cc.roomLabel" class="concern-room">· {{ cc.roomLabel }}</span>
                </div>

                <div v-if="cc.manager_response" class="concern-reply q-pa-sm">
                  <div class="text-caption text-weight-bold q-mb-xs">Your response:</div>
                  <div class="text-caption text-grey-7" style="white-space: pre-wrap;">{{ cc.manager_response }}</div>
                </div>

                <q-input
                  v-model="cc.reply"
                  dense
                  outlined
                  type="textarea"
                  autogrow
                  placeholder="Write a response for the student..."
                  class="concern-reply-input"
                />

                <div class="concern-actions">
                  <q-btn
                    dense no-caps rounded unelevated size="sm"
                    color="teal-8"
                    label="Acknowledge"
                    class="mini-btn"
                    :disable="cc.status === 'acknowledged' || cc.status === 'in_progress' || cc.status === 'resolved' || cc.busy"
                    @click="updateConcern(cc, 'acknowledged')"
                  />
                  <q-btn
                    dense no-caps rounded unelevated size="sm"
                    color="teal"
                    label="In Progress"
                    class="mini-btn"
                    :disable="cc.status === 'in_progress' || cc.status === 'resolved' || cc.busy"
                    @click="updateConcern(cc, 'in_progress')"
                  />
                  <q-btn
                    dense no-caps rounded unelevated size="sm"
                    color="green-7"
                    label="Resolve"
                    class="mini-btn"
                    :disable="cc.status === 'resolved' || !cc.reply.trim() || cc.busy"
                    @click="updateConcern(cc, 'resolved')"
                  />
                  <q-btn
                    dense no-caps rounded unelevated size="sm"
                    color="red-7"
                    label="Reject"
                    class="mini-btn"
                    :disable="cc.status === 'resolved' || cc.busy"
                    @click="updateConcern(cc, 'rejected')"
                  />
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </template>
      </div>
    </template>
    <template v-else>
      <div class="empty-card text-center">
        <q-icon name="inbox" size="40px" class="empty-icon" />
        <div class="empty-title">{{ concernsFilter === 'open' ? 'All caught up' : 'No concerns here' }}</div>
        <div class="empty-sub">{{ concernsFilter === 'open' ? 'No complaints waiting for action. Nice.' : 'Nothing in this filter right now.' }}</div>
      </div>
    </template>

    <!-- Fixed bottom search + filter (discover-style) -->
    <div class="mgr-action-bar">
      <button type="button" class="mgr-filter-button" :class="{ 'has-active': mgrHasFilterChips }" aria-label="Filter concerns" @click="filterDialog = true">
        <IconifyIcon icon="mdi:tune" width="21" aria-hidden="true" />
      </button>
      <label class="mgr-search-field" for="concerns-search">
        <IconifyIcon icon="lucide:search" width="20" aria-hidden="true" />
        <span class="sr-only">Search concerns</span>
        <input id="concerns-search" v-model="searchQuery" type="search" autocomplete="off" placeholder="Search concerns" />
        <button v-if="searchQuery" type="button" class="mgr-clear-search" aria-label="Clear search" @click="searchQuery = ''"><IconifyIcon icon="lucide:x" width="18" /></button>
      </label>
    </div>

    <!-- Filter bottom sheet -->
    <q-dialog v-model="filterDialog" position="bottom">
      <q-card class="mgr-filter-sheet">
        <q-card-section class="mgr-filter-heading">
          <div>
            <h2>Filter concerns</h2>
            <p>Narrow down tenant concerns.</p>
          </div>
          <q-btn flat round aria-label="Close filters" @click="filterDialog = false"><IconifyIcon icon="lucide:x" width="20" /></q-btn>
        </q-card-section>

        <q-card-section>
          <h3>Status</h3>
          <div class="mgr-filter-options">
            <button v-for="opt in statusOptions" :key="opt.value" type="button" class="f-chip"
              :class="{ active: selectedStatus === opt.value }" @click="toggleStatus(opt.value)">
              {{ opt.label }}
            </button>
          </div>

          <h3>Category</h3>
          <div class="mgr-filter-options">
            <button v-for="opt in categoryOptions" :key="opt.value" type="button" class="f-chip"
              :class="{ active: selectedCategory === opt.value }" @click="selectedCategory = selectedCategory === opt.value ? null : opt.value">
              {{ opt.label }}
            </button>
          </div>
        </q-card-section>

        <q-card-actions class="mgr-filter-actions">
          <q-btn flat no-caps @click="clearFilters">Clear</q-btn>
          <q-btn unelevated no-caps class="primary-button" @click="filterDialog = false">Show concerns</q-btn>
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from '@/shared/utils/supabase'

const $q = useQuasar()

interface TenantConcern {
  id: string
  lease_id: string
  category: string
  description: string | null
  status: string
  reported_at: string
  manager_response: string | null
  studentName: string
  studentInitial: string
  roomLabel: string | null
  reply: string
  busy: boolean
}

const CONCERN_STATUS: Record<string, { text: string; color: string }> = {
  open: { text: 'Open', color: 'amber' },
  acknowledged: { text: 'Acknowledged', color: 'teal' },
  in_progress: { text: 'In Progress', color: 'teal' },
  resolved: { text: 'Resolved', color: 'green' },
  rejected: { text: 'Rejected', color: 'red' },
}

const concernStatusColor = (s?: string | null) => CONCERN_STATUS[s || 'open']?.color ?? 'grey'
const concernStatusText = (s?: string | null) => CONCERN_STATUS[s || 'open']?.text ?? (s || 'Open')

const CONCERN_CATEGORIES: Record<string, string> = {
  maintenance: 'Maintenance', noise: 'Noise', cleanliness: 'Cleanliness',
  amenities: 'Amenities', security: 'Security', others: 'Others',
}
const concernCategoryLabel = (category: string | null | undefined) =>
  CONCERN_CATEGORIES[category || ''] || category || 'Concern'

const tenantConcerns = ref<TenantConcern[]>([])
const tenantConcernsLoading = ref(false)
const concernsFilter = ref<'open' | 'progress' | 'resolved'>('open')

// Search + filter (discover-style)
const searchQuery = ref('')
const filterDialog = ref(false)
const selectedStatus = ref<string | null>(null)
const selectedCategory = ref<string | null>(null)
const statusOptions = [
  { value: 'open', label: 'Open' },
  { value: 'acknowledged', label: 'Acknowledged' },
  { value: 'in_progress', label: 'In Progress' },
  { value: 'resolved', label: 'Resolved' },
  { value: 'rejected', label: 'Rejected' },
]
const categoryOptions = [
  { value: 'maintenance', label: 'Maintenance' },
  { value: 'noise', label: 'Noise' },
  { value: 'cleanliness', label: 'Cleanliness' },
  { value: 'amenities', label: 'Amenities' },
  { value: 'security', label: 'Security' },
  { value: 'others', label: 'Others' },
]
const mgrHasFilterChips = computed(() => !!selectedStatus.value || !!selectedCategory.value)
function toggleStatus(value: string) {
  selectedStatus.value = selectedStatus.value === value ? null : value
}
function clearFilters() {
  searchQuery.value = ''
  selectedStatus.value = null
  selectedCategory.value = null
  concernsFilter.value = 'open'
  filterDialog.value = false
}

const mgrSummary = computed(() => ({
  open: tenantConcerns.value.filter((c) => c.status === 'open' || c.status === 'acknowledged').length,
  progress: tenantConcerns.value.filter((c) => c.status === 'in_progress').length,
  resolved: tenantConcerns.value.filter((c) => c.status === 'resolved' || c.status === 'rejected').length,
}))

const filteredManagerConcerns = computed(() => {
  const anyOpen = tenantConcerns.value.some((c) => c.status === 'open' || c.status === 'acknowledged')
  let base: TenantConcern[]
  // If nothing needs action, default the filter to "all" view so the manager still sees everything.
  if (concernsFilter.value === 'open' && !anyOpen) {
    base = tenantConcerns.value
  } else {
    switch (concernsFilter.value) {
      case 'progress': base = tenantConcerns.value.filter((c) => c.status === 'in_progress'); break
      case 'resolved': base = tenantConcerns.value.filter((c) => c.status === 'resolved' || c.status === 'rejected'); break
      default: base = tenantConcerns.value
    }
  }
  const q = searchQuery.value.trim().toLowerCase()
  return base.filter((c) => {
    if (q) {
      const hay = `${c.studentName} ${c.category} ${c.description ?? ''}`.toLowerCase()
      if (!hay.includes(q)) return false
    }
    if (selectedStatus.value && c.status !== selectedStatus.value) return false
    if (selectedCategory.value && c.category !== selectedCategory.value) return false
    return true
  })
})

const mgrGroups = computed(() => {
  const list = filteredManagerConcerns.value
  const rank = (s: string) => (s === 'open' || s === 'acknowledged' ? 0 : s === 'in_progress' ? 1 : 2)
  const sorted = [...list].sort((a, b) => rank(a.status) - rank(b.status) || (a.reported_at < b.reported_at ? 1 : -1))
  const open = sorted.filter((c) => c.status === 'open' || c.status === 'acknowledged')
  const active = sorted.filter((c) => c.status === 'in_progress')
  const done = sorted.filter((c) => c.status === 'resolved' || c.status === 'rejected')
  return [
    { label: 'Needs your action', items: open },
    { label: 'In progress', items: active },
    { label: 'Resolved / closed', items: done },
  ].filter((g) => g.items.length)
})

function timeAgo(iso: string | null): string {
  if (!iso) return ''
  const t = new Date(iso).getTime()
  if (isNaN(t)) return ''
  const mins = Math.max(0, Math.round((Date.now() - t) / 60000))
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hrs = Math.round(mins / 60)
  if (hrs < 24) return `${hrs}h ago`
  const days = Math.round(hrs / 24)
  return `${days}d ago`
}

const loadTenantConcerns = async (): Promise<void> => {
  tenantConcernsLoading.value = true
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return

    // Accommodations → rooms → leases this manager owns, with student + room names.
    const { data: accs } = await supabase
      .from('accommodations' as any)
      .select('id')
      .eq('accommodation_manager_id', user.id)
    const accIds = (accs ?? []).map((a: any) => a.id)

    const leaseMeta = new Map<string, { studentName: string; roomLabel: string | null }>()
    const leaseIds: string[] = []
    if (accIds.length) {
      const { data: rooms } = await supabase.from('rooms').select('id').in('accommodation_id', accIds)
      const roomIds = (rooms ?? []).map((r: any) => r.id)
      if (roomIds.length) {
        const { data: leases } = await supabase
          .from('leases')
          .select('id, student:student_id(full_name), room:room_id(label, room_number)')
          .in('room_id', roomIds)
        for (const l of (leases ?? []) as any[]) {
          const stu = Array.isArray(l.student) ? l.student[0] : l.student
          const rm = Array.isArray(l.room) ? l.room[0] : l.room
          leaseIds.push(l.id)
          leaseMeta.set(l.id, {
            studentName: stu?.full_name || 'Student',
            roomLabel: rm?.label || rm?.room_number || null,
          })
        }
      }
    }

    let rows: any[] = []
    if (leaseIds.length) {
      const { data: cs, error } = await supabase
        .from('concerns')
        .select('id, lease_id, category, description, status, reported_at, manager_response')
        .in('lease_id', leaseIds)
        .order('reported_at', { ascending: false })
      if (error) throw error
      rows = cs ?? []
    }

    tenantConcerns.value = rows.map((c: any) => {
      const meta = leaseMeta.get(c.lease_id) || { studentName: 'Student', roomLabel: null }
      return {
        id: c.id,
        lease_id: c.lease_id,
        category: c.category,
        description: c.description,
        status: c.status,
        reported_at: c.reported_at,
        manager_response: c.manager_response,
        studentName: meta.studentName,
        studentInitial: (meta.studentName || '?')[0]?.toUpperCase() || '?',
        roomLabel: meta.roomLabel,
        reply: '',
        busy: false,
      }
    })
  } catch (e) {
    console.error('loadTenantConcerns error:', e)
  } finally {
    tenantConcernsLoading.value = false
  }
}

const updateConcern = async (cc: TenantConcern, status: string): Promise<void> => {
  if (cc.busy) return
  cc.busy = true
  try {
    const updates: {
      status: string
      acknowledged_at?: string
      resolved_at?: string
      manager_response?: string
    } = { status }
    if (status === 'acknowledged') updates.acknowledged_at = new Date().toISOString()
    if (status === 'resolved') updates.resolved_at = new Date().toISOString()
    if (cc.reply.trim()) updates.manager_response = cc.reply.trim()
    const { error } = await supabase.from('concerns').update(updates).eq('id', cc.id)
    if (error) throw error
    cc.status = status
    cc.manager_response = cc.reply.trim() || cc.manager_response
    cc.reply = ''
    $q.notify({ type: 'positive', message: `Concern ${concernStatusText(status).toLowerCase()}. Student has been updated.` })
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to update concern' })
  } finally {
    cc.busy = false
  }
}

onMounted(() => {
  void loadTenantConcerns()
})
</script>

<style scoped>
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
.support-page {
  padding: 16px;
  padding-bottom: calc(168px + env(safe-area-inset-bottom));
  background: #f3f4f6;
  min-height: 100vh;
}

/* --- Overview --- */
.mgr-hero {
  background: linear-gradient(135deg, #0f766e, #14b8a6);
  border-radius: 16px;
  padding: 18px 16px;
  color: white;
  margin-bottom: 14px;
}
.mgr-hero-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.mgm-kicker {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.08em;
  opacity: 0.85;
}
.mgr-new-badge {
  font-size: 11px;
  font-weight: 800;
  padding: 4px 10px;
  border-radius: 999px;
  background: #fff3cd;
  color: #92400e;
}
.mgr-hero-title {
  font-size: 17px;
  font-weight: 800;
  margin-top: 6px;
  line-height: 1.25;
}
.mgr-hero-sub {
  font-size: 12.5px;
  opacity: 0.9;
  margin-top: 4px;
}
.mgr-group { margin-bottom: 16px; }
.mgr-group-label {
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.03em;
  color: #6b7280;
  margin: 0 2px 8px;
}
.mgr-group-count {
  font-size: 11px;
  font-weight: 800;
  color: var(--m-primary);
  background: color-mix(in srgb, var(--m-primary-soft) 60%, white);
  padding: 1px 7px;
  border-radius: 999px;
  margin-left: 4px;
}

/* --- Concern list --- */
.concern-list {
  background: white;
  border-radius: 14px;
  overflow: hidden;
}
.concern-item {
  padding: 14px;
}
.concern-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 6px;
}
.concern-ago {
  font-size: 12px;
  color: #9ca3af;
  font-weight: 600;
}
.concern-category {
  font-size: 15px;
  font-weight: 800;
  color: #111827;
  text-transform: capitalize;
}
.concern-desc {
  font-size: 13px;
  color: #4b5563;
  margin-top: 2px;
  white-space: pre-wrap;
}
.concern-tenant {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 10px;
}
.tenant-avatar {
  background: #0f766e;
  color: white;
  font-weight: 700;
}
.tenant-name {
  font-size: 13px;
  font-weight: 700;
  color: #374151;
}
.concern-room {
  font-size: 12px;
  color: #6b7280;
}
.concern-reply {
  margin-top: 10px;
  border: 1px solid #d1e8e4;
  border-radius: 10px;
  background: #f0faf9;
}
.concern-reply-input {
  margin-top: 8px;
}
.concern-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 10px;
}
.mini-btn {
  font-weight: 700;
}
.mini-chip {
  font-size: 11px;
  font-weight: 700;
}
.empty-card {
  padding: 40px 20px;
}
.empty-icon {
  color: #9ca3af;
}
.empty-title {
  font-size: 16px;
  font-weight: 800;
  color: #111827;
  margin-top: 10px;
}
.empty-sub {
  font-size: 13px;
  color: #6b7280;
  margin-top: 4px;
}

/* --- Fixed bottom search + filter (discover-style) --- */
.mgr-action-bar {
  position: fixed;
  z-index: 59;
  right: 72px;
  bottom: 80px;
  left: 12px;
  display: flex;
  gap: 8px;
  align-items: center;
}
.mgr-search-field {
  display: flex;
  min-width: 0;
  flex: 1;
  align-items: center;
  gap: 8px;
  min-height: 44px;
  padding: 0 12px;
  color: #6b7280;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(15, 23, 42, .08);
}
.mgr-search-field input {
  min-width: 0;
  flex: 1;
  color: #111827;
  border: 0;
  outline: 0;
  background: transparent;
  font: inherit;
}
.mgr-clear-search,
.mgr-filter-button {
  display: grid;
  flex: 0 0 auto;
  place-items: center;
  border: 0;
  background: transparent;
  font: inherit;
  cursor: pointer;
}
.mgr-clear-search {
  width: 28px;
  height: 28px;
  color: #6b7280;
}
.mgr-filter-button {
  width: 44px;
  height: 44px;
  color: var(--m-primary-dark);
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(15, 23, 42, .08);
}
.mgr-filter-button.has-active {
  border-color: var(--m-primary);
  background: color-mix(in srgb, var(--m-primary-soft) 60%, white);
}

.mgr-filter-sheet {
  border-radius: 20px 20px 0 0;
  padding-bottom: env(safe-area-inset-bottom);
}
.mgr-filter-heading {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}
.mgr-filter-heading h2 { margin: 0; font-size: 17px; font-weight: 800; }
.mgr-filter-heading p { margin: 4px 0 0; color: #6b7280; font-size: 13px; }
.mgr-filter-sheet h3 {
  margin: 4px 0 10px;
  color: #6b7280;
  font-size: 12px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.mgr-filter-options {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.f-chip {
  min-height: 38px;
  padding: 0 16px;
  border: 1px solid #e5e7eb;
  border-radius: 999px;
  background: white;
  color: #374151;
  font-weight: 600;
  font-size: 13px;
  cursor: pointer;
}
.f-chip.active {
  color: #fff;
  background: var(--m-primary);
  border-color: var(--m-primary);
}
.mgr-filter-actions {
  display: flex;
  justify-content: space-between;
  padding: 12px 16px;
}
.primary-button {
  color: #fff;
  background: var(--m-primary);
  border-radius: 12px;
  font-weight: 700;
}
</style>
