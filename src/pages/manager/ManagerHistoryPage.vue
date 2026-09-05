<template>
  <q-page class="history-page">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="40px" class="sk" />
      <q-skeleton type="rect" height="90px" class="sk" />
      <q-skeleton type="rect" height="90px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your history</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <div v-else class="stack">
      <q-tabs v-model="tab" class="tabs" active-color="primary" indicator-color="primary" dense align="left">
        <q-tab name="reviews" label="Reviews" />
        <q-tab name="payments" label="Payments" />
      </q-tabs>

      <q-tab-panels v-model="tab" animated class="panels">
        <q-tab-panel name="reviews" class="panel">
          <div class="panel-card">
            <div v-if="reviews.length">
              <div class="rating-summary">
                <StarRating :model-value="avgRating" :size="18" />
                <span class="rating-count">{{ avgRating.toFixed(1) }} · {{ reviews.length }} review{{ reviews.length === 1 ? '' : 's' }}</span>
              </div>
              <div v-for="r in reviews" :key="r.id" class="review-row">
                <div class="review-top">
                  <span class="review-author">{{ r.authorName }} <span class="review-source">· {{ r.source }}</span></span>
                  <StarRating :model-value="r.rating" :size="13" />
                </div>
                <p v-if="r.comment" class="review-comment">{{ r.comment }}</p>
              </div>
            </div>
            <p v-else class="empty-message">No reviews yet.</p>
          </div>
        </q-tab-panel>

        <q-tab-panel name="payments" class="panel">
          <div class="panel-card">
            <div v-if="payments.length">
              <button
                v-for="p in payments"
                :key="p.id"
                type="button"
                class="pay-row"
                @click="router.push(`/manager/tenant/${p.leaseId}`)"
              >
                <span class="pay-avatar">{{ initialsOf(p.studentName) }}</span>
                <span class="pay-body">
                  <span class="pay-name">{{ p.studentName }}</span>
                  <span class="pay-sub">{{ p.roomLabel }} · {{ formatMonth(p.month) }}</span>
                </span>
                <span class="pay-side">
                  <span class="pay-amount">{{ formatPeso(p.amount) }}</span>
                  <span class="pay-chip" :class="`pay-chip--${statusColor(PAYMENT_STATUS, p.status)}`">
                    {{ statusText(PAYMENT_STATUS, p.status) }}
                  </span>
                </span>
              </button>
            </div>
            <p v-else class="empty-message">No payments yet.</p>
          </div>
        </q-tab-panel>
      </q-tab-panels>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import StarRating from '@/components/shared/StarRating.vue'
import { formatPeso, formatMonth, initialsOf, PAYMENT_STATUS, statusText, statusColor } from '@/utils/format'

interface Review {
  id: string
  rating: number
  comment: string
  createdAt: string
  authorName: string
  source: string
}
interface PaymentRow {
  id: string
  leaseId: string
  studentName: string
  roomLabel: string
  month: string
  amount: number
  status: string
}

const router = useRouter()

const loading = ref(true)
const error = ref('')
const tab = ref('reviews')

const reviews = ref<Review[]>([])
const payments = ref<PaymentRow[]>([])
const avgRating = computed(() => (reviews.value.length ? reviews.value.reduce((n, r) => n + r.rating, 0) / reviews.value.length : 0))

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: auth } = await supabase.auth.getUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }

    const { data: accommodations } = await supabase
      .from('accommodations')
      .select('id')
      .eq('accommodation_manager_id', user.id)
    const accommodationIds = (accommodations || []).map((a) => a.id)

    const [{ data: managerReviews }, { data: accReviews }, { data: paymentRows }] = await Promise.all([
      supabase
        .from('accommodation_manager_reviews')
        .select('id, rating, comment, created_at, users!accommodation_manager_reviews_student_id_fkey(full_name)')
        .eq('accommodation_manager_id', user.id)
        .order('created_at', { ascending: false }),
      accommodationIds.length
        ? supabase
            .from('accommodation_reviews')
            .select('id, rating, comment, created_at, accommodations(name), users!accommodation_reviews_student_id_fkey(full_name)')
            .in('accommodation_id', accommodationIds)
            .order('created_at', { ascending: false })
        : Promise.resolve({ data: [] as never[] }),
      supabase
        .from('payments')
        .select(
          'id, month, amount, status, leases!inner(id, accommodation_manager_id, users!leases_student_id_fkey(full_name), rooms(room_number, label, accommodations(name)))',
        )
        .eq('leases.accommodation_manager_id', user.id)
        .order('month', { ascending: false }),
    ])

    const fromManager = (managerReviews ?? []).map((r) => ({
      id: r.id,
      rating: r.rating,
      comment: r.comment || '',
      createdAt: r.created_at,
      authorName: (r.users as unknown as { full_name: string | null } | null)?.full_name || 'A student',
      source: 'You',
    }))
    const fromAcc = (accReviews ?? []).map((r) => ({
      id: r.id,
      rating: r.rating,
      comment: r.comment || '',
      createdAt: r.created_at,
      authorName: (r.users as unknown as { full_name: string | null } | null)?.full_name || 'A student',
      source: (r.accommodations as unknown as { name: string | null } | null)?.name || 'A property',
    }))
    reviews.value = [...fromManager, ...fromAcc].sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))

    payments.value = (paymentRows ?? []).map((p) => {
      const lease = p.leases as unknown as {
        id: string
        users: { full_name: string | null } | null
        rooms: { room_number: string | null; label: string | null; accommodations: { name: string | null } | null } | null
      }
      const room = lease.rooms
      return {
        id: p.id,
        leaseId: lease.id,
        studentName: lease.users?.full_name || 'A student',
        roomLabel: [room?.label || (room?.room_number ? `Room ${room.room_number}` : 'Room'), room?.accommodations?.name]
          .filter(Boolean)
          .join(' · '),
        month: p.month,
        amount: Number(p.amount),
        status: p.status,
      }
    })
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.history-page {
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 10px 16px 24px;
}
.sk {
  border-radius: var(--m-radius);
}
.card {
  padding: 18px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
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

.tabs {
  border-radius: var(--m-radius);
  background: var(--m-surface);
  border: 1px solid var(--m-border);
}
.panels {
  background: transparent;
}
.panel {
  padding: 0;
}
.panel-card {
  padding: 12px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  border: 1px solid var(--m-border);
}
.empty-message {
  margin: 0;
  font-size: 13px;
  color: var(--m-muted);
  text-align: center;
  padding: 16px 0;
}

.rating-summary {
  display: flex;
  align-items: center;
  gap: 8px;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--m-border);
}
.rating-count {
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.review-row {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 8px 0;
  border-bottom: 1px solid var(--m-border);
}
.review-row:last-child {
  border-bottom: 0;
  padding-bottom: 0;
}
.review-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}
.review-author {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
}
.review-source {
  color: var(--m-muted);
  font-weight: 600;
}
.review-comment {
  margin: 0;
  color: var(--m-text);
  font-size: 12.5px;
  line-height: 1.5;
}

.pay-row {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  padding: 10px 0;
  border: 0;
  border-bottom: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.pay-row:last-child {
  border-bottom: 0;
  padding-bottom: 0;
}
.pay-avatar {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 12px;
  font-weight: 800;
}
.pay-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.pay-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.pay-sub {
  color: var(--m-muted);
  font-size: 11.5px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pay-side {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: flex-end;
  gap: 3px;
}
.pay-amount {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 14px;
  font-weight: 700;
}
.pay-chip {
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}
.pay-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.pay-chip--amber,
.pay-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.pay-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.pay-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
</style>
