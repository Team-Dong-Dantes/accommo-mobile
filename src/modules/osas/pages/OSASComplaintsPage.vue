<template>
  <q-page class="osas-inbox bg-grey-1 q-pb-xl">
    <div class="header-banner text-white q-pa-md">
      <div class="text-h5 text-weight-bold">OSAS Inbox</div>
      <div class="text-subtitle2 q-mt-xs opacity-8">Tickets and concerns from landlords and students</div>
    </div>

    <div class="q-pa-md" v-if="role && role !== 'admin'">
      <q-banner class="bg-orange-1 text-orange-9 rounded-borders">
        You need an OSAS admin account to view this inbox.
      </q-banner>
    </div>

    <div class="q-px-md q-mt-sm" v-else>
      <div class="row q-gutter-sm q-mb-md">
        <q-chip
          v-for="opt in filterOptions"
          :key="opt.value"
          clickable
          :color="filter === opt.value ? 'teal-8' : 'white'"
          :text-color="filter === opt.value ? 'white' : 'grey-8'"
          @click="filter = opt.value"
        >
          {{ opt.label }}
        </q-chip>
      </div>

      <template v-if="loading">
        <q-skeleton type="rect" height="96px" class="q-mb-sm" v-for="i in 3" :key="i" style="border-radius:14px" />
      </template>
      <template v-else-if="filteredRows.length === 0">
        <q-card flat bordered class="text-center text-grey-6 q-py-lg">No tickets found.</q-card>
      </template>
      <template v-else>
        <q-card v-for="row in filteredRows" :key="row.id" flat bordered class="ticket-card q-mb-sm">
          <q-card-section>
            <div class="row items-start justify-between">
              <div class="text-subtitle1 text-weight-bold">{{ row.subject }}</div>
              <q-badge :color="statusColor(COMPLAINT_STATUS, row.status)" class="q-px-sm">
                {{ statusText(COMPLAINT_STATUS, row.status) }}
              </q-badge>
            </div>
            <div class="row q-gutter-xs q-mt-xs">
              <q-chip dense outline color="teal-8">{{ row.category }}</q-chip>
              <q-chip dense outline color="deep-orange-7">Priority: {{ row.priority }}</q-chip>
              <q-chip dense outline color="grey-7">{{ propName(row.property_id) }}</q-chip>
            </div>
            <div class="text-caption text-grey-7 q-mt-xs">
              Filed by {{ userName(row.landlord_id) }} •
              {{ new Date(row.filed_at).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' }) }}
            </div>
            <div class="text-body2 q-mt-sm" v-if="row.description">{{ row.description }}</div>

            <div class="row items-center q-mt-md">
              <q-select
                :model-value="row.status"
                :options="statusOptions"
                map-options
                emit-value
                dense
                outlined
                class="status-select"
                :loading="updatingId === row.id"
                @update:model-value="updateStatus(row, $event)"
              />
              <q-btn
                flat
                dense
                color="teal-8"
                icon="person_add"
                label="Assign to me"
                class="q-ml-sm"
                :loading="updatingId === row.id"
                @click="assignToMe(row)"
              />
            </div>
          </q-card-section>
        </q-card>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from '@/shared/utils/supabase'
import { COMPLAINT_STATUS, statusText, statusColor } from '@/shared/utils/format'

const $q = useQuasar()

interface ComplaintRow {
  id: string
  subject: string
  category: string
  priority: string
  status: string
  description: string | null
  filed_at: string
  property_id: string | null
  landlord_id: string | null
  student_id: string | null
}

const loading = ref(true)
const rows = ref<ComplaintRow[]>([])
const propertyNames = ref<Record<string, string>>({})
const userNames = ref<Record<string, string>>({})
const role = ref<string>('')
const filter = ref<string>('all')
const updatingId = ref<string | null>(null)

const filterOptions = [
  { label: 'All', value: 'all' },
  { label: 'Pending', value: 'pending' },
  { label: 'Assigned', value: 'assigned' },
  { label: 'Under Review', value: 'under_review' },
  { label: 'Resolved', value: 'resolved' },
]

const statusOptions = [
  { label: 'Pending', value: 'pending' },
  { label: 'Assigned', value: 'assigned' },
  { label: 'Under Review', value: 'under_review' },
  { label: 'Resolved', value: 'resolved' },
]

const filteredRows = computed(() => {
  if (filter.value === 'all') return rows.value
  return rows.value.filter((r) => r.status === filter.value)
})

const propName = (id: string | null) =>
  id ? (propertyNames.value[id] || 'Unknown property') : 'No property'
const userName = (id: string | null) =>
  id ? (userNames.value[id] || 'Unknown user') : 'Unknown'

async function loadRole() {
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return
  const { data } = await supabase.from('users').select('role').eq('id', user.id).single()
  role.value = (data as any)?.role ?? ''
}

async function loadComplaints() {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('complaints')
      .select(
        'id, subject, category, priority, status, description, filed_at, property_id, landlord_id, student_id',
      )
      .order('filed_at', { ascending: false })
    if (error) throw error
    rows.value = (data ?? []) as ComplaintRow[]

    const propertyIds = Array.from(
      new Set((data ?? []).map((c: any) => c.property_id).filter(Boolean)),
    ) as string[]
    const userIds = Array.from(
      new Set((data ?? []).flatMap((c: any) => [c.landlord_id, c.student_id]).filter(Boolean)),
    ) as string[]

    if (propertyIds.length) {
      const { data: props } = await supabase
        .from('properties')
        .select('id, name')
        .in('id', propertyIds)
      propertyNames.value = Object.fromEntries((props ?? []).map((p: any) => [p.id, p.name]))
    }
    if (userIds.length) {
      const { data: users } = await supabase
        .from('users')
        .select('id, full_name')
        .in('id', userIds)
      userNames.value = Object.fromEntries((users ?? []).map((u: any) => [u.id, u.full_name]))
    }
  } catch (e) {
    console.error('loadComplaints error:', e)
    $q.notify({ type: 'negative', message: 'Failed to load complaints' })
  } finally {
    loading.value = false
  }
}

async function updateStatus(row: ComplaintRow, status: string) {
  updatingId.value = row.id
  try {
    const { error } = await supabase
      .from('complaints')
      .update({ status } as any)
      .eq('id', row.id)
    if (error) throw error
    row.status = status
    $q.notify({ type: 'positive', message: 'Status updated' })
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to update' })
  } finally {
    updatingId.value = null
  }
}

async function assignToMe(row: ComplaintRow) {
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return
  updatingId.value = row.id
  try {
    const nextStatus = row.status === 'pending' ? 'assigned' : row.status
    const { error } = await supabase
      .from('complaints')
      .update({ osas_officer_id: user.id, status: nextStatus } as any)
      .eq('id', row.id)
    if (error) throw error
    row.status = nextStatus
    $q.notify({ type: 'positive', message: 'Assigned to you' })
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to assign' })
  } finally {
    updatingId.value = null
  }
}

onMounted(async () => {
  await loadRole()
  await loadComplaints()
})
</script>

<style scoped>
.header-banner {
  background: linear-gradient(135deg, #6d28d9, #8b5cf6);
  border-radius: 0 0 24px 24px;
}
.opacity-8 { opacity: 0.85; }
.ticket-card { border-radius: 14px; }
.status-select { min-width: 170px; }
</style>
