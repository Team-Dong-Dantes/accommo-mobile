<template>
  <q-page class="dash">
    <q-pull-to-refresh @refresh="onPull">
      <div v-if="loading" class="stack">
        <div class="greet">
          <q-skeleton type="text" width="160px" height="24px" />
        </div>
        <q-skeleton type="rect" height="190px" class="sk" />
        <q-skeleton type="rect" height="300px" class="sk" />
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your dashboard" :detail="error" :retry="load" />
      </div>

      <div v-else class="stack">
        <div class="greet">
          <span class="greet-line">
            <span class="greet-time">{{ greeting }},</span>
            <span class="greet-name">{{ firstName }}</span>
          </span>
          <span class="greet-date">{{ today }}</span>
        </div>

        <DashTasks :tasks="openTasks" :done-count="doneCount" @go="go" />

        <DashStayCard v-if="stay" :stay="stay" :manager="manager" :next="nextPayment" @go="go" @message="messageManager" />

        <div v-else class="stay stay--empty">
          <span class="stay-icon"><IconifyIcon icon="lucide:house" width="20" /></span>
          <p class="stay-name">Find a place to stay</p>
          <p class="stay-room">Your room, rent and dates land here once your landlord/landlady accepts you</p>
          <button type="button" class="stay-cta" @click="go('/student/discover')">
            Browse rooms
            <IconifyIcon icon="lucide:arrow-right" width="16" />
          </button>
        </div>
      </div>
    </q-pull-to-refresh>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { formatPeso, formatPesoExact, formatDate, formatMonth, initialsOf, landlordTitle, LANDLORD_ROLE_LABEL } from '@/utils/format'
import { BILL_TAG, isBillSettled, manilaToday, nextLedgerRent, toLedger, type LedgerRow } from '@/utils/payments'
import type { UtilityKey } from '@/utils/listings'
import { ago, listGaps, loadProfileGaps } from '@/utils/profile'
import { resolveAsset, AVATAR, CARD } from '@/utils/cloudinaryUrl'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import DashTasks from '@/components/shared/DashTasks.vue'
import DashStayCard from '@/components/student/DashStayCard.vue'
import type { Task } from '@/components/shared/dashboard'
import type { Manager, NextPayment, Stay } from '@/components/student/dashboard'

const router = useRouter()

const loading = ref(true)
const error = ref('')
const firstName = ref('there')
const stay = ref<Stay | null>(null)
const tasks = ref<Task[]>([])
const nextPayment = ref<NextPayment | null>(null)
const manager = ref<Manager | null>(null)

const greeting = computed(() => {
  const h = new Date().getHours()
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'
})

// One ranked list: DashTasks makes the most urgent open task its lead row.
// Finished tasks are kept only so the card can say how many are behind you.
const openTasks = computed(() => tasks.value.filter((t) => t.tone !== 'done'))
const doneCount = computed(() => tasks.value.length - openTasks.value.length)

const today = new Date().toLocaleDateString('en-PH', { weekday: 'short', month: 'short', day: 'numeric' })

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

function go(path: string) {
  void router.push(path)
}

