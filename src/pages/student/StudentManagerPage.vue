<template>
  <q-page class="mp">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="90px" class="sk" />
      <q-skeleton type="rect" height="90px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load this manager</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn
          unelevated
          rounded
          no-caps
          dense
          color="primary"
          label="Try again"
          class="q-mt-sm q-px-md"
          @click="load"
        />
      </q-card>
    </div>

    <div v-else class="stack">
      <div class="head">
        <span class="head-avatar" :class="manager.avatarColor ? ['bg-' + manager.avatarColor, 'text-white'] : []">
          {{ manager.initials }}
        </span>
        <span class="head-name">{{ manager.name }}</span>
        <span class="head-sub">Accommodation manager</span>
        <span v-if="manager.verified" class="badge">
          <IconifyIcon icon="lucide:shield-check" width="11" />ID Verified
        </span>
        <p v-if="stats" class="head-stats">{{ stats }}</p>
        <div v-if="manager.replyMinutes || manager.responseRate !== null || manager.memberSince" class="head-tags">
          <span v-if="manager.replyMinutes" class="tag tag--soft">
            <IconifyIcon icon="lucide:clock" width="11" />Replies in ~{{ manager.replyMinutes }} min
          </span>
          <span v-if="manager.responseRate !== null" class="tag tag--soft">
            <IconifyIcon icon="lucide:check-check" width="11" />{{ manager.responseRate }}% response rate
          </span>
          <span v-if="manager.memberSince" class="tag">
            <IconifyIcon icon="lucide:calendar" width="11" />Managing since {{ manager.memberSince }}
          </span>
        </div>
      </div>

      <section class="sec">
        <h2 class="sec-title">
          Properties{{ properties.length ? ` (${properties.length})` : '' }}
        </h2>
        <div v-if="properties.length" class="grid">
          <PropertyCard
            v-for="p in properties"
            :key="p.id"
            variant="grid"
            :id="p.id"
            :name="p.name"
            :address="p.address"
            :image="p.image"
            :monogram="p.monogram"
            :distance="p.distance"
            :vacancies="p.vacancies"
            @open="(propId) => router.push(`/student/listing/${propId}`)"
          />
        </div>
        <EmptyState
          v-else
          variant="compact"
          icon="lucide:building-2"
          title="No accredited properties yet"
          message="This manager hasn't published any accommodations."
        />
      </section>

      <div class="tail" />
    </div>

    <div v-if="!loading && !error" class="cta">
      <button type="button" class="cta-btn" @click="router.push(`/student/messages?to=${id}`)">
        <IconifyIcon icon="lucide:message-circle" width="17" />
        Message manager
      </button>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { initialsOf, parseServerTime } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel } from '@/utils/geo'
import { listingMonogram } from '@/utils/listings'
import PropertyCard from '@/components/student/PropertyCard.vue'
import EmptyState from '@/components/shared/EmptyState.vue'

interface Property {
  id: string
  name: string
  address: string
  image: string
  monogram: string
  distance: string
  vacancies: number
  roomCount: number
}

const route = useRoute()
const router = useRouter()

const loading = ref(true)
const error = ref('')
const manager = reactive({
  name: '',
  initials: '?',
  replyMinutes: null as number | null,
  responseRate: null as number | null,
  memberSince: '',
  avatarColor: null as string | null,
  verified: false,
})
const properties = ref<Property[]>([])

const id = computed(() => String(route.params.id || ''))
const stats = computed(() => {
  if (!properties.value.length) return ''
  const roomCount = properties.value.reduce((n, p) => n + p.roomCount, 0)
  const available = properties.value.reduce((n, p) => n + p.vacancies, 0)
  if (!roomCount) return ''
  return `${roomCount} room${roomCount === 1 ? '' : 's'} · ${available} available`
})

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [{ data: person }, { data: profile }, { data: props, error: propsError }] = await Promise.all([
      supabase
        .from('users')
        .select('id,full_name,initials,avatar_color,created_at,status')
        .eq('id', id.value)
        .eq('role', 'accommodation_manager')
        .maybeSingle(),
      supabase
        .from('accommodation_manager_profiles')
        .select('avg_response_minutes,response_rate')
        .eq('user_id', id.value)
        .maybeSingle(),
      supabase
        .from('accommodations')
        .select('id,name,address,city,barangay,lat,lng,accommodation_images(url,sort_order),rooms(status)')
        .eq('accommodation_manager_id', id.value)
        .eq('status', 'accredited'),
    ])

    if (!person) {
      error.value = 'This manager could not be found.'
      return
    }
    if (propsError) throw propsError

    manager.name = person.full_name?.trim() || 'Accommodation manager'
    manager.initials = person.initials || initialsOf(manager.name)
    manager.avatarColor = person.avatar_color
    manager.memberSince = person.created_at ? String(parseServerTime(person.created_at).getFullYear()) : ''
    manager.replyMinutes = profile?.avg_response_minutes ?? null
    manager.responseRate = profile?.response_rate ?? null
    manager.verified = person.status === 'verified'

    properties.value = (props ?? []).map((row) => {
      const rooms = (row.rooms ?? []) as { status: string }[]
      const images = [...((row.accommodation_images ?? []) as { url: string; sort_order: number | null }[])].sort(
        (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
      )
      const address = row.address || [row.barangay, row.city].filter(Boolean).join(', ') || 'Address not given'
      const name = row.name?.trim() || 'Unnamed accommodation'
      return {
        id: row.id,
        name,
        address,
        image: images[0]?.url ? resolveAsset(images[0].url) : '',
        monogram: listingMonogram(name),
        distance: campusDistanceLabel(row.lat, row.lng),
        vacancies: rooms.filter((r) => r.status === 'available').length,
        roomCount: rooms.length,
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
.mp {
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 8px var(--m-page-gutter) 0;
}
.sk {
  border-radius: var(--m-radius);
}
.tail {
  height: 78px;
}

.card {
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

.head {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 12px 0 4px;
  text-align: center;
}
.head-avatar {
  display: grid;
  width: 64px;
  height: 64px;
  place-items: center;
  margin-bottom: 4px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 22px;
  font-weight: 800;
}
.head-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 19px;
  font-weight: 700;
}
.head-sub {
  color: var(--m-muted);
  font-size: 12.5px;
}
.badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin-top: 6px;
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-success-soft);
  color: var(--m-success);
  font-size: 11px;
  font-weight: 700;
}
.head-stats {
  margin: 6px 0 0;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.head-tags {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 6px;
  margin-top: 6px;
}
.tag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 10px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 11.5px;
  font-weight: 700;
}
.tag--soft {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}

.sec {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.sec-title {
  margin: 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}

.cta {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 5;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  padding: 10px var(--m-page-gutter) calc(10px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.cta-btn {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-height: 46px;
  padding: 0 20px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
</style>
