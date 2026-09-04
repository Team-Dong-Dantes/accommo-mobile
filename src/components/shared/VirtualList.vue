<template>
  <!-- Reusable virtualized list for the tall feature screens (Discover, Messages,
       Concerns, Tenants, Payments). Drop this in during the rebuild instead of a
       bare v-for: it renders only visible rows so long lists stay at native FPS.
       Give it a bounded height — put it inside a page/panel that sets height:100%
       and do NOT also let the outer shell scroll, or virtualization can't work. -->
  <div class="vlist" :style="{ height }">
    <!-- Optional pinned header (search bar / filters / section title). -->
    <slot name="header" />

    <div v-if="loading" class="vlist-loading">
      <slot name="loading">
        <q-skeleton
          v-for="i in loadingRows"
          :key="i"
          type="rect"
          class="vlist-sk"
          style="height: 56px"
        />
      </slot>
    </div>

    <EmptyState
      v-else-if="items.length === 0"
      class="vlist-empty"
      variant="compact"
      :icon="emptyIcon"
      :title="emptyTitle"
      :message="emptyMessage"
    >
      <slot name="empty-actions" />
    </EmptyState>

    <div v-else class="vlist-scroll">
      <q-virtual-scroll
        :items="items"
        :virtual-scroll-item-size="estimatedItemSize"
        :virtual-scroll-slice-size="10"
        :virtual-scroll-slice-ratio-before="1.5"
        :virtual-scroll-slice-ratio-after="1.5"
      >
        <template #default="{ item, index }">
          <slot name="item" :item="item" :index="index" />
        </template>
      </q-virtual-scroll>
    </div>
  </div>
</template>

<script setup lang="ts" generic="T extends { id: string | number }">
import EmptyState from '@/components/shared/EmptyState.vue'

withDefaults(
  defineProps<{
    items: readonly T[]
    loading?: boolean
    /** Height of the whole widget: a px/vh string ('100%', '60vh', '500px'). */
    height?: string
    /** Approximate px height of one row; used to prime the virtual window. */
    estimatedItemSize?: number
    /** Rows of skeleton to paint while loading. */
    loadingRows?: number
    emptyIcon?: string
    emptyTitle?: string
    emptyMessage?: string
  }>(),
  {
    loading: false,
    height: '100%',
    estimatedItemSize: 56,
    loadingRows: 6,
    emptyIcon: 'lucide:inbox',
    emptyTitle: 'Nothing here yet',
    emptyMessage: '',
  },
)
</script>

<style scoped>
.vlist {
  display: flex;
  flex-direction: column;
  min-height: 0;
  width: 100%;
}

.vlist-loading,
.vlist-empty {
  display: flex;
  flex: 1 1 auto;
  min-height: 0;
  width: 100%;
}

/* Loading keeps the skeleton stack anchored at the top scrollable area. */
.vlist-loading {
  flex-direction: column;
  overflow: auto;
}

/* Empty uses the shared EmptyState (which centers itself); we only need to let
   it fill the available height. */
.vlist-empty {
  align-items: stretch;
  justify-content: stretch;
}

.vlist-empty :deep(.empty-state) {
  height: 100%;
}

.vlist-sk {
  width: 100%;
  flex: 0 0 auto;
  border-radius: var(--m-radius, 16px);
  margin-bottom: 8px;
}

.vlist-scroll {
  flex: 1 1 auto;
  min-height: 0;
  height: 100%;
  overflow: auto;
}
</style>