// ?to= lets Messages find or create the thread with this landlord/landlady.
function messageManager() {
  const id = manager.value?.id
  void router.push(id ? `/student/messages?to=${id}` : '/student/messages')
}

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data: auth } = await authUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }

    const { data: profile } = await supabase
      .from('users')
      .select('full_name, status')
      .eq('id', user.id)
      .maybeSingle()
    firstName.value = String(profile?.full_name || 'there').split(' ')[0] || 'there'
    const verification = profile?.status || 'unverified'
    // Why OSAS put the account in this state, and what it is restricted from.
    // Its own table because only the student and OSAS may read it.
    const { data: standing } = await supabase
      .from('account_standing')
      .select('reason, restrictions')
      .eq('user_id', user.id)
      .maybeSingle()

    let ledger: LedgerRow[] = []
    // A student holds at most one live lease, so one row is enough.
    const { data: leaseRow, error: leaseError } = await supabase
      .from('leases')
      .select(
        'id, status, start_date, end_date, monthly_rent, room_id, rooms(room_number, label, monthly_rent, accommodations(id, name, landlord_id, lat, lng))',
      )
      .eq('student_id', user.id)
      .in('status', ['active', 'pending', 'leave_requested'])
      .order('start_date', { ascending: false })
      .limit(1)
      .maybeSingle()
    if (leaseError) throw leaseError

    type AccommodationEmbed = {
      id: string
      name: string
      landlord_id: string
      lat: number | null
      lng: number | null
    } | null

    if (leaseRow) {
      const room = leaseRow.rooms as unknown as {
        room_number: string | null
        label: string | null
        monthly_rent: number | null
        accommodations: AccommodationEmbed
      } | null
      const acc = room?.accommodations ?? null

      // Only the cover photo — house rules live on /student/stay, which shows
      // all of them instead of an arbitrary first three.
      let photoUrl = ''
      if (acc?.id) {
        const { data: imageRows } = await supabase
          .from('accommodation_images')
          .select('url, sort_order')
          .eq('accommodation_id', acc.id)
          .order('sort_order', { ascending: true })
          .limit(1)
        photoUrl = imageRows?.[0]?.url ? resolveAsset(imageRows[0].url, CARD) : ''
      }

      stay.value = {
        id: leaseRow.id,
        status: leaseRow.status,
        startDate: leaseRow.start_date,
        endDate: leaseRow.end_date,
        monthlyRent: Number(leaseRow.monthly_rent ?? room?.monthly_rent ?? 0),
        accommodationId: acc?.id ?? '',
        accommodationName: acc?.name || 'Your accommodation',
        roomNumber: room?.room_number ?? null,
        roomLabel: room?.label ?? null,
        lat: acc?.lat ?? null,
        lng: acc?.lng ?? null,
        photoUrl,
        moveIn: null,
      }

      // Read off the ledger. These used to come from leases.advance_paid and
      // deposit_paid, which nothing ever writes, so both read "not yet paid"
      // for every stay forever.
      if (leaseRow.status !== 'pending') {
        const { data: rows } = await supabase.rpc('lease_ledger', { p_lease: leaseRow.id })
        ledger = toLedger(rows)
        const upFront = ledger.filter((r) => r.kind === 'deposit' || (r.kind === 'rent' && r.dueDate === leaseRow.start_date))
        const due = upFront.reduce((s, r) => s + r.due, 0)
        if (due > 0.009) stay.value.moveIn = { due, left: upFront.reduce((s, r) => s + r.balance, 0) }
      }
    } else {
      stay.value = null
      manager.value = null
    }

    if (leaseRow) {
      const room = leaseRow.rooms as unknown as {
        accommodations: { landlord_id: string } | null
      } | null
      const managerId = room?.accommodations?.landlord_id

      // No rating on the landlord/landlady card. It used to average
      // `landlord_reviews` filtered to this landlord/landlady, but RLS only
      // ever returned the reviews *this student* had written — so the number
      // shown was the student's own score played back at them. Students don't
      // see ratings while browsing either, so there is nothing to replace it
      // with; the card is name, response time and the actions.
      if (managerId) {
        const [{ data: mgr }, { data: mgrProfile }] = await Promise.all([
          supabase.from('users').select('full_name, initials, avatar_url, sex').eq('id', managerId).maybeSingle(),
          supabase
            .from('landlord_profiles')
            .select('avg_response_minutes')
            .eq('user_id', managerId)
            .maybeSingle(),
        ])
        if (mgr) {
          manager.value = {
            id: managerId,
            name: mgr.full_name,
            initials: mgr.initials || initialsOf(mgr.full_name),
            avatarUrl: mgr.avatar_url ? resolveAsset(mgr.avatar_url, AVATAR) : null,
            replyMinutes: mgrProfile?.avg_response_minutes ?? null,
            title: landlordTitle(mgr.sex),
          }
        }
      }
    }

    const list: Task[] = []
    // The student's own landlord or landlady once known, else the neutral compound.
    const who = (manager.value?.title ?? LANDLORD_ROLE_LABEL).toLowerCase()

    if (standing?.restrictions?.includes('apply')) {
      list.push({
        id: 'osas-apply',
        icon: 'lucide:shield-minus',
        kind: 'OSAS',
        label: 'OSAS has paused your room applications',
        hint: standing.reason || 'Contact OSAS to sort this out',
        when: '',
        action: 'Open OSAS',
        route: '/student/support',
        tone: 'danger',
        rank: 0,
      })
    }

    // Verification: whether they must act depends on what they have already
    // submitted, so the pending documents decide the wording and the action.
    if (verification !== 'verified') {
      const { count: pendingDocs } = await supabase
        .from('verification_documents')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .eq('status', 'pending')

      if (verification === 'rejected' || verification === 'needs_resubmission' || verification === 'suspended') {
        const sentBack = verification === 'needs_resubmission'
        list.push({
          id: 'verify',
          icon: 'lucide:file-x',
          kind: 'OSAS',
          label: sentBack ? 'OSAS asked for new requirements' : verification === 'rejected' ? 'Your requirements were rejected' : 'Your account is suspended',
          hint: standing?.reason || (sentBack ? 'Upload them again to stay verified' : verification === 'rejected' ? 'Upload clearer copies to get verified' : 'Contact OSAS to sort this out'),
          when: '',
          action: verification === 'suspended' ? 'Open OSAS' : 'Re-upload requirements',
          route: '/student/support',
          tone: 'danger',
          rank: 1,
        })
      } else if (pendingDocs && pendingDocs > 0) {
        list.push({
          id: 'verify',
          icon: 'lucide:hourglass',
          kind: 'OSAS',
          label: 'OSAS is reviewing your requirements',
          hint: `${pendingDocs} ${pendingDocs === 1 ? 'requirement' : 'requirements'} submitted`,
          when: '',
          action: '',
          route: '',
          tone: 'info',
          rank: 9,
        })
      } else {
        list.push({
          id: 'verify',
          icon: 'lucide:id-card',
          kind: 'OSAS',
          label: 'Finish your OSAS verification',
          hint: 'Landlords/Landladies can only accept verified students',
          when: '',
          action: 'Upload requirements',
          route: '/student/support',
          tone: 'warn',
          rank: 2,
        })
      }
    } else {
      list.push({
        id: 'verify',
        icon: 'lucide:shield-check',
        kind: 'OSAS',
        label: 'OSAS verified',
        hint: '',
        when: '',
        action: '',
        route: '',
        tone: 'done',
        rank: 99,
      })
    }

    // Whatever is still blank on the profile — student ID (freshmen register before
    // ISU issues one), emergency contact, and sex/birth date on older accounts —
    // chased as one row that opens the step-by-step flow.
    const missing = (await loadProfileGaps(user.id, true)).filter((g) => g.needed)
    if (missing.length) {
      list.push({
        id: 'profile',
        icon: 'lucide:user-round-pen',
        kind: 'Profile',
        label: 'Complete your profile',
        hint: `Add your ${listGaps(missing)}`,
        when: '',
        action: 'Continue',
        route: '/student/profile/complete',
        tone: 'warn',
        rank: 3,
      })
    }

    if (leaseRow?.status === 'pending') {
      list.push({
        id: 'application',
        icon: 'lucide:file-clock',
        kind: 'Application',
        label: `Your ${who} is reviewing your application`,
        hint: 'You will be told as soon as they decide',
        when: '',
        action: '',
        route: '',
        tone: 'info',
        rank: 8,
      })
    }

    if (stay.value) {
      const moveIn = stay.value.moveIn
      if (moveIn) {
        const paid = moveIn.left <= 0.009
        list.push({
          id: 'move-in',
          icon: paid ? 'lucide:check-circle' : 'lucide:circle-dashed',
          kind: 'Move-in',
          label: 'Advance and deposit',
          hint: paid ? 'Paid' : `${formatPesoExact(moveIn.left)} of ${formatPesoExact(moveIn.due)} left`,
          when: '',
          action: paid ? '' : 'Pay now',
          route: '/student/payments',
          tone: paid ? 'done' : 'warn',
          rank: paid ? 99 : 2,
        })
      }

      // The countdown lives on the stay card; this row exists only once the
      // renewal window opens and there is actually something to do about it.
      const end = new Date(stay.value.endDate).getTime()
      const daysLeft = Number.isNaN(end) ? null : Math.ceil((end - Date.now()) / 86400000)
      if (stay.value.status === 'active' && daysLeft !== null && daysLeft >= 0 && daysLeft <= 30) {
        list.push({
          id: 'renewal',
          icon: 'lucide:calendar-clock',
          kind: 'Lease',
          label: `Your lease ends in ${daysLeft} ${daysLeft === 1 ? 'day' : 'days'}`,
          hint: `Talk to your ${who} if you want to renew`,
          when: '',
          action: `Message ${who}`,
          route: '/student/messages',
          tone: 'warn',
          rank: 5,
        })
      }
    }

    if (leaseRow) {
      // Concerns the student filed against this stay, and any reply.
      const { data: concernRows } = await supabase
        .from('concerns')
        .select('id, category, status, reported_at, manager_response')
        .eq('lease_id', leaseRow.id)
        .neq('status', 'resolved')
        .order('reported_at', { ascending: false })
        .limit(4)

      for (const c of concernRows || []) {
        const answered = Boolean(c.manager_response)
        list.push({
          id: `concern-${c.id}`,
          icon: answered ? 'lucide:message-square-reply' : 'lucide:triangle-alert',
          kind: 'Your report',
          label: answered
            ? `Your ${who} replied about ${(titleCase(c.category) || 'your report').toLowerCase()}`
            : `${titleCase(c.category) || 'Concern'} still open`,
          hint: answered ? 'Read the reply and close it off' : `Waiting on your ${who}`,
          when: ago(c.reported_at),
          action: answered ? 'Read reply' : '',
          route: '/student/concerns',
          tone: answered ? 'warn' : 'info',
          rank: answered ? 3 : 7,
        })
      }

      // A payment that is merely due is shown by the stay card's money strip, which is
      // tappable — only an overdue one is a task. Read off the ledger: this
      // used to look for payments rows with status due/overdue, which nothing
      // has written since record_payments, so it always said "Nothing due".
      const due = nextLedgerRent(ledger)
      nextPayment.value = due?.month
        ? { amount: due.balance, month: due.month, overdue: due.state === 'overdue' }
        : null

      // Utility bills the landlord/landlady posted and nobody has paid yet.
      const { data: billRows } = await supabase
        .from('utility_bills')
        .select('id, utility, month, amount, due_date, payments(status, amount)')
        .eq('lease_id', leaseRow.id)
      for (const b of billRows ?? []) {
        if (isBillSettled(b.payments, Number(b.amount))) continue
        const overdue = b.due_date < manilaToday()
        list.push({
          id: `bill-${b.id}`,
          icon: 'lucide:receipt',
          kind: 'Utilities',
          label: `${BILL_TAG[b.utility as UtilityKey]} · ${formatPesoExact(Number(b.amount || 0))}`,
          hint: `${formatMonth(b.month)} · ${overdue ? 'overdue since' : 'due'} ${formatDate(b.due_date)}`,
          when: '',
          action: 'Pay now',
          route: '/student/payments',
          tone: overdue ? 'danger' : 'warn',
          rank: overdue ? 0 : 1,
        })
      }

      if (due?.month && due.state === 'overdue') {
        list.push({
          id: `payment-${due.month}`,
          icon: 'lucide:banknote',
          kind: 'Rent',
          label: `${formatPeso(due.balance)} is overdue`,
          hint: `Rent for ${formatMonth(due.month)}`,
          when: '',
          action: 'Pay now',
          route: '/student/payments',
          tone: 'danger',
          rank: 0,
        })
      }
    } else {
      nextPayment.value = null
    }

    // Unread messages from the landlord/landlady.
    const { data: convos } = await supabase
      .from('conversations')
      .select('user_a_id, user_b_id, unread_a, unread_b')
      .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
    const unread = (convos || []).reduce((n, c) => {
      const mine = c.user_a_id === user.id ? c.unread_a : c.unread_b
      return n + Number(mine || 0)
    }, 0)
    if (unread > 0) {
      list.push({
        id: 'unread',
        icon: 'lucide:message-circle',
        kind: 'Messages',
        label: `${unread} unread ${unread === 1 ? 'message' : 'messages'}`,
        hint: `From your ${who}`,
        when: '',
        action: 'Open messages',
        route: '/student/messages',
        tone: 'warn',
        rank: 4,
      })
    }

    tasks.value = list.sort((a, b) => a.rank - b.rank)
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

