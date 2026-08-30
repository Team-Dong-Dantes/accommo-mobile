<template>
  <q-page class="support-page">
    <div class="support-tabs">
      <q-btn
        no-caps
        rounded
        unelevated
        class="pill"
        :class="{ 'pill-active': activeTab === 'osas' }"
        label="OSAS Support"
        @click="activeTab = 'osas'"
      />
      <q-btn
        no-caps
        rounded
        unelevated
        class="pill"
        :class="{ 'pill-active': activeTab === 'maintenance' }"
        label="Maintenance"
        @click="activeTab = 'maintenance'"
      />
      <q-btn
        no-caps
        rounded
        unelevated
        class="pill"
        :class="{ 'pill-active': activeTab === 'reviews' }"
        label="Reviews"
        @click="activeTab = 'reviews'"
      />
    </div>

    <div v-if="view === 'newTicket'" class="new-ticket">
      <div class="nt-header">
        <q-btn flat round dense icon="arrow_back" @click="goBack" />
        <div class="nt-title">New Ticket</div>
        <q-chip dense outline color="teal-8" class="nt-chip">{{ categoryLabel(ticketCategory) }}</q-chip>
      </div>

      <div class="nt-body">
        <label class="nt-label">Related boarding house</label>
        <q-select
          v-model="selectedProperty"
          :options="propertyOptions"
          option-value="id"
          option-label="name"
          emit-value
          map-options
          outlined
          dense
          placeholder="Select boarding house"
          class="nt-input"
        />

        <label class="nt-label">Subject</label>
        <q-input v-model="subject" outlined dense placeholder="Enter subject" class="nt-input" />

        <label class="nt-label">Details</label>
        <q-input
          v-model="details"
          outlined
          dense
          type="textarea"
          autogrow
          placeholder="Describe the issue"
          class="nt-input"
        />

        <label class="nt-label">Priority</label>
        <div class="priority-row">
          <q-btn
            no-caps
            rounded
            unelevated
            class="prio-pill"
            :class="{ 'prio-active': priority === 'medium' }"
            label="Normal"
            @click="priority = 'medium'"
          />
          <q-btn
            no-caps
            rounded
            unelevated
            class="prio-pill"
            :class="{ 'prio-active': priority === 'urgent' }"
            label="Urgent"
            @click="priority = 'urgent'"
          />
        </div>

        <q-btn
          unelevated
          class="submit-ticket"
          label="Submit Ticket"
          :disable="!subject.trim() || !selectedProperty"
          :loading="submitting"
          @click="submitTicket"
        />
      </div>
    </div>

    <div v-else>
      <div v-if="activeTab === 'osas'">
        <div class="search-banner">
          <q-icon name="search" size="20px" class="search-icon" />
          <input v-model="osasSearch" class="search-input" placeholder="Search for help..." />
        </div>

        <div class="cat-grid">
          <q-btn
            v-for="cat in categoryOptions"
            :key="cat.value"
            flat
            class="cat-card"
            @click="openNewTicket(cat.value)"
          >
            <div class="cat-inner">
              <q-icon name="article" size="22px" class="cat-icon" />
              <div class="cat-name">{{ cat.label }}</div>
            </div>
          </q-btn>
        </div>

        <div class="section-label">MY TICKETS</div>
        <q-list v-if="!ticketLoading && myTickets.length" separator class="ticket-list">
          <q-item
            v-for="t in myTickets"
            :key="t.id"
            class="ticket-item"
            clickable
            @click="openTicket(t)"
          >
            <q-item-section>
              <q-item-label class="ticket-subject">{{ t.subject }}</q-item-label>
              <q-item-label caption class="ticket-meta">{{ categoryLabel(t.category) }} · {{ priorityLabel(t.priority) }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-badge
                :color="statusColor(COMPLAINT_STATUS, t.status)"
                class="ticket-badge"
              >
                {{ statusText(COMPLAINT_STATUS, t.status) }}
              </q-badge>
            </q-item-section>
          </q-item>
        </q-list>
        <div v-else-if="ticketLoading" class="text-center q-pa-md">
          <q-spinner size="28px" color="teal-8" />
        </div>
        <div v-else class="text-grey-7 text-center q-pa-md">No tickets submitted yet.</div>
      </div>

      <div v-else-if="activeTab === 'maintenance'">
        <q-list separator class="maint-list">
          <q-item v-for="m in maintenanceTickets" :key="m.id" class="maint-item">
            <q-item-section>
              <div class="maint-top">
                <q-chip dense color="teal-8" text-color="white" class="mini-chip">{{ m.category }}</q-chip>
                <q-chip dense color="orange-7" text-color="white" class="mini-chip">{{ m.priority }}</q-chip>
              </div>
              <q-item-label class="maint-title">{{ m.title }}</q-item-label>
              <q-item-label caption class="maint-desc">{{ m.description }}</q-item-label>
              <div class="maint-tenant">
                <q-avatar size="22px" class="tenant-avatar">{{ m.tenantInitial }}</q-avatar>
                <span class="tenant-name">{{ m.tenantName }}</span>
              </div>
              <div class="maint-resolved">Resolved: {{ m.resolutionDate }}</div>
              <q-select
                v-model="m.status"
                :options="['Resolved', 'In Progress']"
                dense
                outlined
                class="maint-select"
              />
            </q-item-section>
          </q-item>
        </q-list>
      </div>

      <div v-else-if="activeTab === 'reviews'">
        <div class="review-summary">
          <div class="summary-score">{{ reviewSummary.score.toFixed(1) }}</div>
          <div class="summary-stars">
            <q-icon
              v-for="n in 5"
              :key="n"
              :name="starIcon(n, reviewSummary.score)"
              size="18px"
              class="summary-star"
            />
          </div>
          <div class="summary-count">{{ reviewSummary.total }} reviews</div>
          <div class="breakdown">
            <div v-for="b in reviewSummary.breakdown" :key="b.stars" class="break-row">
              <span class="break-label">{{ b.stars }} star</span>
              <q-linear-progress
                :value="b.count / reviewSummary.total"
                color="amber"
                class="break-bar"
              />
              <span class="break-count">{{ b.count }}</span>
            </div>
          </div>
        </div>

        <q-list separator class="review-list">
          <q-item v-for="r in reviewList" :key="r.id" class="review-item">
            <q-item-section avatar>
              <q-avatar size="36px" class="anon-avatar">
                <q-icon name="person" size="20px" />
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <div class="review-stars">
                <q-icon
                  v-for="n in 5"
                  :key="n"
                  :name="starIcon(n, r.stars)"
                  size="15px"
                  class="review-star"
                />
              </div>
              <q-item-label caption class="review-date">{{ r.date }}</q-item-label>
              <q-item-label class="review-text">{{ r.feedback }}</q-item-label>
            </q-item-section>
          </q-item>
        </q-list>
      </div>
    </div>

    <q-dialog v-model="detailOpen" position="bottom">
      <q-card class="ticket-detail">
        <q-card-section>
          <div class="td-header">
            <div class="td-title">{{ detailTicket?.subject }}</div>
            <q-btn flat round dense icon="close" @click="detailOpen = false" />
          </div>
          <q-badge :color="statusColor(COMPLAINT_STATUS, detailTicket?.status)" class="td-badge">
            {{ statusText(COMPLAINT_STATUS, detailTicket?.status) }}
          </q-badge>
          <div class="td-rows">
            <div class="td-row"><span class="td-key">Category</span><span class="td-val">{{ categoryLabel(detailTicket?.category || '') }}</span></div>
            <div class="td-row"><span class="td-key">Priority</span><span class="td-val">{{ priorityLabel(detailTicket?.priority) }}</span></div>
            <div class="td-row"><span class="td-key">Boarding house</span><span class="td-val">{{ propertyName(detailTicket?.property_id) }}</span></div>
            <div class="td-row"><span class="td-key">Reported</span><span class="td-val">{{ formatDate(detailTicket?.reported_at) }}</span></div>
            <div class="td-row"><span class="td-key">Reporter</span><span class="td-val">{{ detailTicket?.reporter_name || '—' }}</span></div>
          </div>
          <div class="td-desc-label">Details</div>
          <div class="td-desc">{{ detailTicket?.description || 'No additional details provided.' }}</div>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from '@/shared/utils/supabase'
import { useLandlordStore } from '@/stores/landlord'
import { COMPLAINT_STATUS, statusText, statusColor } from '@/shared/utils/format'

type SupportTab = 'osas' | 'maintenance' | 'reviews'

const $q = useQuasar()
const landlord = useLandlordStore()

const activeTab = ref<SupportTab>('osas')
const view = ref<'list' | 'newTicket'>('list')
const ticketCategory = ref<string>('')
const subject = ref<string>('')
const details = ref<string>('')
const priority = ref<'medium' | 'urgent'>('medium')
const selectedProperty = ref<string>('')
const osasSearch = ref<string>('')
const submitting = ref(false)
const ticketLoading = ref(false)

const categoryOptions: { value: string; label: string }[] = [
  { value: 'financial', label: 'Financial / Payments' },
  { value: 'privacy', label: 'Privacy' },
  { value: 'maintenance', label: 'Maintenance' },
  { value: 'safety', label: 'Safety / Inspection' },
  { value: 'harassment', label: 'Harassment / Dispute' },
  { value: 'contract', label: 'Contract / Accreditation' },
]

const propertyOptions = ref<{ id: string; name: string }[]>([])

interface MyTicket {
  id: string
  subject: string
  status: string
  category: string
  priority: string
  property_id: string | null
  reported_at: string | null
  reporter_name: string | null
  description: string | null
}

const myTickets = ref<MyTicket[]>([])

const detailOpen = ref(false)
const detailTicket = ref<MyTicket | null>(null)

const priorityLabel = (value: string | null | undefined) =>
  value === 'urgent' ? 'Urgent' : value === 'high' ? 'High' : 'Normal'

const propertyName = (id: string | null | undefined) =>
  propertyOptions.value.find((p) => p.id === id)?.name ?? 'Unknown boarding house'

const formatDate = (value: string | null | undefined) => {
  if (!value) return '—'
  const d = new Date(value)
  if (isNaN(d.getTime())) return '—'
  return d.toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' })
}

const openTicket = (ticket: MyTicket) => {
  detailTicket.value = ticket
  detailOpen.value = true
}

interface MaintenanceTicket {
  id: string
  category: string
  priority: string
  status: 'Resolved' | 'In Progress'
  title: string
  description: string
  tenantName: string
  tenantInitial: string
  resolutionDate: string
}

const maintenanceTickets = ref<MaintenanceTicket[]>([
  {
    id: 'MT-0042',
    category: 'Plumbing',
    priority: 'Medium',
    status: 'Resolved',
    title: 'Leaking faucet in Room 3-A',
    description: 'Kitchen faucet drips continuously and wastes water',
    tenantName: 'Maria Santos',
    tenantInitial: 'M',
    resolutionDate: 'Apr 18, 2026',
  },
  {
    id: 'MT-0041',
    category: 'Electrical',
    priority: 'High',
    status: 'In Progress',
    title: 'Power outlet not working',
    description: 'Bedroom outlet sparks when plugging in charger',
    tenantName: 'Jose Reyes',
    tenantInitial: 'J',
    resolutionDate: 'Apr 20, 2026',
  },
])

interface ReviewSummary {
  score: number
  total: number
  breakdown: { stars: number; count: number }[]
}

const reviewSummary = ref<ReviewSummary>({
  score: 4.5,
  total: 40,
  breakdown: [
    { stars: 5, count: 28 },
    { stars: 4, count: 8 },
    { stars: 3, count: 3 },
    { stars: 2, count: 1 },
    { stars: 1, count: 0 },
  ],
})

interface Review {
  id: number
  stars: number
  date: string
  feedback: string
}

const reviewList = ref<Review[]>([
  { id: 1, stars: 5, date: 'Apr 12, 2026', feedback: 'Very clean boarding house and responsive landlord' },
  { id: 2, stars: 4, date: 'Apr 05, 2026', feedback: 'Good location but wifi can be slow at night' },
  { id: 3, stars: 5, date: 'Mar 28, 2026', feedback: 'Safe and peaceful. Recommended for students' },
])

const starIcon = (position: number, rating = 5) => {
  if (position <= Math.floor(rating)) return 'star'
  if (position - 0.5 === rating) return 'star_half'
  return 'star_border'
}

const categoryLabel = (value: string) =>
  categoryOptions.find((c) => c.value === value)?.label ?? value

const openNewTicket = (category: string) => {
  ticketCategory.value = category
  subject.value = ''
  details.value = ''
  priority.value = 'medium'
  selectedProperty.value = propertyOptions.value[0]?.id ?? ''
  view.value = 'newTicket'
}

const goBack = () => {
  view.value = 'list'
}

const submitTicket = async () => {
  const subj = subject.value.trim()
  if (!subj) {
    $q.notify({ type: 'negative', message: 'Please enter a subject' })
    return
  }
  if (!ticketCategory.value) {
    $q.notify({ type: 'negative', message: 'Please choose a category' })
    return
  }
  if (!selectedProperty.value) {
    $q.notify({ type: 'negative', message: 'Please select a boarding house' })
    return
  }

  submitting.value = true
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser()
    if (!user) throw new Error('Not signed in')

    const reporterName =
      ((user.user_metadata as Record<string, any>)?.full_name as string) ||
      user.email ||
      'Unknown'

    const { error } = await supabase.from('tickets').insert({
      id: crypto.randomUUID(),
      // Landlord is the filer. For a landlord -> OSAS ticket there is no specific
      // student, so student_id is left null and the ticket is owned via landlord_id
      // (satisfies RLS, which allows landlord_id = auth.uid()).
      landlord_id: user.id,
      student_id: null,
      property_id: selectedProperty.value,
      category: ticketCategory.value,
      priority: priority.value,
      subject: subj,
      description: details.value.trim() || null,
      status: 'pending',
      reported_at: new Date().toISOString(),
      reporter_name: reporterName,
    } as any)
    if (error) throw error

    $q.notify({ type: 'positive', message: 'Ticket submitted to OSAS' })
    view.value = 'list'
    await loadMyTickets()
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to submit ticket' })
  } finally {
    submitting.value = false
  }
}

