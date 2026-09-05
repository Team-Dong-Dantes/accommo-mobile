<template>
  <q-page class="msgs">
    <ThreadList :empty-message="emptyMessage" :query="query" :filter="filter" @open="openThread" />
    <ChatThread
      v-if="openId"
      :key="openId"
      :conversation-id="openId"
      :role="role"
      :room-id="roomId"
      @close="closeThread"
    />

    <!-- Search sits on the FAB's baseline so the two read as one control band -->
    <div v-if="!openId && store.ready" class="dock">
      <button
        type="button"
        class="dock-btn"
        :class="{ 'dock-btn--on': filter !== 'all' }"
        aria-label="Filters"
        @click="filtersOpen = true"
      >
        <IconifyIcon icon="lucide:sliders-horizontal" width="17" />
        <span v-if="filter !== 'all'" class="dock-dot">1</span>
      </button>
      <div class="dock-field">
        <IconifyIcon icon="lucide:search" width="16" class="dock-icon" />
        <input v-model="query" class="dock-input" type="search" placeholder="Search conversations" aria-label="Search conversations" />
      </div>
    </div>

    <q-dialog v-model="filtersOpen" position="bottom">
      <div class="sheet">
        <div class="sheet-head">
          <h2 class="sheet-title">Filters</h2>
          <button type="button" class="sheet-clear" @click="filter = 'all'">Reset</button>
        </div>
        <div class="sheet-block">
          <span class="sheet-label">Status</span>
          <div class="chips">
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
        </div>
        <button type="button" class="sheet-done" @click="filtersOpen = false">Done</button>
      </div>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useMessagesStore } from '@/stores/messages'
import { chatFullscreen } from '@/utils/chatFullscreen'
import { useNotify } from '@/utils/notify'
import ThreadList from '@/components/messages/ThreadList.vue'
import ChatThread from '@/components/messages/ChatThread.vue'

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

onMounted(async () => {
  const { data } = await supabase.auth.getUser()
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
</script>

<style scoped>
.msgs {
  background: var(--m-bg);
}

/* Docked search — same baseline and height as the quick-actions FAB, ending
   where it begins, so the two read as one band. */
.dock {
  position: fixed;
  bottom: 68px;
  left: var(--m-page-gutter);
  /* 16px FAB inset + 44px FAB + 8px gap */
  right: 68px;
  z-index: 60;
  display: flex;
  align-items: center;
  gap: 8px;
}
.dock-field {
  position: relative;
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  align-items: center;
}
.dock-icon {
  position: absolute;
  left: 13px;
  color: var(--m-muted);
  pointer-events: none;
}
.dock-input {
  width: 100%;
  height: 44px;
  padding: 0 14px 0 35px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  box-shadow: var(--m-shadow);
  color: var(--m-ink);
  font: inherit;
  font-size: 13.5px;
}
.dock-input:focus {
  border-color: var(--m-primary);
  outline: none;
}
.dock-btn {
  position: relative;
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 50%;
  background: var(--m-surface);
  box-shadow: var(--m-shadow);
  color: var(--m-ink);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.dock-btn--on {
  border-color: var(--m-primary);
  color: var(--m-primary-dark);
}
.dock-dot {
  position: absolute;
  top: -2px;
  right: -2px;
  display: grid;
  min-width: 17px;
  height: 17px;
  place-items: center;
  padding: 0 4px;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
}

/* Filter sheet */
.sheet {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 14px;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0;
  background: var(--m-surface);
}
.sheet-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.sheet-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.sheet-clear {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.sheet-block {
  display: flex;
  flex-direction: column;
  gap: 7px;
}
.sheet-label {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
}
.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
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
.sheet-done {
  min-height: 48px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
</style>
