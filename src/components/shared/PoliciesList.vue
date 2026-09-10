<template>
  <div class="pol-stack">
    <template v-if="loading">
      <q-skeleton type="rect" height="58px" class="pol-sk" />
      <q-skeleton type="rect" height="58px" class="pol-sk" />
      <q-skeleton type="rect" height="58px" class="pol-sk" />
    </template>

    <EmptyState
      v-else-if="error"
      variant="compact"
      icon="lucide:cloud-off"
      title="Couldn't load policies"
      :message="error"
    >
      <template #actions>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-px-md" @click="load" />
      </template>
    </EmptyState>

    <EmptyState
      v-else-if="!policies.length"
      variant="compact"
      icon="lucide:scroll-text"
      title="No policies published"
      message="OSAS hasn't published any policies or guidelines yet."
    />

    <template v-else>
      <details v-for="policy in policies" :key="policy.id" class="pol">
        <summary class="pol-head">
          <span class="pol-text">
            <span class="pol-title">{{ policy.title }}</span>
            <span class="pol-meta">
              <span v-if="policy.version" class="pol-version">{{ policy.version }}</span>
              Effective {{ formatMonth(policy.effective_date) }}
            </span>
          </span>
          <IconifyIcon icon="lucide:chevron-down" width="16" class="pol-chev" />
        </summary>
        <p class="pol-body">{{ policy.body }}</p>
      </details>
    </template>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { formatMonth } from '@/utils/format'
import EmptyState from '@/components/shared/EmptyState.vue'

// The OSAS policy documents, read-only, identical for every reader — so one
// component serves the student page, the manager page, and the terms dialog on
// the register screens (that last one runs signed-out, which is why `policies`
// grants anon SELECT).
//
// No archived/effective filtering here on purpose: RLS already restricts
// non-admins to live documents, so a forgotten client filter can't leak a
// draft.

type Policy = {
  id: string
  title: string
  body: string
  version: string | null
  effective_date: string
}

// The terms dialog needs to know when the documents have rendered so it can
// decide whether there is anything to scroll through.
const emit = defineEmits<{ (e: 'loaded', count: number): void }>()

const policies = ref<Policy[]>([])
const loading = ref(true)
const error = ref('')

async function load() {
  loading.value = true
  error.value = ''
  const { data, error: err } = await supabase
    .from('policies')
    .select('id, title, body, version, effective_date')
    .order('effective_date', { ascending: false })
  if (err) error.value = err.message
  else policies.value = data ?? []
  loading.value = false
  emit('loaded', policies.value.length)
}

onMounted(load)
</script>

<style scoped>
.pol-stack { display: flex; flex-direction: column; gap: 8px; }
.pol-sk { border-radius: var(--m-radius); }

.pol {
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.pol-head {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 11px 13px;
  cursor: pointer;
  list-style: none;
  -webkit-tap-highlight-color: transparent;
}
/* Safari still paints the default disclosure triangle without this. */
.pol-head::-webkit-details-marker { display: none; }
.pol-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 2px; }
.pol-title { color: var(--m-ink); font-size: 13.5px; font-weight: 700; line-height: 1.25; }
.pol-meta { display: flex; align-items: center; gap: 6px; color: var(--m-muted); font-size: 11px; font-weight: 600; }
.pol-version {
  padding: 1px 6px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 10px;
}
.pol-chev { flex: 0 0 auto; color: var(--m-muted); transition: transform .2s ease; }
.pol[open] .pol-chev { transform: rotate(180deg); }
.pol-body {
  margin: 0;
  padding: 0 13px 13px;
  color: var(--m-text);
  font-size: 12.5px;
  line-height: 1.5;
  white-space: pre-wrap;
}
</style>
