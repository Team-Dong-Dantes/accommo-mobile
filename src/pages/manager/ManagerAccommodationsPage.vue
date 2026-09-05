<template>
  <q-page class="ap">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="230px" class="sk" />
      <q-skeleton type="rect" height="230px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your accommodations</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <EmptyState
      v-else-if="!rows.length"
      icon="lucide:building-2"
      title="No accommodations listed yet"
      message="Add your first place and its rooms so students can find and apply to stay with you."
    >
      <template #actions>
        <q-btn unelevated rounded no-caps color="primary" label="Add accommodation" @click="router.push('/manager/properties/new')" />
      </template>
    </EmptyState>

    <div v-else class="stack">
      <button v-for="a in rows" :key="a.id" type="button" class="acc-card" @click="router.push(`/manager/properties/${a.id}`)">
        <span class="acc-photo" :class="{ 'acc-photo--empty': !a.image }">
          <img v-if="a.image" :src="a.image" :alt="a.name" loading="lazy" />
          <span v-else class="acc-photo-empty">
            <IconifyIcon icon="lucide:image-off" width="24" />
            <span class="acc-photo-empty-label">No photo</span>
          </span>
          <span class="acc-status" :class="`acc-status--${STATUS_TONE[a.status] || 'grey'}`">
            <IconifyIcon :icon="STATUS_ICON[a.status] || 'lucide:circle'" width="10" />
            {{ STATUS_LABEL[a.status] || a.status }}
          </span>
          <span class="acc-health-dot" :class="`acc-health-dot--${healthTone(a)}`" />
        </span>

        <span class="acc-body">
          <span class="acc-head">
            <span class="acc-name">{{ a.name }}</span>
            <span v-if="a.type" class="acc-type">{{ a.type }}</span>
          </span>
          <span v-if="a.address" class="acc-addr">
            <IconifyIcon icon="lucide:map-pin" width="12" />
            {{ a.address }}
          </span>

          <span class="facts">
            <span class="fact">
              <span class="fact-value">{{ a.roomCount }}</span>
              <span class="fact-label">{{ a.roomCount === 1 ? 'Room' : 'Rooms' }}</span>
            </span>
            <span class="fact-div" />
            <span class="fact">
              <span class="fact-value">{{ a.filled }}/{{ a.capacity }}</span>
              <span class="fact-label">Beds filled</span>
            </span>
          </span>

          <span class="acc-doc-summary">
            <span v-if="a.expired > 0" class="doc-expired">
              <IconifyIcon icon="lucide:file-warning" width="14" />
              {{ a.expired }} expired {{ a.expired === 1 ? 'permit' : 'permits' }}
            </span>
            <span v-else-if="a.expiringSoon > 0" class="doc-expiring">
              <IconifyIcon icon="lucide:clock" width="14" />
              {{ a.expiringSoon }} expiring soon
            </span>
            <span v-else class="doc-ok">
              <IconifyIcon icon="lucide:check-circle" width="14" />
              All permits up to date
            </span>
          </span>
        </span>
      </button>

      <button type="button" class="acc-card acc-card--add" @click="router.push('/manager/properties/new')">
        <span class="acc-add-icon"><IconifyIcon icon="lucide:plus" width="22" /></span>
        <span class="acc-add-label">Add another</span>
      </button>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import EmptyState from '@/components/shared/EmptyState.vue'

const STATUS_LABEL: Record<string, string> = {
  pending: 'Pending review',
  reviewing: 'Reviewing',
  accredited: 'Accredited',
  rejected: 'Rejected',
  delisted: 'Delisted',
}
const STATUS_TONE: Record<string, string> = {
  pending: 'amber',
  reviewing: 'amber',
  accredited: 'green',
  rejected: 'red',
  delisted: 'grey',
}
const STATUS_ICON: Record<string, string> = {
  pending: 'lucide:hourglass',
  reviewing: 'lucide:search',
  accredited: 'lucide:badge-check',
  rejected: 'lucide:x-circle',
  delisted: 'lucide:archive',
}

interface Row {
  id: string
  name: string
  address: string
  status: string
  type: string
  image: string
  roomCount: number
  capacity: number
  filled: number
  expired: number
  expiringSoon: number
}

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

// Health tone for the photo dot: permit trouble first, then accreditation.
function healthTone(a: Row): 'good' | 'warn' | 'danger' {
  if (a.expired > 0) return 'danger'
  if (a.expiringSoon > 0) return 'warn'
  if (a.status !== 'accredited') return 'warn'
  return 'good'
}

