<template>
  <ListingBlock :title="manager.title">
    <button type="button" class="mgr" @click="router.push(`/student/manager/${manager.id}`)">
      <span class="mgr-avatar">
        <img v-if="manager.avatarUrl && !avatarFailed" :src="manager.avatarUrl" alt="" class="mgr-avatar-img" @error="avatarFailed = true" />
        <template v-else>{{ manager.initials }}</template>
      </span>
      <span class="mgr-body">
        <span class="mgr-name">{{ manager.name }}</span>
        <span class="mgr-sub">
          {{ manager.replyMinutes ? `Replies in ~${manager.replyMinutes} min` : manager.title }}
        </span>
      </span>
      <IconifyIcon icon="lucide:chevron-right" width="16" class="mgr-chevron" />
    </button>
  </ListingBlock>
</template>

<script setup lang="ts">
// The person to ask, closing a listing or room page.
import { ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import ListingBlock from './ListingBlock.vue'

const props = defineProps<{
  manager: { id: string; title: string; name: string; initials: string; avatarUrl: string | null; replyMinutes: number | null }
}>()

const router = useRouter()
// A broken avatar link falls back to the initials.
const avatarFailed = ref(false)
watch(() => props.manager.avatarUrl, () => { avatarFailed.value = false })
</script>

<style scoped>
/* Landlord/landlady */
.mgr {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 11px;
  padding: 12px 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.mgr-avatar {
  display: grid;
  width: 40px;
  height: 40px;
  flex: 0 0 40px;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 800;
}
.mgr-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.mgr-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.mgr-name {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.mgr-sub {
  color: var(--m-muted);
  font-size: 11.5px;
}
.mgr-chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
}
</style>
