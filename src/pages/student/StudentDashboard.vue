<template>
  <q-page class="dash" :style-fn="fitScreen">
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
import DashAction from '@/components/shared/DashAction.vue'
import DashHero from '@/components/shared/DashHero.vue'
import { type DashTile } from '@/components/student/dashboard'
import DashTiles from '@/components/student/DashTiles.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import { type Task } from '@/components/shared/dashboard'
import { computed } from 'vue'
import { formatDate, formatPeso, formatPesoExact } from '@/utils/format'
import { manilaToday } from '@/utils/payments'
import { stayMonthSummary } from '@/utils/collections'
import { verificationSteps } from '@/utils/verificationSteps'
import { useStudentHome } from '@/components/student/home/state'

// The data lives in components/student/home/; this page turns it into the
// hero, the action card and the tiles.
const {
  router,
  loading,
  error,
  firstName,
  stay,
  tasks,
  nextPayment,
  manager,
  ver,
  stayLedger,
  unread,
  past,
  load,
  onPull,
} = useStudentHome()

// One-screen rule: the page is exactly the space between header and bottom nav
// (QPage's style-fn gets both), and the layout below flexes inside it instead of
// scrolling. The flexible card (stay / property photos) absorbs the difference.
const fitScreen = (offset: number, height: number) => ({ height: `${height - offset}px` })

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
      big: formatPesoExact(sent),
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


function go(path: string) {
  void router.push(path)
}

</script>

<style scoped>
/* One screen at 390x844: greeting, hero, action, stay row, two tiles — no scroll. */
.dash { overflow: hidden; background: var(--m-bg); }
.dash :deep(.q-pull-to-refresh),
.dash :deep(.q-pull-to-refresh__content) { height: 100%; }
.stack {
  display: flex;
  height: 100%;
  box-sizing: border-box;
  flex-direction: column;
  overflow: hidden;
  gap: 12px;
  /* Bottom room for BottomNav's raised centre button. */
  padding: 8px var(--m-page-gutter) 26px;
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
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.stack > * { flex-shrink: 0; }
</style>
