<template>
  <q-page class="ann-page">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="120px" class="sk" />
      <q-skeleton type="rect" height="70px" class="sk" />
    </div>

    <EmptyState
      v-else-if="!accommodations.length"
      icon="lucide:building-2"
      title="No accommodation yet"
      message="Add an accommodation first — announcements go to the tenants of one of your houses."
    />

    <div v-else class="stack">
      <!-- Compose -->
      <section class="card">
        <div class="row row--wrap">
          <span class="row-label">To</span>
          <span class="chips">
            <button
              v-for="a in accommodations"
              :key="a.id"
              type="button"
              class="chip"
              :class="{ 'chip--on': form.accommodationId === a.id }"
              @click="form.accommodationId = a.id"
            >
              {{ a.name }}
            </button>
          </span>
        </div>
        <p class="reach">
          {{ tenantCount === null ? 'Counting tenants…' : `${tenantCount} ${tenantCount === 1 ? 'tenant' : 'tenants'} will get this` }}
        </p>

        <div class="row">
          <span class="row-label">Title</span>
          <input v-model="form.title" type="text" class="row-input" maxlength="120" placeholder="Water interruption Tuesday" />
        </div>

        <div class="row">
          <span class="row-label">Summary</span>
          <input v-model="form.summary" type="text" class="row-input" maxlength="140" placeholder="One line for the banner" />
        </div>

        <textarea v-model="form.body" class="body" placeholder="The full notice: what is happening, when, and what your tenants need to do." />

        <div class="row">
          <span class="row-label">Happens</span>
          <input v-model="form.eventAt" type="datetime-local" class="row-input" />
          <button v-if="form.eventAt" type="button" class="row-now" @click="form.eventAt = ''">Clear</button>
        </div>

        <div v-if="form.eventAt" class="row">
          <span class="row-label">Until</span>
          <input v-model="form.eventEnd" type="datetime-local" class="row-input" />
          <button v-if="form.eventEnd" type="button" class="row-now" @click="form.eventEnd = ''">Clear</button>
        </div>

        <div class="row">
          <span class="row-label">Where</span>
          <input v-model="form.location" type="text" class="row-input" maxlength="120" placeholder="Ground floor · Zone 3" />
        </div>

        <div class="row">
          <span class="row-label">Send</span>
          <input v-model="form.publishAt" type="datetime-local" class="row-input" />
          <button type="button" class="row-now" @click="form.publishAt = ''">Now</button>
        </div>

        <div class="row">
          <span class="row-label">Hide after</span>
          <input v-model="form.expiresAt" type="date" class="row-input" />
          <button v-if="form.expiresAt" type="button" class="row-now" @click="form.expiresAt = ''">Clear</button>
        </div>

        <button type="button" class="send" :disabled="!canSend" @click="send">
          {{ sending ? 'Sending…' : form.publishAt ? 'Schedule' : 'Send now' }}
        </button>
      </section>

      <!-- Sent -->
      <section class="sec">
        <h2 class="sec-title">Your announcements</h2>
        <EmptyState
          v-if="!mine.length"
          variant="compact"
          icon="lucide:megaphone"
          title="Nothing sent yet"
          message="Notices you send your tenants are listed here."
        />
        <div v-for="a in mine" :key="a.id" class="item">
          <div class="item-text">
            <span class="item-title">{{ a.title }}</span>
            <span class="item-meta">{{ houseName(a.accommodation_id) }} · {{ statusOf(a) }}</span>
          </div>
          <button type="button" class="item-act" @click="remove(a)">
            <IconifyIcon icon="lucide:trash-2" width="16" />
          </button>
        </div>
      </section>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'
import { errorMessage } from '@/utils/errors'
import { formatDate } from '@/utils/format'
import EmptyState from '@/components/shared/EmptyState.vue'

// A manager announcing to their own tenants. OSAS broadcasts leave
// accommodation_id null; setting it is what makes an announcement a house
// notice, and RLS uses that same column to decide who may write and read it.

type Accommodation = { id: string; name: string }
type Mine = {
  id: string
  title: string
  accommodation_id: string | null
  published_at: string | null
  expires_at: string | null
}

const notify = useNotify()

const loading = ref(true)
const sending = ref(false)
const userId = ref('')
const accommodations = ref<Accommodation[]>([])
const mine = ref<Mine[]>([])
const tenantCount = ref<number | null>(null)

const form = reactive({
  accommodationId: '',
  title: '',
  summary: '',
  body: '',
  // What the notice is about — shown as facts on the announcement, instead of
  // being buried in the sentence.
  eventAt: '',
  eventEnd: '',
  location: '',
  publishAt: '',
  expiresAt: '',
})

const canSend = computed(
  () => Boolean(form.accommodationId && form.title.trim() && form.body.trim()) && !sending.value,
)

function houseName(id: string | null) {
  return accommodations.value.find((a) => a.id === id)?.name ?? 'Your accommodation'
}

function statusOf(a: Mine) {
  if (!a.published_at) return 'Draft'
  const published = new Date(a.published_at)
  if (published.getTime() > Date.now()) return `Scheduled ${formatDate(a.published_at)}`
  if (a.expires_at && new Date(a.expires_at).getTime() < Date.now()) return 'Ended'
  return `Sent ${formatDate(a.published_at)}`
}

