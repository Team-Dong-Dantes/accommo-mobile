<template>
  <q-page class="tenants-page">
    <main id="tenant-list" class="tenant-content">
      <section v-if="isLoading" class="state-panel" aria-busy="true" aria-label="Loading tenants">
        <div v-for="index in 5" :key="index" class="skeleton-row" aria-hidden="true">
          <span class="skeleton-avatar" />
          <span class="skeleton-copy"><i /><i /></span>
          <span class="skeleton-badge" />
        </div>
        <span class="sr-only">Loading tenants</span>
      </section>

      <section v-else-if="loadError" class="state-panel state-panel--error" role="alert" aria-live="assertive">
        <span class="state-icon"><IconifyIcon icon="lucide:cloud-alert" width="24" aria-hidden="true" /></span>
        <h2>Unable to load tenants</h2>
        <p>{{ loadError }}</p>
        <button type="button" class="retry-button" @click="loadTenants">
          <IconifyIcon icon="lucide:refresh-cw" width="17" aria-hidden="true" />
          Retry
        </button>
      </section>

      <template v-else>
        <section class="roster-section homes-section">
          <div class="homes-list">
            <article v-for="home in structuredHomes" :key="home.id" class="home-block">
              <header class="home-heading">
                <span class="home-icon" aria-hidden="true"><IconifyIcon icon="lucide:building-2" width="18" /></span>
                <div class="home-heading-copy">
                  <strong>{{ home.name }}</strong>
                  <small>{{ home.rooms.length }} {{ home.rooms.length === 1 ? 'room' : 'rooms' }}</small>
                </div>
              </header>

              <div v-if="!home.rooms.length" class="surface home-empty">No rooms added for this property yet.</div>

              <div v-for="room in home.rooms" :key="room.id" class="room-group">
                <!-- Room header: ALWAYS visible, even with zero tenants -->
                <div class="room-head">
                  <span class="room-head__icon" aria-hidden="true"><IconifyIcon icon="lucide:door-closed" width="16" /></span>
                  <strong class="room-head__label">{{ room.label }}</strong>
                  <small v-if="room.floor" class="room-head__floor">Floor {{ room.floor }}</small>
                  <span class="room-head__count" :class="{ 'room-head__count--full': room.capacity != null && room.tenants.length >= room.capacity }">
                    {{ room.tenants.length }}<template v-if="room.capacity != null">/{{ room.capacity }}</template>
                  </span>
                </div>

                <div class="room-body">
                  <!-- Pending applicants for this room -->
                  <button
                    v-for="applicant in room.applicants"
                    :key="applicant.leaseId"
                    type="button"
                    class="room-row room-row--pending"
                    @click="openTenant(applicant.studentId)"
                  >
                    <q-avatar size="40px" class="tenant-avatar" aria-hidden="true">{{ applicant.initials }}</q-avatar>
                    <span class="row-copy">
                      <strong>{{ applicant.name }}</strong>
                      <small>Applicant — awaiting decision</small>
                    </span>
                    <span class="status-badge status-badge--warning"><IconifyIcon icon="lucide:clock-3" width="13" /> Pending</span>
                    <IconifyIcon class="row-chevron" icon="lucide:chevron-right" width="18" aria-hidden="true" />
                  </button>

                  <!-- Current tenants in this room (all of them) -->
                  <button
                    v-for="tenant in room.tenants"
                    :key="tenant.studentId"
                    type="button"
                    class="room-row room-row--taken"
                    :class="{ 'room-row--leaving': tenant.statusKey === 'leaving' }"
                    @click="openTenant(tenant.studentId)"
                  >
                    <q-avatar size="40px" class="tenant-avatar" aria-hidden="true">{{ tenant.initials }}</q-avatar>
                    <span class="row-copy">
                      <strong>{{ tenant.name }}</strong>
                      <small>Occupant</small>
                    </span>
                    <span class="status-badge" :class="`status-badge--${tenant.statusKey}`">
                      <IconifyIcon :icon="tenant.statusIcon" width="13" /> {{ tenant.status }}
                    </span>
                    <IconifyIcon class="row-chevron" icon="lucide:chevron-right" width="18" aria-hidden="true" />
                  </button>

                  <!-- No one in this room yet -->
                  <div v-if="!room.tenants.length && !room.applicants.length" class="room-row room-row--open">
                    <span class="room-open-icon" aria-hidden="true"><IconifyIcon icon="lucide:door-open" width="18" /></span>
                    <span class="row-copy">
                      <strong>Open room</strong>
                      <small>No tenant yet</small>
                    </span>
                    <span class="status-badge status-badge--neutral">Available</span>
                  </div>
                </div>
              </div>
            </article>
          </div>
        </section>

        <EmptyState v-if="!structuredHomes.length && !visiblePendingApplications.length" icon="lucide:users-round" title="No tenants yet" message="Properties and rooms appear here once you add them." />
      </template>

      <div class="tenant-action-bar">
        <button type="button" class="filter-icon-button" :class="{ 'filter-icon-button--active': statusFilter !== 'all' }" aria-label="Filter tenants" @click="filterDialog = true">
          <IconifyIcon icon="mdi:tune" width="21" aria-hidden="true" />
        </button>
        <label class="search-field" for="tenant-search">
          <IconifyIcon icon="lucide:search" width="20" aria-hidden="true" />
          <span class="sr-only">Search tenants, properties, or rooms</span>
          <input id="tenant-search" v-model="searchText" type="search" autocomplete="off" placeholder="Search tenants" />
          <button v-if="searchText" type="button" class="search-clear" aria-label="Clear search" @click="searchText = ''"><IconifyIcon icon="lucide:x" width="18" aria-hidden="true" /></button>
        </label>
      </div>

      <q-dialog v-model="filterDialog" position="bottom">
        <q-card class="tenant-filter-sheet">
          <q-card-section class="tenant-filter-sheet__heading">
            <div><h2>Filter tenants</h2><p>Choose the tenant status to review.</p></div>
            <q-btn flat round dense aria-label="Close filters" @click="filterDialog = false"><IconifyIcon icon="lucide:x" width="20" /></q-btn>
          </q-card-section>
          <q-card-section>
            <div class="tenant-filter-options">
              <button v-for="filter in filters" :key="filter.value" type="button" :class="{ active: statusFilter === filter.value }" @click="statusFilter = filter.value">{{ filter.label }}</button>
            </div>
          </q-card-section>
          <q-card-actions class="tenant-filter-sheet__actions">
            <q-btn flat no-caps label="Clear" @click="clearFilters" />
            <q-btn unelevated no-caps class="retry-button" label="Show results" @click="filterDialog = false" />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </main>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onActivated, onMounted, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useQuasar } from 'quasar'
import { useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'
import EmptyState from '@/components/shared/EmptyState.vue'

type TenantFilter = 'all' | 'active' | 'pending' | 'payment-due' | 'leaving'
type TenantStatusKey = Exclude<TenantFilter, 'all' | 'pending'> | 'ended' | 'unknown'

interface Tenant {
  id: string
  studentId: string
  roomId: string
  name: string
  initials: string
  property: string
  room: string
  status: string
  statusKey: TenantStatusKey
  statusIcon: string
  payment: {
    label: string
    amount: string
    tone: 'danger' | 'warning' | 'success' | 'neutral'
    icon: string
  } | null
}

interface PendingApplication {
  id: string
  studentId: string
  name: string
  initials: string
  property: string
  room: string
  roomId: string
}

const $q = useQuasar()
const router = useRouter()
const searchText = ref('')
const statusFilter = ref<TenantFilter>('all')
const filterDialog = ref(false)
const isLoading = ref(false)
const loadError = ref<string | null>(null)
const applicationAction = ref<string | null>(null)
interface HomeRoom { id: string; label: string; floor: string | null; capacity: number | null; tenants: { studentId: string; name: string; initials: string; status: string; statusKey: string; statusIcon: string }[]; applicants: { studentId: string; name: string; initials: string; leaseId: string }[] }
interface HomeGroup { id: string; name: string; rooms: HomeRoom[] }
const tenants = ref<Tenant[]>([])
const pendingApplications = ref<PendingApplication[]>([])
const structuredHomes = ref<HomeGroup[]>([])

const filters: { label: string; value: TenantFilter }[] = [
  { label: 'All', value: 'all' },
  { label: 'Active', value: 'active' },
  { label: 'Pending', value: 'pending' },
  { label: 'Payment due', value: 'payment-due' },
  { label: 'Leaving', value: 'leaving' },
]

function initialsOf(name: string): string {
  return (name || '?')
    .trim()
    .split(/\s+/)
    .map((part) => part[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

function displayName(user: any, studentId: string): string {
  return user?.full_name?.trim() || `Tenant ${(studentId || '').slice(0, 4)}`
}

function roomName(room: any): string {
  return room?.label || (room?.room_number ? `Room ${room.room_number}` : 'Unassigned room')
}

function matchesSearch(entry: { name: string; property: string; room: string }, term: string): boolean {
  return [entry.name, entry.property, entry.room].some((value) => value.toLowerCase().includes(term))
}

function tenantStatus(status: string, leaveRequested: boolean, paymentDue: boolean): Pick<Tenant, 'status' | 'statusKey' | 'statusIcon'> {
  // Status FIRST: an ended lease is ended, full stop. A stale
  // leave_requested_at on an ended/terminated lease must NOT render as
  // "Leaving" (it previously overrode real state and confused the roster).
  if (['ended', 'expired', 'terminated'].includes(status)) return { status: 'Ended', statusKey: 'ended', statusIcon: 'lucide:circle-x' }
  if (paymentDue) return { status: 'Payment due', statusKey: 'payment-due', statusIcon: 'lucide:receipt-text' }
  if (leaveRequested) return { status: 'Leaving', statusKey: 'leaving', statusIcon: 'lucide:log-out' }
  if (status === 'active') return { status: 'Active', statusKey: 'active', statusIcon: 'lucide:circle-check' }
  return { status: status ? status.replace(/_/g, ' ') : 'Unknown', statusKey: 'unknown', statusIcon: 'lucide:circle-help' }
}

function formatPeso(value: number): string {
  return new Intl.NumberFormat('en-PH', {
    style: 'currency',
    currency: 'PHP',
    maximumFractionDigits: 0,
  }).format(value)
}

function paymentSummary(payments: any[]): Tenant['payment'] {
  if (!payments.length) return null

  const priority = ['overdue', 'pending_verification', 'due', 'paid']
  const payment = [...payments].sort((a, b) => priority.indexOf(a.status) - priority.indexOf(b.status))[0]
  if (!payment) return null

  const summaries: Record<string, Omit<NonNullable<Tenant['payment']>, 'amount'>> = {
    overdue: { label: 'Overdue', tone: 'danger', icon: 'lucide:circle-alert' },
    pending_verification: { label: 'Payment to verify', tone: 'warning', icon: 'lucide:file-check-2' },
    due: { label: 'Payment due', tone: 'warning', icon: 'lucide:receipt-text' },
    paid: { label: 'Last payment received', tone: 'success', icon: 'lucide:circle-check' },
  }
  const presentation = summaries[payment.status] || { label: 'Payment recorded', tone: 'neutral' as const, icon: 'lucide:receipt-text' }
  return { ...presentation, amount: formatPeso(Number(payment.amount || 0)) }
}

async function loadTenants() {
  isLoading.value = true
  loadError.value = null

  try {
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError) throw userError
    if (!user) {
      tenants.value = []
      pendingApplications.value = []
      return
    }

    // Data is deliberately loaded through the tenant relationship: accommodations -> rooms -> leases -> payments -> users.
    const { data: accommodations, error: accommodationError } = await supabase
      .from('accommodations' as any)
      .select('id, name, address')
      .eq('accommodation_manager_id', user.id)
    if (accommodationError) throw accommodationError

    const propertyRows = (accommodations || []) as any[]
    const propertyIds = propertyRows.map((property) => property.id)
    const propertyById = new Map(propertyRows.map((property) => [property.id, property]))

    let roomRows: any[] = []
    if (propertyIds.length) {
      const { data: rooms, error: roomError } = await supabase
        .from('rooms')
        .select('id, accommodation_id, room_number, label, floor, capacity, current_pax, status')
        .in('accommodation_id', propertyIds)
      if (roomError) throw roomError
      roomRows = (rooms || []) as any[]
    }
    const roomById = new Map(roomRows.map((room) => [room.id, room]))

    let leaseRows: any[] = []
    const roomIds = roomRows.map((room) => room.id)
    if (roomIds.length) {
      const { data: leases, error: leaseError } = await supabase
        .from('leases')
        .select('id, student_id, status, leave_requested_at, room_id')
        .in('room_id', roomIds)
      if (leaseError) throw leaseError
      leaseRows = (leases || []) as any[]
    }

    const paymentsByLease = new Map<string, any[]>()
    const leaseIds = leaseRows.map((lease) => lease.id)
    if (leaseIds.length) {
      const { data: payments, error: paymentError } = await supabase
        .from('payments')
        .select('lease_id, amount, status, month, paid_at')
        .in('lease_id', leaseIds)
      if (paymentError) throw paymentError
      ;(payments || []).forEach((payment: any) => {
        paymentsByLease.set(payment.lease_id, [...(paymentsByLease.get(payment.lease_id) || []), payment])
      })
    }

    const userById = new Map<string, any>()
    const studentIds = Array.from(new Set(leaseRows.map((lease) => lease.student_id).filter(Boolean)))
    if (studentIds.length) {
      const { data: users, error: usersError } = await supabase
        .from('users')
        .select('id, full_name, avatar_color')
        .in('id', studentIds)
      if (usersError) throw usersError
      ;(users || []).forEach((student: any) => userById.set(student.id, student))
    }

    const nextTenants: Tenant[] = []
    const nextPendingApplications: PendingApplication[] = []

    for (const lease of leaseRows) {
      const room = roomById.get(lease.room_id)
      const property = propertyById.get(room?.accommodation_id)
      const userRecord = userById.get(lease.student_id)
      const name = displayName(userRecord, lease.student_id)
      const tenantLocation = {
        property: property?.name || 'Unnamed property',
        room: roomName(room),
        roomId: lease.room_id,
      }

      if (lease.status === 'pending') {
        nextPendingApplications.push({
          id: lease.id,
          studentId: lease.student_id,
          name,
          initials: initialsOf(name),
          ...tenantLocation,
        })
        continue
      }

      const status = tenantStatus(
        String(lease.status || '').toLowerCase(),
        Boolean(lease.leave_requested_at),
        (paymentsByLease.get(lease.id) || []).some((payment) => ['due', 'overdue', 'pending_verification'].includes(payment.status)),
      )
      nextTenants.push({
        id: lease.id,
        studentId: lease.student_id,
        name,
        initials: initialsOf(name),
        ...tenantLocation,
        ...status,
        payment: paymentSummary(paymentsByLease.get(lease.id) || []),
      })
    }

    tenants.value = nextTenants
    pendingApplications.value = nextPendingApplications

    // Property -> room -> occupant list (all current tenants per room, not just
    // one). Ended leases never occupy. Rooms with zero tenants still render.
    const OCCUPYING = new Set(['active', 'payment-due', 'leaving'])
    const tenantsByRoomId = new Map<string, Tenant[]>()
    for (const t of nextTenants) {
      if (!t.roomId || !OCCUPYING.has(t.statusKey)) continue
      tenantsByRoomId.set(t.roomId, [...(tenantsByRoomId.get(t.roomId) || []), t])
    }
    const applicantsByRoomId = new Map<string, PendingApplication[]>()
    for (const a of nextPendingApplications) {
      if (!a.roomId) continue
      applicantsByRoomId.set(a.roomId, [...(applicantsByRoomId.get(a.roomId) || []), a])
    }

    structuredHomes.value = propertyRows.map((property: any) => ({
      id: property.id,
      name: property.name || 'Unnamed property',
      rooms: roomRows
        .filter((room) => room.accommodation_id === property.id)
        .map((room) => {
          const tenants = tenantsByRoomId.get(room.id) || []
          const applicants = applicantsByRoomId.get(room.id) || []
          return {
            id: room.id,
            label: roomName(room),
            floor: room.floor || null,
            capacity: room.capacity || null,
            tenants: tenants.map((tenant) => ({ studentId: tenant.studentId, name: tenant.name, initials: tenant.initials, status: tenant.status, statusKey: tenant.statusKey, statusIcon: tenant.statusIcon })),
            applicants: applicants.map((applicant) => ({ studentId: applicant.studentId, name: applicant.name, initials: applicant.initials, leaseId: applicant.id })),
          }
        }),
    }))
  } catch (error: any) {
    loadError.value = error?.message || 'Failed to load tenants'
  } finally {
    isLoading.value = false
  }
}

async function acceptApplication(leaseId: string) {
  applicationAction.value = leaseId
  const { error } = await supabase.from('leases').update({ status: 'active' } as any).eq('id', leaseId)
  if (error) {
    $q.notify({ type: 'negative', message: error.message })
    applicationAction.value = null
    return
  }
  $q.notify({ type: 'positive', message: 'Application accepted' })
  await loadTenants()
  applicationAction.value = null
}

async function declineApplication(leaseId: string) {
  applicationAction.value = leaseId
  const { error } = await supabase.from('leases').update({ status: 'ended' } as any).eq('id', leaseId)
  if (error) {
    $q.notify({ type: 'negative', message: error.message })
    applicationAction.value = null
    return
  }
  $q.notify({ type: 'positive', message: 'Application declined' })
  await loadTenants()
  applicationAction.value = null
}

const activeCount = computed(() => tenants.value.filter((tenant) => tenant.statusKey === 'active').length)
const hasEntries = computed(() => tenants.value.length > 0 || pendingApplications.value.length > 0)
const searchTerm = computed(() => searchText.value.trim().toLowerCase())
const hasActiveFilters = computed(() => statusFilter.value !== 'all' || Boolean(searchTerm.value))

const visiblePendingApplications = computed(() => {
  if (statusFilter.value !== 'all' && statusFilter.value !== 'pending') return []
  return pendingApplications.value.filter((application) => matchesSearch(application, searchTerm.value))
})

const visibleTenants = computed(() => {
  if (statusFilter.value === 'pending') return []
  return tenants.value.filter((tenant) => {
    const matchesFilter = statusFilter.value === 'all' || tenant.statusKey === statusFilter.value
    return matchesFilter && matchesSearch(tenant, searchTerm.value)
  })
})

const resultCount = computed(() => visibleTenants.value.length + visiblePendingApplications.value.length)

function clearFilters() {
  searchText.value = ''
  statusFilter.value = 'all'
  filterDialog.value = false
}

function openTenant(studentId: string) {
  void router.push(`/manager/tenant/${studentId}`)
}

onMounted(() => {
  void loadTenants()
})

// The tenant detail page mutates leases (accept / decline / approve leave). When
// the router returns here the component may be kept alive, so `onMounted` does
// not re-run and the list would still show the pre-decision state (e.g. a
// student who already moved out). Reload whenever this view is re-activated.
onActivated(() => {
  void loadTenants()
})
</script>

<style scoped>
.tenants-page {
  min-height: 100%;
  padding-bottom: calc(168px + env(safe-area-inset-bottom));
  background: var(--m-bg);
  color: var(--m-text);
}

.tenant-content {
  width: min(100%, 680px);
  margin: 0 auto;
  padding: var(--m-space-5) var(--m-space-4) var(--m-space-8);
}

.page-header { margin-bottom: var(--m-space-3); }
.eyebrow, .section-kicker { margin: 0; color: var(--m-primary); font-size: 11px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; }
.page-summary { margin: 0; color: var(--m-muted); font-size: 13px; line-height: 1.45; }
.page-summary span::before { content: ' '; }

.results-bar { display: flex; min-height: 24px; align-items: center; justify-content: space-between; gap: var(--m-space-3); margin-bottom: var(--m-space-5); color: var(--m-muted); font-size: 12px; font-weight: 700; }
.clear-filters { min-height: 36px; margin: -6px 0; padding: 0 4px; border: 0; background: transparent; color: var(--m-primary-dark); cursor: pointer; font: inherit; font-size: 12px; font-weight: 800; }

.tenant-action-bar { position: fixed; z-index: 59; right: 72px; bottom: 68px; left: var(--m-space-4); display: flex; align-items: center; gap: var(--m-space-2); }
.search-field { display: flex; min-width: 0; flex: 1; min-height: 44px; align-items: center; gap: var(--m-space-2); padding: 0 var(--m-space-3); border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); box-shadow: 0 4px 12px rgba(15, 23, 42, .08); color: var(--m-muted); }
.search-field:focus-within { border-color: var(--m-primary); color: var(--m-primary-dark); }
.search-field input { min-width: 0; flex: 1; border: 0; outline: 0; background: transparent; color: var(--m-ink); font: inherit; font-size: 14px; }
.search-field input::placeholder { color: var(--m-muted); opacity: 1; }
.search-clear, .filter-icon-button { display: grid; width: 44px; height: 44px; flex: 0 0 auto; place-items: center; padding: 0; border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); box-shadow: 0 4px 12px rgba(15, 23, 42, .08); color: var(--m-primary-dark); cursor: pointer; }
.search-clear { width: 28px; height: 28px; margin-right: -4px; border: 0; border-radius: 50%; box-shadow: none; color: var(--m-muted); }
.filter-icon-button--active { border-color: var(--m-primary-dark); background: var(--m-primary-soft); }

.tenant-filter-sheet { width: 100%; max-width: 680px; margin: 0 auto; border-radius: 18px 18px 0 0; }
.tenant-filter-sheet__heading { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--m-space-3); border-bottom: 1px solid var(--m-border); }
.tenant-filter-sheet__heading h2 { margin: 0; color: var(--m-ink); font-size: 18px; }
.tenant-filter-sheet__heading p { margin: 4px 0 0; color: var(--m-muted); font-size: 12px; }
.tenant-filter-options { display: flex; flex-wrap: wrap; gap: var(--m-space-2); }
.tenant-filter-options button { min-height: 40px; padding: 0 13px; border: 1px solid var(--m-border); border-radius: 999px; background: var(--m-surface); color: var(--m-text); font: inherit; font-size: 12px; font-weight: 750; }
.tenant-filter-options button.active { border-color: var(--m-primary-dark); background: var(--m-primary-dark); color: #fff; }
.tenant-filter-sheet__actions { display: flex; justify-content: space-between; padding: var(--m-space-3) var(--m-space-4) max(var(--m-space-3), env(safe-area-inset-bottom)); border-top: 1px solid var(--m-border); }

.applications-section, .roster-section { margin-top: var(--m-space-6); }
.applications-section:first-of-type { margin-top: 0; }
.section-heading { display: flex; min-height: 34px; align-items: center; justify-content: space-between; gap: var(--m-space-3); margin-bottom: var(--m-space-2); }
.section-heading h2 { margin: 2px 0 0; color: var(--m-ink); font-size: 17px; line-height: 1.2; letter-spacing: -.02em; }
.section-count { display: grid; min-width: 28px; height: 28px; padding: 0 var(--m-space-2); place-items: center; border-radius: 999px; background: var(--m-primary-soft); color: var(--m-primary-dark); font-size: 12px; font-weight: 800; }

.application-list, .tenant-list { overflow: hidden; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); box-shadow: var(--m-shadow); }
.application-row { display: grid; grid-template-columns: 40px minmax(0, 1fr); gap: var(--m-space-3); padding: var(--m-space-3); border-bottom: 1px solid var(--m-border); }
.application-row:last-child, .tenant-row:last-child { border-bottom: 0; }
.tenant-avatar { background: var(--m-primary-soft); color: var(--m-primary-dark); font-size: 12px; font-weight: 800; }
.row-copy { display: grid; min-width: 0; align-content: center; gap: 3px; text-align: left; }
.row-copy strong, .row-copy > span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.row-copy strong { color: var(--m-ink); font-size: 14px; line-height: 1.25; }
.row-copy > span { color: var(--m-muted); font-size: 12px; line-height: 1.25; }
.tenant-payment { display: inline-flex; align-items: center; gap: 4px; margin-top: 2px; font-size: 11px; font-weight: 750; line-height: 1.25; }
.tenant-payment--danger { color: var(--m-danger); }
.tenant-payment--warning { color: var(--m-warning); }
.tenant-payment--success { color: var(--m-success); }
.tenant-payment--neutral { color: var(--m-muted); }
.application-actions { display: grid; grid-column: 1 / -1; grid-template-columns: 1fr 1fr; gap: var(--m-space-2); }
.application-action, .retry-button { display: inline-flex; min-height: 44px; align-items: center; justify-content: center; gap: 6px; border-radius: var(--m-radius-sm); cursor: pointer; font: inherit; font-size: 13px; font-weight: 800; }
.application-action--accept { border: 1px solid var(--m-success); background: var(--m-success); color: var(--m-surface); }
.application-action--decline { border: 1px solid var(--m-border); background: var(--m-surface); color: var(--m-danger); }
.application-action:disabled { opacity: .6; cursor: wait; }

