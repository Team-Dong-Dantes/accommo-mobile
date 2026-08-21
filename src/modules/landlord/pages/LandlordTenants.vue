<template>
  <q-page class="tenants-page bg-grey-1">
    <div class="header-shell q-px-md q-pt-lg q-pb-md">
      <div class="page-title">Tenants</div>
      <div class="page-subtitle">{{ activeCount }} active · {{ overdueCount }} with pending payments</div>
    </div>

    <div class="q-px-md q-mt-md">
      <q-input
        v-model="searchText"
        outlined
        dense
        rounded
        class="tenant-search"
        placeholder="Search tenants, rooms or properties..."
      >
        <template #prepend>
          <q-icon name="search" color="grey-7" />
        </template>
      </q-input>
    </div>

    <div v-if="isLoading" class="center-state">
      <q-spinner size="42px" color="teal-8" />
    </div>

    <div v-else-if="loadError" class="q-px-md q-pb-xl">
      <q-banner class="bg-red-1 text-red-8 rounded-borders">
        <template #avatar><q-icon name="error_outline" /></template>
        {{ loadError }}
      </q-banner>
    </div>

    <div v-else-if="!propertyGroups.length" class="center-state text-grey-7">
      No tenants yet. Tenants appear here once a lease is created for your property.
    </div>

    <div v-else class="tenant-groups q-px-md q-pb-xl">
      <div v-for="propertyGroup in filteredGroups" :key="propertyGroup.id" class="property-group">
        <div class="group-header row items-center no-wrap">
          <div class="group-icon">
            <q-icon name="apartment" size="20px" color="teal-8" />
          </div>

          <div class="group-copy col">
            <div class="group-name">{{ propertyGroup.name }}</div>
            <div class="group-address">{{ propertyGroup.address }}</div>
          </div>

          <q-badge color="teal-1" text-color="teal-8" class="tenant-count-badge">
            {{ propertyGroup.tenantCount }} tenants
          </q-badge>
        </div>

        <div class="room-groups">
          <div v-for="room in propertyGroup.rooms" :key="room.id" class="room-section">
            <div class="room-header row items-center no-wrap">
              <div class="room-icon" :class="room.iconColor">
                <q-icon :name="room.icon" size="18px" />
              </div>

              <div class="room-copy col">
                <div class="room-title">{{ room.title }}</div>
                <div class="room-subtitle" :class="room.subtextColor">{{ room.subtitle }}</div>
              </div>

              <div class="room-dots row items-center no-wrap">
                <span
                  v-for="dot in room.dotList"
                  :key="`${room.id}-${dot.id}`"
                  class="room-dot"
                  :class="dot.filled ? room.dotColor : 'dot-muted'"
                />
              </div>
            </div>

            <div class="tenant-list">
              <div
                v-for="tenant in room.tenants"
                :key="tenant.id"
                class="tenant-row row items-center no-wrap cursor-pointer"
                @click="openTenant(tenant.studentId)"
              >
                <q-avatar :color="tenant.avatarColor" text-color="white" size="38px" class="tenant-avatar">
                  {{ tenant.initials }}
                </q-avatar>

                <div class="tenant-copy col">
                  <div class="tenant-name">{{ tenant.name }}</div>
                  <div class="tenant-course">{{ tenant.course }}</div>
                </div>

                <q-badge :color="tenant.statusColor" :text-color="tenant.statusTextColor" class="tenant-status-badge">
                  {{ tenant.status }}
                </q-badge>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { supabase } from '@/shared/utils/supabase'

const $q = useQuasar()

const router = useRouter()
const searchText = ref('')

const isLoading = ref(false)
const loadError = ref<string | null>(null)
const propertyGroups = ref<any[]>([])

const AVATAR_PALETTE = ['teal-8', 'purple-6', 'pink-5', 'orange-5', 'blue-6', 'green-6']

function hashIndex(id: string, mod: number): number {
  let sum = 0
  for (const ch of id) sum += ch.charCodeAt(0)
  return sum % mod
}