onMounted(async () => {
  const { data } = await authUser()
  userId.value = data?.user?.id ?? ''
  if (!userId.value) {
    loading.value = false
    return
  }

  const [{ data: houses }, { data: rows }] = await Promise.all([
    supabase
      .from('accommodations')
      .select('id, name')
      .eq('accommodation_manager_id', userId.value)
      .order('name'),
    supabase
      .from('announcements')
      .select('id, title, accommodation_id, published_at, expires_at')
      .not('accommodation_id', 'is', null)
      .order('published_at', { ascending: false, nullsFirst: true }),
  ])

  accommodations.value = houses ?? []
  mine.value = (rows ?? []) as Mine[]
  form.accommodationId = accommodations.value[0]?.id ?? ''
  loading.value = false
})

// The count is the honest version of "who am I about to interrupt".
watch(() => form.accommodationId, countTenants, { immediate: true })

async function countTenants() {
  if (!form.accommodationId) {
    tenantCount.value = null
    return
  }
  tenantCount.value = null
  const { data } = await supabase
    .from('leases')
    .select('id, rooms!inner(accommodation_id)')
    .eq('status', 'active')
    .eq('rooms.accommodation_id', form.accommodationId)
  tenantCount.value = (data ?? []).length
}

async function send() {
  if (!canSend.value) return
  sending.value = true
  try {
    const publishAt = form.publishAt ? new Date(form.publishAt).toISOString() : new Date().toISOString()
    const { data, error } = await supabase
      .from('announcements')
      .insert({
        title: form.title.trim(),
        summary: form.summary.trim() || null,
        body: form.body.trim(),
        // Tenants are students; the audience column is ignored for house
        // notices, which are addressed by accommodation instead.
        audience: 'students',
        accommodation_id: form.accommodationId,
        event_at: form.eventAt ? new Date(form.eventAt).toISOString() : null,
        event_end: form.eventEnd ? new Date(form.eventEnd).toISOString() : null,
        location: form.location.trim() || null,
        author_id: userId.value,
        published_at: publishAt,
        expires_at: form.expiresAt ? new Date(`${form.expiresAt}T23:59:59`).toISOString() : null,
      })
      .select('id, title, accommodation_id, published_at, expires_at')
      .single()
    if (error) throw error

    mine.value = [data as Mine, ...mine.value]
    notify.success(form.publishAt ? 'Scheduled.' : 'Sent to your tenants.')
    form.title = ''
    form.summary = ''
    form.body = ''
    form.eventAt = ''
    form.eventEnd = ''
    form.location = ''
    form.publishAt = ''
    form.expiresAt = ''
  } catch (e) {
    notify.error(errorMessage(e, 'Could not send that announcement.'))
  } finally {
    sending.value = false
  }
}

async function remove(a: Mine) {
  const { error } = await supabase.from('announcements').delete().eq('id', a.id)
  if (error) {
    notify.error(error.message)
    return
  }
  mine.value = mine.value.filter((row) => row.id !== a.id)
  notify.success('Removed. Notifications already delivered stay in your tenants\' inbox.')
}
</script>

<style scoped>
.ann-page { padding: 12px 12px 28px; }
.stack { display: flex; flex-direction: column; gap: 12px; }
.sk { border-radius: var(--m-radius); }

.card {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 4px 12px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-lg);
  background: var(--m-surface);
}

.row {
  display: flex;
  min-height: 42px;
  align-items: center;
  gap: 10px;
  border-bottom: 1px solid var(--m-border);
}
.row--wrap { flex-wrap: wrap; padding: 8px 0; }
.row-label { flex: 0 0 62px; color: var(--m-muted); font-size: 12px; font-weight: 700; }
.row-input {
  min-width: 0;
  flex: 1 1 auto;
  border: 0;
  background: none;
  color: var(--m-ink);
  font: inherit;
  font-size: 13px;
  outline: none;
}
.row-now {
  flex: 0 0 auto;
  padding: 3px 9px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  font: inherit;
  font-size: 11px;
  font-weight: 700;
  cursor: pointer;
}
.chips { display: flex; flex: 1 1 auto; flex-wrap: wrap; gap: 6px; }
.chip {
  padding: 5px 11px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  font: inherit;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
}
.chip--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary);
}
.reach {
  margin: 6px 0 2px;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
.body {
  min-height: 120px;
  margin-top: 10px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  color: var(--m-ink);
  font: inherit;
  font-size: 13px;
  line-height: 1.5;
  outline: none;
  resize: vertical;
}
.send {
  margin-top: 12px;
  padding: 11px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  cursor: pointer;
}
.send:disabled { opacity: 0.45; cursor: default; }

.sec { display: flex; flex-direction: column; gap: 6px; }
.sec-title { margin: 0 2px; color: var(--m-ink); font-size: 14px; font-weight: 700; }
.item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.item-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 2px; }
.item-title {
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.item-meta { color: var(--m-muted); font-size: 11px; font-weight: 600; }
.item-act {
  flex: 0 0 auto;
  border: 0;
  background: none;
  color: var(--m-muted);
  cursor: pointer;
}
</style>