.tenant-row { display: grid; width: 100%; min-height: 66px; grid-template-columns: 40px minmax(0, 1fr) auto 20px; align-items: center; gap: var(--m-space-3); padding: var(--m-space-3); border: 0; border-bottom: 1px solid var(--m-border); background: var(--m-surface); color: inherit; cursor: pointer; font: inherit; }
.tenant-row:hover { background: var(--m-bg); }
.status-badge { display: inline-flex; max-width: 96px; min-height: 28px; align-items: center; gap: 4px; padding: 0 var(--m-space-2); border-radius: 999px; font-size: 10px; font-weight: 800; line-height: 1; white-space: nowrap; }
.status-badge--active { background: var(--m-primary-soft); color: var(--m-primary-dark); }
.status-badge--payment-due { background: var(--m-danger-soft); color: var(--m-danger); }
.status-badge--leaving { background: var(--m-warning-soft); color: var(--m-warning); }
.status-badge--ended, .status-badge--unknown { background: var(--m-bg); color: var(--m-muted); }
.row-chevron { color: var(--m-muted); }

.state-panel { display: grid; justify-items: center; gap: var(--m-space-2); padding: var(--m-space-8) var(--m-space-5); border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); color: var(--m-muted); text-align: center; }
.state-panel h2 { margin: var(--m-space-2) 0 0; color: var(--m-ink); font-size: 17px; }
.state-panel p { max-width: 340px; margin: 0; font-size: 13px; line-height: 1.5; }
.state-panel--error { border-color: var(--m-danger); }
.state-panel--error .state-icon { background: var(--m-danger-soft); color: var(--m-danger); }
.state-icon { display: grid; width: 48px; height: 48px; place-items: center; border-radius: var(--m-radius-sm); background: var(--m-primary-soft); color: var(--m-primary-dark); }
.retry-button { min-width: 108px; margin-top: var(--m-space-2); padding: 0 var(--m-space-3); border: 1px solid var(--m-primary-dark); background: var(--m-primary-dark); color: var(--m-surface); }

