<template>
  <q-page class="dash" :style-fn="fitScreen">
    <q-pull-to-refresh @refresh="onPull">
      <div v-if="loading" class="stack">
        <q-skeleton type="text" width="160px" height="26px" />
        <q-skeleton type="rect" height="132px" class="sk" />
        <q-skeleton type="rect" height="64px" class="sk" />
        <q-skeleton type="rect" height="176px" class="sk" />
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your dashboard" :detail="error" :retry="load" />
      </div>

      <div v-else class="stack">
        <!-- The one-screen rule (390x844, no scroll): greeting, hero, one action, four tiles, two properties. -->
        <h1 class="greet">{{ unverified && !verification.inReview ? 'Welcome' : 'Hi' }}, {{ firstName }}</h1>

        <!-- Unverified: where the OSAS check stands (D-LE1 / D-LE2). Verified: this month's rent (D-L5 / D-LE3). -->
        <DashHero
          v-if="unverified"
          label="OSAS verification"
          :right="verification.inReview ? `Sent ${sentLabel}` : `Step ${Math.min(verification.done + 1, 3)} of 3`"
          :big="String(verification.done)"
          of="/ 3 steps done"
          :segments="verifySegments"
          :legend="verifyLegend"
          to="/manager/osas"
        />
        <DashHero
          v-else
          :label="`${monthName} rent`"
          :right="`${daysLeft} ${daysLeft === 1 ? 'day' : 'days'} left`"
          :big="formatPeso(rent.collected)"
          :of="`/ ${formatPeso(rent.total)}`"
          :segments="[
            { value: rent.collected, tone: 'success' },
            { value: rent.coming, tone: 'info' },
            { value: rent.late, tone: 'danger' },
          ]"
          :legend="[
            { label: 'Paid', value: formatPeso(rent.collected), tone: 'success' },
            { label: 'Coming', value: formatPesoExact(rent.coming), tone: 'info' },
            { label: 'Late', value: formatPesoExact(rent.late), tone: 'danger' },
          ]"
          to="/manager/tenants?tab=payments"
        />

        <DashAction
          v-if="action"
          :icon="action.icon"
          :tone="action.tone"
          :title="action.title"
          :sub="action.sub"
          :button="action.button"
          @action="go(action.route)"
        />

        <div class="tiles">
          <component
            :is="unverified ? 'div' : 'button'"
            v-for="t in tiles"
            :key="t.label"
            :type="unverified ? undefined : 'button'"
            class="tile"
            :class="{ 'tile--off': unverified, [`tile--${t.tone}`]: !unverified && t.tone }"
            @click="unverified || go(t.route)"
          >
            <span class="tile-val">{{ t.value }}</span>
            <span class="tile-label">{{ t.label }}</span>
            <span class="tile-sub">{{ t.sub }}</span>
          </component>
        </div>

        <section class="sec" aria-labelledby="myprops">
          <div class="sec-head">
            <h2 id="myprops" class="sec-title">My properties</h2>
            <button v-if="properties.length > shownProperties.length" type="button" class="sec-link" @click="go('/manager/properties')">
              See all
            </button>
          </div>

          <div v-if="hasProperties" class="plist">
            <DashPropertyCard
              v-for="p in shownProperties"
              :key="p.id"
              :property="p"
              :paid="propRent[p.id]?.paid ?? 0"
              :due="propRent[p.id]?.due ?? 0"
              :dot="propRent[p.id]?.dot ?? false"
              @open="openProperty"
            />
          </div>

          <PropertyCard v-else-if="auth.isVerifiedLandlord" add-label="Add your first accommodation" @add="go('/manager/properties/new')" />

          <div v-else class="locked">
            <span class="locked-icon"><IconifyIcon icon="lucide:lock" width="18" /></span>
            <span class="locked-text">
              <span class="locked-title">Add property</span>
              <span class="locked-sub">After OSAS verifies you</span>
            </span>
          </div>
        </section>
      </div>
    </q-pull-to-refresh>
  </q-page>
</template>

<script setup lang="ts">
import DashAction from '@/components/shared/DashAction.vue'
import DashHero from '@/components/shared/DashHero.vue'
import DashPropertyCard from '@/components/manager/DashPropertyCard.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import PropertyCard from '@/components/manager/PropertyCard.vue'
import { computed } from 'vue'
import { formatPeso, formatPesoExact } from '@/utils/format'
import { healthTone } from '@/components/manager/property'
import { manilaToday } from '@/utils/payments'
import { monthEndOf } from '@/utils/collections'
import { shortDate } from '@/components/manager/dashboard/money'
import { useAuthStore } from '@/stores/auth'
import { verificationSteps } from '@/utils/verificationSteps'
import { useManagerDashboard } from '@/components/manager/dashboard/state'

