<template>
  <q-page class="dash">
    <q-pull-to-refresh @refresh="onPull">
      <div v-if="loading" class="stack">
        <q-skeleton type="text" width="160px" height="28px" />
        <q-skeleton type="rect" height="150px" class="sk" />
        <q-skeleton type="rect" height="64px" class="sk" />
        <q-skeleton type="rect" height="250px" class="sk" />
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your dashboard" :detail="error" :retry="load" />
      </div>

      <!-- Four states, one layout (D-S5, D-SE1..3): verified with a stay, verified
           and all paid, verification not started, verification in review. The
           hero and the one action card change; the tiles keep their places. -->
      <div v-else class="stack">
        <h1 class="greet">{{ welcome ? 'Welcome' : 'Hi' }}, {{ firstName }}</h1>

        <DashHero v-bind="hero" />
        <DashAction v-bind="action.card" @action="go(action.route)" />

        <DashTiles :stay="stay" :manager="manager" :unread="unread" :empty-hint="emptyHint" :browse-hint="browseHint" :tiles="tiles" @go="go" />
      </div>
    </q-pull-to-refresh>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { formatPeso, formatPesoExact, formatDate, formatMonth, initialsOf, landlordTitle, LANDLORD_ROLE_LABEL } from '@/utils/format'
import { BILL_TAG, isBillSettled, manilaToday, nextLedgerRent, toLedger, type LedgerRow } from '@/utils/payments'
import type { UtilityKey } from '@/utils/listings'
import { ago, listGaps, loadProfileGaps } from '@/utils/profile'
import { resolveAsset, AVATAR, CARD } from '@/utils/cloudinaryUrl'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import DashHero from '@/components/shared/DashHero.vue'
import DashAction from '@/components/shared/DashAction.vue'
import DashTiles from '@/components/student/DashTiles.vue'
import type { Task } from '@/components/shared/dashboard'
import type { DashTile, Manager, NextPayment, Stay } from '@/components/student/dashboard'
import { stayMonthSummary } from '@/utils/collections'
import { verificationSteps } from '@/utils/verificationSteps'

const router = useRouter()

const loading = ref(true)
const error = ref('')
const firstName = ref('there')
const stay = ref<Stay | null>(null)
const tasks = ref<Task[]>([])
const nextPayment = ref<NextPayment | null>(null)
const manager = ref<Manager | null>(null)

// What the verification hero and the OSAS tile are drawn from. Cached with the
// rest: it is status and dates only, nothing financial.
const ver = ref({ status: 'unverified', docsSentAt: null as string | null, profileComplete: true, since: null as string | null })
const stayLedger = ref<LedgerRow[]>([])
// Unread messages: from this stay's landlord/landlady when there is one, else from anyone.
const unread = ref(0)
const past = ref<{ count: number; unrated: string | null }>({ count: 0, unrated: null })

const verified = computed(() => ver.value.status === 'verified')
const steps = computed(() =>
  verificationSteps({ role: 'student', status: ver.value.status, docsSentAt: ver.value.docsSentAt, profileComplete: ver.value.profileComplete }),
)
// Brand-new account: nothing sent, no stay.
const welcome = computed(() => !stay.value && steps.value.done === 1 && !steps.value.inReview)

// One ranked list; the most urgent open task is the action card.
const openTasks = computed(() => tasks.value.filter((t) => t.tone !== 'done'))

const monthName = new Date().toLocaleDateString('en-PH', { month: 'long' })

