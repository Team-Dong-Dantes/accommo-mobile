<template>
  <q-page class="msgs">
    <ThreadList :empty-message="emptyMessage" @open="openThread" />
    <ChatThread
      v-if="openId"
      :key="openId"
      :conversation-id="openId"
      :role="role"
      @close="closeThread"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useMessagesStore } from '@/stores/messages'
import { chatFullscreen } from '@/utils/chatFullscreen'
import { useNotify } from '@/utils/notify'
import ThreadList from '@/components/messages/ThreadList.vue'
import ChatThread from '@/components/messages/ChatThread.vue'

const props = defineProps<{ role: 'manager' | 'student'; emptyMessage: string }>()

const route = useRoute()
const router = useRouter()
const notify = useNotify()
const store = useMessagesStore()

// ?c=<id> opens a thread over the list; ?to=<userId> is an enquiry that
// resolves to a thread first. Keeping both on one route means the Messages tab
// stays selected, which is what MainLayout's shell already expects.
const openId = computed(() => (typeof route.query.c === 'string' ? route.query.c : ''))

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
    await router.replace({ path: route.path, query: { c: id } })
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
</style>