// The data lives in components/manager/dashboard/; this page turns it into the
// hero, the action card, the tiles and the property cards.
const {
  router,
  loading,
  error,
  firstName,
  properties,
  attention,
  totalBeds,
  tenants,
  rent,
  propRent,
  lateAction,
  confirmCount,
  unpaidBills,
  applicants,
  docsSentAt,
  profileComplete,
  load,
  onPull,
} = useManagerDashboard()


// One-screen rule: the page is exactly the space between header and bottom nav
// (QPage's style-fn gets both), and the layout below flexes inside it instead of
// scrolling. The flexible card (stay / property photos) absorbs the difference.
const fitScreen = (offset: number, height: number) => ({ height: `${height - offset}px` })
const auth = useAuthStore()

interface Tile { value: string; label: string; sub: string; route: string; tone?: 'warning' | undefined }

const hasProperties = computed(() => properties.value.length > 0)
const vacantBeds = computed(() => Math.max(0, totalBeds.value - tenants.value))

// Verified accounts see the rent dashboard; everyone else sees where the OSAS
// check stands (users.status is the truth, accountStatus mirrors it). An unknown
// status (still loading, demo mode) counts as verified so nothing flashes.
const unverified = computed(() => !!auth.accountStatus && auth.accountStatus !== 'verified')
const verification = computed(() =>
  verificationSteps({
    role: 'manager',
    status: auth.accountStatus ?? '',
    docsSentAt: docsSentAt.value,
    profileComplete: profileComplete.value,
  }),
)
const sentLabel = computed(() => (docsSentAt.value ? shortDate(docsSentAt.value) : ''))
const verifySegments = computed(() => {
  const v = verification.value
  return [
    { value: v.done, tone: 'primary' },
    { value: v.inReview ? 1 : 0, tone: 'info' },
    { value: v.total - v.done - (v.inReview ? 1 : 0), tone: 'border' },
  ]
})
const verifyLegend = computed(() => {
  const v = verification.value
  return [
    { label: 'Done', value: String(v.done), tone: 'primary' },
    v.inReview
      ? { label: 'In review', value: '1', tone: 'info' }
      : { label: 'Left', value: String(v.total - v.done), tone: 'muted' },
  ]
})

const monthName = new Date().toLocaleDateString('en-PH', { month: 'long' })
const daysLeft = Math.max(0, Number(monthEndOf(manilaToday()).slice(8, 10)) - Number(manilaToday().slice(8, 10)))

// The attention list is ranked (0 = concern / hidden listings … 3 = chores). A rank-0 or
// 1 item outranks a late boarder; a late boarder outranks everything below that.
const SHORT_TONE = { danger: 'danger', warn: 'warning', info: 'info', done: 'success' } as const
const action = computed(() => {
  if (unverified.value) {
    const v = verification.value
    return v.next
      ? { icon: 'lucide:file-up', tone: 'warning', title: v.next.label, sub: 'Next step', button: 'Open', route: v.next.route }
      : { icon: 'lucide:hourglass', tone: 'info', title: 'OSAS is reviewing', sub: 'We’ll notify you', button: 'Ask OSAS', route: '/manager/support' }
  }
  const top = attention.value[0]
  const l = lateAction.value
  if (l && !(top && top.rank <= 1)) {
    return {
      icon: 'lucide:clock-alert',
      tone: 'danger',
      title: `${l.name} is ${l.days} ${l.days === 1 ? 'day' : 'days'} late`,
      sub: `${formatPeso(l.amount)} · ${l.property}`,
      button: 'Remind',
      route: `/manager/messages?to=${l.studentId}`,
    }
  }
  if (top) {
    return {
      icon: top.icon,
      tone: SHORT_TONE[top.tone],
      title: top.label,
      sub: top.kind,
      button: top.action.split(' ')[0] ?? '',
      route: top.route,
    }
  }
  const [y, m] = manilaToday().split('-').map(Number) as [number, number]
  const next = new Date(y, m, 1)
  return {
    icon: 'lucide:circle-check',
    tone: 'success',
    title: 'Nothing needs you',
    sub: `Next: ${next.toLocaleDateString('en-PH', { month: 'long' })} rent · ${next.toLocaleDateString('en-PH', { month: 'short' })} 1`,
    button: '',
    route: '',
  }
})