// Hero: the stay's month while verified with a stay, otherwise the verification steps.
const hero = computed(() => {
  if (verified.value && stay.value) {
    if (stay.value.status === 'pending') {
      return { label: 'Application', right: 'Sent', big: 'Pending', segments: [{ value: 1, tone: 'info' }], legend: [{ label: 'Waiting on', value: 'your landlord/landlady', tone: 'info' }], to: '/student/stay' }
    }
    const m = stayMonthSummary(stayLedger.value, manilaToday())
    const sent = m.collected + m.toConfirm
    const toPay = m.overdue + m.toCome
    const clear = toPay < 0.01
    return {
      label: monthName,
      right: clear ? 'All paid' : `${formatPeso(toPay)} to pay`,
      big: formatPeso(sent),
      of: `/ ${formatPeso(sent + toPay)} ${clear ? 'paid' : 'sent'}`,
      segments: [
        { value: sent, tone: clear ? 'success' : 'info' },
        { value: m.toCome, tone: 'warning' },
        { value: m.overdue, tone: 'danger' },
      ],
      legend: [
        { label: clear ? 'Paid' : 'Sent', value: formatPeso(sent), tone: clear ? 'success' : 'info' },
        { label: 'To pay', value: formatPeso(toPay), tone: m.overdue > 0 ? 'danger' : 'warning' },
      ],
      to: '/student/payments',
    }
  }
  const { done, inReview } = steps.value
  const sent = ver.value.docsSentAt ? new Date(ver.value.docsSentAt).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }) : ''
  const left = 3 - done - (inReview ? 1 : 0)
  return {
    label: 'OSAS verification',
    right: verified.value ? 'Verified' : inReview ? `Sent ${sent}` : `Step ${Math.min(done + 1, 3)} of 3`,
    big: String(done),
    of: '/ 3 steps done',
    segments: [
      ...Array.from({ length: done }, () => ({ value: 1, tone: 'primary' })),
      ...(inReview ? [{ value: 1, tone: 'info' }] : []),
      ...Array.from({ length: left }, () => ({ value: 1, tone: 'border' })),
    ],
    legend: [
      { label: 'Done', value: String(done), tone: 'primary' },
      inReview ? { label: 'In review', value: '1', tone: 'info' } : { label: 'Left', value: String(left), tone: 'muted' },
    ],
    to: '/student/support',
  }
})

const TASK_TONE = { danger: 'danger', warn: 'warning', info: 'info', done: 'success' } as const

const action = computed(() => {
  const top = openTasks.value[0]
  const fromTask = (t: Task) => ({
    card: {
      icon: t.icon,
      tone: TASK_TONE[t.tone],
      title: t.label,
      sub: t.hint,
      // The card is short; a long action label ("Re-upload requirements") is just "Open".
      button: t.route ? (t.action && t.action.length <= 9 ? t.action : 'Open') : '',
    },
    route: t.route,
  })
  // Before verification only an urgent task (OSAS pause, rejected papers) outranks the next step.
  if (top && (verified.value || top.rank <= 1)) return fromTask(top)
  if (!verified.value) {
    const next = steps.value.next
    if (next) return { card: { icon: 'lucide:user-round', tone: 'warning', title: next.label, sub: 'Next step', button: 'Start' }, route: next.route }
    return { card: { icon: 'lucide:clock', tone: 'info', title: 'OSAS is reviewing', sub: 'We\u2019ll notify you', button: 'Ask OSAS' }, route: '/student/support' }
  }
  if (!stay.value) {
    return { card: { icon: 'lucide:search', tone: 'primary', title: 'You\u2019re verified', sub: 'Find a place to stay', button: 'Browse' }, route: '/student/discover' }
  }
  const n = nextPayment.value
  const sub = n ? `Next: ${new Date(n.month).toLocaleDateString('en-PH', { month: 'long' })} rent${n.dueDate ? ` \u00b7 ${formatDate(n.dueDate)}` : ''}` : 'Nothing due'
  return { card: { icon: 'lucide:check', tone: 'success', title: 'You\u2019re all caught up', sub, button: '' }, route: '' }
})

const emptyHint = computed(() => (verified.value ? 'Apply to a room you like' : steps.value.inReview ? 'Apply once you\u2019re verified' : 'Shows here once a landlord accepts you'))
const browseHint = computed(() => (steps.value.inReview ? 'While you wait' : 'Look around now'))

const tiles = computed<DashTile[]>(() => {
  const v = ver.value.status
  const osas: DashTile = verified.value
    ? { icon: 'lucide:shield-check', tone: 'success', title: 'OSAS verified', sub: ver.value.since ? `Since ${new Date(ver.value.since).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' })}` : 'Verified', route: '/student/support' }
    : steps.value.inReview
      ? { icon: 'lucide:shield-check', tone: 'info', title: 'OSAS', sub: 'In review', route: '/student/support' }
      : { icon: 'lucide:shield-check', tone: v === 'unverified' ? 'muted' : 'danger', title: 'OSAS', sub: v === 'unverified' ? 'Not verified yet' : 'Needs attention', route: '/student/support' }
  const p = past.value
  const history: DashTile = p.unrated
    ? { icon: 'lucide:star', tone: 'warning', title: `Rate ${p.unrated}`, sub: 'Your last stay', route: '/student/profile/history' }
    : p.count > 0
      ? { icon: 'lucide:history', tone: 'primary', title: 'History', sub: `${p.count} past ${p.count === 1 ? 'stay' : 'stays'}`, route: '/student/profile/history' }
      : { icon: 'lucide:star', tone: 'muted', title: 'Ratings', sub: 'Nothing to rate', route: '/student/profile/history' }
  return [osas, history]
})

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

