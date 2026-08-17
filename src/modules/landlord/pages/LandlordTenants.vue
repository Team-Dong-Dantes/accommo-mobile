<template>
  <q-page class="tenants-page bg-grey-1">
    <div class="header-shell q-px-md q-pt-lg q-pb-md">
      <div class="page-title">Tenants</div>
      <div class="page-subtitle">6 active · 1 overdue</div>
    </div>

    <div class="q-px-md q-mt-md">
      <q-input
        v-model="searchText"
        outlined
        dense
        rounded
        class="tenant-search"
        placeholder="Search tenants..."
      >
        <template #prepend>
          <q-icon name="search" color="grey-7" />
        </template>
      </q-input>
    </div>

    <div class="tenant-groups q-px-md q-pb-xl">
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
              <div v-for="tenant in room.tenants" :key="tenant.id" class="tenant-row row items-center no-wrap">
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
import { computed, ref } from 'vue'

interface TenantStatusDot {
  id: string
  filled: boolean
}

interface RoomTenant {
  id: string
  initials: string
  name: string
  course: string
  status: string
  avatarColor: string
  statusColor: string
  statusTextColor: string
}

interface RoomGroup {
  id: string
  title: string
  icon: string
  iconColor: string
  subtitle: string
  subtextColor: string
  dotColor: string
  dotList: TenantStatusDot[]
  tenants: RoomTenant[]
}

interface PropertyGroup {
  id: string
  name: string
  address: string
  tenantCount: number
  rooms: RoomGroup[]
}

const searchText = ref('')

const propertyGroups = ref<PropertyGroup[]>([
  {
    id: 'pinzon',
    name: 'Pinzon Student Hub',
    address: 'Blk 5 Pinzon Subdivision, Echague',
    tenantCount: 4,
    rooms: [
      {
        id: 'bed-1a',
        title: 'Bedspacer · Bed 1-A',
        icon: 'bed',
        iconColor: 'icon-orange',
        subtitle: '2/6 occupied · 4 vacant',
        subtextColor: 'text-orange',
        dotColor: 'dot-orange',
        dotList: [
          { id: 'o1', filled: true },
          { id: 'o2', filled: true },
          { id: 'o3', filled: false },
          { id: 'o4', filled: false },
          { id: 'o5', filled: false },
          { id: 'o6', filled: false },
        ],
        tenants: [
          {
            id: 'jose',
            initials: 'JR',
            name: 'Jose Reyes',
            course: 'BS Civil Engineering',
            status: 'Due',
            avatarColor: 'purple-6',
            statusColor: 'amber-1',
            statusTextColor: 'amber-8',
          },
          {
            id: 'carlo',
            initials: 'CM',
            name: 'Carlo Mendoza',
            course: 'BS Nursing',
            status: 'Current',
            avatarColor: 'pink-5',
            statusColor: 'teal-1',
            statusTextColor: 'teal-8',
          },
        ],
      },
      {
        id: 'solo-2b',
        title: 'Solo · Room 2-B',
        icon: 'person_outline',
        iconColor: 'icon-teal',
        subtitle: '1/1 occupied',
        subtextColor: 'text-teal',
        dotColor: 'dot-teal',
        dotList: [
          { id: 't1', filled: true },
          { id: 't2', filled: false },
          { id: 't3', filled: false },
          { id: 't4', filled: false },
          { id: 't5', filled: false },
          { id: 't6', filled: false },
        ],
        tenants: [
          {
            id: 'maria',
            initials: 'MS',
            name: 'Maria Santos',
            course: 'BS Computer Engineering',
            status: 'Current',
            avatarColor: 'teal-8',
            statusColor: 'teal-1',
            statusTextColor: 'teal-8',
          },
        ],
      },
      {
        id: 'double-101',
        title: 'Double · Room 101',
        icon: 'people_outline',
        iconColor: 'icon-purple',
        subtitle: '1/2 occupied · 1 vacant',
        subtextColor: 'text-purple',
        dotColor: 'dot-purple',
        dotList: [
          { id: 'p1', filled: true },
          { id: 'p2', filled: false },
          { id: 'p3', filled: false },
          { id: 'p4', filled: false },
          { id: 'p5', filled: false },
          { id: 'p6', filled: false },
        ],
        tenants: [
          {
            id: 'ana',
            initials: 'AV',
            name: 'Ana Villanueva',
            course: 'BS Accountancy',
            status: 'Overdue',
            avatarColor: 'orange-5',
            statusColor: 'red-1',
            statusTextColor: 'red-7',
          },
        ],
      },
    ],
  },
])

const filteredGroups = computed(() => {
  if (!searchText.value.trim()) return propertyGroups.value

  const term = searchText.value.trim().toLowerCase()

  return propertyGroups.value
    .map((propertyGroup) => ({
      ...propertyGroup,
      rooms: propertyGroup.rooms
        .map((room) => ({
          ...room,
          tenants: room.tenants.filter((tenant) =>
            tenant.name.toLowerCase().includes(term) ||
            tenant.course.toLowerCase().includes(term),
          ),
        }))
        .filter((room) => room.tenants.length > 0),
    }))
    .filter((propertyGroup) => {
      const matchProperty = propertyGroup.name.toLowerCase().includes(term)
      const matchRoom = propertyGroup.rooms.some((room) => room.title.toLowerCase().includes(term))
      return matchProperty || matchRoom || propertyGroup.rooms.length > 0
    })
})
</script>

<style scoped>
.tenants-page {
  background: #f4f5f7;
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