.skeleton-row { display: grid; width: 100%; grid-template-columns: 40px minmax(0, 1fr) 76px; align-items: center; gap: var(--m-space-3); }
.skeleton-row + .skeleton-row { padding-top: var(--m-space-3); border-top: 1px solid var(--m-border); }
.skeleton-avatar, .skeleton-copy i, .skeleton-badge { display: block; border-radius: var(--m-radius-sm); background: var(--m-primary-soft); animation: pulse 1.2s ease-in-out infinite alternate; }
.skeleton-avatar { width: 40px; height: 40px; border-radius: 50%; }
.skeleton-copy { display: grid; gap: 7px; }
.skeleton-copy i { width: 72%; height: 11px; }
.skeleton-copy i:last-child { width: 48%; height: 9px; }
.skeleton-badge { width: 76px; height: 28px; }

button:focus-visible, input:focus-visible { outline: 2px solid var(--m-primary); outline-offset: 2px; }
.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }

@keyframes pulse { to { opacity: .45; } }
@media (prefers-reduced-motion: reduce) { .skeleton-avatar, .skeleton-copy i, .skeleton-badge { animation: none; } }
@media (max-width: 360px) { .tenant-row { grid-template-columns: 40px minmax(0, 1fr) 20px; gap: var(--m-space-2); } .status-badge { grid-column: 2; justify-self: start; } .row-chevron { grid-column: 3; grid-row: 1 / span 2; } }

