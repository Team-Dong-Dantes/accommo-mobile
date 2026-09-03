<template>
  <q-page class="dash-page">
    <main class="dash-shell" aria-label="Student dashboard">
      <div v-if="loading" class="dash-state" role="status" aria-live="polite">
        <q-spinner color="primary" size="32px" />
        <span>Loading your stay…</span>
      </div>

      <div v-else-if="error" class="dash-state dash-state--error" role="alert">
        <IconifyIcon icon="lucide:circle-alert" width="26" />
        <strong>Couldn’t load your dashboard</strong>
        <span>{{ error }}</span>
        <q-btn outline no-caps color="primary" label="Try again" @click="load" />
      </div>

      <template v-else>
        <!-- Briefing (manager-dashboard style) -->
        <section class="manager-briefing" aria-labelledby="dash-title">
          <div class="dashboard-intro">
            <div>
              <h1 id="dash-title">{{ greeting }}{{ firstName ? `, ${firstName}` : '' }}.</h1>
              <p>{{ lease ? `${accommodationName} · ${roomLabel}` : 'No active stay yet' }}</p>
            </div>
          </div>

          <div class="portfolio-pulse" aria-labelledby="pulse-title">
            <div class="portfolio-pulse__main">
              <span class="portfolio-pulse__eyebrow">Rent dues</span>
              <strong id="pulse-title">{{ oweAmountText }}</strong>
              <div class="portfolio-pulse__meter" aria-hidden="true"><span :style="{ width: `${leaseProgress}%` }" /></div>
              <p>{{ lease ? `${daysLeftLabel} on lease` : 'Find a verified place to board' }}</p>
            </div>
            <div class="portfolio-pulse__payments">
              <span>Rent status</span>
              <strong :class="{ 'portfolio-pulse__warning': hasOverdue || owedTotal > 0 }">{{ oweStatus }}</strong>
              <small :class="{ 'portfolio-pulse__warning': hasOverdue }">{{ oweDetail }}</small>
            </div>
          </div>
        </section>

        <!-- No lease -->
        <template v-if="!lease">
          <section class="state-empty">
            <span class="state-empty-icon"><IconifyIcon icon="lucide:bed-double" width="26" /></span>
            <h2>No active stay yet</h2>
            <p>Browse verified accommodations and find a room near ISU Echague.</p>
            <q-btn unelevated no-caps class="primary-button full" @click="goDiscover">
              <IconifyIcon icon="lucide:search" width="17" /> Discover accommodations
            </q-btn>
          </section>

          <nav class="quick-links" aria-label="Shortcuts">
            <button type="button" @click="goPayments"><span class="action-icon"><IconifyIcon icon="lucide:wallet-cards" width="20" /></span><span>Payments</span></button>
            <button type="button" @click="goSupport"><span class="action-icon"><IconifyIcon icon="lucide:life-buoy" width="20" /></span><span>Support</span></button>
          </nav>
        </template>

        <!-- Lease: pay + overview -->
        <template v-else>
          <!-- Dues attention -->
          <section class="dash-block" aria-labelledby="attention-title">
            <div class="dash-block-head">
              <p class="dash-kicker">Action queue</p>
              <h2 id="attention-title">Needs your attention</h2>
            </div>
            <div v-if="owedTotal > 0" class="due-card" :class="{ 'due-card--overdue': hasOverdue }">
              <span class="due-icon" aria-hidden="true"><IconifyIcon :icon="hasOverdue ? 'lucide:circle-alert' : 'lucide:calendar-clock'" width="20" /></span>
              <div class="due-copy">
                <strong>{{ hasOverdue ? 'Rent payment overdue' : 'Rent payment due' }}</strong>
                <small>{{ formatPeso(owedTotal) }}<template v-if="nextMonthLabel"> · {{ nextMonthLabel }}</template></small>
              </div>
              <q-btn unelevated no-caps class="primary-button" @click="goPayments">Pay now</q-btn>
            </div>
            <div v-else class="all-clear surface">
              <span class="all-clear-icon" aria-hidden="true"><IconifyIcon icon="lucide:circle-check" width="20" /></span>
              <div><h3>You are all caught up</h3><p>No outstanding rent. Payments are up to date.</p></div>
            </div>
          </section>

          <!-- At a glance -->
          <section class="dash-block" aria-labelledby="glance-title">
            <div class="dash-block-head">
              <p class="dash-kicker">Your numbers</p>
              <h2 id="glance-title">At a glance</h2>
            </div>
            <div class="glance-grid">
              <article class="glance-tile"><span>Monthly rent</span><strong>{{ monthlyRent }}</strong></article>
              <article class="glance-tile"><span>Days left</span><strong>{{ daysNumber }}</strong><small>on lease</small></article>
              <article class="glance-tile"><span>Room</span><strong>{{ shortRoom }}</strong></article>
            </div>
          </section>

          <!-- Quick links -->
          <nav class="quick-links" aria-label="Shortcuts">
            <button type="button" @click="goPayments"><span class="action-icon"><IconifyIcon icon="lucide:wallet-cards" width="20" /></span><span>Payments</span></button>
            <button type="button" @click="goDiscover"><span class="action-icon"><IconifyIcon icon="lucide:search" width="20" /></span><span>Find rooms</span></button>
            <button type="button" @click="goStay"><span class="action-icon"><IconifyIcon icon="lucide:door-open" width="20" /></span><span>My stay</span></button>
          </nav>
        </template>
      </template>
    </main>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { supabase } from '@/shared/utils/supabase'

