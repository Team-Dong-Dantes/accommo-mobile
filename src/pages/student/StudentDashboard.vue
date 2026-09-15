<template>
  <q-page class="dash">
    <q-pull-to-refresh @refresh="onPull">
      <div v-if="loading" class="stack">
        <div class="greet">
          <q-skeleton type="text" width="60px" height="17px" />
          <q-skeleton type="text" width="100px" height="20px" />
        </div>
        <q-skeleton type="rect" height="150px" class="sk" />
        <q-skeleton type="rect" height="60px" class="sk" />
        <section class="sec">
          <q-skeleton type="text" width="60px" height="16px" />
          <q-skeleton type="rect" height="42px" class="sk-sm" />
          <q-skeleton type="rect" height="42px" class="sk-sm" />
        </section>
        <q-skeleton type="rect" height="180px" class="sk" />
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your dashboard" :detail="error" :retry="load" />
      </div>

      <div v-else class="stack">
        <div class="greet">
          <span class="greet-time">{{ greeting }},</span>
          <span class="greet-name">{{ firstName }}</span>
        </div>

        <DashPriority :task="priority" @go="go" />

        <button v-if="stay" type="button" class="money" @click="go('/student/payments')">
          <span class="money-cell">
            <span class="money-value">{{ formatPeso(stay.monthlyRent) }}<span class="money-unit">/mo</span></span>
            <span class="money-cap">Rent</span>
          </span>
          <span class="money-div" />
          <span class="money-cell">
            <span class="money-value" :class="{ 'money-value--due': nextPayment?.overdue }">
              {{ nextPayment ? formatPeso(nextPayment.amount) : 'None' }}
            </span>
            <span class="money-cap">{{ nextDueLabel }}</span>
          </span>
          <IconifyIcon icon="lucide:chevron-right" width="17" class="money-chev" />
        </button>

        <DashTodoList :tasks="todo" :done-count="doneCount" @go="go" />

        <DashStayCard v-if="stay" :stay="stay" :manager="manager" @go="go" @message="messageManager" />

        <div v-else class="stay stay--empty">
          <span class="stay-cap">No stay yet</span>
          <p class="stay-name">Find a place to stay</p>
          <p class="stay-room">Your room, rent and dates land here once a manager accepts you</p>
          <button type="button" class="stay-cta" @click="go('/student/discover')">
            Browse rooms
            <IconifyIcon icon="lucide:arrow-right" width="15" />
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
import { formatPeso, formatMonth, initialsOf } from '@/utils/format'
import { ago } from '@/utils/profile'
import { resolveAsset, AVATAR, CARD } from '@/utils/cloudinaryUrl'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import DashPriority from '@/components/shared/DashPriority.vue'
import DashTodoList from '@/components/shared/DashTodoList.vue'
import DashStayCard from '@/components/student/DashStayCard.vue'
import type { Task } from '@/components/shared/dashboard'
import type { Manager, Stay } from '@/components/student/dashboard'

interface NextPayment {
  amount: number
  month: string
  overdue: boolean
}

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

// One ranked list feeds both slots: the most urgent open task becomes the
// priority card, everything else below it is the to-do list. Finished tasks
// are kept only so the list can say how many are behind you.
const openTasks = computed(() => tasks.value.filter((t) => t.tone !== 'done'))
const priority = computed(() => openTasks.value[0] ?? null)
const todo = computed(() => openTasks.value.slice(1))
const doneCount = computed(() => tasks.value.length - openTasks.value.length)

const nextDueLabel = computed(() => {
  const p = nextPayment.value
  if (!p) return 'Nothing due'
  const month = formatMonth(p.month)
  return p.overdue ? `Overdue · ${month}` : `Due · ${month}`
})

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

function go(path: string) {
  void router.push(path)
}

