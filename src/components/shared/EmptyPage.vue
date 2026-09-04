<template>
  <q-page class="emptypage" :class="{ 'emptypage--centered': center }">
    <!-- On-screen heading. Omitted for sub-pages whose header already labels them. -->
    <header v-if="title" class="emptypage-head">
      <h1 class="emptypage-title">
        {{ title }}
      </h1>
      <p v-if="subtitle" class="emptypage-subtitle">
        {{ subtitle }}
      </p>
    </header>

    <EmptyState
      :icon="icon"
      :title="emptyTitle"
      :message="emptyMessage"
      variant="expanded"
    >
      <template #actions>
        <button
          v-if="actionLabel"
          type="button"
          class="empty-action"
          :aria-label="actionLabel"
          @click="runAction"
        >
          <IconifyIcon v-if="actionIcon" :icon="actionIcon" width="16" />
          <span>{{ actionLabel }}</span>
        </button>
      </template>
    </EmptyState>
  </q-page>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import { hapticLight } from '@/utils/haptics'

const props = withDefaults(
  defineProps<{
    /** Big on-screen heading. Leave empty on nav sub-pages that already get a header title. */
    title?: string
    /** Secondary line under the heading. */
    subtitle?: string
    /** Screens short on content: center the empty state in the remaining space. */
    center?: boolean
    icon: string
    emptyTitle: string
    emptyMessage: string
    /** Optional helper action (labels as a quiet pill). When given BOTH actionTo and a slot, slot wins. */
    actionLabel?: string
    /** Router path the action navigates to. */
    actionTo?: string
    actionIcon?: string
  }>(),
  {
    title: '',
    subtitle: '',
    center: false,
    actionLabel: '',
    actionTo: '',
    actionIcon: '',
  },
)

const router = useRouter()
function runAction() {
  hapticLight()
  if (props.actionTo) void router.push(props.actionTo)
}
</script>

<style scoped>
.emptypage {
  min-height: 100%;
  display: flex;
  flex-direction: column;
  gap: var(--m-space-4, 16px);
  padding: var(--m-space-3, 12px) var(--m-page-gutter, 12px) 110px; /* clears fixed footer */
  background: var(--m-bg, #f6f7f8);
}

.emptypage--centered {
  justify-content: center;
}

.emptypage-head {
  padding: 0 2px;
}

.emptypage-title {
  margin: 0;
  color: var(--m-ink, #17202a);
  font-family: var(--m-font-display, inherit);
  font-size: 22px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
}

.emptypage-subtitle {
  margin: var(--m-space-1, 4px) 0 0;
  color: var(--m-muted, #6b7280);
  font-size: 13.5px;
  line-height: 1.5;
}

.emptypage :deep(.empty-state) {
  flex: 1 1 auto;
}

.empty-action {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-height: 44px;
  padding: 0 18px;
  border: 1px solid var(--m-primary, #00897b);
  border-radius: 999px;
  background: transparent;
  color: var(--m-primary, #00897b);
  font-family: var(--m-font-body, inherit);
  font-size: 13.5px;
  font-weight: 600;
  line-height: 1;
  cursor: pointer;
}
</style>