function go(path: string) {
  void router.push(path)
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

    // Latest upload = "Sent Oct 13" on the verification hero; the pending ones decide
    // the wording of the OSAS task below. osas_verified_at feeds the OSAS tile.
    const [{ data: docs }, { data: sp }] = await Promise.all([
      supabase.from('verification_documents').select('status, uploaded_at').eq('user_id', user.id).order('uploaded_at', { ascending: false }),
      supabase.from('student_profiles').select('osas_verified_at').eq('user_id', user.id).maybeSingle(),
    ])
    const docRows = docs ?? []

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
      const pendingDocs = docRows.filter((d) => d.status === 'pending').length

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
      } else if (pendingDocs > 0) {
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
    ver.value = { status: verification, docsSentAt: docRows[0]?.uploaded_at ?? null, profileComplete: missing.length === 0, since: sp?.osas_verified_at ?? null }
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
        ? { amount: due.balance, month: due.month, dueDate: due.dueDate, overdue: due.state === 'overdue' }
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
    stayLedger.value = ledger

    // Unread messages from the landlord/landlady.
    const { data: convos } = await supabase
      .from('conversations')
      .select('user_a_id, user_b_id, unread_a, unread_b')
      .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
    const totalUnread = (convos || []).reduce((n, c) => {
      const mine = c.user_a_id === user.id ? c.unread_a : c.unread_b
      return n + Number(mine || 0)
    }, 0)
    unread.value = leaseRow && manager.value
      ? (convos || []).filter((c) => c.user_a_id === manager.value?.id || c.user_b_id === manager.value?.id).reduce((n, c) => n + Number((c.user_a_id === user.id ? c.unread_a : c.unread_b) || 0), 0)
      : totalUnread
    if (totalUnread > 0) {
      list.push({
        id: 'unread',
        icon: 'lucide:message-circle',
        kind: 'Messages',
        label: `${totalUnread} unread ${totalUnread === 1 ? 'message' : 'messages'}`,
        hint: `From your ${who}`,
        when: '',
        action: 'Open messages',
        route: '/student/messages',
        tone: 'warn',
        rank: 4,
      })
    }

    // Past stays for the History / "Rate X" tile. Ended leases the student has
    // not reviewed yet (accommodation or landlord review) are what "Rate" waits on.
    const [{ data: endedLeases }, { data: written }] = await Promise.all([
      supabase
        .from('leases')
        .select('id, rooms(accommodations(name))')
        .eq('student_id', user.id)
        .in('status', ['ended', 'terminated'])
        .order('end_date', { ascending: false }),
      supabase.from('review_written_leases').select('lease_id').in('kind', ['accommodation', 'manager']),
    ])
    const reviewed = new Set((written ?? []).map((r) => r.lease_id))
    const unrated = (endedLeases ?? []).find((l) => !reviewed.has(l.id))
    past.value = {
      count: endedLeases?.length ?? 0,
      unrated: unrated ? (unrated.rooms as unknown as { accommodations: { name: string } | null } | null)?.accommodations?.name ?? 'your last stay' : null,
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
type DashboardCache = { firstName: string; tasks: Task[]; manager: Manager | null; ver: typeof ver.value }

const { refresh } = useLiveData({
  key: 'student-dashboard',
  load,
  watch: (uid) => [{ table: 'leases', filter: `student_id=eq.${uid}` }],
  cache: {
    get: (): DashboardCache => ({ firstName: firstName.value, tasks: tasks.value, manager: manager.value, ver: ver.value }),
    set: (d) => {
      const c = d as DashboardCache
      firstName.value = c.firstName
      tasks.value = c.tasks
      manager.value = c.manager
      if (c.ver) ver.value = c.ver
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
/* One screen at 390x844: greeting, hero, action, stay row, two tiles — no scroll. */
.dash { background: var(--m-bg); }
.stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 8px var(--m-page-gutter) 12px;
}
.sk { border-radius: var(--m-radius); }
.greet {
  margin: 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 22px;
  font-weight: 700;
  line-height: 1.2;
}
</style>