function initialsOf(name: string): string {
  return (name || '?')
    .trim()
    .split(/\s+/)
    .map((p) => p[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

interface LeaseStatusInfo {
  label: string
  color: string
  textColor: string
  dotColor: string
  icon: string
  iconColor: string
  subtextColor: string
}

function leaseStatusInfo(status: string, leaveRequested: boolean | null): LeaseStatusInfo {
  if (leaveRequested) {
    return { label: 'Leaving', color: 'amber-1', textColor: 'amber-8', dotColor: 'dot-orange', icon: 'exit_to_app', iconColor: 'icon-orange', subtextColor: 'text-orange' }
  }
  switch (status) {
    case 'active':
      return { label: 'Current', color: 'teal-1', textColor: 'teal-8', dotColor: 'dot-teal', icon: 'person_outline', iconColor: 'icon-teal', subtextColor: 'text-teal' }
    case 'pending':
      return { label: 'Pending', color: 'blue-1', textColor: 'blue-8', dotColor: 'dot-teal', icon: 'schedule', iconColor: 'icon-teal', subtextColor: 'text-teal' }
    case 'terminated':
    case 'ended':
    case 'expired':
      return { label: 'Ended', color: 'grey-3', textColor: 'grey-8', dotColor: 'dot-muted', icon: 'block', iconColor: 'icon-purple', subtextColor: 'text-purple' }
    default:
      return { label: (status || 'Unknown').replace('_', ' '), color: 'grey-3', textColor: 'grey-8', dotColor: 'dot-muted', icon: 'help', iconColor: 'icon-purple', subtextColor: 'text-purple' }
  }
}

async function loadTenants() {
  isLoading.value = true
  loadError.value = null
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser()
    if (!user) return

    const { data: leases, error } = await supabase
      .from('leases')
      .select(
        `id, student_id, status, start_date, end_date, monthly_rent, deposit_paid, leave_requested_at,
         room:rooms!room_id(id, room_number, label, floor, capacity, current_pax, status,
           property:properties(name, address))`,
      )
      .eq('landlord_id', user.id)
      .order('start_date', { ascending: false })

    if (error) throw error

    const leaseRows = (leases || []) as any[]

    // Pull payment status per lease to surface pending/overdue tenants.
    const leaseIds = leaseRows.map((l) => l.id)
    const payPending = new Set<string>()
    if (leaseIds.length) {
      const { data: pays } = await supabase
        .from('payments')
        .select('lease_id, status')
        .in('lease_id', leaseIds)
        .in('status', ['due', 'overdue', 'pending_verification'])
      ;(pays || []).forEach((p: any) => payPending.add(p.lease_id))
    }

    const propMap = new Map<string, any>()
    let activeTotal = 0
    let overdueTotal = 0

    for (const l of leaseRows) {
      const room = (l.room as any) || {}
      const prop = (room.property as any) || {}
      const propId = prop.id || 'unknown'
      const propName = prop.name || 'Property'
      const propAddr = prop.address || ''
      const roomId = room.id || l.id
      const roomLabel = room.label || (room.room_number ? `Room ${room.room_number}` : 'Room')
      const capacity = room.capacity ?? 0
      const currentPax = room.current_pax ?? 0
      const statusInfo = leaseStatusInfo(l.status, !!l.leave_requested_at)

      if (l.status === 'active') activeTotal++
      if (payPending.has(l.id)) overdueTotal++

      const name = (l as any).student?.full_name || `Tenant ${l.student_id.slice(0, 4)}`
      const course =
        (room.label || room.room_number ? `Room ${room.room_number || room.label}` : '') +
        (room.floor ? ` · Floor ${room.floor}` : '')

      const tenant = {
        id: l.id,
        studentId: l.student_id,
        name,
        initials: (l as any).student?.initials || initialsOf(name),
        course: course || '—',
        status: payPending.has(l.id) ? 'Payment due' : statusInfo.label,
        avatarColor:
          (l as any).student?.avatar_color ||
          AVATAR_PALETTE[hashIndex(l.student_id, AVATAR_PALETTE.length)],
        statusColor: payPending.has(l.id) ? 'red-1' : statusInfo.color,
        statusTextColor: payPending.has(l.id) ? 'red-7' : statusInfo.textColor,
      }

      if (!propMap.has(propId)) {
        propMap.set(propId, {
          id: propId,
          name: propName,
          address: propAddr,
          tenantCount: 0,
          rooms: new Map<string, any>(),
        })
      }
      const pg = propMap.get(propId)!
      pg.tenantCount++

      if (!pg.rooms.has(roomId)) {
        const dots = []
        const dotCount = Math.max(capacity, 1)
        for (let i = 0; i < dotCount; i++) {
          dots.push({ id: String(i), filled: i < currentPax })
        }
        pg.rooms.set(roomId, {
          id: roomId,
          title: roomLabel,
          icon: statusInfo.icon,
          iconColor: statusInfo.iconColor,
          subtitle: `${currentPax}/${capacity} occupied`,
          subtextColor: statusInfo.subtextColor,
          dotColor: statusInfo.dotColor,
          dotList: dots,
          tenants: [],
        })
      }
      pg.rooms.get(roomId)!.tenants.push(tenant)
    }

    propertyGroups.value = Array.from(propMap.values()).map((pg) => ({
      id: pg.id,
      name: pg.name,
      address: pg.address,
      tenantCount: pg.tenantCount,
      rooms: Array.from(pg.rooms.values()),
    }))

    if (propertyGroups.value.length === 0) loadSampleData()
  } catch (e: any) {
    loadError.value = e?.message || 'Failed to load tenants'
  } finally {
    isLoading.value = false
  }
}

function loadSampleData() {
  propertyGroups.value = [
    {
      id: 'sample-prop-1',
      name: 'Sample Boarding House',
      address: 'Sample St., Sample City',
      tenantCount: 3,
      rooms: [
        {
          id: 'sample-room-1',
          title: 'Room 101',
          icon: 'person_outline',
          iconColor: 'icon-teal',
          subtitle: '2/4 occupied',
          subtextColor: 'text-teal',
          dotColor: 'dot-teal',
          dotList: [
            { id: '0', filled: true },
            { id: '1', filled: true },
            { id: '2', filled: false },
            { id: '3', filled: false },
          ],
          tenants: [
            { id: 's1', studentId: 'sample-1', name: 'Sample Tenant A', initials: 'ST', course: 'Room 101 · Floor 1', status: 'Current', avatarColor: 'teal-8', statusColor: 'teal-1', statusTextColor: 'teal-8' },
            { id: 's2', studentId: 'sample-2', name: 'Sample Tenant B', initials: 'SB', course: 'Room 101 · Floor 1', status: 'Current', avatarColor: 'purple-6', statusColor: 'teal-1', statusTextColor: 'teal-8' },
          ],
        },
        {
          id: 'sample-room-2',
          title: 'Room 102',
          icon: 'schedule',
          iconColor: 'icon-teal',
          subtitle: '1/2 occupied',
          subtextColor: 'text-teal',
          dotColor: 'dot-teal',
          dotList: [
            { id: '0', filled: true },
            { id: '1', filled: false },
          ],
          tenants: [
            { id: 's3', studentId: 'sample-3', name: 'Sample Tenant C', initials: 'SC', course: 'Room 102 · Floor 1', status: 'Payment due', avatarColor: 'orange-5', statusColor: 'red-1', statusTextColor: 'red-7' },
          ],
        },
      ],
    },
  ]
}

const activeCount = computed(() => {
  // count leases with status active from loaded groups
  let n = 0
  propertyGroups.value.forEach((pg) =>
    pg.rooms.forEach((r: any) => r.tenants.forEach((t: any) => {
      if (t.status === 'Current') n++
    })),
  )
  return n
})

const overdueCount = computed(() => {
  let n = 0
  propertyGroups.value.forEach((pg) =>
    pg.rooms.forEach((r: any) => r.tenants.forEach((t: any) => {
      if (t.status === 'Payment due') n++
    })),
  )
  return n
})

const filteredGroups = computed(() => {
  const term = searchText.value.trim().toLowerCase()
  if (!term) return propertyGroups.value

  return propertyGroups.value
    .map((pg) => {
      const rooms = pg.rooms
        .map((room: any) => ({
          ...room,
          tenants: room.tenants.filter(
            (t: any) =>
              t.name.toLowerCase().includes(term) ||
              t.course.toLowerCase().includes(term),
          ),
        }))
        .filter((room: any) => room.tenants.length > 0)
      const matchProperty = pg.name.toLowerCase().includes(term)
      if (matchProperty) {
        // when searching the property name, keep all its tenants
        const allRooms = pg.rooms
        return { ...pg, rooms: allRooms }
      }
      return rooms.length ? { ...pg, rooms } : null
    })
    .filter(Boolean) as any[]
})

function openTenant(studentId: string) {
  void router.push(`/landlord/tenant/${studentId}`)
}

onMounted(() => {
  void loadTenants()
})
</script>

<style scoped>
.tenants-page {
  background: #f4f5f7;
}

.center-state {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 48px 24px;
  text-align: center;
  color: #6b7280;
}

.header-shell {
  background: #f4f5f7;
}

.page-title {
  color: #111827;
  font-size: 30px;
  font-weight: 800;
  letter-spacing: -0.05em;
}

.page-subtitle {
  color: #6b7280;
  font-size: 13px;
  font-weight: 600;
  margin-top: 4px;
}

.tenant-search :deep(.q-field__control) {
  height: 48px;
  border-radius: 14px;
}

.tenant-groups {
  display: flex;
  flex-direction: column;
  gap: 22px;
}

.property-group {
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 22px;
  overflow: hidden;
}

.group-header {
  padding: 16px 14px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
}

.group-icon {
  width: 38px;
  height: 38px;
  border-radius: 10px;
  background: rgba(13, 148, 136, 0.08);
  display: flex;
  align-items: center;
  justify-content: center;
}

.group-copy {
  margin-left: 12px;
}

.group-name {
  color: #111827;
  font-size: 15px;
  font-weight: 800;
}

.group-address {
  color: #6b7280;
  font-size: 11px;
  margin-top: 3px;
}

.tenant-count-badge {
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  padding: 6px 10px;
}

.room-groups {
  background: #ffffff;
}

.room-section {
  padding: 14px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.05);
}

.room-section:last-child {
  border-bottom: none;
}

.room-header {
  gap: 10px;
}

.room-icon {
  width: 32px;
  height: 32px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.icon-orange {
  background: rgba(245, 158, 11, 0.1);
  color: #d97706;
}

.icon-teal {
  background: rgba(13, 148, 136, 0.1);
  color: #0f766e;
}

.icon-purple {
  background: rgba(124, 58, 237, 0.1);
  color: #7c3aed;
}

.room-copy {
  min-width: 0;
}

.room-title {
  color: #111827;
  font-size: 14px;
  font-weight: 700;
}

.room-subtitle {
  font-size: 11px;
  font-weight: 700;
  margin-top: 3px;
}

.text-orange {
  color: #d97706;
}

.text-teal {
  color: #0f766e;
}

.text-purple {
  color: #7c3aed;
}

.room-dots {
  gap: 6px;
}

.room-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: inline-block;
}

.dot-orange {
  background: #f59e0b;
}

.dot-teal {
  background: #0f766e;
}

.dot-purple {
  background: #8b5cf6;
}

.dot-muted {
  background: #d1d5db;
}

.tenant-list {
  margin-top: 12px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.tenant-row {
  gap: 12px;
  padding: 2px 0;
}

.tenant-avatar {
  font-size: 12px;
  font-weight: 700;
  letter-spacing: -0.02em;
}

.tenant-copy {
  min-width: 0;
}

.tenant-name {
  color: #111827;
  font-size: 15px;
  font-weight: 700;
}

.tenant-course {
  color: #6b7280;
  font-size: 12px;
  margin-top: 3px;
}

.tenant-status-badge {
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  padding: 5px 10px;
}
</style>
