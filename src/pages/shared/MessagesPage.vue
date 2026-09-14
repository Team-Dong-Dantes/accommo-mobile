<template>
  <q-page class="msgs">
    <q-pull-to-refresh @refresh="onPull">
      <ThreadList :empty-message="emptyMessage" :query="query" :filter="filter" @open="openThread" />
      <ChatThread
        v-if="openId"
        :key="openId"
        :conversation-id="openId"
        :role="role"
        :room-id="roomId"
        @close="closeThread"
      />

    </q-pull-to-refresh>

    <!-- Search sits on the FAB's baseline so the two read as one control band -->
    <SearchDock
      v-if="!openId && store.ready"
      v-model="query"
      :filter-count="filter !== 'all' ? 1 : 0"
      placeholder="Search conversations"
      search-label="Search conversations"
      above-nav
      @open-filters="filtersOpen = true"
    />

    <BottomSheet
      v-model="filtersOpen"
      title="Filters"
      @clear="filter = 'all'"
    >
      <div class="sheet-block">
        <span class="sheet-label">Status</span>
        <div class="m-chips">
          <button
            v-for="f in FILTERS"
            :key="f.key"
            type="button"
            class="m-chip"
            :class="{ 'm-chip--on': filter === f.key }"
            @click="filter = f.key"
          >
            {{ f.label }}
          </button>
        </div>
      </div>
    </BottomSheet>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted, onActivated, onDeactivated } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { authUser } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useMessagesStore } from '@/stores/messages'
import { chatFullscreen } from '@/utils/chatFullscreen'
import { useNotify } from '@/utils/notify'
import ThreadList from '@/components/messages/ThreadList.vue'
import ChatThread from '@/components/messages/ChatThread.vue'
import SearchDock from '@/components/shared/SearchDock.vue'
import BottomSheet from '@/components/shared/BottomSheet.vue'

const FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'unread', label: 'Unread' },
] as const

const props = defineProps<{ role: 'manager' | 'student'; emptyMessage: string }>()

const route = useRoute()
const router = useRouter()
const notify = useNotify()
const store = useMessagesStore()

const query = ref('')
const filter = ref<(typeof FILTERS)[number]['key']>('all')
const filtersOpen = ref(false)

// ?c=<id> opens a thread over the list; ?to=<userId> is an enquiry that
// resolves to a thread first. Keeping both on one route means the Messages tab
// stays selected, which is what MainLayout's shell already expects.
const openId = computed(() => (typeof route.query.c === 'string' ? route.query.c : ''))
const roomId = computed(() => (typeof route.query.room === 'string' ? route.query.room : undefined))

const starting = ref(false)

function openThread(id: string) {
  void router.push({ path: route.path, query: { c: id } })
}

function closeThread() {
  void router.push({ path: route.path })
}

async function resolveEnquiry(to: string) {
  if (starting.value) return
  starting.value = true
  try {
    const id = await store.findOrCreate(to, props.role)
    const room = typeof route.query.room === 'string' ? route.query.room : undefined
    await router.replace({ path: route.path, query: room ? { c: id, room } : { c: id } })
  } catch (e) {
    notify.error(errorMessage(e, 'Could not open that conversation.'))
    await router.replace({ path: route.path })
  } finally {
    starting.value = false
  }
}

// An open thread covers the screen, so the shell's nav and FAB step aside.
watch(openId, (id) => { chatFullscreen.value = Boolean(id) }, { immediate: true })

watch(
  () => route.query.to,
  (to) => {
    if (typeof to === 'string' && to && store.userId) void resolveEnquiry(to)
  },
)

// The thread list is store-backed and realtime-driven, so a pull is only ever a
// manual reconciliation — re-read the conversations for the signed-in user.
function onPull(done: () => void) {
  if (!store.userId) {
    done()
    return
  }
  void store.load(store.userId).finally(done)
}

onMounted(async () => {
  const { data } = await authUser()
  const user = data?.user
  if (!user) {
    void router.push('/login')
    return
  }
  await store.start(user.id)

  const to = route.query.to
  if (typeof to === 'string' && to) await resolveEnquiry(to)
})

onUnmounted(() => {
  chatFullscreen.value = false
})

// Both messages pages are kept alive, so navigating out of an open thread —
// to the other person's profile, say — deactivates this page instead of
// unmounting it, and onUnmounted never runs. Without these the shell's header
// and nav would stay hidden on whatever screen came next.
onDeactivated(() => {
  chatFullscreen.value = false
})
onActivated(() => {
  chatFullscreen.value = Boolean(openId.value)
})
</script>

<style scoped>
.msgs {
  background: var(--m-bg);
}

/* Docked search — same baseline and height as the quick-actions FAB, ending
   where it begins, so the two read as one band. */

/* Filter sheet */
</style>