const todoCount = computed(() => attention.value.filter((t) => t.id !== 'payments-to-verify').length + confirmCount.value)
const tiles = computed<Tile[]>(() => {
  const off = unverified.value
  const open = vacantBeds.value
  return [
    {
      value: off ? '0' : String(todoCount.value),
      label: 'To do',
      sub: off ? 'Nothing yet' : confirmCount.value ? `${confirmCount.value} payment${confirmCount.value === 1 ? '' : 's'} to check` : todoCount.value ? 'Tap to start' : 'All done',
      route: confirmCount.value ? '/manager/tenants?tab=payments' : (attention.value[0]?.route ?? '/manager/properties'),
      tone: !off && todoCount.value ? 'warning' : undefined,
    },
    {
      value: `${tenants.value}/${totalBeds.value}`,
      label: 'Beds filled',
      sub: off || !totalBeds.value ? 'No rooms yet' : `${open} open`,
      route: '/manager/properties',
    },
    {
      value: formatPeso(unpaidBills.value.amount),
      label: 'Unpaid bills',
      sub: off ? 'No bills yet' : unpaidBills.value.sub,
      route: '/manager/tenants?tab=payments',
    },
    {
      value: String(applicants.value.count),
      label: 'Applicants',
      sub: off ? 'None yet' : applicants.value.sub,
      route: applicants.value.route,
    },
  ]
})

// Two property cards fit the screen; the rest are one tap away. Worst health first.
const HEALTH_RANK = { danger: 0, warn: 1, good: 2 } as const
const shownProperties = computed(() =>
  [...properties.value].sort((a, b) => HEALTH_RANK[healthTone(a)] - HEALTH_RANK[healthTone(b)]).slice(0, 2),
)

/** The boarder who is furthest behind, for the action card. */


function go(path: string) {
  void router.push(path)
}

function openProperty(id: string) {
  go(`/manager/properties/${id}`)
}
</script>

<style scoped>
.dash { overflow: hidden; background: var(--m-bg); }
.dash :deep(.q-pull-to-refresh),
.dash :deep(.q-pull-to-refresh__content) { height: 100%; }
.stack {
  display: flex;
  height: 100%;
  box-sizing: border-box;
  flex-direction: column;
  overflow: hidden;
  gap: 10px;
  /* Bottom room for BottomNav's raised centre button. */
  padding: 4px var(--m-page-gutter) 26px;
}
.sk { border-radius: var(--m-radius); }

.greet {
  margin: 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 22px;
  font-weight: 700;
  /* Quasar's global h1 line-height is 6rem; without this the greeting sits in a 96px band. */
  line-height: 1.2;
  letter-spacing: -0.02em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.stack > * { flex-shrink: 0; }

.tiles { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
.tile {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
  padding: 12px 14px;
  border: 0;
  border-radius: 20px;
  background: var(--m-surface);
  color: inherit;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.tile--warning { background: var(--m-warning-soft); }
.tile-val {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 24px;
  font-weight: 700;
  line-height: 1.1;
}
.tile-label { color: var(--m-ink); font-size: 14px; font-weight: 600; }
.tile-sub { overflow: hidden; color: var(--m-muted); font-size: 12.5px; text-overflow: ellipsis; white-space: nowrap; }
/* Before OSAS verifies there is nothing to count: the tiles show their shape, greyed. */
.tile--off { cursor: default; }
.tile--off .tile-val { color: var(--m-muted); opacity: 0.6; }

.stack > .sec { display: flex; flex: 1 1 auto; min-height: 0; flex-direction: column; gap: 8px; }
.sec-head { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 0 2px; }
.sec-title { margin: 0; color: var(--m-ink); font-family: var(--m-font-display); font-size: 18px; font-weight: 700; line-height: 1.2; }
.sec-link {
  min-height: 32px;
  padding: 0 8px;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.plist { display: grid; flex: 1; min-height: 0; grid-template-columns: repeat(2, minmax(0, 1fr)); grid-template-rows: minmax(0, 1fr); gap: 10px; }

.locked {
  display: flex;
  align-items: center;
  gap: 14px;
  min-height: 76px;
  padding: 0 18px;
  border: 1.5px dashed var(--m-border);
  border-radius: 20px;
}
.locked-icon { display: grid; flex: 0 0 40px; width: 40px; height: 40px; place-items: center; border-radius: 999px; background: var(--m-bg); color: var(--m-muted); }
.locked-text { display: flex; flex-direction: column; }
.locked-title { color: var(--m-ink); font-size: 15px; font-weight: 600; }
.locked-sub { color: var(--m-muted); font-size: 12.5px; }
</style>
