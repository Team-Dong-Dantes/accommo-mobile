<template>
  <q-page class="tp">
    <div v-if="!loading && !error" class="dock">
      <div class="dock-field">
        <IconifyIcon icon="lucide:search" width="16" class="dock-icon" />
        <input
          v-model="query"
          class="dock-input"
          type="search"
          placeholder="Search tenants or rooms"
          aria-label="Search tenants"
        />
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
      <q-skeleton type="rect" height="96px" class="sk" />
      <q-skeleton type="rect" height="96px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your tenants</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <EmptyState
      v-else-if="!accommodations.length"
      icon="lucide:users"
      title="No tenants yet"
      message="When a student applies for one of your rooms and you accept them, they show up here grouped by room — empty beds included, plus any applications still waiting on you."
    />

    <div v-else class="stack">
      <section v-for="acc in visibleAccommodations" :key="acc.id" class="acc">
        <h2 class="acc-title">{{ acc.name }}</h2>
        <div v-for="room in acc.rooms" :key="room.id" class="room">
          <div class="room-head">
            <span class="room-name">{{ room.label }}</span>
            <span class="room-cap">{{ room.leases.length }}/{{ room.capacity ?? '—' }}</span>
          </div>
          <div v-if="room.leases.length" class="room-list">
            <button
              v-for="l in room.leases"
              :key="l.id"
              type="button"
              class="lease-row"
              @click="router.push(`/manager/tenant/${l.id}`)"
            >
              <span class="lease-avatar">{{ initialsOf(l.studentName) }}</span>
              <span class="lease-body">
                <span class="lease-name">{{ l.studentName }}</span>
                <span class="lease-sub">{{ statusText(LEASE_STATUS, l.status) }}</span>
              </span>
              <span class="lease-chip" :class="`lease-chip--${statusColor(LEASE_STATUS, l.status)}`">
                {{ statusText(LEASE_STATUS, l.status) }}
              </span>
            </button>
          </div>
          <p v-else class="room-none">No tenants</p>
        </div>
      </section>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { initialsOf, LEASE_STATUS, statusText, statusColor } from '@/utils/format'
import EmptyState from '@/components/shared/EmptyState.vue'

interface Lease {
  id: string
  status: string
  studentName: string
}
interface Room {
  id: string
  label: string
  capacity: number | null
  leases: Lease[]
}
interface Accommodation {
  id: string
  name: string
  rooms: Room[]
}

const FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'pending', label: 'Applications' },
  { key: 'active', label: 'Tenants' },
  { key: 'leave_requested', label: 'Leave requests' },
] as const

const router = useRouter()

const loading = ref(true)
const error = ref('')
const accommodations = ref<Accommodation[]>([])
const query = ref('')
const filter = ref<(typeof FILTERS)[number]['key']>('all')

const visibleAccommodations = computed(() => {
  const q = query.value.trim().toLowerCase()
  return accommodations.value
    .map((acc) => ({
      ...acc,
      rooms: acc.rooms
        .map((room) => ({
          ...room,
          leases: room.leases.filter((l) => {
            if (filter.value !== 'all' && l.status !== filter.value) return false
            if (!q) return true
            return (
              l.studentName.toLowerCase().includes(q) ||
              room.label.toLowerCase().includes(q) ||
              acc.name.toLowerCase().includes(q)
            )
          }),
        }))
        .filter((room) => (filter.value === 'all' && !q ? true : room.leases.length > 0)),
    }))
    .filter((acc) => acc.rooms.length > 0)
})

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

    const { data: accRows, error: accError } = await supabase
      .from('accommodations')
      .select('id,name')
      .eq('accommodation_manager_id', user.id)
    if (accError) throw accError

    const accIds = (accRows ?? []).map((a) => a.id)
    let roomRows: { id: string; label: string | null; room_number: string | null; capacity: number | null; accommodation_id: string }[] = []
    if (accIds.length) {
      const { data, error: roomError } = await supabase
        .from('rooms')
        .select('id,label,room_number,capacity,accommodation_id')
        .in('accommodation_id', accIds)
      if (roomError) throw roomError
      roomRows = data ?? []
    }

    const { data: leaseRows, error: leaseError } = await supabase
      .from('leases')
      .select('id,status,room_id,users!leases_student_id_fkey(full_name)')
      .eq('accommodation_manager_id', user.id)
      .in('status', ['active', 'pending', 'leave_requested'])
    if (leaseError) throw leaseError

    const leasesByRoom = new Map<string, Lease[]>()
    for (const l of leaseRows ?? []) {
      const student = l.users as unknown as { full_name: string | null } | null
      const list = leasesByRoom.get(l.room_id) ?? []
      list.push({ id: l.id, status: l.status, studentName: student?.full_name || 'A student' })
      leasesByRoom.set(l.room_id, list)
    }

    accommodations.value = (accRows ?? []).map((acc) => ({
      id: acc.id,
      name: acc.name?.trim() || 'Unnamed accommodation',
      rooms: roomRows
        .filter((r) => r.accommodation_id === acc.id)
        .map((r) => ({
          id: r.id,
          label: r.label || (r.room_number ? `Room ${r.room_number}` : 'Room'),
          capacity: r.capacity,
          leases: leasesByRoom.get(r.id) ?? [],
        })),
    }))
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.tp {
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 8px var(--m-page-gutter) 24px;
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

.acc {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.acc-title {
  margin: 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.room {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.room-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 9px 12px;
  background: var(--m-bg);
}
.room-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.room-cap {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 600;
}
.room-none {
  margin: 0;
  padding: 12px;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}
.room-list {
  display: flex;
  flex-direction: column;
}
.lease-row {
  display: flex;
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
.room-list > .lease-row:first-child {
  border-top: 0;
}
.lease-avatar {
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
.lease-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.lease-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.lease-sub {
  color: var(--m-muted);
  font-size: 11.5px;
}
.lease-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.lease-chip--teal {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.lease-chip--amber,
.lease-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.lease-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.lease-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
</style>