// ?to= lets Messages find or create the thread with this manager.
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

    // A student holds at most one live lease, so one row is enough.
    const { data: leaseRow, error: leaseError } = await supabase
      .from('leases')
      .select(
        'id, status, start_date, end_date, monthly_rent, room_id, advance_paid, deposit_paid, rooms(room_number, label, monthly_rent, accommodations(id, name, accommodation_manager_id, lat, lng))',
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
      accommodation_manager_id: string
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
        advancePaid: Boolean(leaseRow.advance_paid),
        depositPaid: Boolean(leaseRow.deposit_paid),
      }
    } else {
      stay.value = null
      manager.value = null
    }

    if (leaseRow) {
      const room = leaseRow.rooms as unknown as {
        accommodations: { accommodation_manager_id: string } | null
      } | null
      const managerId = room?.accommodations?.accommodation_manager_id

      // No rating on the manager card. It used to average
      // `accommodation_manager_reviews` filtered to this manager, but RLS only
      // ever returned the reviews *this student* had written — so the number
      // shown was the student's own score played back at them. Students don't
      // see ratings while browsing either, so there is nothing to replace it
      // with; the card is name, response time and the actions.
      if (managerId) {
        const [{ data: mgr }, { data: mgrProfile }] = await Promise.all([
          supabase.from('users').select('full_name, initials, avatar_url').eq('id', managerId).maybeSingle(),
          supabase
            .from('accommodation_manager_profiles')
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
          }
        }
      }
    }

    const list: Task[] = []

    // Verification: whether they must act depends on what they have already
    // submitted, so the pending documents decide the wording and the action.
    if (verification !== 'verified') {
      const { count: pendingDocs } = await supabase
        .from('verification_documents')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .eq('status', 'pending')

      if (verification === 'rejected' || verification === 'suspended') {
        list.push({
          id: 'verify',
          icon: 'lucide:file-x',
          kind: 'OSAS',
          label: verification === 'rejected' ? 'Your documents were rejected' : 'Your account is suspended',
          hint: verification === 'rejected' ? 'Upload clearer copies to get verified' : 'Contact OSAS to sort this out',
          when: '',
          action: verification === 'rejected' ? 'Re-upload documents' : 'Open OSAS',
          route: '/student/support',
          tone: 'danger',
          rank: 1,
        })
      } else if (pendingDocs && pendingDocs > 0) {
        list.push({
          id: 'verify',
          icon: 'lucide:hourglass',
          kind: 'OSAS',
          label: 'OSAS is reviewing your documents',
          hint: `${pendingDocs} ${pendingDocs === 1 ? 'document' : 'documents'} submitted`,
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
          hint: 'Managers can only accept verified students',
          when: '',
          action: 'Upload documents',
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

    if (leaseRow?.status === 'pending') {
      list.push({
        id: 'application',
        icon: 'lucide:file-clock',
        kind: 'Application',
        label: 'Your manager is reviewing your application',
        hint: 'You will be told as soon as they decide',
        when: '',
        action: '',
        route: '',
        tone: 'info',
        rank: 8,
      })
    }

    if (stay.value) {
      for (const p of [
        { id: 'deposit', label: 'Security deposit', paid: stay.value.depositPaid },
        { id: 'advance', label: 'Advance payment', paid: stay.value.advancePaid },
      ]) {
        list.push({
          id: p.id,
          icon: p.paid ? 'lucide:check-circle' : 'lucide:circle-dashed',
          kind: 'Move-in',
          label: p.label,
          hint: p.paid ? 'Paid' : 'Not yet recorded as paid',
          when: '',
          action: p.paid ? '' : 'Pay now',
          route: '/student/payments',
          tone: p.paid ? 'done' : 'warn',
          rank: p.paid ? 99 : 2,
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
          hint: 'Talk to your manager if you want to renew',
          when: '',
          action: 'Message manager',
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
            ? `Your manager replied about ${(titleCase(c.category) || 'your report').toLowerCase()}`
            : `${titleCase(c.category) || 'Concern'} still open`,
          hint: answered ? 'Read the reply and close it off' : 'Waiting on your manager',
          when: ago(c.reported_at),
          action: answered ? 'Read reply' : '',
          route: '/student/concerns',
          tone: answered ? 'warn' : 'info',
          rank: answered ? 3 : 7,
        })
      }

      // A payment that is merely due is shown by the money row, which is
      // tappable — only an overdue one is a task.
      const { data: dueRows } = await supabase
        .from('payments')
        .select('id, amount, month, status')
        .eq('lease_id', leaseRow.id)
        .in('status', ['due', 'overdue'])
        .order('month', { ascending: true })
        .limit(1)

      const due = dueRows?.[0]
      nextPayment.value = due
        ? { amount: Number(due.amount || 0), month: due.month, overdue: due.status === 'overdue' }
        : null

      if (due && due.status === 'overdue') {
        list.push({
          id: `payment-${due.id}`,
          icon: 'lucide:banknote',
          kind: 'Rent',
          label: `${formatPeso(Number(due.amount || 0))} is overdue`,
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

    // Unread messages from the manager.
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
        hint: 'From your accommodation manager',
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
const { refresh } = useLiveData({
  key: 'student-dashboard',
  load,
  watch: (uid) => [{ table: 'leases', filter: `student_id=eq.${uid}` }],
})

// Pull-to-refresh goes through useLiveData's refresh rather than load(): it
// loads silently (no skeleton behind the spinner) and resets the freshness
// clock, so returning to the screen does not immediately fetch again.
function onPull(done: () => void) {
  void refresh().finally(done)
}
</script>

<style scoped>
.dash { background: var(--m-bg); }
.stack {
  display: flex;
  flex-direction: column;
  gap: 7px;
  padding: 5px var(--m-page-gutter) 16px;
}
.sk { border-radius: var(--m-radius); }
.sk-sm { border-radius: var(--m-radius-sm); }
.sec { display: flex; flex-direction: column; gap: 5px; }

.greet { display: flex; align-items: baseline; gap: 5px; padding: 0 2px; flex-wrap: wrap; }
.greet-time { color: var(--m-muted); font-size: 15px; font-weight: 500; }
.greet-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.02em;
}

/* Money row — rent and what's next, in one place */
.money {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 9px 8px 9px 4px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: center;
  -webkit-tap-highlight-color: transparent;
}
.money-cell { display: flex; flex: 1 1 0; min-width: 0; flex-direction: column; gap: 1px; padding: 0 6px; }
.money-div { width: 1px; align-self: stretch; background: var(--m-border); }
.money-value {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.money-value--due { color: var(--m-danger); }
.money-unit { font-size: 11px; font-weight: 600; color: var(--m-muted); }
.money-cap { color: var(--m-muted); font-size: 10.5px; font-weight: 600; }
.money-chev { flex: 0 0 auto; color: var(--m-muted); }

/* Stay (empty state) */
.stay { display: flex; flex-direction: column; padding: 12px 13px; border-radius: var(--m-radius); }
.stay--empty { border: 1px dashed var(--m-border); background: var(--m-surface); color: var(--m-ink); }
.stay-cap { font-size: 11px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; color: var(--m-muted); }
.stay-name {
  margin: 5px 0 0;
  font-family: var(--m-font-display);
  font-size: 19px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.15;
}
.stay-room { margin: 2px 0 0; font-size: 12.5px; color: var(--m-muted); }
.stay-cta {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 6px;
  min-height: 44px;
  margin-top: 11px;
  padding: 0 15px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
</style>
