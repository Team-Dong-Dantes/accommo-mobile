<template>
  <q-page class="ap">
    <div v-if="!loading && !error" class="dock">
      <button type="button" class="dock-btn" @click="router.push('/manager/properties/new')">
        <IconifyIcon icon="lucide:plus" width="16" />
        Add accommodation
      </button>
    </div>

    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="96px" class="sk" />
      <q-skeleton type="rect" height="96px" class="sk" />
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
        <span class="acc-shot">
          <img v-if="a.image" :src="a.image" :alt="a.name" loading="lazy" />
          <span v-else class="acc-mono">{{ a.monogram }}</span>
        </span>
        <span class="acc-body">
          <span class="acc-top">
            <span class="acc-name">{{ a.name }}</span>
            <span class="acc-chip" :class="`acc-chip--${STATUS_TONE[a.status] || 'grey'}`">{{ STATUS_LABEL[a.status] || a.status }}</span>
          </span>
          <span class="acc-addr">{{ a.address }}</span>
          <span class="acc-meta">{{ a.roomCount }} room{{ a.roomCount === 1 ? '' : 's' }}</span>
        </span>
        <IconifyIcon icon="lucide:chevron-right" width="18" class="acc-chevron" />
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
import { listingMonogram } from '@/utils/listings'
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

interface Row {
  id: string
  name: string
  address: string
  status: string
  image: string
  monogram: string
  roomCount: number
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
      .select('id,name,address,barangay,city,status,accommodation_images(url,sort_order),rooms(id)')
      .eq('accommodation_manager_id', user.id)
      .order('name')
    if (loadError) throw loadError

    rows.value = (data ?? []).map((a) => {
      const images = [...((a.accommodation_images ?? []) as { url: string; sort_order: number | null }[])].sort(
        (x, y) => (x.sort_order ?? 0) - (y.sort_order ?? 0),
      )
      const name = a.name?.trim() || 'Unnamed accommodation'
      return {
        id: a.id,
        name,
        address: a.address || [a.barangay, a.city].filter(Boolean).join(', ') || 'Address not given',
        status: a.status,
        image: images[0]?.url ? resolveAsset(images[0].url) : '',
        monogram: listingMonogram(name),
        roomCount: (a.rooms ?? []).length,
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

.dock {
  padding: 8px var(--m-page-gutter) 0;
}
.dock-btn {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-height: 42px;
  padding: 0 16px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

.acc-card {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 11px;
  padding: 10px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.acc-shot {
  display: grid;
  width: 56px;
  height: 56px;
  flex: 0 0 56px;
  place-items: center;
  overflow: hidden;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
}
.acc-shot img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.acc-mono {
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 800;
}
.acc-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.acc-top {
  display: flex;
  align-items: center;
  gap: 8px;
}
.acc-name {
  min-width: 0;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.acc-chip {
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}
.acc-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.acc-chip--amber {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.acc-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.acc-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.acc-addr {
  overflow: hidden;
  color: var(--m-muted);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.acc-meta {
  color: var(--m-muted);
  font-size: 11.5px;
}
.acc-chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
}
</style>
