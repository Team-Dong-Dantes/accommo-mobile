<template>
  <AppModal :model-value="modelValue" tall @update:model-value="emit('update:modelValue', $event)">
    <template #header>
      <span class="mx-head">
        <h3 class="mx-head-title">Post {{ monthName }} bills</h3>
        <span class="mx-head-sub">
          {{ propertyName }} · due
          <DateTimeField v-model="dueDate" mode="date" :min="today" placeholder="Due date" class="pb-due">
            {{ formatDate(dueDate) }}
          </DateTimeField>
        </span>
      </span>
    </template>

    <div v-if="loading" class="mx-body pb-center"><q-spinner size="24px" color="primary" /></div>
    <div v-else-if="!utilities.length" class="mx-body pb-center">
      <p class="mx-hint">None of your boarders' terms bill water, electricity or Wi-Fi monthly, so there's nothing to post.</p>
    </div>

    <div v-else class="mx-body">
      <div v-if="properties.length > 1" class="m-chips">
        <button
          v-for="p in properties"
          :key="p.id"
          type="button"
          class="m-chip"
          :class="{ 'm-chip--on': propertyId === p.id }"
          @click="propertyId = p.id"
        >
          {{ p.name }}
        </button>
      </div>

      <div v-if="utilities.length > 1" class="mx-segs" role="tablist" aria-label="Utility">
        <button
          v-for="u in utilities"
          :key="u.key"
          type="button"
          role="tab"
          class="mx-seg"
          :class="{ 'mx-seg--on': utility === u.key }"
          :aria-selected="utility === u.key"
          @click="utility = u.key"
        >
          {{ u.label }}
        </button>
      </div>

      <p class="mx-hint">Shared meters: enter the room's total and it's split evenly. Own meters: enter each boarder's reading.</p>

      <!-- A room per card: one total in, each tenant's share out. -->
      <div v-for="room in rooms" :key="room.id" class="pb-room">
        <div class="pb-room-head">
          <span class="pb-room-body">
            <span class="pb-room-name">{{ room.label }}</span>
            <span class="mx-hint">{{ roomLine(room) }}</span>
          </span>
          <label v-if="room.split.length" class="pb-money">
            <span class="pb-sign">₱</span>
            <input v-model="roomTotals[room.id]" type="number" min="0" step="0.01" inputmode="decimal" placeholder="0" :aria-label="`${room.label} total`" />
          </label>
        </div>
        <div v-if="room.split.length" class="pb-who">
          <span v-for="t in room.split" :key="t.id" class="pb-chip">
            <span class="pb-av" :class="t.color ? [`bg-${t.color}`, 'text-white'] : []">{{ initialsOf(t.name) }}</span>{{ t.name.split(' ')[0] }}
          </span>
        </div>
        <div v-for="t in room.own" :key="t.id" class="pb-own">
          <span class="pb-av pb-av--lg" :class="t.color ? [`bg-${t.color}`, 'text-white'] : []">{{ initialsOf(t.name) }}</span>
          <span class="pb-room-body">
            <span class="pb-own-name">{{ t.name }}</span>
            <span class="mx-hint">{{ t.posted != null ? `Posted · ${formatPesoExact(t.posted)}` : 'Own meter' }}</span>
          </span>
          <label v-if="t.posted == null" class="pb-money">
            <span class="pb-sign">₱</span>
            <input v-model="ownAmounts[t.id]" type="number" min="0" step="0.01" inputmode="decimal" placeholder="0" :aria-label="`${t.name} amount`" />
          </label>
        </div>
      </div>
    </div>

    <template v-if="utilities.length" #footer>
      <div class="mx-foot">
        <button type="button" class="mx-btn" :disabled="busy || !rows.length" @click="post">
          {{ busy ? 'Posting…' : rows.length ? `Post ${rows.length} ${utilityName.toLowerCase()} bill${rows.length === 1 ? '' : 's'} · ${formatPesoExact(sum)}` : 'Enter an amount' }}
        </button>
        <p class="mx-foot-note">Each boarder sees theirs under Payments and pays it like rent.</p>
      </div>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { supabase, authUser } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { formatDate, formatMonth, formatPesoExact, initialsOf } from '@/utils/format'
import { manilaToday } from '@/utils/payments'
import { UTILITIES, type UtilityKey } from '@/utils/listings'
import AppModal from '@/components/shared/AppModal.vue'
import DateTimeField from '@/components/shared/DateTimeField.vue'

