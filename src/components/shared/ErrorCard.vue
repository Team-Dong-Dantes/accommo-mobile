<template>
  <q-card flat bordered class="err" :class="{ 'err--inset': inset }" role="alert">
    <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
    <p class="err-title">{{ title }}</p>
    <p class="err-sub">{{ detail }}</p>
    <q-btn
      v-if="retry"
      unelevated
      rounded
      no-caps
      dense
      color="primary"
      label="Try again"
      class="q-mt-sm q-px-md"
      @click="retry()"
    />
  </q-card>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'

// The "couldn't load this" card, which every data screen needs and twenty-four
// of them used to spell out by hand — identical markup, and an identical
// `.err-title`/`.err-sub` pair in each one's scoped styles.
//
// `retry` is a function rather than an emit so the button disappears on its own
// when a screen has nothing to retry (ThreadList reads a store that reloads
// itself). It is always invoked with no arguments: the loaders it receives take
// an optional `silent` flag, and a bare `@click="load"` would hand them a
// MouseEvent as that flag — which is why the old call sites wrote `load()`.
withDefaults(
  defineProps<{
    title: string
    detail?: string
    retry?: () => void
    /** Adds the page gutter as margin, for screens whose list rows are inset. */
    inset?: boolean
  }>(),
  {
    detail: '',
    inset: false,
  },
)
</script>

<style scoped>
.err {
  padding: 18px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}
.err--inset {
  margin: 8px var(--m-page-gutter);
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
</style>