interface LeaseRow { id: string; status: string; start_date: string | null; end_date: string | null; monthly_rent: number | null; room: { room_number: string | null; accommodation: { name: string | null } | null } | null }
interface PaymentRow { amount: number; status: string; month: string | null }

const router = useRouter()
const $q = useQuasar()
const loading = ref(true)
const error = ref<string | null>(null)
const lease = ref<LeaseRow | null>(null)
const firstName = ref('')
const dues = ref<PaymentRow[]>([])

const greeting = computed(() => {
  const h = new Date().getHours()
  if (h < 12) return 'Good morning'
  if (h < 18) return 'Good afternoon'
  return 'Good evening'
})

const accommodationName = computed(() => lease.value?.room?.accommodation?.name ?? 'Your accommodation')
const roomLabel = computed(() => (lease.value?.room?.room_number ? `Room ${lease.value.room.room_number}` : ''))
const shortRoom = computed(() => (lease.value?.room?.room_number ? lease.value.room.room_number : '—'))
const monthlyRent = computed(() => formatPeso(lease.value?.monthly_rent ?? 0))
const daysNumber = computed(() => {
  if (!lease.value?.end_date) return 0
  return Math.max(0, Math.ceil((new Date(lease.value.end_date).getTime() - Date.now()) / 86400000))
})
const daysLeftLabel = computed(() => {
  if (!lease.value?.end_date) return '—'
  const days = daysNumber.value
  if (days === 0) return 'Ends today'
  return `${days} day${days === 1 ? '' : 's'} left`
})
const leaseProgress = computed(() => {
  if (!lease.value?.start_date || !lease.value.end_date) return 0
  const start = new Date(lease.value.start_date).getTime()
  const end = new Date(lease.value.end_date).getTime()
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return 0
  return Math.min(100, Math.max(0, Math.round(((Date.now() - start) / (end - start)) * 100)))
})

const owedTotal = computed(() => dues.value.filter((p) => p.status === 'overdue' || p.status === 'due').reduce((s, p) => s + (Number(p.amount) || 0), 0))
const hasOverdue = computed(() => dues.value.some((p) => p.status === 'overdue'))
const oweAmountText = computed(() => formatPeso(owedTotal.value))
const oweStatus = computed(() => (owedTotal.value > 0 ? (hasOverdue.value ? 'Overdue' : 'Due') : 'Up to date'))
const oweDetail = computed(() => (owedTotal.value > 0 ? (hasOverdue.value ? 'Settle now to keep your stay active.' : 'Settle before the due date.') : 'No outstanding balance'))
const nextMonthLabel = computed(() => {
  const next = dues.value.find((p) => p.status === 'overdue' || p.status === 'due')
  return next?.month ? formatMonth(next.month) : ''
})

function formatPeso(v: number | null | undefined): string {
  return '₱' + (Number(v) || 0).toLocaleString('en-PH', { maximumFractionDigits: 0 })
}
function formatMonth(value: string): string {
  const d = new Date(`${value}-01T00:00:00`)
  return Number.isNaN(d.getTime()) ? value : d.toLocaleDateString('en-PH', { month: 'long', year: 'numeric' })
}