/* Property -> room -> occupant tree */
.homes-list { display: grid; gap: 16px; }
.home-block { overflow: hidden; border: 1px solid var(--m-border); border-radius: 14px; background: var(--m-surface); }
.home-heading { display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-bottom: 1px solid var(--m-border); background: var(--m-bg); }
.home-icon { display: grid; width: 34px; height: 34px; flex: 0 0 auto; place-items: center; border-radius: 9px; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.home-heading-copy { display: flex; flex-direction: column; min-width: 0; }
.home-heading-copy strong { color: var(--m-ink); font-size: 14px; font-weight: 700; }
.home-heading-copy small { color: var(--m-muted); font-size: 11px; }
.room-row { display: flex; width: 100%; min-height: 62px; align-items: center; gap: 12px; padding: 12px 16px; border: 0; background: var(--m-surface); text-align: left; font: inherit; }
.room-row + .room-row, .room-row + .room-row--open { border-top: 1px solid var(--m-border); }
.room-row--open { cursor: default; }
.room-row--taken { cursor: pointer; }
.room-row--taken:hover { background: color-mix(in srgb, var(--m-primary) 5%, var(--m-surface)); }
.room-row--pending { background: color-mix(in srgb, var(--m-warning) 6%, var(--m-surface)); cursor: default; }
.room-open-icon { display: grid; width: 38px; height: 38px; flex: 0 0 auto; place-items: center; border-radius: 9px; background: var(--m-bg); color: var(--m-muted); }
.room-open-icon--pending { background: var(--m-warning-soft); color: var(--m-warning); }
.home-empty { margin: 12px; padding: 14px; border: 1px dashed var(--m-border); border-radius: 10px; color: var(--m-muted); font-size: 12px; text-align: center; }

/* Room group: header strip + stacked occupant rows */
.room-group { border-top: 1px solid var(--m-border); }
.room-group:first-of-type { border-top: 0; }
.room-head { display: flex; align-items: center; gap: 8px; padding: 10px 16px 6px; background: color-mix(in srgb, var(--m-bg) 55%, var(--m-surface)); }
.room-head__icon { display: grid; width: 26px; height: 26px; place-items: center; border-radius: 7px; background: var(--m-surface); color: var(--m-muted); border: 1px solid var(--m-border); }
.room-head__label { font-size: 13.5px; letter-spacing: -0.01em; }
.room-head__floor { color: var(--m-muted); font-size: 11px; }
.room-head__count { margin-left: auto; padding: 2px 9px; border-radius: 999px; font-size: 11px; font-weight: 700; background: var(--m-primary-soft, color-mix(in srgb, var(--m-primary) 10%, transparent)); color: var(--m-primary); }
.room-head__count--full { background: var(--m-warning-soft); color: var(--m-warning); }
.room-body { display: grid; }
.room-row .row-copy { display: flex; min-width: 0; flex: 1; flex-direction: column; gap: 2px; }
.room-row .row-copy strong { color: var(--m-ink); font-size: 14px; font-weight: 700; }
.room-row .row-copy small { color: var(--m-muted); font-size: 12px; }
.room-row--pending .application-actions { display: flex; gap: 8px; }
.status-badge--neutral { background: var(--m-bg); color: var(--m-muted); }

</style>