const loadMyTickets = async () => {
  ticketLoading.value = true
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser()
    if (!user) return
    const { data, error } = await supabase
      .from('tickets')
      .select('id, subject, status, category, priority, property_id, reported_at, reporter_name, description')
      .eq('landlord_id', user.id)
      .order('reported_at', { ascending: false })
    if (error) throw error
    myTickets.value = (data ?? []).map((c: any) => ({
      id: c.id,
      subject: c.subject,
      status: c.status,
      category: c.category,
      priority: c.priority,
      property_id: c.property_id,
      reported_at: c.reported_at,
      reporter_name: c.reporter_name,
      description: c.description,
    }))
  } catch (e) {
    console.error('loadMyTickets error:', e)
  } finally {
    ticketLoading.value = false
  }
}

onMounted(async () => {
  try {
    if (!landlord.properties.length) await landlord.loadProperties()
    propertyOptions.value = landlord.properties.map((p: any) => ({
      id: p.id,
      name: p.name || 'Boarding House',
    }))
  } catch (e) {
    console.error('Failed to load boarding houses', e)
  }
  await loadMyTickets()
})
</script>

<style scoped>
.support-page {
  padding: 16px;
  padding-bottom: 90px;
  background: #f3f4f6;
  min-height: 100vh;
}
.support-tabs {
  display: flex;
  gap: 8px;
  margin-bottom: 16px;
}
.pill {
  background: #e5e7eb;
  color: #111827;
  font-weight: 700;
  font-size: 13px;
  padding: 6px 14px;
}
.pill-active {
  background: #111827;
  color: white;
}
.search-banner {
  display: flex;
  align-items: center;
  gap: 8px;
  background: #0f766e;
  border-radius: 14px;
  padding: 12px 14px;
  margin-bottom: 16px;
}
.search-icon {
  color: white;
}
.search-input {
  flex: 1;
  border: none;
  background: transparent;
  color: white;
  font-size: 14px;
  outline: none;
}
.search-input::placeholder {
  color: rgba(255, 255, 255, 0.7);
}
.cat-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-bottom: 20px;
}
.cat-card {
  background: white;
  border-radius: 14px;
  padding: 16px;
  min-height: 76px;
  align-items: center;
  justify-content: center;
}
.cat-inner {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
}
.cat-icon {
  color: #0f766e;
}
.cat-name {
  font-size: 13px;
  font-weight: 700;
  color: #111827;
}
.section-label {
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.05em;
  color: #6b7280;
  margin-bottom: 8px;
}
.ticket-list {
  background: white;
  border-radius: 14px;
  overflow: hidden;
}
.ticket-item {
  padding: 12px;
}
.ticket-meta {
  font-size: 12px;
  color: #6b7280;
  margin-top: 2px;
}
.ticket-subject {
  font-size: 14px;
  color: #111827;
  margin-top: 2px;
}
.ticket-badge {
  font-weight: 700;
}
.maint-list {
  background: white;
  border-radius: 14px;
  overflow: hidden;
}
.maint-item {
  padding: 14px;
}
.maint-top {
  display: flex;
  gap: 6px;
  margin-bottom: 6px;
}
.mini-chip {
  font-size: 11px;
  font-weight: 700;
}
.maint-title {
  font-size: 15px;
  font-weight: 700;
  color: #111827;
}
.maint-desc {
  font-size: 13px;
  color: #4b5563;
  margin-top: 2px;
}
.maint-tenant {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 8px;
}
.tenant-avatar {
  background: #0f766e;
  color: white;
  font-weight: 700;
}
.tenant-name {
  font-size: 13px;
  color: #374151;
}
.maint-resolved {
  font-size: 12px;
  color: #6b7280;
  margin-top: 4px;
}
.maint-select {
  margin-top: 8px;
  max-width: 180px;
}
.review-summary {
  background: white;
  border-radius: 14px;
  padding: 16px;
  margin-bottom: 16px;
}
.summary-score {
  font-size: 34px;
  font-weight: 800;
  color: #111827;
}
.summary-stars {
  display: flex;
  gap: 2px;
  margin-top: 2px;
}
.summary-star {
  color: #f59e0b;
}
.summary-count {
  font-size: 12px;
  color: #6b7280;
  margin-top: 2px;
}
.breakdown {
  margin-top: 12px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.break-row {
  display: flex;
  align-items: center;
  gap: 8px;
}
.break-label {
  font-size: 11px;
  color: #6b7280;
  width: 42px;
}
.break-bar {
  flex: 1;
  height: 8px;
  border-radius: 4px;
}
.break-count {
  font-size: 11px;
  color: #6b7280;
  width: 22px;
  text-align: right;
}
.review-list {
  background: white;
  border-radius: 14px;
  overflow: hidden;
}
.review-item {
  padding: 14px;
}
.anon-avatar {
  background: #e5e7eb;
  color: #6b7280;
}
.review-stars {
  display: flex;
  gap: 1px;
}
.review-star {
  color: #f59e0b;
}
.review-date {
  font-size: 11px;
  color: #9ca3af;
  margin-top: 2px;
}
.review-text {
  font-size: 13px;
  color: #374151;
  margin-top: 4px;
}
.new-ticket {
  background: white;
  border-radius: 14px;
  padding: 14px;
}
.nt-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
}
.nt-title {
  font-size: 18px;
  font-weight: 800;
  color: #111827;
  flex: 1;
}
.nt-chip {
  font-weight: 700;
}
.nt-label {
  display: block;
  font-size: 13px;
  font-weight: 700;
  color: #374151;
  margin: 10px 0 4px;
}
.nt-input {
  margin-bottom: 4px;
}
.priority-row {
  display: flex;
  gap: 8px;
  margin-top: 4px;
}
.prio-pill {
  background: #e5e7eb;
  color: #111827;
  font-weight: 700;
  font-size: 13px;
  padding: 6px 18px;
}
.prio-active {
  background: #0f766e;
  color: white;
}
.submit-ticket {
  background: #0d9488;
  color: white;
  font-weight: 700;
  width: 100%;
  margin-top: 18px;
  padding: 10px;
  border-radius: 10px;
  text-transform: none;
}
.ticket-detail {
  width: 100%;
  max-width: 520px;
  border-radius: 20px 20px 0 0;
  padding: 8px 0 16px;
}
.td-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px 4px;
}
.td-title {
  font-size: 18px;
  font-weight: 800;
  color: #111827;
  flex: 1;
}
.td-badge {
  margin: 4px 16px 8px;
  font-weight: 700;
}
.td-rows {
  padding: 0 16px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.td-row {
  display: flex;
  gap: 12px;
  font-size: 13px;
}
.td-key {
  width: 110px;
  color: #6b7280;
  font-weight: 600;
}
.td-val {
  color: #111827;
  flex: 1;
}
.td-desc-label {
  padding: 12px 16px 4px;
  font-size: 13px;
  font-weight: 700;
  color: #374151;
}
.td-desc {
  padding: 0 16px;
  font-size: 14px;
  color: #374151;
  line-height: 1.5;
  white-space: pre-wrap;
}
</style>
