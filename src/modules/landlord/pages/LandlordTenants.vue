<template>
  <q-page class="tenants-page">
    <main id="tenant-list" class="tenant-content">
      <header class="page-header">
        <h1 class="sr-only">Tenants</h1>
        <p class="page-summary">
          {{ activeCount }} active {{ activeCount === 1 ? 'tenant' : 'tenants' }}
          <span v-if="pendingApplications.length">and {{ pendingApplications.length }} application{{ pendingApplications.length === 1 ? '' : 's' }} to review</span>
        </p>
      </header>

      <section class="search-section" aria-label="Find tenants">
        <label class="sr-only" for="tenant-search">Search tenants, properties, or rooms</label>
        <div class="search-control">
          <IconifyIcon icon="lucide:search" width="19" aria-hidden="true" />
          <input
            id="tenant-search"
            v-model="searchText"
            type="search"
            autocomplete="off"
            placeholder="Search tenants, properties, or rooms"
          />
          <button v-if="searchText" type="button" class="search-clear" aria-label="Clear search" @click="searchText = ''">
            <IconifyIcon icon="lucide:x" width="18" aria-hidden="true" />
          </button>
        </div>

        <nav class="filter-bar" aria-label="Tenant status filters">
          <button
            v-for="filter in filters"
            :key="filter.value"
            type="button"
            class="filter-button"
            :class="{ 'filter-button--active': statusFilter === filter.value }"
            :aria-pressed="statusFilter === filter.value"
            @click="statusFilter = filter.value"
          >
            {{ filter.label }}
          </button>
        </nav>

        <div class="results-bar" aria-live="polite">
          <span>{{ resultCount }} {{ resultCount === 1 ? 'result' : 'results' }}</span>
          <button v-if="hasActiveFilters" type="button" class="clear-filters" @click="clearFilters">
            Clear filters
          </button>
        </div>
      </section>

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
        <section v-if="visiblePendingApplications.length" class="applications-section" aria-labelledby="applications-heading">
          <div class="section-heading">
            <div>
              <p class="section-kicker">Needs a decision</p>
              <h2 id="applications-heading">Pending applications</h2>
            </div>
            <span class="section-count">{{ visiblePendingApplications.length }}</span>
          </div>

          <div class="application-list">
            <article v-for="application in visiblePendingApplications" :key="application.id" class="application-row">
              <q-avatar size="40px" class="tenant-avatar" aria-hidden="true">{{ application.initials }}</q-avatar>
              <div class="row-copy">
                <strong :title="application.name">{{ application.name }}</strong>
                <span :title="`${application.property} · ${application.room}`">{{ application.property }} · {{ application.room }}</span>
              </div>
              <div class="application-actions">
                <button
                  type="button"
                  class="application-action application-action--accept"
                  :disabled="applicationAction === application.id"
                  @click="acceptApplication(application.id)"
                >
                  <IconifyIcon icon="lucide:check" width="16" aria-hidden="true" />
                  Accept
                </button>
                <button
                  type="button"
                  class="application-action application-action--decline"
                  :disabled="applicationAction === application.id"
                  @click="declineApplication(application.id)"
                >
                  <IconifyIcon icon="lucide:x" width="16" aria-hidden="true" />
                  Decline
                </button>
              </div>
            </article>
          </div>
        </section>

        <section v-if="visibleTenants.length" class="roster-section" aria-labelledby="roster-heading">
          <div class="section-heading">
            <div>
              <p class="section-kicker">Current roster</p>
              <h2 id="roster-heading">Tenant list</h2>
            </div>
            <span class="section-count">{{ visibleTenants.length }}</span>
          </div>

          <div class="tenant-list">
            <button
              v-for="tenant in visibleTenants"
              :key="tenant.id"
              type="button"
              class="tenant-row"
              :aria-label="`View ${tenant.name}, ${tenant.property}, ${tenant.room}, ${tenant.status}`"
              @click="openTenant(tenant.studentId)"
            >
              <q-avatar size="40px" class="tenant-avatar" aria-hidden="true">{{ tenant.initials }}</q-avatar>
              <span class="row-copy">
                <strong :title="tenant.name">{{ tenant.name }}</strong>
                <span :title="`${tenant.property} · ${tenant.room}`">{{ tenant.property }} · {{ tenant.room }}</span>
              </span>
              <span class="status-badge" :class="`status-badge--${tenant.statusKey}`">
                <IconifyIcon :icon="tenant.statusIcon" width="14" aria-hidden="true" />
                {{ tenant.status }}
              </span>
              <IconifyIcon class="row-chevron" icon="lucide:chevron-right" width="20" aria-hidden="true" />
            </button>
          </div>
        </section>

        <section v-if="!hasEntries" class="state-panel" aria-labelledby="empty-heading">
          <span class="state-icon"><IconifyIcon icon="lucide:users-round" width="24" aria-hidden="true" /></span>
          <h2 id="empty-heading">No tenants yet</h2>
          <p>Tenants appear here after a lease is created for one of your properties.</p>
        </section>

        <section v-else-if="!visibleTenants.length && !visiblePendingApplications.length" class="state-panel" aria-labelledby="no-results-heading">
          <span class="state-icon"><IconifyIcon icon="lucide:search-x" width="24" aria-hidden="true" /></span>
          <h2 id="no-results-heading">No matching tenants</h2>
          <p>Try another search or clear the active filters.</p>
          <button type="button" class="retry-button" @click="clearFilters">Clear filters</button>
        </section>
      </template>
    </main>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useQuasar } from 'quasar'
import { useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'

type TenantFilter = 'all' | 'active' | 'pending' | 'payment-due' | 'leaving'
type TenantStatusKey = Exclude<TenantFilter, 'all' | 'pending'> | 'ended' | 'unknown'

interface Tenant {
  id: string
  studentId: string
  name: string
  initials: string
  property: string
  room: string
  status: string
  statusKey: TenantStatusKey
  statusIcon: string
}

interface PendingApplication {
  id: string
  name: string
  initials: string
  property: string
  room: string
}

const $q = useQuasar()
const router = useRouter()
const searchText = ref('')
const statusFilter = ref<TenantFilter>('all')
const isLoading = ref(false)
const loadError = ref<string | null>(null)
const applicationAction = ref<string | null>(null)
const tenants = ref<Tenant[]>([])
const pendingApplications = ref<PendingApplication[]>([])

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
  if (paymentDue) return { status: 'Payment due', statusKey: 'payment-due', statusIcon: 'lucide:receipt-text' }
  if (leaveRequested) return { status: 'Leaving', statusKey: 'leaving', statusIcon: 'lucide:log-out' }
  if (status === 'active') return { status: 'Active', statusKey: 'active', statusIcon: 'lucide:circle-check' }
  if (['ended', 'expired', 'terminated'].includes(status)) return { status: 'Ended', statusKey: 'ended', statusIcon: 'lucide:circle-x' }
  return { status: status ? status.replace(/_/g, ' ') : 'Unknown', statusKey: 'unknown', statusIcon: 'lucide:circle-help' }
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

    const paymentDueLeaseIds = new Set<string>()
    const leaseIds = leaseRows.map((lease) => lease.id)
    if (leaseIds.length) {
      const { data: payments, error: paymentError } = await supabase
        .from('payments')
        .select('lease_id, status')
        .in('lease_id', leaseIds)
        .in('status', ['due', 'overdue', 'pending_verification'])
      if (paymentError) throw paymentError
      ;(payments || []).forEach((payment: any) => paymentDueLeaseIds.add(payment.lease_id))
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
      }

      if (lease.status === 'pending') {
        nextPendingApplications.push({
          id: lease.id,
          name,
          initials: initialsOf(name),
          ...tenantLocation,
        })
        continue
      }

      const status = tenantStatus(
        String(lease.status || '').toLowerCase(),
        Boolean(lease.leave_requested_at),
        paymentDueLeaseIds.has(lease.id),
      )
      nextTenants.push({
        id: lease.id,
        studentId: lease.student_id,
        name,
        initials: initialsOf(name),
        ...tenantLocation,
        ...status,
      })
    }

    tenants.value = nextTenants
    pendingApplications.value = nextPendingApplications
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
}

function openTenant(studentId: string) {
  void router.push(`/landlord/tenant/${studentId}`)
}

onMounted(() => {
  void loadTenants()
})
</script>

<style scoped>
.tenants-page {
  min-height: 100%;
  padding-bottom: calc(84px + env(safe-area-inset-bottom));
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

.search-section { display: grid; gap: var(--m-space-3); margin-bottom: var(--m-space-6); }
.search-control { display: grid; min-height: 48px; grid-template-columns: auto minmax(0, 1fr) auto; align-items: center; gap: var(--m-space-2); padding: 0 var(--m-space-3); border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); color: var(--m-muted); }
.search-control:focus-within { border-color: var(--m-primary); box-shadow: 0 0 0 2px var(--m-primary-soft); color: var(--m-primary-dark); }
.search-control input { min-width: 0; border: 0; outline: 0; background: transparent; color: var(--m-ink); font: inherit; font-size: 15px; }
.search-control input::placeholder { color: var(--m-muted); opacity: 1; }
.search-clear { display: grid; width: 36px; height: 36px; margin-right: -6px; padding: 0; place-items: center; border: 0; border-radius: 50%; background: transparent; color: var(--m-muted); cursor: pointer; }
.search-clear:hover { background: var(--m-bg); color: var(--m-ink); }

.filter-bar { display: flex; flex-wrap: wrap; gap: var(--m-space-2); }
.filter-button { min-height: 36px; padding: 0 12px; border: 1px solid var(--m-border); border-radius: 999px; background: var(--m-surface); color: var(--m-muted); cursor: pointer; font: inherit; font-size: 12px; font-weight: 700; }
.filter-button:hover { border-color: var(--m-primary); color: var(--m-primary-dark); }
.filter-button--active { border-color: var(--m-primary-dark); background: var(--m-primary-dark); color: var(--m-surface); }
.filter-button--active:hover { color: var(--m-surface); }
.results-bar { display: flex; min-height: 24px; align-items: center; justify-content: space-between; gap: var(--m-space-3); color: var(--m-muted); font-size: 12px; font-weight: 700; }
.clear-filters { min-height: 36px; margin: -6px 0; padding: 0 4px; border: 0; background: transparent; color: var(--m-primary-dark); cursor: pointer; font: inherit; font-size: 12px; font-weight: 800; }

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
</style>