// Kept alive across tab switches (see MainLayout's KEEP_ALIVE_PAGES), so the
// database pushes lease changes here instead of the page re-asking on every
// return. utils/useLiveData.ts owns the whole policy — first load, the
// subscription's lifetime, and how stale the data may be on return.
// Only the low-stakes fields are cached to disk — stay/nextPayment carry
// rent and payment amounts, same bar that keeps StudentStayPage out of this
// entirely (see persistCache.ts). Those two stay RAM-only and just show
// their loading state again on a fresh launch.
type DashboardCache = { firstName: string; tasks: Task[]; manager: Manager | null }

const { refresh } = useLiveData({
  key: 'student-dashboard',
  load,
  watch: (uid) => [{ table: 'leases', filter: `student_id=eq.${uid}` }],
  cache: {
    get: (): DashboardCache => ({ firstName: firstName.value, tasks: tasks.value, manager: manager.value }),
    set: (d) => {
      const c = d as DashboardCache
      firstName.value = c.firstName
      tasks.value = c.tasks
      manager.value = c.manager
      loading.value = false
    },
  },
})

// Pull-to-refresh goes through useLiveData's refresh rather than load(): it
// loads silently (no skeleton behind the spinner) and resets the freshness
// clock, so returning to the screen does not immediately fetch again.
function onPull(done: () => void) {
  void refresh().finally(done)
}
</script>

<style scoped>
/* One type scale: 12 / 13 / 15 / 20. */
.dash { background: var(--m-bg); }
.stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 8px var(--m-page-gutter) 20px;
}
.sk { border-radius: var(--m-radius); }

.greet { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; padding: 4px 2px 0; }
.greet-line { display: flex; min-width: 0; flex-wrap: wrap; align-items: baseline; gap: 6px; }
.greet-time { color: var(--m-muted); font-size: 15px; font-weight: 500; }
.greet-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.greet-date { flex: 0 0 auto; color: var(--m-muted); font-size: 12px; font-weight: 600; }

/* Stay (empty state) */
.stay { display: flex; flex-direction: column; padding: 16px 14px; border-radius: var(--m-radius); }
.stay--empty { border: 1px dashed var(--m-border); background: var(--m-surface); color: var(--m-ink); }
.stay-icon { display: grid; width: 40px; height: 40px; place-items: center; border-radius: 999px; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.stay-name {
  margin: 12px 0 0;
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
}
.stay-room { margin: 4px 0 0; color: var(--m-muted); font-size: 13px; line-height: 1.4; }
.stay-cta {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 8px;
  min-height: 44px;
  margin-top: 14px;
  padding: 0 18px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 15px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
</style>
