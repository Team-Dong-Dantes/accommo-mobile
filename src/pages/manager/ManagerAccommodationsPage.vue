<template>
  <q-page class="ap">
    <q-pull-to-refresh @refresh="onPull">
      <div v-if="loading" class="stack">
        <q-skeleton type="rect" height="230px" class="sk" />
        <q-skeleton type="rect" height="230px" class="sk" />
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your accommodations" :detail="error" :retry="load" inset />
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

      <div v-else class="grid">
        <PropertyCard v-for="a in rows" :key="a.id" :property="a" @open="open" />
        <PropertyCard @add="router.push('/manager/properties/new')" />
      </div>
    </q-pull-to-refresh>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { resolveAsset, CARD } from '@/utils/cloudinaryUrl'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import PropertyCard from '@/components/manager/PropertyCard.vue'
import type { Property } from '@/components/manager/property'

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

const router = useRouter()
const loading = ref(true)
const error = ref('')
const rows = ref<Property[]>([])

function open(id: string) {
  void router.push(`/manager/properties/${id}`)
}

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data: authData } = await authUser()
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
      const acRooms = (a.rooms ?? []) as { id: string; capacity: number | null }[]
      return {
        id: a.id,
        name: a.name?.trim() || 'Unnamed accommodation',
        address: a.address || [a.barangay, a.city].filter(Boolean).join(', ') || 'Address not given',
        status: a.status,
        type: titleCase(a.accommodation_type),
        image: images[0]?.url ? resolveAsset(images[0].url, CARD) : '',
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

// Kept alive across navigation (see MainLayout's KEEP_ALIVE_PAGES), so the
// database pushes lease changes here instead of the page re-asking on every
// return. utils/useLiveData.ts owns the whole policy — first load, the
// subscription's lifetime, and how stale the data may be on return.
const { refresh } = useLiveData({
  key: 'manager-accommodations',
  load,
  watch: (uid) => [{ table: 'leases', filter: `accommodation_manager_id=eq.${uid}` }],
  cache: { get: () => rows.value, set: (d) => { rows.value = d as Property[]; loading.value = false } },
})

// Pull-to-refresh goes through useLiveData's refresh rather than load(): it
// loads silently (no skeleton behind the spinner) and resets the freshness
// clock, so returning to the screen does not immediately fetch again.
function onPull(done: () => void) {
  void refresh().finally(done)
}
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
.grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  padding: 10px var(--m-page-gutter) 24px;
}
.sk {
  border-radius: var(--m-radius);
  margin: 0 var(--m-page-gutter);
}
</style>