async function load() {
  loading.value = true
  error.value = null
  try {
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError) throw authError
    if (!user) { void router.push('/login'); return }
    const meta = user.user_metadata as Record<string, unknown> | undefined
    firstName.value = (typeof meta?.full_name === 'string' ? meta.full_name : '') || ''

    const { data: leaseRow } = await (supabase as any)
      .from('leases')
      .select('id, status, start_date, end_date, monthly_rent, room:rooms(room_number, accommodation:accommodations(name))')
      .eq('student_id', user.id)
      .in('status', ['active', 'leave_requested'])
      .maybeSingle()
    if (!leaseRow) { lease.value = null; dues.value = []; return }
    lease.value = leaseRow as LeaseRow

    const { data: payRows } = await supabase
      .from('payments')
      .select('amount, status, month')
      .eq('lease_id', lease.value.id)
      .in('status', ['due', 'overdue'])
    dues.value = (payRows ?? []) as PaymentRow[]
  } catch (caught) {
    error.value = caught instanceof Error ? caught.message : 'Failed to load dashboard'
  } finally {
    loading.value = false
  }
}

function goDiscover() { void router.push('/student/discover') }
function goPayments() { void router.push('/student/payments') }
function goStay() { void router.push('/student/stay') }
function goSupport() { void router.push('/student/support') }

onMounted(() => void load())
</script>

<style scoped>
.dash-page { min-height: 100%; background: var(--m-bg); color: var(--m-text); }
.dash-shell { width: min(100%, 760px); margin: 0 auto; padding: max(var(--m-space-3), env(safe-area-inset-top)) var(--m-page-gutter) calc(var(--m-space-8) + env(safe-area-inset-bottom)); }
.dash-state { display: grid; min-height: 45vh; place-items: center; align-content: center; gap: 10px; color: var(--m-muted); text-align: center; }
.dash-state--error { color: var(--m-danger); }

