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
          <span v-if="signedIn" class="pol-state" :class="`pol-state--${state(policy)}`">
            <IconifyIcon v-if="state(policy) === 'accepted'" icon="lucide:check" width="12" />
            {{ STATE_LABEL[state(policy)] }}
          </span>
          <IconifyIcon icon="lucide:chevron-down" width="16" class="pol-chev" />
        </summary>
        <p class="pol-body">{{ policy.body }}</p>
        <div v-if="signedIn" class="pol-accept">
          <span v-if="state(policy) === 'accepted'" class="pol-accepted">
            You accepted this {{ formatMonth(accepted[policy.id]!.accepted_at) }}.
          </span>
          <template v-else>
            <span v-if="state(policy) === 'updated'" class="pol-updated">
              This policy changed since you accepted it. Please review it again.
            </span>
            <q-btn
              unelevated rounded no-caps dense color="primary" class="q-px-md"
              label="I have read and accept"
              :loading="accepting === policy.id"
              @click="accept(policy)"
            />
          </template>
        </div>
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
import { useNotify } from '@/utils/notify'

// The OSAS policy documents — house rules, guidelines, regulations. Read-only
// and identical for every reader, so one component serves the student and the
// landlord/landlady Policies screens.
//
// Deliberately NOT the Terms of Service or the Privacy Notice. Those are the
// agreement between a user and Accommo rather than OSAS content, so they ship
// in the bundle (src/constants/legal.ts) where an administrator cannot rewrite
// them and they can never be missing when consent is asked for.
//
// No archived/effective filtering here on purpose: RLS already restricts
// non-admins to live documents, so a forgotten client filter can't leak a draft.
//
// Acceptance is per revision: OSAS publishing a new version bumps `revision`,
// and an acceptance of an older one no longer counts. accept_policy() stamps
// the current revision server-side, so the client never says which one.

type Policy = {
  id: string
  title: string
  body: string
  version: string | null
  revision: number
  effective_date: string
}
type Acceptance = { revision: number; accepted_at: string }
type State = 'accepted' | 'updated' | 'pending'

const STATE_LABEL: Record<State, string> = { accepted: 'Accepted', updated: 'Updated', pending: 'To accept' }

const notify = useNotify()
const policies = ref<Policy[]>([])
const accepted = ref<Record<string, Acceptance>>({})
const signedIn = ref(false)
const accepting = ref<string | null>(null)
const loading = ref(true)
const error = ref('')

function state(p: Policy): State {
  const a = accepted.value[p.id]
  if (!a) return 'pending'
  return a.revision >= p.revision ? 'accepted' : 'updated'
}

async function load() {
  loading.value = true
  error.value = ''
  const { data: { session } } = await supabase.auth.getSession()
  signedIn.value = !!session
  const [pol, acc] = await Promise.all([
    supabase.from('policies').select('id, title, body, version, revision, effective_date').order('effective_date', { ascending: false }),
    session
      ? supabase.from('policy_acceptances').select('policy_id, revision, accepted_at').eq('user_id', session.user.id)
      : Promise.resolve({ data: [], error: null }),
  ])
  if (pol.error) error.value = pol.error.message
  else policies.value = pol.data ?? []
  accepted.value = Object.fromEntries((acc.data ?? []).map((a) => [a.policy_id, a]))
  loading.value = false
}

async function accept(p: Policy) {
  accepting.value = p.id
  const { error: err } = await supabase.rpc('accept_policy', { p_id: p.id })
  accepting.value = null
  if (err) {
    notify.error("Couldn't record your acceptance", err.message)
    return
  }
  accepted.value = { ...accepted.value, [p.id]: { revision: p.revision, accepted_at: new Date().toISOString() } }
  notify.success('Policy accepted')
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
.pol-state {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.pol-state--accepted { background: var(--m-success-soft); color: var(--m-success); }
.pol-state--updated { background: var(--m-warning-soft); color: var(--m-warning); }
.pol-state--pending { background: var(--m-primary-soft); color: var(--m-primary); }
.pol-accept {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 8px;
  margin: 0 13px 13px;
  padding-top: 11px;
  border-top: 1px solid var(--m-border);
  font-size: 12px;
}
.pol-accepted { color: var(--m-success); font-weight: 600; }
.pol-updated { color: var(--m-warning); font-weight: 600; }
</style>
