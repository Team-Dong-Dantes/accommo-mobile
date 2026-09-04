<template>
  <div class="cta">
    <button type="button" class="cta-btn" @click="go">
      <IconifyIcon :icon="icon" width="17" />
      {{ label }}
    </button>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'

const props = withDefaults(
  defineProps<{
    managerId: string
    mode?: 'profile' | 'message'
    label?: string
  }>(),
  { mode: 'profile' },
)

const router = useRouter()

const label = computed(() => props.label ?? (props.mode === 'message' ? 'Message Manager' : 'View Manager'))
const icon = computed(() => (props.mode === 'message' ? 'lucide:message-circle' : 'lucide:user-round'))

function go() {
  if (props.mode === 'message') {
    void router.push(`/student/messages?to=${props.managerId}`)
  } else {
    void router.push(`/student/manager/${props.managerId}`)
  }
}
</script>

<style scoped>
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
