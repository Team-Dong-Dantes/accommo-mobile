<template>
  <q-page class="mp">
    <div v-if="loading" class="stack">
      <div class="head">
        <q-skeleton type="circle" size="64px" />
        <q-skeleton type="text" width="130px" height="17px" />
        <q-skeleton type="text" width="110px" height="12px" />
      </div>
      <q-skeleton type="rect" height="90px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <ErrorCard title="Couldn't load this landlord/landlady" :detail="error" :retry="load" />
    </div>

    <PersonProfile
      v-else
      v-model="tab"
      :tabs="TABS"
      :name="manager.name"
      :initials="manager.initials"
      :avatar-url="manager.avatarUrl"
      :cover-url="manager.coverUrl"
      :chip="manager.verified ? 'OSAS verified' : ''"
      chip-tone="good"
      :role="{ label: manager.title, icon: 'lucide:house' }"
      message-to
      @message="messageManager"
    >
    <div class="stack">
      <div v-if="manager.replyMinutes || manager.responseRate !== null || manager.memberSince" class="head-tags">
        <span v-if="manager.replyMinutes" class="tag tag--soft">
          <IconifyIcon icon="lucide:clock" width="11" />Replies in ~{{ manager.replyMinutes }} min
        </span>
        <span v-if="manager.responseRate !== null" class="tag tag--soft">
          <IconifyIcon icon="lucide:check-check" width="11" />{{ manager.responseRate }}% response rate
        </span>
        <span v-if="manager.memberSince" class="tag">
          <IconifyIcon icon="lucide:calendar" width="11" />Member since {{ manager.memberSince }}
        </span>
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
          :message="`This ${manager.title.toLowerCase()} hasn't published any accommodations.`"
        />
      </section>

      <div class="tail" />
    </div>
    </PersonProfile>

    <div v-if="!loading && !error && !embed.managerId" class="cta">
      <button type="button" class="cta-btn" @click="messageManager">
        <IconifyIcon icon="lucide:message-circle" width="17" />
        Message {{ manager.title.toLowerCase() }}
      </button>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onActivated, onDeactivated } from 'vue'
import { pageTitleOverride } from '@/utils/pageTitle'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { initialsOf, parseServerTime, landlordTitle } from '@/utils/format'
import { resolveAsset, COVER } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel } from '@/utils/geo'
import { listingMonogram } from '@/utils/listings'
import PersonProfile from '@/components/shared/PersonProfile.vue'
import PropertyCard from '@/components/student/PropertyCard.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'

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

// One tab: PersonProfile is the shared profile shell (the scanner and chat
// profiles use it too); the tab strip hides itself when there is only one.
const TABS = [{ key: 'properties', label: 'Properties' }] as const
const tab = ref<string>('properties')

// Set when PersonPage shows this inside a conversation's profile: no fixed
// Message bar (the profile card has one) and no header title.
const embed = defineProps<{ managerId?: string }>()
const route = useRoute()
const router = useRouter()

const loading = ref(true)
const error = ref('')
// Kept alive (MainLayout's KEEP_ALIVE_PAGES), so leaving deactivates rather than
// unmounts: the header title must follow activation, or it sticks on the next screen.
let active = false
onActivated(() => { active = !embed.managerId; if (active && manager.name) pageTitleOverride.value = manager.title })
onDeactivated(() => { if (active) pageTitleOverride.value = null; active = false })
const manager = reactive({
  name: '',
  title: landlordTitle(null),
  initials: '?',
  replyMinutes: null as number | null,
  responseRate: null as number | null,
  memberSince: '',
  avatarColor: null as string | null,
  avatarUrl: null as string | null,
  coverUrl: null as string | null,
  verified: false,
})
const properties = ref<Property[]>([])

const id = computed(() => embed.managerId || String(route.params.id || ''))
function messageManager() { void router.push(`/student/messages?to=${id.value}`) }

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const [{ data: person }, { data: profile }, { data: props, error: propsError }] = await Promise.all([
      supabase
        .from('users')
        .select('id,full_name,initials,avatar_color,avatar_url,cover_url,created_at,status,sex')
        .eq('id', id.value)
        .eq('role', 'landlord')
        .maybeSingle(),
      supabase
        .from('landlord_profiles')
        .select('avg_response_minutes,response_rate')
        .eq('user_id', id.value)
        .maybeSingle(),
      supabase
        .from('accommodations')
        .select('id,name,address,city,barangay,purok,lat,lng,accommodation_images(url,sort_order),rooms(status)')
        .eq('landlord_id', id.value)
        .eq('status', 'accredited').eq('hidden_from_listings', false),
    ])

    if (!person) {
      error.value = 'This landlord/landlady could not be found.'
      return
    }
    if (propsError) throw propsError

    manager.title = landlordTitle(person.sex)
    manager.name = person.full_name?.trim() || manager.title
    if (active) pageTitleOverride.value = manager.title
    manager.initials = person.initials || initialsOf(manager.name)
    manager.avatarColor = person.avatar_color
    manager.avatarUrl = person.avatar_url ? resolveAsset(person.avatar_url) : null
    manager.coverUrl = person.cover_url ? resolveAsset(person.cover_url, COVER) : null
    manager.memberSince = person.created_at ? String(parseServerTime(person.created_at).getFullYear()) : ''
    manager.replyMinutes = profile?.avg_response_minutes ?? null
    manager.responseRate = profile?.response_rate ?? null
    manager.verified = person.status === 'verified'

    properties.value = (props ?? []).map((row) => {
      const rooms = (row.rooms ?? []) as { status: string }[]
      const images = [...((row.accommodation_images ?? []) as { url: string; sort_order: number | null }[])].sort(
        (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
      )
      const address = row.address || [row.purok, row.barangay, row.city].filter(Boolean).join(', ') || 'Address not given'
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

// Kept alive per landlord/landlady id (see MainLayout's KEEP_ALIVE_PAGES + the
// route.fullPath key), so new and updated listings push here instead of the
// page re-asking on return. utils/useLiveData.ts owns the whole policy — the
// key folds in the id so each landlord/landlady gets its own freshness clock.
useLiveData({
  key: () => `student-manager:${id.value}`,
  load,
  watch: () =>
    id.value
      ? [{ table: 'accommodations', filter: `landlord_id=eq.${id.value}` }]
      : [],
  cache: { get: () => properties.value, set: (d) => { properties.value = d as Property[]; loading.value = false } },
})
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
  line-height: 1.3;
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