const router = useRouter()
const loading = ref(true)
const error = ref('')
const rows = ref<Row[]>([])

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
      .from('accommodations')
      .select(
        'id,name,address,barangay,city,status,accommodation_type,total_rooms,accommodation_images(url,sort_order),rooms(id,capacity)',
      )
      .eq('accommodation_manager_id', user.id)
      .order('name')
    if (loadError) throw loadError

    const accs = data ?? []
    const accIds = accs.map((a) => a.id)

    const roomToAcc = new Map<string, string>()
    for (const a of accs) {
      for (const r of (a.rooms ?? []) as { id: string }[]) {
        roomToAcc.set(r.id, a.id)
      }
    }

    // Active leases -> beds filled per accommodation.
    const filledByAcc = new Map<string, number>()
    if (accIds.length) {
      const { data: leaseRows } = await supabase
        .from('leases')
        .select('room_id')
        .eq('accommodation_manager_id', user.id)
        .eq('status', 'active')
      for (const l of leaseRows || []) {
        const accId = roomToAcc.get(l.room_id)
        if (accId) filledByAcc.set(accId, (filledByAcc.get(accId) || 0) + 1)
      }
    }

    // Permit/document health per accommodation.
    const expiredByAcc = new Map<string, number>()
    const expiringSoonByAcc = new Map<string, number>()
    if (accIds.length) {
      const { data: docRows } = await supabase
        .from('accommodation_documents')
        .select('id, expires_at, accommodation_id')
        .in('accommodation_id', accIds)
      const now = Date.now()
      const soon = now + 30 * 24 * 60 * 60 * 1000
      for (const d of docRows || []) {
        if (!d.expires_at) continue
        const t = new Date(d.expires_at).getTime()
        if (t < now) expiredByAcc.set(d.accommodation_id, (expiredByAcc.get(d.accommodation_id) || 0) + 1)
        else if (t < soon) expiringSoonByAcc.set(d.accommodation_id, (expiringSoonByAcc.get(d.accommodation_id) || 0) + 1)
      }
    }

    rows.value = accs.map((a) => {
      const images = [...((a.accommodation_images ?? []) as { url: string; sort_order: number | null }[])].sort(
        (x, y) => (x.sort_order ?? 0) - (y.sort_order ?? 0),
      )
      const name = a.name?.trim() || 'Unnamed accommodation'
      const acRooms = (a.rooms ?? []) as { id: string; capacity: number | null }[]
      return {
        id: a.id,
        name,
        address: a.address || [a.barangay, a.city].filter(Boolean).join(', ') || 'Address not given',
        status: a.status,
        type: titleCase(a.accommodation_type),
        image: images[0]?.url ? resolveAsset(images[0].url) : '',
        roomCount: a.total_rooms ?? acRooms.length,
        capacity: acRooms.reduce((n, r) => n + Number(r.capacity || 0), 0),
        filled: filledByAcc.get(a.id) || 0,
        expired: expiredByAcc.get(a.id) || 0,
        expiringSoon: expiringSoonByAcc.get(a.id) || 0,
      }
    })
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.ap {
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

.acc-card {
  display: flex;
  width: 100%;
  flex-direction: column;
  padding: 0 0 11px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  overflow: hidden;
  position: relative;
  transition: box-shadow 0.15s, transform 0.12s ease;
  box-shadow: 0 1px 3px rgba(0,0,0,0.02);
}
.acc-card:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.06);
}
.acc-card:active {
  transform: scale(0.985);
}
.acc-photo {
  position: relative;
  display: grid;
  width: 100%;
  aspect-ratio: 16 / 9;
  place-items: center;
  overflow: hidden;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.acc-photo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.acc-photo--empty {
  background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%);
}
.acc-photo-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
}
.acc-photo-empty-label { font-size: 10.5px; font-weight: 700; letter-spacing: 0.02em; }
.acc-status {
  position: absolute;
  top: 8px;
  left: 8px;
  display: flex;
  align-items: center;
  gap: 3px;
  padding: 3px 9px 3px 7px;
  border-radius: 999px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.15);
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.01em;
}
.acc-status--green {
  background: var(--m-success);
  color: #fff;
}
.acc-status--amber {
  background: var(--m-warning);
  color: #fff;
}
.acc-status--red {
  background: var(--m-danger);
  color: #fff;
}
.acc-status--grey {
  background: rgba(23, 32, 42, 0.72);
  color: #fff;
}
.acc-health-dot {
  position: absolute;
  top: 10px;
  right: 10px;
  width: 10px;
  height: 10px;
  border-radius: 999px;
  border: 2px solid rgba(255, 255, 255, 0.9);
  box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.15);
}
.acc-health-dot--good { background: var(--m-success); }
.acc-health-dot--warn { background: var(--m-warning); }
.acc-health-dot--danger { background: var(--m-danger); }

.acc-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 4px;
  padding: 10px 12px 0;
}
.acc-head { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; }
.acc-name {
  min-width: 0;
  overflow: hidden;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 16px;
  font-weight: 700;
  letter-spacing: -0.01em;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.acc-type {
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  font-size: 10px;
  font-weight: 700;
}
.acc-addr {
  display: flex;
  align-items: center;
  gap: 4px;
  overflow: hidden;
  color: var(--m-muted);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.facts {
  display: flex;
  align-items: stretch;
  margin-top: 4px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
}
.fact { display: flex; flex: 1 1 0; min-width: 0; flex-direction: column; align-items: center; padding: 6px 4px; text-align: center; }
.fact-div { width: 1px; background: var(--m-border); }
.fact-value {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 13px;
  font-weight: 700;
  letter-spacing: -0.01em;
}
.fact-label { color: var(--m-muted); font-size: 10px; font-weight: 600; }

.acc-doc-summary {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-top: 6px;
  font-size: 12px;
  font-weight: 600;
}
.doc-expired { color: var(--m-danger); }
.doc-expiring { color: var(--m-warning); }
.doc-ok { color: var(--m-success); }

.acc-card--add {
  flex-direction: row;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 18px 12px;
  border-style: dashed;
  background: transparent;
  box-shadow: none;
}
.acc-card--add:hover {
  background: var(--m-surface);
  box-shadow: 0 1px 4px rgba(0,0,0,0.05);
}
.acc-add-icon {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.acc-add-label {
  color: var(--m-muted);
  font-size: 13px;
  font-weight: 700;
}
</style>