// This month's metered bills for a whole property at once. A shared (split)
// meter is one total per room, divided evenly between the tenants on it; an own
// meter is one amount per tenant. Bills already posted for the month are shown,
// not posted twice (utility_bills is unique per stay, utility and month).
const props = defineProps<{ modelValue: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; posted: [] }>()
const notify = useNotify()

interface Tenant {
  id: string
  name: string
  color: string | null
  roomId: string
  roomLabel: string
  accommodationId: string
  accommodationName: string
  billing: Record<UtilityKey, string | null>
}

const today = manilaToday()
const month = `${today.slice(0, 7)}-01`
const monthName = formatMonth(month).split(' ')[0]
const loading = ref(false)
const busy = ref(false)
const tenants = ref<Tenant[]>([])
const posted = ref(new Map<string, number>())
const propertyId = ref('')
const utility = ref<UtilityKey>('water')
const dueDate = ref('')
const roomTotals = reactive<Record<string, number | ''>>({})
const ownAmounts = reactive<Record<string, number | ''>>({})

const metered = (b: string | null) => b === 'own_meter' || b === 'split'
const properties = computed(() => {
  const m = new Map<string, string>()
  for (const t of tenants.value) if (UTILITIES.some((u) => metered(t.billing[u.key]))) m.set(t.accommodationId, t.accommodationName)
  return [...m.entries()].map(([id, name]) => ({ id, name }))
})
const propertyName = computed(() => properties.value.find((p) => p.id === propertyId.value)?.name ?? '')
const here = computed(() => tenants.value.filter((t) => t.accommodationId === propertyId.value))
const utilities = computed(() => UTILITIES.filter((u) => here.value.some((t) => metered(t.billing[u.key]))))
const utilityName = computed(() => UTILITIES.find((u) => u.key === utility.value)?.label ?? '')

const rooms = computed(() => {
  const m = new Map<string, { id: string; label: string; split: (Tenant & { posted: number | null })[]; own: (Tenant & { posted: number | null })[] }>()
  for (const t of here.value) {
    const b = t.billing[utility.value]
    if (!metered(b)) continue
    const room = m.get(t.roomId) ?? { id: t.roomId, label: t.roomLabel, split: [], own: [] }
    const p = posted.value.get(`${t.id}:${utility.value}`) ?? null
    if (b === 'split') {
      if (p == null) room.split.push({ ...t, posted: p })
    } else room.own.push({ ...t, posted: p })
    m.set(t.roomId, room)
  }
  return [...m.values()].filter((r) => r.split.length || r.own.length).sort((a, b) => a.label.localeCompare(b.label, undefined, { numeric: true }))
})

function shares(total: number, n: number): number[] {
  const each = Math.floor((total / n) * 100) / 100
  return Array.from({ length: n }, (_, i) => (i === n - 1 ? Math.round((total - each * (n - 1)) * 100) / 100 : each))
}
function roomLine(room: (typeof rooms.value)[number]): string {
  if (!room.split.length) return room.own.length === 1 ? '1 boarder · own meter' : `${room.own.length} boarders · own meters`
  const total = Number(roomTotals[room.id]) || 0
  const n = room.split.length
  if (!total) return `${n} boarder${n === 1 ? '' : 's'} · left blank, skipped`
  return `${n} boarder${n === 1 ? '' : 's'} · ${formatPesoExact(shares(total, n)[0]!)} each`
}

const rows = computed(() => {
  const out: { lease_id: string; utility: UtilityKey; month: string; amount: number; due_date: string }[] = []
  for (const room of rooms.value) {
    const total = Number(roomTotals[room.id]) || 0
    if (total > 0 && room.split.length) {
      shares(total, room.split.length).forEach((amount, i) => out.push({ lease_id: room.split[i]!.id, utility: utility.value, month, amount, due_date: dueDate.value }))
    }
    for (const t of room.own) {
      const amount = Number(ownAmounts[t.id]) || 0
      if (t.posted == null && amount > 0) out.push({ lease_id: t.id, utility: utility.value, month, amount, due_date: dueDate.value })
    }
  }
  return out
})
const sum = computed(() => rows.value.reduce((s, r) => s + r.amount, 0))

watch(utility, () => {
  for (const k of Object.keys(roomTotals)) delete roomTotals[k]
  for (const k of Object.keys(ownAmounts)) delete ownAmounts[k]
})
watch(utilities, (list) => {
  if (list.length && !list.some((u) => u.key === utility.value)) utility.value = list[0]!.key
})