/* Briefing (manager dashboard style) */
.manager-briefing { overflow: hidden; border-radius: 14px; background: #0e2e2a; color: #eaf4f1; margin-bottom: var(--m-space-4); }
.dashboard-intro { padding: var(--m-space-4); }
.dashboard-intro h1 { margin: 0; color: #eaf4f1; font-family: var(--m-font-display); font-size: clamp(23px, 7vw, 31px); font-weight: 700; letter-spacing: -0.04em; line-height: 1.05; text-wrap: balance; }
.dashboard-intro > div > p:last-child { margin: var(--m-space-2) 0 0; color: rgba(234,244,241,.7); font-family: var(--m-font-mono); font-size: 10px; font-weight: 600; letter-spacing: .025em; overflow-wrap: anywhere; }
.portfolio-pulse { display: grid; grid-template-columns: minmax(0,1fr) minmax(122px,.7fr); border-top: 1px solid rgba(234,244,241,.14); background: #0b2421; color: #eaf4f1; }
.portfolio-pulse__main, .portfolio-pulse__payments { display: grid; align-content: center; padding: var(--m-space-4); }
.portfolio-pulse__main { gap: 6px; }
.portfolio-pulse__eyebrow, .portfolio-pulse__payments span { color: rgba(255,255,255,.7); font-size: 10px; font-weight: 800; letter-spacing: .07em; text-transform: uppercase; }
.portfolio-pulse__main strong { font-family: var(--m-font-display); font-size: clamp(23px,7vw,31px); font-weight: 700; letter-spacing: -.045em; line-height: 1; }
.portfolio-pulse__main p, .portfolio-pulse__payments small { margin: 0; color: rgba(255,255,255,.75); font-size: 11px; line-height: 1.35; }
.portfolio-pulse__meter { height: 5px; overflow: hidden; border-radius: 999px; background: rgba(255,255,255,.2); }
.portfolio-pulse__meter span { display: block; height: 100%; border-radius: inherit; background: #fff; }
.portfolio-pulse__payments { gap: 6px; border-left: 1px solid rgba(255,255,255,.22); }
.portfolio-pulse__payments strong { font-family: var(--m-font-display); font-size: 16px; font-weight: 700; letter-spacing: -.025em; }
.portfolio-pulse__warning { color: #fde68a; }

/* Sections */
.dash-block { margin-bottom: var(--m-space-4); }
.dash-block-head { margin-bottom: var(--m-space-3); }
.dash-kicker { margin: 0 0 2px; color: var(--m-muted); font-size: 10px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; }
.dash-block-head h2 { margin: 0; color: var(--m-ink); font-size: 18px; font-weight: 700; line-height: 1.25; }
.surface { overflow: hidden; border: 1px solid var(--m-border); border-radius: 12px; background: var(--m-surface); }

.due-card { display: flex; align-items: center; gap: var(--m-space-3); padding: var(--m-space-4); border: 1px solid var(--m-border); border-radius: 12px; background: var(--m-warning-soft); }
.due-card--overdue { background: var(--m-danger-soft); border-color: color-mix(in srgb, var(--m-danger) 28%, var(--m-border)); }
.due-icon { display: grid; width: 40px; height: 40px; flex: 0 0 auto; place-items: center; border-radius: 10px; background: var(--m-surface); color: var(--m-warning); }
.due-card--overdue .due-icon { color: var(--m-danger); }
.due-copy { display: flex; min-width: 0; flex: 1; flex-direction: column; }
.due-copy strong { color: var(--m-ink); font-size: 14px; font-weight: 800; }
.due-copy small { color: var(--m-muted); font-size: 12px; }
.primary-button { min-height: 44px; padding: 0 16px; border: 0; border-radius: 8px; background: var(--m-primary-dark); color: #fff; font-size: 13px; font-weight: 800; }
.all-clear { display: flex; align-items: center; gap: var(--m-space-3); padding: var(--m-space-4); }
.all-clear-icon { display: grid; width: 38px; height: 38px; flex: 0 0 auto; place-items: center; border-radius: 9px; background: var(--m-success-soft); color: var(--m-success); }
.all-clear h3 { margin: 0; color: var(--m-ink); font-size: 14px; font-weight: 800; }
.all-clear p { margin: 3px 0 0; color: var(--m-muted); font-size: 12px; }

.glance-grid { display: grid; grid-template-columns: repeat(3, minmax(0,1fr)); gap: var(--m-space-2); }
.glance-tile { min-width: 0; padding: var(--m-space-3); border: 1px solid var(--m-border); border-radius: 10px; background: var(--m-surface); }
.glance-tile span { display: block; color: var(--m-muted); font-size: 9px; font-weight: 800; letter-spacing: .04em; text-transform: uppercase; }
.glance-tile strong { display: block; margin-top: 4px; overflow: hidden; color: var(--m-ink); font-family: var(--m-font-display); font-size: 18px; font-weight: 800; line-height: 1.1; text-overflow: ellipsis; white-space: nowrap; }
.glance-tile small { display: block; margin-top: 3px; color: var(--m-muted); font-size: 10px; }

.quick-links { display: grid; grid-template-columns: repeat(3, minmax(0,1fr)); gap: var(--m-space-2); }
.quick-links button { display: flex; min-width: 0; min-height: 84px; align-items: center; justify-content: center; flex-direction: column; gap: 8px; padding: 10px; border: 1px solid var(--m-border); border-radius: 12px; background: var(--m-surface); color: var(--m-ink); cursor: pointer; font: inherit; font-size: 11px; font-weight: 700; }
.quick-links button:only-of-type:last-child { grid-column: span 1; }
.action-icon { display: grid; width: 40px; height: 40px; place-items: center; border-radius: 10px; background: var(--m-primary-soft); color: var(--m-primary-dark); }

/* No lease */
.state-empty { display: flex; align-items: center; flex-direction: column; gap: 8px; padding: var(--m-space-8) var(--m-space-5); margin-bottom: var(--m-space-4); border: 1px solid var(--m-border); border-radius: 14px; background: var(--m-surface); text-align: center; }
.state-empty-icon { display: grid; width: 56px; height: 56px; place-items: center; border-radius: 14px; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.state-empty h2 { margin: 4px 0 0; color: var(--m-ink); font-size: 18px; }
.state-empty p { margin: 0; color: var(--m-muted); font-size: 13px; line-height: 1.5; }
.full { width: 100%; }
</style>