async function load() {
  loading.value = true
  try {
    const { data: auth } = await authUser()
    const { data, error } = await supabase
      .from('leases')
      .select('id,water_billing,electric_billing,wifi_billing,users!leases_student_id_fkey(full_name,avatar_color),rooms(id,label,room_number,accommodation_id,accommodations(name))')
      .eq('landlord_id', auth?.user?.id ?? '')
      .in('status', ['active', 'leave_requested'])
      .lte('start_date', today)
    if (error) throw error
    tenants.value = (data ?? []).map((l) => {
      const u = l.users as unknown as { full_name: string | null; avatar_color: string | null } | null
      const r = l.rooms as unknown as { id: string; label: string | null; room_number: string | null; accommodation_id: string; accommodations: { name: string | null } | null } | null
      return {
        id: l.id,
        name: u?.full_name || 'A student',
        color: u?.avatar_color ?? null,
        roomId: r?.id ?? '',
        roomLabel: r?.label || (r?.room_number ? `Room ${r.room_number}` : 'Room'),
        accommodationId: r?.accommodation_id ?? '',
        accommodationName: r?.accommodations?.name?.trim() || 'Accommodation',
        billing: { water: l.water_billing, electric: l.electric_billing, wifi: l.wifi_billing },
      }
    })
    const ids = tenants.value.map((t) => t.id)
    const { data: bills } = ids.length
      ? await supabase.from('utility_bills').select('lease_id,utility,amount').in('lease_id', ids).eq('month', month)
      : { data: [] }
    posted.value = new Map((bills ?? []).map((b) => [`${b.lease_id}:${b.utility}`, Number(b.amount)]))
    if (!properties.value.some((p) => p.id === propertyId.value)) propertyId.value = properties.value[0]?.id ?? ''
  } catch (e) {
    notify.error(errorMessage(e, 'Could not load your boarders.'))
  } finally {
    loading.value = false
  }
}

watch(
  () => [propertyId.value],
  () => {
    for (const k of Object.keys(roomTotals)) delete roomTotals[k]
    for (const k of Object.keys(ownAmounts)) delete ownAmounts[k]
  },
)

// A week to pay, the same default the database uses.
function weekFromToday(): string {
  const d = new Date(`${today}T00:00:00`)
  d.setDate(d.getDate() + 7)
  return d.toLocaleDateString('en-CA')
}

watch(
  () => props.modelValue,
  (open) => {
    if (!open) return
    dueDate.value = weekFromToday()
    void load()
  },
  { immediate: true },
)

async function post() {
  if (busy.value || !rows.value.length) return
  busy.value = true
  try {
    const { error } = await supabase.from('utility_bills').insert(rows.value)
    if (error) {
      if (error.code === '23505') throw new Error(`Some of these ${monthName} bills were already posted. Reopen this sheet to see which.`)
      throw error
    }
    notify.success(`${rows.value.length} bill${rows.value.length === 1 ? '' : 's'} posted.`)
    emit('posted')
    emit('update:modelValue', false)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not post the bills.'))
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.pb-center {
  align-items: center;
  justify-content: center;
  text-align: center;
}
/* An inline link in the subtitle rather than a field: the slot replaces the
   picker's contents with the formatted date. */
.pb-due {
  display: inline;
  width: auto;
  padding: 0;
  border: 0;
  background: none;
  color: var(--m-primary-dark);
  font: inherit;
  font-weight: 700;
  text-decoration: underline dotted;
}
.pb-room {
  overflow: hidden;
  flex: 0 0 auto;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
}
.pb-room-head {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px 10px 14px;
}
.pb-room-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.pb-room-name {
  color: var(--m-ink);
  font-size: 14.5px;
  font-weight: 700;
}
.pb-money {
  display: flex;
  width: 118px;
  min-height: 44px;
  flex: 0 0 auto;
  align-items: center;
  gap: 4px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
}
.pb-sign {
  color: var(--m-muted);
  font-weight: 700;
}
.pb-money input {
  min-width: 0;
  flex: 1;
  border: 0;
  outline: 0;
  background: none;
  color: var(--m-ink);
  font: inherit;
  font-size: 15px;
  font-weight: 700;
  text-align: right;
}
.pb-who {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  padding: 0 14px 12px;
}
.pb-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px 4px 4px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 600;
}
.pb-av {
  display: inline-flex;
  width: 22px;
  height: 22px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: var(--m-border);
  color: var(--m-ink);
  font-size: 9.5px;
  font-weight: 700;
}
.pb-av--lg {
  width: 32px;
  height: 32px;
  font-size: 11px;
}
.pb-own {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px 10px 14px;
  border-top: 1px solid var(--m-border);
}
.pb-room-head + .pb-own {
  border-top: 0;
}
.pb-own-name {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 600;
}
</style>
